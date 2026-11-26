import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campaigns.dart';
import 'offline_storage.dart';
import 'session_dates.dart';

const notebookRequestTimeout = Duration(seconds: 12);

bool isConnectionFailure(Object error) =>
    error is ClientException ||
    error is TimeoutException ||
    error is PostgrestException &&
        const {
          '502',
          '503',
          '504',
          'PGRST000',
          'PGRST001',
          'PGRST002',
          'PGRST003',
        }.contains(error.code);

enum DraftStatus { editing, queued, review }

class NotebookDraft {
  const NotebookDraft({
    required this.id,
    required this.category,
    required this.epoch,
    required this.text,
    this.dates,
    this.original,
    this.status = DraftStatus.editing,
    this.message,
    this.remote,
  });

  factory NotebookDraft.fromJson(Map<String, dynamic> data) => NotebookDraft(
    id: data['id'] as String,
    category: data['category'] as String,
    epoch: data['epoch'] as int,
    text: CampaignRecord.fromJson(data['text'] as Map<String, dynamic>).text,
    dates: data['dates'] == null ? null : readSessionDates(data['dates']),
    original: data['original'] == null
        ? null
        : CampaignRecord.fromJson(data['original'] as Map<String, dynamic>),
    status: DraftStatus.values.byName(data['status'] as String),
    message: data['message'] as String?,
    remote: data['remote'] == null
        ? null
        : CampaignRecord.fromJson(data['remote'] as Map<String, dynamic>),
  );

  final String id;
  final String category;
  final int epoch;
  final NotebookText text;
  final List<String>? dates;
  final CampaignRecord? original;
  final DraftStatus status;
  final String? message;
  final CampaignRecord? remote;

  bool get isSession => category == 'Sessão';

  NotebookDraft withStatus(DraftStatus status, [NotebookConflict? conflict]) =>
      NotebookDraft(
        id: id,
        category: category,
        epoch: epoch,
        text: text,
        dates: dates,
        original: original,
        status: status,
        message: conflict?.message,
        remote: conflict?.current,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'category': category,
    'epoch': epoch,
    'text': {
      'title': text.title,
      'body': text.body,
      'answer': text.answer,
      'confidence': text.confidence,
    },
    'original': original?.toJson(),
    'dates': dates,
    'status': status.name,
    'message': message,
    'remote': remote?.toJson(),
  };
}

class NotebookSync extends ChangeNotifier {
  NotebookSync({
    required this.repository,
    required this.campaignId,
    required this.storage,
    required this.isCurrentAccount,
  });

  final CampaignRepository repository;
  final String campaignId;
  final OfflineStorage storage;
  final bool Function() isCurrentAccount;

  String get _cacheKey => 'notebook/$campaignId';
  String get _draftKey => 'drafts/$campaignId';

  bool _disposed = false;
  bool _ready = false;
  bool _draftsLoaded = false;
  bool _localError = false;
  bool _offline = false;
  String? _error;
  Notebook? _notebook;
  Map<String, NotebookDraft> _drafts = {};
  Future<void> _writes = Future.value();
  Future<void>? _refreshing;

  bool get offline => _offline;
  String? get error => _error;
  bool get localError => _localError;
  Notebook? get notebook => _notebook;
  Iterable<NotebookDraft> get drafts => _drafts.values;
  bool get _active => !_disposed && isCurrentAccount();

  Future<void> load() async {
    try {
      final cache = await storage.read(_cacheKey);
      if (!_active) return;
      if (cache != null && cache != 'null') {
        _notebook = Notebook.fromRpc(jsonDecode(cache));
      }
    } catch (_) {
      _localError = true;
    }
    try {
      final entries = await storage.read(_draftKey);
      if (!_active) return;
      if (entries != null) {
        _drafts = {
          for (final data in jsonDecode(entries) as List)
            data['id'] as String: NotebookDraft.fromJson(
              data as Map<String, dynamic>,
            ),
        };
      }
      _draftsLoaded = true;
    } catch (_) {
      if (!_active) return;
      _localError = true;
    }
    if (!_active) return;
    _ready = true;
    notifyListeners();
    await refresh();
  }

  Future<void> keep(NotebookDraft draft) => _changeDrafts((drafts) {
    drafts[draft.id] = draft;
  });

  Future<void> discard(String id) =>
      _changeDrafts((drafts) => drafts.remove(id));

  Future<void> _changeDrafts(void Function(Map<String, NotebookDraft>) update) {
    final operation = _writes.then((_) async {
      if (!_active) return;
      if (!_draftsLoaded) {
        throw const FormatException(
          'Os rascunhos locais não puderam ser lidos.',
        );
      }
      final next = Map.of(_drafts);
      update(next);
      await storage.write(
        _draftKey,
        jsonEncode(next.values.map((draft) => draft.toJson()).toList()),
      );
      if (!_active) return;
      _drafts = next;
      _localError = false;
      notifyListeners();
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        if (_active) {
          _localError = true;
          notifyListeners();
        }
      },
    );
    return operation;
  }

  Future<void> refresh() {
    if (!_active || !_ready) return Future.value();
    return _refreshing ??= _sync().whenComplete(() => _refreshing = null);
  }

  Future<void> refreshAfterChange() async {
    await _refreshing;
    await refresh();
  }

  Future<void> _sync() async {
    try {
      final previous = _notebook;
      final remote = await _read();
      if (!_active) return;
      _offline = false;
      _error = null;
      _notebook = remote;
      notifyListeners();
      if (!identical(previous, remote)) await _cache(remote);
      for (final draft in _drafts.values.toList()) {
        if (!_active) return;
        if (draft.status == DraftStatus.queued) await _send(draft);
      }
    } on Exception catch (error) {
      if (!_active) return;
      if (error is PostgrestException &&
          const {'42501', 'PGRST301', 'PGRST303'}.contains(error.code)) {
        _notebook = null;
        _offline = false;
        _error = 'O acesso ao caderno precisa ser confirmado pela sua conta.';
        notifyListeners();
        await _cache(null);
      } else if (isConnectionFailure(error)) {
        _offline = true;
        _error = _notebook == null
            ? 'Abra a campanha com internet para fazer a primeira cópia.'
            : null;
      } else {
        _error = 'Não foi possível atualizar o caderno.';
      }
      if (_active) notifyListeners();
    }
  }

  Future<Notebook> _read() => repository
      .readNotebook(campaignId, known: _notebook)
      .timeout(notebookRequestTimeout);

  Future<void> _cache(Notebook? notebook) async {
    try {
      await storage.write(_cacheKey, jsonEncode(notebook?.toJson()));
    } catch (_) {
      if (_active) {
        _localError = true;
        notifyListeners();
      }
    }
  }

  Future<void> _send(NotebookDraft draft) async {
    if (!identical(_drafts[draft.id], draft)) return;
    try {
      final base = _notebook!;
      if (base.epoch != draft.epoch) {
        throw const NotebookConflict(
          'A campanha foi reiniciada. Confira o rascunho antes de criar outro registro.',
        );
      }
      await repository
          .saveNotebookRecord(
            campaignId: campaignId,
            notebook: base,
            id: draft.id,
            category: draft.category,
            text: draft.text,
            original: draft.original,
            dates: draft.dates,
          )
          .timeout(notebookRequestTimeout);
      if (!_active) return;
      final remote = await _read();
      if (!_active) return;
      _notebook = remote;
      notifyListeners();
      await _cache(remote);
      if (remote.epoch != draft.epoch) {
        throw const NotebookConflict(
          'A campanha foi reiniciada. Seu texto está no rascunho.',
        );
      }
      if (!(draft.isSession ? remote.sessions : remote.records).any(
        (record) => record.id == draft.id,
      )) {
        throw const NotebookConflict(
          'O registro deixou de aparecer na campanha. Seu texto está no rascunho.',
        );
      }
      await discard(draft.id);
    } on NotebookConflict catch (error) {
      await keep(draft.withStatus(DraftStatus.review, error));
    } on PostgrestException catch (error) {
      if (error.code != '22023' && error.code != '23514') rethrow;
      await keep(
        draft.withStatus(
          DraftStatus.review,
          const NotebookConflict(
            'O servidor recusou esses dados. Revise o texto antes de reenviar.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
