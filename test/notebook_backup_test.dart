import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:rpg_master_set/notebook_backup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('restaura o ZIP com imagens e preserva registros atuais', () async {
    final picture = Uint8List.fromList([12, 14, 18]);
    final hash = sha256.convert(picture).toString();
    final old = Notebook.fromRpc({
      'epoch': 1,
      'revision': 2,
      'entries': [
        {'id': 'same', 'title': 'Título antigo', 'category': 'Lugar'},
        {
          'id': 'restore',
          'title': 'Crônica',
          'category': 'Sessão',
          'imagePath': 'rpg-media:$hash',
          'paper': 'Pergaminho',
        },
      ],
    });
    final bytes = await createNotebookBackup(old, (requested) async {
      expect(requested, hash);
      return picture;
    });
    final backup = readNotebookBackup(bytes);
    expect(
      backup.notebook.sessions.single.presentation.paper.label,
      'Pergaminho',
    );
    expect(backup.images[hash], picture);

    var revision = 7;
    var entries = <Map<String, dynamic>>[
      {'id': 'same', 'title': 'Título atualizado', 'category': 'Lugar'},
    ];
    final api = SupabaseClient(
      'https://example.test',
      'test',
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/storage/')) {
          expect(
            request.url.path,
            '/storage/v1/object/rpg-notes/campaign/$hash.png',
          );
          return _json(request, {'Key': 'campaign/$hash.png'});
        }
        if (request.url.path.endsWith('rpg_poll_notebook_v3')) {
          return _json(request, {
            'epoch': 4,
            'revision': revision,
            'entries': entries,
          });
        }
        expect(request.url.path, '/rest/v1/rpc/rpg_try_save_notebook_v3');
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['p_expected'], revision);
        expect(data['p_epoch'], 4);
        entries = (data['p_entries'] as List).cast<Map<String, dynamic>>();
        return _json(request, ++revision);
      }),
    );
    addTearDown(api.dispose);
    await api.auth.setInitialSession(
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
    final repository = CampaignRepository(api);
    const campaign = Campaign(id: 'campaign', name: 'Mesa', ownerId: 'master');
    final baseline = await repository.readNotebook(campaign.id);
    expect(
      await repository.restoreNotebookBackup(
        campaign,
        baseline,
        backup.notebook,
        backup.images,
      ),
      1,
    );
    expect(entries.map((item) => item['title']), [
      'Título atualizado',
      'Crônica',
    ]);
    expect(
      await repository.restoreNotebookBackup(
        campaign,
        baseline,
        backup.notebook,
        backup.images,
      ),
      0,
    );
  });
}

http.Response _json(http.Request request, Object value) => http.Response(
  jsonEncode(value),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);
