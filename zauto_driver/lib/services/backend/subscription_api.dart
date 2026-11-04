import 'dart:math';

import '../../config/app_config.dart';
import '../auth_service.dart';
import 'backend_api_base.dart';

Map<String, dynamic> subscriptionMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> subscriptionRows(dynamic value) => value is List
    ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
    : <Map<String, dynamic>>[];

abstract class SubscriptionGateway {
  Future<Map<String, dynamic>> overview();
  Future<Map<String, dynamic>> users({String query = '', int offset = 0});
  Future<Map<String, dynamic>> user(String id);
  Future<List<Map<String, dynamic>>> logs({String? userId});
  Future<Map<String, dynamic>> command(String userId, String action, Map<String, dynamic> body);
}

SubscriptionGateway createSubscriptionApi() => SubscriptionApi(
  baseUrl: AppConfig.backendUrl, auth: AuthService(),
);
String newSubscriptionRequestId() {
  final random = Random.secure();
  return List.generate(24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class SubscriptionApi extends BackendApiBase implements SubscriptionGateway {
  SubscriptionApi({required super.baseUrl, required super.auth});
  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/subscriptions$path').replace(queryParameters: query);

  @override
  Future<Map<String, dynamic>> overview() async {
    final values = await Future.wait([getJson(_uri('/me')), getJson(_uri('/plans'))]);
    return {...subscriptionMap(values[0]), 'plans': subscriptionMap(values[1])['plans']};
  }
  @override
  Future<Map<String, dynamic>> users({String query = '', int offset = 0}) async =>
      subscriptionMap(await getJson(_uri('/admin/users', {'q': query, 'offset': '$offset', 'limit': '25'})));
  @override
  Future<Map<String, dynamic>> user(String id) async =>
      subscriptionMap(await getJson(_uri('/admin/users/${Uri.encodeComponent(id)}')));
  @override
  Future<List<Map<String, dynamic>>> logs({String? userId}) async =>
      subscriptionRows(subscriptionMap(await getJson(_uri('/admin/logs',
          userId == null ? null : {'userId': userId})))['logs']);
  @override
  Future<Map<String, dynamic>> command(String userId, String action, Map<String, dynamic> body) async {
    final id = Uri.encodeComponent(userId);
    switch (action) {
      case 'assign': return subscriptionMap(await postJson(_uri('/admin/users/$id/plan'), body: body));
      case 'renew': return subscriptionMap(await postJson(_uri('/admin/users/$id/renew'), body: body));
      case 'revoke': return subscriptionMap(await deleteJson(_uri('/admin/users/$id/plan'), body: body));
      case 'reconcile': return subscriptionMap(await postJson(_uri('/admin/users/$id/resolve'), body: body));
      default: throw ArgumentError.value(action, 'action');
    }
  }
}
