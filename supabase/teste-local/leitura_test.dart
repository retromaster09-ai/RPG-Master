import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_master_set/accounts.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const endpoint = String.fromEnvironment(
    'SUPABASE_TEST_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );
  const key = String.fromEnvironment('SUPABASE_TEST_KEY');
  const projectRef = String.fromEnvironment('SUPABASE_TEST_PROJECT_REF');

  test('mestre e jogador leem somente o conteúdo autorizado', () async {
    final uri = Uri.parse(endpoint);
    if (projectRef.isEmpty) {
      expect(uri.scheme, 'http');
      expect(uri.host, anyOf('127.0.0.1', 'localhost', '::1'));
    } else {
      expect(projectRef, matches(RegExp(r'^[a-z0-9]{20}$')));
      expect(uri.origin, 'https://$projectRef.supabase.co');
    }
    expect(key, isNotEmpty, reason: 'Use a chave pública do projeto de teste.');

    final gm = SupabaseClient(endpoint, key);
    final player = SupabaseClient(endpoint, key);
    addTearDown(gm.dispose);
    addTearDown(player.dispose);

    final run = DateTime.now().microsecondsSinceEpoch;
    final gmName = 'mestre-$run';
    final playerName = 'jog-$run';
    if (projectRef.isEmpty) {
      await _signUp(gm, '$gmName@example.com');
      await _signUp(player, '$playerName@example.com');
    } else {
      final gmAccounts = AccountService(gm);
      final playerAccounts = AccountService(player);
      final gmPassword = 'Senha-teste-${newNotebookRecordId()}';
      final playerPassword = 'Senha-teste-${newNotebookRecordId()}';
      await gmAccounts.register(gmName, gmPassword);
      await playerAccounts.register(playerName, playerPassword);
      await expectLater(
        playerAccounts.register(gmName, playerPassword),
        throwsA(
          isA<FunctionException>().having((e) => e.status, 'status', 409),
        ),
      );
      await gmAccounts.signIn(gmName, gmPassword);
      await playerAccounts.signIn(playerName, playerPassword);
      expect((await gmAccounts.call('settings'))['username'], gmName);
      expect((await playerAccounts.call('settings'))['username'], playerName);
      expect(gm.auth.currentUser!.id, isNot(player.auth.currentUser!.id));
    }

    final campaignId = newNotebookRecordId();
    final gmRepo = CampaignRepository(gm);
    final playerRepo = CampaignRepository(player);
    await gmRepo.createCampaign(campaignId, 'Campanha fictícia');
    await gmRepo.createCampaign(campaignId, 'Campanha fictícia');
    final memberArgs = {'p_campaign': campaignId};
    final campaign = (await gmRepo.list()).singleWhere(
      (c) => c.id == campaignId,
    );
    expect((await playerRepo.list()).where((c) => c.id == campaignId), isEmpty);
    await expectLater(
      playerRepo.readNotebook(campaignId),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jKx8AAAAASUVORK5CYII=',
    );
    const coverLayout = CampaignCoverLayout(fill: false, zoom: 1.5, x: 0.2);
    await gmRepo.setCampaignCover(campaign, coverLayout, png: png);
    final withCover = (await gmRepo.list()).singleWhere(
      (c) => c.id == campaignId,
    );
    final campaignCoverHash = withCover.coverHash!;
    expect(withCover.coverLayout.toJson(), coverLayout.toJson());
    await expectLater(
      playerRepo.readCampaignCover(withCover, campaignCoverHash),
      throwsA(isA<StorageException>()),
    );
    await expectLater(
      gmRepo.setCampaignCover(campaign, coverLayout, hash: campaignCoverHash),
      throwsA(isA<CampaignCoverConflict>()),
    );
    final code = 'mesa-${campaignId.substring(0, 24)}';
    expect((await gmRepo.readAccess(campaign)).codeEnabled, isFalse);
    await gmRepo.setCampaignCode(campaign, code);
    await playerRepo.joinCampaign(code.toUpperCase());
    final playerCampaign = (await playerRepo.list()).singleWhere(
      (c) => c.id == campaignId,
    );
    expect(playerCampaign.coverHash, campaignCoverHash);
    expect(
      await playerRepo.readCampaignCover(playerCampaign, campaignCoverHash),
      orderedEquals(png),
    );
    await expectLater(
      player.rpc<int?>(
        'rpg_try_set_campaign_cover',
        params: {
          ...memberArgs,
          'p_expected': playerCampaign.coverRevision,
          'p_hash': null,
          'p_layout': coverLayout.toJson(),
        },
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await gmRepo.setCampaignCover(withCover, const CampaignCoverLayout());
    expect(
      (await gmRepo.list()).singleWhere((c) => c.id == campaignId).coverHash,
      isNull,
    );
    final access = await gmRepo.readAccess(campaign);
    expect(access.codeEnabled, isTrue);
    expect(access.members.map((m) => m.isOwner), [true, false]);
    if (projectRef.isNotEmpty) {
      expect(access.members.map((m) => m.name), [gmName, playerName]);
    }
    await expectLater(
      player.rpc<Map<String, dynamic>>(
        'rpg_campaign_access',
        params: memberArgs,
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await expectLater(
      player.rpc<bool>(
        'rpg_set_campaign_code',
        params: {...memberArgs, 'p_code': null},
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    final invitation = await gmRepo.createCampaignInvite(campaign);
    await playerRepo.joinCampaign(invitation);
    await gmRepo.setCampaignCode(campaign, null);
    await expectLater(
      playerRepo.joinCampaign(code),
      throwsA(
        isA<CampaignJoinException>().having(
          (e) => e.status,
          'status',
          'invalid',
        ),
      ),
    );
    expect((await gmRepo.readAccess(campaign)).codeEnabled, isFalse);

    await gm.rpc<int>(
      'rpg_save_notebook_v3',
      params: {
        ...memberArgs,
        'p_expected': 0,
        'p_epoch': 0,
        'p_entries': [
          _entry(
            '10000000-0000-4000-8000-000000000001',
            'Investigação',
            'Uma pista',
          ),
          {
            ..._entry(
              '10000000-0000-4000-8000-000000000002',
              'Sessão',
              'A primeira sessão',
            ),
            'dates': ['2026-01-09T00:00:00.000'],
          },
        ],
      },
    );
    await gm.rpc<int>(
      'rpg_gm_save_visual',
      params: {
        ...memberArgs,
        'p_id': campaignId,
        'p_expected': 0,
        'p_note': {
          'title': 'Uma nota privada de teste',
          'body': 'Informação fictícia reservada ao mestre.',
          'section': 'idea',
          'state': 'idea',
          'tags': 'privado',
          'cue': '',
          'music': '',
          'next_session': true,
        },
      },
    );

    expect(campaign.ownerId, gm.auth.currentUser!.id);
    expect((await playerRepo.list()).map((c) => c.id), contains(campaignId));

    for (final repo in [gmRepo, playerRepo]) {
      final notebook = await repo.readNotebook(campaignId);
      expect(notebook.records.single.title, 'Uma pista');
      expect(notebook.sessions.single.title, 'A primeira sessão');
    }
    final sessionBaseline = await gmRepo.readNotebook(campaignId);
    final datedSession = sessionBaseline.sessions.single;
    expect(datedSession.dates, ['2026-01-09T00:00:00.000']);
    final sessionDates = [...datedSession.dates, '2026-01-12T00:00:00.000Z'];
    await gmRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: sessionBaseline,
      id: datedSession.id!,
      category: 'Sessão',
      text: datedSession.text,
      original: datedSession,
      dates: sessionDates,
    );
    final anotherSession = await playerRepo.readNotebook(campaignId);
    expect(anotherSession.sessions.single.dates, sessionDates);
    await expectLater(
      playerRepo.saveNotebookRecord(
        campaignId: campaignId,
        notebook: sessionBaseline,
        id: datedSession.id!,
        category: 'Sessão',
        text: datedSession.text,
        original: datedSession,
        dates: ['2026-01-15T00:00:00.000Z'],
      ),
      throwsA(
        isA<NotebookConflict>().having(
          (error) => error.current?.dates,
          'datas compartilhadas',
          sessionDates,
        ),
      ),
    );
    await playerRepo.setNotebookTrash(
      campaignId,
      anotherSession,
      anotherSession.sessions.single,
      trashed: true,
    );
    final sharedTrash = await gmRepo.readNotebook(campaignId);
    expect(sharedTrash.sessions, isEmpty);
    expect(sharedTrash.trash.single.dates, sessionDates);
    await playerRepo.setNotebookTrash(
      campaignId,
      sharedTrash,
      sharedTrash.trash.single,
      trashed: false,
    );
    final untrashed = await gmRepo.readNotebook(campaignId);
    expect(untrashed.trash, isEmpty);
    expect(untrashed.sessions.single.dates, sessionDates);

    final legacy = (await gmRepo.readGmNotes(campaign)).single;
    expect(legacy.text.title, 'Uma nota privada de teste');
    expect(legacy.text.kind, GmNoteKind.note);
    final coverHash = await gmRepo.uploadGmCover(campaign, png);
    expect(await gmRepo.uploadGmCover(campaign, png), coverHash);
    final id = newNotebookRecordId();
    final draft = (
      title: 'Segredo',
      body: 'Texto inicial',
      section: GmSection.idea,
      kind: GmNoteKind.character,
      coverHash: coverHash,
    );
    await gmRepo.saveGmNote(campaign: campaign, id: id, draft: draft);
    await gmRepo.saveGmNote(campaign: campaign, id: id, draft: draft);
    expect((await gmRepo.readGmNotes(campaign)).length, 2);
    expect(
      (await gmRepo.readGmNotes(campaign))
          .singleWhere((note) => note.id == id)
          .text,
      draft,
    );
    expect(await gmRepo.readGmCover(campaign, coverHash), orderedEquals(png));

    const revised = (
      title: 'Uma nota revisada',
      body: 'Texto novo',
      section: GmSection.backstage,
      kind: GmNoteKind.note,
      coverHash: null,
    );
    await gmRepo.saveGmNote(
      campaign: campaign,
      id: legacy.id,
      draft: revised,
      original: legacy,
    );
    final updated = (await gmRepo.readGmNotes(campaign))
        .singleWhere((note) => note.id == legacy.id);
    expect(updated.text, revised);
    expect(updated.revision, legacy.revision + 1);
    final fields = await gm
        .from('rpg_gm_notes')
        .select('tags, next_session')
        .eq('id', legacy.id)
        .single();
    expect(fields, {'tags': 'privado', 'next_session': true});
    await expectLater(
      gmRepo.saveGmNote(
        campaign: campaign,
        id: legacy.id,
        draft: draft,
        original: legacy,
      ),
      throwsA(isA<GmNoteConflict>()),
    );
    await gmRepo.setGmTrash(campaign, updated, trashed: true);
    await gmRepo.setGmTrash(campaign, updated, trashed: true);
    final gmTrash = await gmRepo.readGmNotes(campaign, trashed: true);
    expect(gmTrash.single.id, updated.id);
    expect(
      (await gmRepo.readGmNotes(campaign)).any((item) => item.id == updated.id),
      isFalse,
    );
    await expectLater(
      player.rpc<int?>(
        'rpg_try_set_gm_trash',
        params: {
          ...memberArgs,
          'p_id': updated.id,
          'p_expected': gmTrash.single.revision,
          'p_deleted': false,
        },
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await expectLater(playerRepo.readGmNotes(campaign), throwsStateError);
    await expectLater(
      player.rpc<List<dynamic>>('rpg_gm_list_v2', params: memberArgs),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await gmRepo.setGmTrash(campaign, gmTrash.single, trashed: false);
    expect((await gmRepo.readGmNotes(campaign, trashed: true)), isEmpty);
    expect(
      (await gmRepo.readGmNotes(campaign))
          .singleWhere((item) => item.id == updated.id)
          .text,
      updated.text,
    );
    final filteredRows = await player
        .from('rpg_gm_notes')
        .select('id')
        .eq('campaign_id', campaignId);
    expect(filteredRows, isEmpty);
    await expectLater(
      player.rpc<int?>(
        'rpg_try_save_gm_note',
        params: {...memberArgs, 'p_id': id, 'p_expected': 1, 'p_note': {}},
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );

    final name = '$campaignId/${List.filled(64, 'a').join()}.png';
    final gmBucket = gm.storage.from('rpg-gm-private');
    final playerBucket = player.storage.from('rpg-gm-private');
    await expectLater(
      playerBucket.download('$campaignId/$coverHash.png'),
      throwsA(isA<StorageException>()),
    );
    await gmBucket.uploadBinary(
      name,
      png,
      fileOptions: const FileOptions(contentType: 'image/png'),
    );
    expect(await gmBucket.download(name), orderedEquals(png));
    expect(await playerBucket.list(path: campaignId), isEmpty);
    await expectLater(
      playerBucket.download(name),
      throwsA(isA<StorageException>()),
    );

    final sharedBucket = gm.storage.from('rpg-notes');
    await sharedBucket.uploadBinary(
      name,
      png,
      fileOptions: const FileOptions(contentType: 'image/png'),
    );
    expect(
      await player.storage.from('rpg-notes').download(name),
      orderedEquals(png),
    );

    final gmSnapshot = await gmRepo.readNotebook(campaignId);
    final playerSnapshot = await playerRepo.readNotebook(campaignId);
    final clue = gmSnapshot.records.single;
    final session = playerSnapshot.sessions.single;
    await Future.wait([
      _saveTitle(gmRepo, campaignId, gmSnapshot, clue, 'Pista revisada'),
      _saveTitle(
        playerRepo,
        campaignId,
        playerSnapshot,
        session,
        'Crônica revisada',
      ),
    ]);
    final combined = await gmRepo.readNotebook(campaignId);
    expect(combined.records.single.title, 'Pista revisada');
    expect(combined.sessions.single.title, 'Crônica revisada');

    final sameRecord = combined.records.single;
    final results = await Future.wait([
      _attemptTitle(
        gmRepo,
        campaignId,
        combined,
        sameRecord,
        'Rascunho do mestre',
      ),
      _attemptTitle(
        playerRepo,
        campaignId,
        combined,
        sameRecord,
        'Rascunho do jogador',
      ),
    ]);
    final conflict = results.whereType<NotebookConflict>().single;
    final afterConflict = await gmRepo.readNotebook(campaignId);
    expect(
      afterConflict.records.single.title,
      anyOf('Rascunho do mestre', 'Rascunho do jogador'),
    );
    expect(conflict.current?.title, afterConflict.records.single.title);
    expect(afterConflict.sessions.single.title, 'Crônica revisada');

    final newId = newNotebookRecordId();
    Future<void> create() => playerRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: afterConflict,
      id: newId,
      category: 'Sessão',
      text: (
        title: 'Segunda crônica',
        body: 'Resumo',
        answer: '',
        confidence: 'Não se aplica',
      ),
    );
    await create();
    await create();
    expect(
      (await gmRepo.readNotebook(campaignId)).sessions
          .where((record) => record.id == newId),
      hasLength(1),
    );
  }, timeout: const Timeout(Duration(seconds: 40)));
}

Future<NotebookConflict?> _attemptTitle(
  CampaignRepository repository,
  String campaignId,
  Notebook notebook,
  CampaignRecord record,
  String title,
) async {
  try {
    await _saveTitle(repository, campaignId, notebook, record, title);
    return null;
  } on NotebookConflict catch (conflict) {
    return conflict;
  }
}

Future<void> _saveTitle(
  CampaignRepository repository,
  String campaignId,
  Notebook notebook,
  CampaignRecord record,
  String title,
) => repository.saveNotebookRecord(
  campaignId: campaignId,
  notebook: notebook,
  id: record.id!,
  category: record.category!,
  original: record,
  text: (
    title: title,
    body: record.body,
    answer: record.answer,
    confidence: record.text.confidence,
  ),
);

Future<void> _signUp(SupabaseClient client, String email) async {
  final auth = await client.auth.signUp(
    email: email,
    password: 'Senha-local-teste!29',
  );
  expect(
    auth.session,
    isNotNull,
    reason: 'Desabilite confirmação de e-mail no Supabase local.',
  );
}

Map<String, Object> _entry(String id, String category, String title) => {
  'id': id,
  'category': category,
  'title': title,
  'body': 'Texto de teste.',
  'source': '',
  'confidence': 'Não se aplica',
  'answer': '',
  'paper': 'Leitura simples',
  'resolution': 'open',
  'priority': 'normal',
  'completed': false,
  'started': false,
  'dates': <String>[],
  'history': <String>[],
  'pictures': <Object>[],
  'steps': <Object>[],
  'bodyMarks': <Object>[],
  'answerMarks': <Object>[],
  'thumbLook': <String, Object>{},
  'pageLook': <String, Object>{},
};
