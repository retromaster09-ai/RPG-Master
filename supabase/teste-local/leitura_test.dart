import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

    if (projectRef.isEmpty) {
      final run = DateTime.now().microsecondsSinceEpoch;
      await _signUp(gm, 'mestre-$run@example.com');
      await _signUp(player, 'jogador-$run@example.com');
    } else {
      await _signIn(
        gm,
        const String.fromEnvironment('SUPABASE_TEST_GM_EMAIL'),
        const String.fromEnvironment('SUPABASE_TEST_GM_PASSWORD'),
      );
      await _signIn(
        player,
        const String.fromEnvironment('SUPABASE_TEST_PLAYER_EMAIL'),
        const String.fromEnvironment('SUPABASE_TEST_PLAYER_PASSWORD'),
      );
      expect(gm.auth.currentUser!.id, isNot(player.auth.currentUser!.id));
    }

    final campaignId = await gm.rpc<String>(
      'rpg_create_campaign',
      params: {'p_name': 'Campanha fictícia'},
    );
    final memberArgs = {'p_campaign': campaignId};

    final playerRepo = CampaignRepository(player);
    expect((await playerRepo.list()).where((c) => c.id == campaignId), isEmpty);
    await expectLater(
      playerRepo.readNotebook(campaignId),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );

    final invitation = await gm.rpc<String>(
      'rpg_create_invite',
      params: memberArgs,
    );
    await player.rpc<String>(
      'rpg_join_campaign',
      params: {'p_token': invitation},
    );

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
          _entry(
            '10000000-0000-4000-8000-000000000002',
            'Sessão',
            'A primeira sessão',
          ),
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
          'tags': '',
          'cue': '',
          'music': '',
          'next_session': false,
        },
      },
    );

    final gmRepo = CampaignRepository(gm);
    final campaign = (await gmRepo.list()).singleWhere(
      (c) => c.id == campaignId,
    );
    expect(campaign.ownerId, gm.auth.currentUser!.id);
    expect((await playerRepo.list()).map((c) => c.id), contains(campaignId));

    for (final repo in [gmRepo, playerRepo]) {
      final notebook = await repo.readNotebook(campaignId);
      expect(notebook.records.single.title, 'Uma pista');
      expect(notebook.sessions.single.title, 'A primeira sessão');
    }
    expect(
      (await gmRepo.readGmNotes(campaign)).single.title,
      'Uma nota privada de teste',
    );
    await expectLater(playerRepo.readGmNotes(campaign), throwsStateError);
    await expectLater(
      player.rpc<List<dynamic>>('rpg_gm_list_v2', params: memberArgs),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    final filteredRows = await player
        .from('rpg_gm_notes')
        .select('id')
        .eq('campaign_id', campaignId);
    expect(filteredRows, isEmpty);

    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jKx8AAAAASUVORK5CYII=',
    );
    final name = '$campaignId/${List.filled(64, 'a').join()}.png';
    final gmBucket = gm.storage.from('rpg-gm-private');
    final playerBucket = player.storage.from('rpg-gm-private');
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

Future<void> _signIn(
  SupabaseClient client,
  String email,
  String password,
) async {
  expect(
    email,
    isNotEmpty,
    reason: 'Use uma conta fictícia do projeto de teste.',
  );
  expect(password, isNotEmpty);
  final auth = await client.auth.signInWithPassword(
    email: email,
    password: password,
  );
  expect(auth.session, isNotNull);
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
