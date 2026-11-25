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
}

class CampaignRecord {
  const CampaignRecord(this.title, this.body, {this.confidence});

  factory CampaignRecord.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final body = json['body'] ?? json['text'] ?? json['summary'];
    final confidence = json['confidence'];
    return CampaignRecord(
      title is String ? title : '',
      body is String ? body : '',
      confidence: confidence is String ? confidence : null,
    );
  }

  final String title;
  final String body;
  final String? confidence;
}

class Notebook {
  const Notebook(this.records, this.sessions);

  factory Notebook.fromRpc(Object? data) {
    if (data is! Map<String, dynamic> || data['entries'] is! List) {
      throw const FormatException('Formato do caderno não reconhecido.');
    }
    final records = <CampaignRecord>[];
    final sessions = <CampaignRecord>[];
    for (final item in data['entries'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Registro do caderno inválido.');
      }
      final record = CampaignRecord.fromJson(item);
      if (record.title.isEmpty && record.body.isEmpty) {
        throw const FormatException('Conteúdo do registro não reconhecido.');
      }
      final kind = item['kind'] ?? item['type'] ?? item['category'];
      (kind == 'session' ? sessions : records).add(record);
    }
    return Notebook(List.unmodifiable(records), List.unmodifiable(sessions));
  }

  final List<CampaignRecord> records;
  final List<CampaignRecord> sessions;
}

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

  Future<Notebook> readNotebook(String campaignId) async {
    final data = await _client.rpc<Object?>(
      'rpg_read_notebook',
      params: {'p_campaign': campaignId},
    );
    return Notebook.fromRpc(data);
  }

  Future<List<CampaignRecord>> readGmNotes(Campaign campaign) async {
    final userId = _client.auth.currentUser?.id;
    if (userId != campaign.ownerId) {
      throw StateError('O roteiro está reservado ao criador da campanha.');
    }
    // O Supabase deve autorizar esta RPC mesmo quando chamada fora do app.
    final rows = await _client.rpc<List<dynamic>>(
      'rpg_gm_list_v2',
      params: {'p_campaign': campaign.id},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .where((row) => row['deleted_at'] == null)
        .map(CampaignRecord.fromJson)
        .toList(growable: false);
  }
}
