import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zauto_driver/services/auth_service.dart';
import 'package:zauto_driver/services/backend/backend_api_base.dart';

class _FakeAuthService extends AuthService {
  int invalidations = 0;

  @override
  Future<Map<String, String>> authHeaders() async => {
        'Authorization': 'Bearer test-token',
      };

  @override
  Future<void> invalidateSession() async {
    invalidations += 1;
  }
}

void main() {
  test('all REST verbs and multipart reuse a single injected HTTP client',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{"success":true}', 200);
    });
    addTearDown(client.close);
    final auth = _FakeAuthService();
    final api = BackendApiBase(
      baseUrl: 'https://example.test',
      auth: auth,
      client: client,
    );

    final url = Uri.parse('https://example.test/api/me/items');
    await api.getJson(url);
    await api.postJson(url, body: {'action': 'accept'});
    await api.patchJson(url, body: {'changed': true});
    await api.putJson(url, body: {'value': 2});
    await api.deleteJson(url, body: {'id': 'message-1'});

    final multipart = http.MultipartRequest('POST', url);
    multipart.headers.addAll(await auth.authHeaders());
    multipart.files.add(http.MultipartFile.fromString(
      'file',
      'hello',
      filename: 'test.txt',
    ));
    final response = await api.sendMultipartRequest(multipart);
    expect(response.statusCode, 200);

    expect(requests.map((r) => r.method),
        ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'POST']);
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer test-token');
    }
    expect(requests[1].body, '{"action":"accept"}');
    expect(requests[4].body, '{"id":"message-1"}');
    expect(requests[5].headers['content-type'], contains('multipart/form-data'));
    expect(auth.invalidations, 0);
  });

  test('401 still invalidates the session with a pooled HTTP client',
      () async {
    final auth = _FakeAuthService();
    final client = MockClient(
      (_) async => http.Response('{"error":"Phiên hết hạn"}', 401),
    );
    addTearDown(client.close);
    final api = BackendApiBase(
      baseUrl: 'https://example.test',
      auth: auth,
      client: client,
    );

    await expectLater(
      api.getJson(Uri.parse('https://example.test/api/me')),
      throwsA(isA<Exception>()),
    );
    expect(auth.invalidations, 1);
  });

  test('client failures remain user-friendly', () async {
    final client = MockClient((request) async {
      throw http.ClientException('Connection closed', request.url);
    });
    addTearDown(client.close);
    final api = BackendApiBase(
      baseUrl: 'https://example.test',
      auth: _FakeAuthService(),
      client: client,
    );

    await expectLater(
      api.getJson(Uri.parse('https://example.test/api/me')),
      throwsA(predicate((error) =>
          error.toString().contains('Không thể kết nối tới backend'))),
    );
  });
}
