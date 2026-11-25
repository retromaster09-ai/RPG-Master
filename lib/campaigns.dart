import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Campaign {
  const Campaign({required this.id, required this.name, required this.ownerId});

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['created_by'] as String,
  );

  final String id;
  final String name;
  final String ownerId;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'created_by': ownerId,
  };
}

typedef CampaignMember = ({String name, bool isOwner});
typedef CampaignAccess = ({bool codeEnabled, List<CampaignMember> members});

final campaignCodePattern = RegExp(r'^[a-zA-Z0-9_-]{10,48}$');
final campaignInvitePattern = RegExp(r'^[a-fA-F0-9]{64}$');

class CampaignJoinException implements Exception {
  const CampaignJoinException(this.status);

  final String status;
}

class CampaignRecord {
  const CampaignRecord(
    this.title,
    this.body, {
    this.id,
    this.answer = '',
    this.category,
    this.confidence,
  });

  factory CampaignRecord.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final body = json['body'];
    final answer = json['answer'];
    final category = json['category'];
    final confidence = json['confidence'];
    return CampaignRecord(
      title is String ? title : '',
      body is String ? body : '',
      id: json['id'] is String ? json['id'] as String : null,
      answer: answer is String ? answer : '',
      category: category is String && category.isNotEmpty ? category : null,
      confidence:
          confidence is String &&
              confidence.isNotEmpty &&
              confidence != 'Não se aplica'
          ? confidence
          : null,
    );
  }

  final String title;
  final String body;
  final String? id;
  final String answer;
  final String? category;
  final String? confidence;

  NotebookText get text => (
    title: title,
    body: body,
    answer: answer,
    confidence: confidence ?? 'Não se aplica',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'answer': answer,
    'category': category,
    'confidence': confidence,
  };
}

typedef NotebookText = ({
  String title,
  String body,
  String answer,
  String confidence,
});

String newNotebookRecordId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class Notebook {
  const Notebook._(
    this.records,
    this.sessions,
    this._entries,
    this._revision,
    this._epoch,
  );

  factory Notebook.fromRpc(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['entries'] is! List ||
        data['revision'] is! int ||
        data['epoch'] is! int) {
      throw const FormatException('Formato do caderno não reconhecido.');
    }
    final entries = <Map<String, dynamic>>[];
    final records = <CampaignRecord>[];
    final sessions = <CampaignRecord>[];
    for (final item in data['entries'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Registro do caderno inválido.');
      }
      entries.add(Map.unmodifiable(item));
      if (item['deletedAt'] != null) continue;
      final record = CampaignRecord.fromJson(item);
      if (record.title.isEmpty &&
          record.body.isEmpty &&
          record.answer.isEmpty) {
        throw const FormatException('Conteúdo do registro não reconhecido.');
      }
      (record.category == 'Sessão' ? sessions : records).add(record);
    }
    return Notebook._(
      List.unmodifiable(records),
      List.unmodifiable(sessions),
      List.unmodifiable(entries),
      data['revision'] as int,
      data['epoch'] as int,
    );
  }

  final List<CampaignRecord> records;
  final List<CampaignRecord> sessions;
  final List<Map<String, dynamic>> _entries;
  final int _revision;
  final int _epoch;

  int get epoch => _epoch;

  Map<String, Object> toJson() => {
    'entries': _entries,
    'revision': _revision,
    'epoch': _epoch,
  };
}

class NotebookConflict implements Exception {
  const NotebookConflict(this.message, {this.current});

  final String message;
  final CampaignRecord? current;
}

enum GmSection {
  idea('Ideias'),
  scene('Cenas'),
  backstage('Bastidores');

  const GmSection(this.label);

  final String label;
}

enum GmNoteKind {
  note('Nota', 'Notas'),
  character('Personagem', 'Personagens'),
  kingdom('Reino', 'Reinos'),
  organization('Organização', 'Organizações');

  const GmNoteKind(this.label, this.plural);

  final String label;
  final String plural;
}

typedef GmNoteText = ({
  String title,
  String body,
  GmSection section,
  GmNoteKind kind,
  String? coverHash,
});

final _gmCoverHash = RegExp(r'^[0-9a-f]{64}$');

class GmNoteConflict implements Exception {
  const GmNoteConflict();
}

class GmNote {
  GmNote._(this._row);

  final Map<String, dynamic> _row;

  String get id => _row['id'] as String;
  int get revision => _row['revision'] as int;

  Map<String, dynamic> get _presentation =>
      _row['presentation'] as Map<String, dynamic>? ?? const {};

  GmNoteText get text {
    final cover = _presentation['cover'];
    final kind = GmNoteKind.values
        .where((kind) => kind.name == _presentation['entryKind'])
        .firstOrNull;
    return (
      title: _row['title'] as String,
      body: _row['body'] as String,
      section: GmSection.values.byName(_row['section'] as String),
      kind: kind ?? GmNoteKind.note,
      coverHash: cover is String && _gmCoverHash.hasMatch(cover) ? cover : null,
    );
  }

  Map<String, dynamic> _payload(GmNoteText draft) {
    final before = text;
    final presentation = _presentation;
    return {
      ..._newGmNotePayload(draft),
      for (final key in ['state', 'tags', 'cue', 'music', 'next_session'])
        key: _row[key],
      if (draft.kind != before.kind ||
          draft.coverHash != before.coverHash ||
          (draft.body != before.body && presentation.containsKey('marks')))
        'presentation': {
          ..._gmPresentation(draft),
          ...presentation,
          'entryKind': draft.kind.name,
          'cover': draft.coverHash,
          if (draft.body != before.body)
            'marks': _moveUnchangedMarks(
              presentation['marks'],
              before.body,
              draft.body,
            ),
        },
    };
  }
}

Map<String, Object?> _gmPresentation(GmNoteText draft) => {
  'entryKind': draft.kind.name,
  'paper': 'Leitura simples',
  'marks': <Object>[],
  'cover': draft.coverHash,
  'coverLook': {
    'shape': 'rounded',
    'fill': true,
    'border': false,
    'zoom': 1,
    'x': 0,
    'y': 0,
  },
  'pictures': <Object>[],
};

Map<String, Object> _newGmNotePayload(GmNoteText draft) => {
  'title': draft.title.trim(),
  'body': draft.body,
  'section': draft.section.name,
  'state': 'idea',
  'tags': '',
  'cue': '',
  'music': '',
  'next_session': false,
};

class CampaignRepository {
  CampaignRepository(this._client);

  final SupabaseClient _client;

  Future<List<Campaign>> list() async {
    final rows = await _client
        .from('rpg_campaigns')
        .select('id, name, created_by')
        .order('name');
    return rows.map(Campaign.fromJson).toList(growable: false);
  }

  Future<void> createCampaign(String id, String name) async {
    await _client.rpc<String>(
      'rpg_create_campaign_with_id',
      params: {'p_id': id, 'p_name': name},
    );
  }

  Future<void> joinCampaign(String code) async {
    if (campaignInvitePattern.hasMatch(code)) {
      await _client.rpc<String>('rpg_join_campaign', params: {'p_token': code});
      return;
    }
    final result = await _client.rpc<String>(
      'rpg_join_campaign_code',
      params: {'p_code': code},
    );
    if (result != 'joined') throw CampaignJoinException(result);
  }

  Future<CampaignAccess> readAccess(Campaign campaign) async {
    _requireCampaignOwner(campaign);
    final data = await _client.rpc<Map<String, dynamic>>(
      'rpg_campaign_access',
      params: {'p_campaign': campaign.id},
    );
    return (
      codeEnabled: data['codeEnabled'] as bool,
      members: [
        for (final member in data['members'] as List)
          (name: member['name'] as String, isOwner: member['role'] == 'gm'),
      ],
    );
  }

  Future<void> setCampaignCode(Campaign campaign, String? code) async {
    _requireCampaignOwner(campaign);
    await _client.rpc<bool>(
      'rpg_set_campaign_code',
      params: {'p_campaign': campaign.id, 'p_code': code},
    );
  }

  Future<String> createCampaignInvite(Campaign campaign) {
    _requireCampaignOwner(campaign);
    return _client.rpc<String>(
      'rpg_create_invite',
      params: {'p_campaign': campaign.id},
    );
  }

  Future<Notebook> readNotebook(String campaignId, {Notebook? known}) async {
    final data = await _client.rpc<Object?>(
      'rpg_poll_notebook_v3',
      params: {'p_campaign': campaignId, 'p_known': known?._revision ?? -1},
    );
    if (known != null &&
        data is Map<String, dynamic> &&
        data['entries'] == null) {
      if (data['revision'] == known._revision &&
          data['epoch'] == known._epoch) {
        return known;
      }
      return readNotebook(campaignId);
    }
    return Notebook.fromRpc(data);
  }

  Future<void> saveNotebookRecord({
    required String campaignId,
    required Notebook notebook,
    required String id,
    required String category,
    required NotebookText text,
    CampaignRecord? original,
  }) async {
    if (original != null && original.id != id) {
      throw ArgumentError('O registro editado precisa ter o mesmo ID.');
    }
    final author = _client.auth.currentUser?.id;
    var latest = notebook;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_client.auth.currentUser?.id != author) {
        throw const AuthException('A conta mudou durante o envio.');
      }
      if (latest._epoch != notebook._epoch) {
        throw const NotebookConflict(
          'A campanha foi reiniciada durante a edição.',
        );
      }
      final entries = [...latest._entries];
      final index = entries.indexWhere((entry) => entry['id'] == id);
      if (original == null) {
        if (index >= 0) {
          final existing = CampaignRecord.fromJson(entries[index]);
          if (entries[index]['deletedAt'] == null &&
              existing.text == text &&
              existing.category == category) {
            return;
          }
          throw NotebookConflict(
            'Este registro já foi criado e mudou no servidor.',
            current: existing,
          );
        }
        entries.add(_newEntry(id, category, text));
      } else {
        if (index < 0 || entries[index]['deletedAt'] != null) {
          throw const NotebookConflict(
            'Este registro foi removido durante a edição.',
          );
        }
        final merged = _mergeEntry(entries[index], original.text, text);
        if (merged.isEmpty) return;
        entries[index] = {...entries[index], ...merged};
      }
      final revision = await _client.rpc<int?>(
        'rpg_try_save_notebook_v3',
        params: {
          'p_campaign': campaignId,
          'p_expected': latest._revision,
          'p_epoch': latest._epoch,
          'p_entries': entries,
        },
      );
      if (revision != null) return;
      if (attempt < 2) latest = await readNotebook(campaignId);
    }
    throw const NotebookConflict(
      'O caderno continua mudando. Tente salvar novamente.',
    );
  }

  Future<List<GmNote>> readGmNotes(Campaign campaign) async {
    _requireCampaignOwner(campaign);
    // O Supabase deve autorizar esta RPC mesmo quando chamada fora do app.
    final rows = await _client.rpc<List<dynamic>>(
      'rpg_gm_list_v2',
      params: {'p_campaign': campaign.id},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .where((row) => row['deleted_at'] == null)
        .map(GmNote._)
        .toList(growable: false);
  }

  Future<void> saveGmNote({
    required Campaign campaign,
    required String id,
    required GmNoteText draft,
    GmNote? original,
  }) async {
    _requireCampaignOwner(campaign);
    if (original != null && original.id != id) {
      throw ArgumentError('A nota editada precisa ter o mesmo ID.');
    }
    final revision = await _client.rpc<int?>(
      'rpg_try_save_gm_note',
      params: {
        'p_campaign': campaign.id,
        'p_id': id,
        'p_expected': original?.revision ?? 0,
        'p_note':
            original?._payload(draft) ??
            {
              ..._newGmNotePayload(draft),
              if (draft.kind != GmNoteKind.note || draft.coverHash != null)
                'presentation': _gmPresentation(draft),
            },
      },
    );
    if (revision != null) return;
    final notes = await readGmNotes(campaign);
    final saved = notes.where((note) => note.id == id).firstOrNull;
    if (saved?.text !=
        (
          title: draft.title.trim(),
          body: draft.body,
          section: draft.section,
          kind: draft.kind,
          coverHash: draft.coverHash,
        )) {
      throw const GmNoteConflict();
    }
  }

  Future<Uint8List> readGmCover(Campaign campaign, String hash) {
    _requireCampaignOwner(campaign);
    if (!_gmCoverHash.hasMatch(hash)) throw ArgumentError.value(hash, 'hash');
    return _client.storage
        .from('rpg-gm-private')
        .download('${campaign.id}/$hash.png');
  }

  Future<String> uploadGmCover(Campaign campaign, Uint8List png) async {
    _requireCampaignOwner(campaign);
    final hash = sha256.convert(png).toString();
    try {
      await _client.storage
          .from('rpg-gm-private')
          .uploadBinary(
            '${campaign.id}/$hash.png',
            png,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
    } on StorageException catch (error) {
      if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
    }
    return hash;
  }

  void _requireCampaignOwner(Campaign campaign) {
    if (_client.auth.currentUser?.id != campaign.ownerId) {
      throw StateError('O roteiro está reservado ao criador da campanha.');
    }
  }
}

Map<String, Object> _mergeEntry(
  Map<String, dynamic> entry,
  NotebookText original,
  NotebookText draft,
) {
  final current = CampaignRecord.fromJson(entry);
  final remote = current.text;
  final changes = <String, Object>{};

  for (final (name, label, before, saved, desired) in [
    ('title', 'o título', original.title, remote.title, draft.title),
    ('body', 'o texto', original.body, remote.body, draft.body),
    ('answer', 'a resposta', original.answer, remote.answer, draft.answer),
    (
      'confidence',
      'a confiança',
      original.confidence,
      remote.confidence,
      draft.confidence,
    ),
  ]) {
    if (desired == before || desired == saved) continue;
    if (saved != before) {
      throw NotebookConflict(
        'Outra pessoa alterou $label deste registro. Seu rascunho continua aberto.',
        current: current,
      );
    }
    changes[name] = desired;
    if (name == 'body' || name == 'answer') {
      final marksKey = '${name}Marks';
      changes[marksKey] = _moveUnchangedMarks(entry[marksKey], saved, desired);
    }
  }
  return changes;
}

List<Object?> _moveUnchangedMarks(Object? value, String old, String updated) {
  if (value is! List || value.isEmpty) return const [];
  final shortest = min(old.length, updated.length);
  var prefix = 0;
  while (prefix < shortest &&
      old.codeUnitAt(prefix) == updated.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shortest - prefix &&
      old.codeUnitAt(old.length - suffix - 1) ==
          updated.codeUnitAt(updated.length - suffix - 1)) {
    suffix++;
  }
  final shift = updated.length - old.length;
  return [
    for (final mark in value)
      if (mark case {'start': final int start, 'end': final int end})
        if (end <= prefix)
          mark
        else if (start >= old.length - suffix)
          {...mark, 'start': start + shift, 'end': end + shift},
  ];
}

Map<String, Object> _newEntry(String id, String category, NotebookText text) =>
    {
      'id': id,
      'category': category,
      'title': text.title,
      'body': text.body,
      'answer': text.answer,
      'confidence': text.confidence,
      'paper': 'Leitura simples',
      'source': '',
      'resolution': 'open',
      'priority': 'Normal',
      'started': false,
      'completed': false,
      'dates': <Object>[],
      'steps': <Object>[],
      'history': <Object>[],
      'pictures': <Object>[],
      'bodyMarks': <Object>[],
      'answerMarks': <Object>[],
      'thumbLook': <String, Object>{},
      'pageLook': <String, Object>{},
      'orders': <String, Object>{},
    };
