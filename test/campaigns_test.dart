import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rpg_master_set/campaign_cover.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:rpg_master_set/main.dart';
import 'package:rpg_master_set/notebook_sync.dart';
import 'package:rpg_master_set/offline_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const campaign = Campaign(id: 'campaign', name: 'O farol', ownerId: 'master');

http.Response jsonResponse(http.Request request, Object data) => http.Response(
  jsonEncode(data),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'o salvamento preserva a formatação intacta e os dados antigos',
    () async {
      const entry = {
        'id': 'entry',
        'title': 'Pista antiga',
        'body': 'Início meio fim',
        'category': 'Investigação',
        'bodyMarks': [
          {
            'start': 0,
            'end': 6,
            'attributes': {'bold': true},
          },
          {
            'start': 12,
            'end': 15,
            'attributes': {'italic': true},
          },
        ],
        'unknownField': 'Preservar',
      };
      const removed = {'id': 'removed', 'deletedAt': '2026-01-01T00:00:00'};
      var didSave = false;
      final client = SupabaseClient(
        'https://example.invalid',
        'sb_publishable_example',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('rpg_try_save_notebook_v3')) {
            final args = jsonDecode(request.body) as Map;
            expect(args['p_expected'], 1);
            expect(args['p_epoch'], 2);
            expect(args['p_entries'], [
              {
                ...entry,
                'body': 'Início texto novo fim',
                'bodyMarks': [
                  {
                    'start': 0,
                    'end': 6,
                    'attributes': {'bold': true},
                  },
                  {
                    'start': 18,
                    'end': 21,
                    'attributes': {'italic': true},
                  },
                ],
              },
              removed,
            ]);
            didSave = true;
            return jsonResponse(request, 2);
          }
          return jsonResponse(request, {
            'revision': didSave ? 2 : 1,
            'epoch': 2,
            'entries': [
              didSave ? {...entry, 'body': 'Início texto novo fim'} : entry,
              removed,
            ],
          });
        }),
      );
      addTearDown(client.dispose);
      final repository = CampaignRepository(client);
      final notebook = await repository.readNotebook(campaign.id);
      final record = notebook.records.single;
      await repository.saveNotebookRecord(
        campaignId: campaign.id,
        notebook: notebook,
        id: record.id!,
        category: record.category!,
        original: record,
        text: (
          title: record.title,
          body: 'Início texto novo fim',
          answer: '',
          confidence: record.text.confidence,
        ),
      );
      expect(didSave, isTrue);
    },
  );

  testWidgets('o jogador abre o editor e salva pelo botão da tela', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _EditorRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: NotebookScreen(
          campaign: campaign,
          repository: repository,
          isOwner: false,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Texto editado');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(repository.body, 'Texto editado');
    expect(find.text('Texto editado'), findsOneWidget);
  });

  testWidgets('o texto digitado reaparece após fechar o editor sem salvar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _EditorRepository();
    final storage = MemoryOfflineStorage();
    Widget app() => MaterialApp(
      home: NotebookScreen(
        campaign: campaign,
        repository: repository,
        isOwner: false,
        offlineStorage: storage,
        onBack: () {},
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Ainda é um rascunho');
    await tester.pumpAndSettle();
    expect(find.text('Rascunho guardado neste aparelho.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repository.online = false;

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rascunho neste aparelho'));
    await tester.pumpAndSettle();
    expect(find.text('Ainda é um rascunho'), findsOneWidget);
    expect(repository.saves, 0);
  });

  test('a fila sobrevive à reabertura e envia só as edições salvas', () async {
    final repository = _EditorRepository();
    final storage = MemoryOfflineStorage();
    NotebookSync open() => NotebookSync(
      repository: repository,
      campaignId: campaign.id,
      storage: storage,
      isCurrentAccount: () => true,
    );
    final first = open();
    await first.load();
    final original = first.notebook!.records.single;
    repository.online = false;
    await first.keep(
      NotebookDraft(
        id: original.id!,
        category: original.category!,
        epoch: 0,
        text: (
          title: original.title,
          body: 'Texto offline',
          answer: '',
          confidence: 'Não se aplica',
        ),
        original: original,
        status: DraftStatus.queued,
      ),
    );
    await first.keep(
      const NotebookDraft(
        id: 'local-draft',
        category: 'Sessão',
        epoch: 0,
        text: (
          title: 'Rascunho da sessão',
          body: '',
          answer: '',
          confidence: 'Não se aplica',
        ),
      ),
    );
    first.dispose();

    final second = open();
    addTearDown(second.dispose);
    await second.load();
    expect(second.offline, isTrue);
    expect(second.notebook!.records.single.body, 'Texto inicial');
    expect(second.drafts.map((draft) => draft.text.title), [
      'Pista',
      'Rascunho da sessão',
    ]);
    expect(repository.saves, 0);
    repository.online = true;
    await Future.wait([second.refresh(), second.refresh()]);
    expect(repository.saves, 1);
    expect(second.notebook!.records.single.body, 'Texto offline');
    expect(second.drafts.single.status, DraftStatus.editing);
  });

  test('fila de uma geração antiga mantém o texto sem reenviar', () async {
    final repository = _EditorRepository();
    final sync = NotebookSync(
      repository: repository,
      campaignId: campaign.id,
      storage: MemoryOfflineStorage(),
      isCurrentAccount: () => true,
    );
    addTearDown(sync.dispose);
    await sync.load();
    final original = sync.notebook!.records.single;
    await sync.keep(
      NotebookDraft(
        id: original.id!,
        category: original.category!,
        epoch: 0,
        text: (
          title: original.title,
          body: 'Texto antes do reset',
          answer: '',
          confidence: 'Não se aplica',
        ),
        original: original,
        status: DraftStatus.queued,
      ),
    );
    repository.epoch = 1;
    await sync.refresh();
    expect(repository.saves, 0);
    expect(sync.drafts.single.status, DraftStatus.review);
    expect(sync.drafts.single.text.body, 'Texto antes do reset');
  });

  testWidgets('a busca encontra texto com acento e o filtro usa a categoria', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _EditorRepository()..body = 'Uma anotação sobre a torre';
    await tester.pumpWidget(
      MaterialApp(
        home: NotebookScreen(
          campaign: campaign,
          repository: repository,
          isOwner: false,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ANOTACAO torre');
    await tester.pumpAndSettle();
    expect(find.text('Pista'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'floresta');
    await tester.pumpAndSettle();
    expect(find.text('Pista'), findsNothing);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investigação').last);
    await tester.pumpAndSettle();
    expect(find.text('Pista'), findsOneWidget);
  });

  testWidgets('o cartão abre a campanha e a ação de capa fica com o mestre', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            campaign: campaign,
            repository: _EditorRepository(),
            isOwner: false,
            onOpen: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jogador'), findsOneWidget);
    expect(find.byTooltip('Adicionar capa'), findsNothing);
    await tester.tap(find.text('O farol'));
    expect(opened, isTrue);

    var editing = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignCard(
            campaign: campaign,
            repository: _EditorRepository(),
            isOwner: true,
            onOpen: () {},
            onEditCover: () => editing = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mestre'), findsOneWidget);
    await tester.tap(find.byTooltip('Adicionar capa'));
    expect(editing, isTrue);
  });

  test('pede a revisão completa pela RPC v3 e separa as crônicas', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'sb_publishable_example',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/rpg_poll_notebook_v3');
        expect(jsonDecode(request.body), {
          'p_campaign': campaign.id,
          'p_known': -1,
        });
        return jsonResponse(request, {
          'revision': 1,
          'epoch': 0,
          'entries': [
            {
              'category': 'Investigação',
              'title': 'Uma pista',
              'body': '',
              'answer': 'Mapa encontrado',
              'confidence': 'Hipótese',
              'deletedAt': null,
            },
            {
              'category': 'Sessão',
              'title': 'Primeira sessão',
              'body': 'Resumo',
              'confidence': 'Não se aplica',
            },
            {
              'category': 'Sessão',
              'title': 'Sessão apagada',
              'deletedAt': '2026-01-01T00:00:00',
            },
          ],
        });
      }),
    );
    addTearDown(client.dispose);
    final notebook = await CampaignRepository(client).readNotebook(campaign.id);
    expect(notebook.records.single.title, 'Uma pista');
    expect(notebook.records.single.answer, 'Mapa encontrado');
    expect(notebook.records.single.confidence, 'Hipótese');
    expect(notebook.sessions.single.title, 'Primeira sessão');
    expect(notebook.sessions.single.confidence, isNull);
  });

  test('uma sessão de jogador não dispara a consulta privada', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'sb_publishable_example',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/auth/v1/token');
        return jsonResponse(request, {
          'access_token': 'fake.test.token',
          'token_type': 'bearer',
          'refresh_token': 'fake-refresh-token',
          'user': {
            'id': 'player',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        });
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'player@example.invalid',
      password: 'fake-password',
    );
    await expectLater(
      CampaignRepository(client).readGmNotes(campaign),
      throwsStateError,
    );
  });

  test('distingue um caderno vazio de um formato inesperado', () {
    expect(
      Notebook.fromRpc({'revision': 0, 'epoch': 0, 'entries': []}).records,
      isEmpty,
    );
    expect(() => Notebook.fromRpc({'data': []}), throwsFormatException);
    expect(
      () => Notebook.fromRpc({
        'revision': 0,
        'epoch': 0,
        'entries': [{}],
      }),
      throwsFormatException,
    );
  });
}

class _EditorRepository extends Fake implements CampaignRepository {
  String body = 'Texto inicial';
  bool online = true;
  int epoch = 0;
  int saves = 0;

  @override
  Future<Notebook> readNotebook(String campaignId, {Notebook? known}) async {
    if (!online) throw http.ClientException('Sem conexão');
    return Notebook.fromRpc({
      'revision': saves + 1,
      'epoch': epoch,
      'entries': [
        {
          'id': 'entry',
          'title': 'Pista',
          'body': body,
          'category': 'Investigação',
        },
      ],
    });
  }

  @override
  Future<void> saveNotebookRecord({
    required String campaignId,
    required Notebook notebook,
    required String id,
    required String category,
    required NotebookText text,
    CampaignRecord? original,
  }) async {
    saves++;
    body = text.body;
  }
}
