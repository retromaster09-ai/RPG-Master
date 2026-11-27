import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('exclui da lixeira e envia o reset com a revisão da prévia', () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://example.test',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final method = request.url.pathSegments.last;
        paths.add(method);
        final args = jsonDecode(request.body) as Map<String, dynamic>;
        expect(args['p_campaign'], 'campaign');
        final Object? result;
        switch (method) {
          case 'rpg_poll_notebook_v3':
            result = _snapshot;
          case 'rpg_try_save_notebook_v3':
            expect(args['p_expected'], 7);
            expect(args['p_epoch'], 2);
            expect((args['p_entries'] as List).map((entry) => entry['id']), [
              'active',
            ]);
            result = 8;
          case 'rpg_reset_preview':
            result = {'revision': 8, 'shared': 1, 'private': 2};
          case 'rpg_reset_campaign':
            expect(args['p_expected'], 8);
            expect(args['p_private'], isFalse);
            result = null;
          default:
            fail('Chamada inesperada: $method');
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test',
        'token_type': 'bearer',
        'user': {
          'id': 'master',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '',
        },
      }),
    );
    const campaign = Campaign(id: 'campaign', name: 'Mesa', ownerId: 'master');
    final repository = CampaignRepository(client);
    final notebook = Notebook.fromRpc(_snapshot);
    expect(
      () => repository.permanentlyDeleteRecord(
        campaign,
        notebook,
        notebook.records.single,
      ),
      throwsA(isA<NotebookConflict>()),
    );
    await repository.permanentlyDeleteRecord(
      campaign,
      notebook,
      notebook.trash.single,
    );
    final preview = await repository.previewReset(campaign);
    expect(preview.shared, 1);
    await repository.resetSharedNotebook(campaign, preview.revision);
    expect(paths, [
      'rpg_poll_notebook_v3',
      'rpg_try_save_notebook_v3',
      'rpg_reset_preview',
      'rpg_reset_campaign',
    ]);
  });
}

const _snapshot = {
  'revision': 7,
  'epoch': 2,
  'entries': [
    {'id': 'active', 'title': 'Ativo'},
    {'id': 'trash', 'title': 'Descartado', 'deletedAt': '2026-11-26T10:00:00Z'},
  ],
};
