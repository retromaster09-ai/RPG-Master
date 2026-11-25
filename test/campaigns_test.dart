import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const campaign = Campaign(id: 'campaign', name: 'O farol', ownerId: 'master');

http.Response jsonResponse(http.Request request, Object data) => http.Response(
  jsonEncode(data),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);

void main() {
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
    expect(Notebook.fromRpc({'entries': []}).records, isEmpty);
    expect(() => Notebook.fromRpc({'data': []}), throwsFormatException);
    expect(
      () => Notebook.fromRpc({
        'entries': [{}],
      }),
      throwsFormatException,
    );
  });
}
