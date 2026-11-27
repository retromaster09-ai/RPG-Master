import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:rpg_master_set/notebook_format.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'edita a apresentação privada e conserva os metadados legados',
    () async {
      final originalHash = List.filled(64, 'a').join();
      final cutoutHash = List.filled(64, 'b').join();
      var row = <String, dynamic>{
        'id': 'note',
        'revision': 4,
        'title': 'Castelo',
        'body': 'Pista com mapa',
        'section': 'scene',
        'state': 'ready',
        'tags': 'relíquia',
        'next_session': true,
        'presentation': {
          'paper': 'Pergaminho',
          'cover': null,
          'pictures': [
            {'hash': originalHash, 'caption': 'Mapa', 'afterParagraph': 0},
          ],
          'legacyValue': true,
        },
      };
      final client = SupabaseClient(
        'https://example.test',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('rpg_try_save_gm_note')) {
            final data = jsonDecode(request.body) as Map<String, dynamic>;
            final edited = data['p_note'] as Map<String, dynamic>;
            expect(data['p_expected'], 4);
            expect(edited['presentation']['legacyValue'], isTrue);
            expect(edited['presentation']['pictures'][0]['hash'], originalHash);
            expect(
              edited['presentation']['pictures'][0]['cutoutHash'],
              cutoutHash,
            );
            expect(edited['presentation']['marks'][0]['attributes'], {
              'bold': true,
            });
            expect(edited['next_session'], isTrue);
            row = {...row, ...edited, 'revision': 5};
            // Simula uma revisão já salva ao repetir o envio.
            return http.Response('null', 200, request: request);
          }
          expect(request.url.path.endsWith('rpg_gm_list_v2'), isTrue);
          return http.Response(
            jsonEncode([row]),
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
            'id': 'owner',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '',
          },
        }),
      );
      final repository = CampaignRepository(client);
      const campaign = Campaign(id: 'campaign', name: 'Mesa', ownerId: 'owner');
      final note = (await repository.readGmNotes(campaign)).single;
      expect(note.presentation.pictures.single.hash, originalHash);
      final picture = note.presentation.pictures.single;
      await repository.saveGmNote(
        campaign: campaign,
        id: note.id,
        draft: note.text,
        original: note,
        preparation: note.preparation,
        presentation: NotebookPresentation(
          paper: NotebookPaper.diary,
          bodyMarks: const [
            (start: 0, end: 4, attributes: {'bold': true}),
          ],
          pictures: [
            picture.edit(
              caption: 'Mapa',
              afterParagraph: 0,
              cutoutHash: cutoutHash,
            ),
          ],
        ),
      );
      final saved = (await repository.readGmNotes(campaign)).single;
      expect(saved.presentation.pictures.single.displayedHash, cutoutHash);
      expect(saved.preparation.tags, 'relíquia');
    },
  );
}
