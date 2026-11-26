import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_master_set/accounts.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:rpg_master_set/hypotheses.dart';
import 'package:rpg_master_set/missions.dart';
import 'package:rpg_master_set/notebook_sync.dart';
import 'package:rpg_master_set/notebook_format.dart';
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
    final recordPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVR4nGM0Cq5gYGAAAAS5AP+m9miSAAAAAElFTkSuQmCC',
    );
    final notebookBeforeCover = await playerRepo.readNotebook(campaignId);
    final uncovered = notebookBeforeCover.records.single;
    final cutoutPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAEUlEQVR4nGNgYGBg2Gcj9x8ABPACGAybM24AAAAASUVORK5CYII=',
    );
    final playerDraft = NotebookDraft(
      id: uncovered.id!,
      category: uncovered.category!,
      epoch: notebookBeforeCover.epoch,
      text: uncovered.text,
      original: uncovered,
      coverPng: recordPng,
      presentation: NotebookPresentation(
        paper: NotebookPaper.parchment,
        cover: CampaignCoverLayout(zoom: 1.4, y: -0.6),
        bodyMarks: [
          (start: 0, end: 2, attributes: {'bold': true}),
        ],
        pictures: [
          NotebookPicture(
            png: recordPng,
            cutoutPng: cutoutPng,
            caption: 'Ilustração de teste',
            extra: {
              'look': {'size': 0.65, 'zoom': 1.1, 'x': 0.7},
            },
          ),
        ],
      ),
    );
    final restoredDraft = NotebookDraft.fromJson(
      jsonDecode(jsonEncode(playerDraft.toJson())) as Map<String, dynamic>,
    );
    await playerRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: notebookBeforeCover,
      id: restoredDraft.id,
      category: restoredDraft.category,
      text: restoredDraft.text,
      original: restoredDraft.original,
      coverPng: restoredDraft.coverPng,
      presentation: restoredDraft.presentation,
    );
    final notebookWithCover = await gmRepo.readNotebook(campaignId);
    final covered = notebookWithCover.records.single;
    expect(covered.coverHash, isNotNull);
    expect(covered.presentation.paper, NotebookPaper.parchment);
    expect(
      covered.presentation.cover.toJson(),
      playerDraft.presentation!.cover.toJson(),
    );
    expect(
      sameNotebookMarks(
        covered.presentation.bodyMarks,
        playerDraft.presentation!.bodyMarks,
      ),
      isTrue,
    );
    expect(covered.presentation.pictures.single.caption, 'Ilustração de teste');
    expect(covered.presentation.pictures.single.afterParagraph, -1);
    final picture = covered.presentation.pictures.single;
    expect(picture.hash, covered.coverHash);
    expect(picture.displayedHash, isNot(picture.hash));
    expect(picture.layout.size, 0.65);
    expect(picture.layout.x, 0.7);
    expect(
      await gmRepo.readNotebookCover(campaignId, picture.displayedHash!),
      cutoutPng,
    );
    expect(covered.coverHash, isNot(campaignCoverHash));
    expect(
      await gmRepo.readNotebookCover(campaignId, covered.coverHash!),
      recordPng,
    );
    await gmRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: notebookWithCover,
      id: covered.id!,
      category: covered.category!,
      text: covered.text,
      original: covered,
      coverPng: Uint8List(0),
    );
    expect(
      (await playerRepo.readNotebook(campaignId)).records.single.coverHash,
      isNull,
    );
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

    final sharedCopyId = newNotebookRecordId();
    await playerRepo.duplicateRecord(
      campaignId,
      untrashed,
      untrashed.sessions.single,
      sharedCopyId,
    );
    await playerRepo.duplicateRecord(
      campaignId,
      untrashed,
      untrashed.sessions.single,
      sharedCopyId,
    );
    final sharedCopies = await gmRepo.readNotebook(campaignId);
    final savedCopy = sharedCopies.sessions.singleWhere(
      (record) => record.id == sharedCopyId,
    );
    expect(sharedCopies.sessions.length, 2);
    expect(savedCopy.title, 'A primeira sessão (cópia)');
    expect(savedCopy.dates, sessionDates);
    await playerRepo.reorderRecords(campaignId, sharedCopies, [
      sharedCopyId,
      datedSession.id!,
    ], sessions: true);
    final ordered = await gmRepo.readNotebook(campaignId);
    expect(
      ordered.sessions
          .singleWhere((record) => record.id == sharedCopyId)
          .orderIndex(chronicleOrder),
      0,
    );
    expect(
      ordered.sessions
          .singleWhere((record) => record.id == datedSession.id)
          .orderIndex(chronicleOrder),
      1,
    );
    await expectLater(
      playerRepo.reorderRecords(campaignId, sharedCopies, [
        datedSession.id!,
        sharedCopyId,
      ], sessions: true),
      throwsA(isA<NotebookConflict>()),
    );
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

    final privateCopyId = newNotebookRecordId();
    final privateSource = (await gmRepo.readGmNotes(campaign))
        .singleWhere((note) => note.id == id);
    await gmRepo.duplicateGmNote(campaign, privateSource, privateCopyId);
    final group = (await gmRepo.readGmNotes(campaign))
        .where((note) => note.orderGroup == 'character')
        .toList();
    expect(group.length, 2);
    final privateCopy = group.singleWhere((note) => note.id == privateCopyId);
    expect(privateCopy.text.title, 'Segredo (cópia)');
    expect(privateCopy.text.coverHash, privateSource.text.coverHash);
    await gmRepo.reorderGmNotes(campaign, group, [privateCopyId, id]);
    final privateOrder = (await gmRepo.readGmNotes(campaign))
        .singleWhere((note) => note.id == privateCopyId);
    expect(privateOrder.orderIndex, 0);
    await expectLater(
      gmRepo.reorderGmNotes(campaign, group, [id, privateCopyId]),
      throwsA(isA<GmNoteConflict>()),
    );
    await expectLater(
      player.rpc<bool>(
        'rpg_order_gm_group',
        params: {
          ...memberArgs,
          'p_group': 'character',
          'p_ids': [],
          'p_previous': {},
        },
      ),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'code',
          '42501',
        ),
      ),
    );

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
    final session = playerSnapshot.sessions.singleWhere(
      (note) => note.id == datedSession.id,
    );
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
    expect(
      combined.sessions.singleWhere((note) => note.id == datedSession.id).title,
      'Crônica revisada',
    );

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
    expect(
      afterConflict.sessions
          .singleWhere((note) => note.id == datedSession.id)
          .title,
      'Crônica revisada',
    );

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
    final missionId = newNotebookRecordId();
    final mission = MissionPlan(
      steps: [
        MissionStep.fromJson({
          'id': newNotebookRecordId(),
          'title': 'Encontrar a chave',
          'details': 'Estava com o vigia.',
          'completed': false,
          'legacyDetail': 'preservar',
        }),
      ],
    );
    final missionBaseline = await playerRepo.readNotebook(campaignId);
    await playerRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: missionBaseline,
      id: missionId,
      category: 'Missão',
      text: (
        title: 'Abrir o portão',
        body: '',
        answer: '',
        confidence: 'Não se aplica',
      ),
      mission: mission,
    );
    final baseline = await gmRepo.readNotebook(campaignId);
    final quest = baseline.records.singleWhere(
      (record) => record.id == missionId,
    );
    await gmRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: baseline,
      id: missionId,
      category: 'Missão',
      text: quest.text,
      original: quest,
      mission: quest.mission!.copyWith(priority: 'Alta'),
    );
    await playerRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: baseline,
      id: missionId,
      category: 'Missão',
      text: quest.text,
      original: quest,
      mission: quest.mission!.copyWith(
        status: MissionStatus.inProgress,
        steps: [quest.mission!.steps.single.copyWith(completed: true)],
      ),
    );
    final progress = (await gmRepo.readNotebook(campaignId)).records
        .singleWhere((record) => record.id == missionId)
        .mission!;
    expect(progress.completedSteps, 1);
    expect(progress.status, MissionStatus.inProgress);
    expect(progress.priority, 'Alta');
    expect(progress.steps.single.toJson()['legacyDetail'], 'preservar');
    final beforeImport = await playerRepo.readNotebook(campaignId);
    final imported = CampaignRecord(
      'A praça',
      'A mesa encontrou uma estátua.',
      id: newNotebookRecordId(),
      category: 'Lugar',
    );
    final copy = CampaignRecord(
      imported.title,
      imported.body,
      id: newNotebookRecordId(),
      category: imported.category,
    );
    expect(
      await playerRepo.importNotebookRecords(campaignId, beforeImport, [
        imported,
        copy,
      ]),
      (saved: 1, skipped: 1),
    );
    expect(
      await playerRepo.importNotebookRecords(campaignId, beforeImport, [
        imported,
        copy,
      ]),
      (saved: 1, skipped: 1),
    );
    final afterImport = await gmRepo.readNotebook(campaignId);
    expect(
      afterImport.records
          .where((entry) => entry.title == imported.title)
          .single
          .id,
      imported.id,
    );
    expect(afterImport.records.any((entry) => entry.id == missionId), isTrue);
    final hypothesisId = newNotebookRecordId();
    await playerRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: afterImport,
      id: hypothesisId,
      category: 'Investigação',
      text: (
        title: 'A hipótese da ponte',
        body: '',
        answer: '',
        confidence: 'Hipótese',
      ),
    );
    final gmNotebook = await gmRepo.readNotebook(campaignId);
    final hypothesis = gmNotebook.records.singleWhere(
      (item) => item.id == hypothesisId,
    );
    const conclusion = HypothesisResolution(
      status: HypothesisStatus.confirmed,
      reason: 'O grupo achou as pegadas.',
    );
    await gmRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: gmNotebook,
      id: hypothesisId,
      category: 'Investigação',
      original: hypothesis,
      text: hypothesis.text,
      resolution: conclusion,
    );
    final playerNotebook = await playerRepo.readNotebook(campaignId);
    final concluded = playerNotebook.records.singleWhere(
      (item) => item.id == hypothesisId,
    );
    expect(concluded.resolution.sameAs(conclusion), isTrue);
    await playerRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: playerNotebook,
      id: hypothesisId,
      category: 'Investigação',
      original: concluded,
      text: concluded.text,
      resolution: HypothesisResolution(reason: conclusion.reason),
    );
    final reopened = (await gmRepo.readNotebook(campaignId)).records
        .singleWhere((item) => item.id == hypothesisId);
    expect(reopened.resolution.closed, isFalse);
    expect(reopened.resolution.reason, conclusion.reason);
    final notebookWithClue = await gmRepo.readNotebook(campaignId);
    final activeClue = notebookWithClue.records.firstWhere(
      (item) =>
          item.category == 'Investigação' && item.confidence != 'Hipótese',
    );
    await gmRepo.saveNotebookRecord(
      campaignId: campaignId,
      notebook: notebookWithClue,
      id: activeClue.id!,
      category: 'Investigação',
      original: activeClue,
      text: activeClue.text,
      resolution: conclusion,
    );
    final closedClue = (await playerRepo.readNotebook(campaignId)).records
        .singleWhere((item) => item.id == activeClue.id);
    expect(closedClue.resolution.sameAs(conclusion), isTrue);
    expect(closedClue.text, activeClue.text);
  }, timeout: const Timeout(Duration(seconds: 65)));
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
