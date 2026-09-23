import 'backend_api_base.dart';

class GroupApi extends BackendApiBase {
  GroupApi({required super.baseUrl, required super.auth});

  Future<List<Map<String, dynamic>>> getGroups() async {
    final decoded = await getJson(Uri.parse('$baseUrl/api/me/groups'));

    final rawGroups = decoded['groups'];

    if (rawGroups is! List) {
      return [];
    }

    return rawGroups
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<bool> toggleGroup(String groupId, bool enabled) async {
    final decoded = await postJson(
      Uri.parse('$baseUrl/api/me/groups/$groupId/toggle'),

      body: {'enabled': enabled},
    );

    final group = decoded['group'];

    if (group is! Map) {
      return enabled;
    }

    return group['enabled'] == true;
  }
}
