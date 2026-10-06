import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikari_novel_flutter/service/browser_session.dart';

void main() {
  final origin = Uri.parse('https://www.wenku8.net');
  test('verification and account cookies survive and reach API paths', () async {
    final session = encodeBrowserSession(origin, {
      'jieqiUserInfo': 'user=value',
      'jieqiVisitInfo': 'visit',
      'cf_clearance': 'verified',
      '__cf_bm': 'bot-session',
    });
    final jar = CookieJar();
    await jar.saveFromResponse(origin, decodeBrowserSession(session, origin));
    final cookies = await jar.loadForRequest(origin.resolve('/modules/article/bookcase.php'));
    expect({for (final c in cookies) c.name: c.value}, {
      'jieqiUserInfo': 'user=value',
      'jieqiVisitInfo': 'visit',
      'cf_clearance': 'verified',
      '__cf_bm': 'bot-session',
    });
    expect(await jar.loadForRequest(Uri.parse('https://www.wenku8.cc/')), isEmpty);
  });
  test('stored verification session is not reused on another node', () {
    final session = encodeBrowserSession(origin, {'cf_clearance': 'verified'});
    expect(decodeBrowserSession(session, Uri.parse('https://www.wenku8.cc')), isEmpty);
  });
  test('legacy account cookies remain compatible, including equals in values', () {
    final cookies = decodeBrowserSession('jieqiUserInfo=a=b; jieqiVisitInfo=c', origin);
    expect({for (final c in cookies) c.name: c.value}, {
      'jieqiUserInfo': 'a=b', 'jieqiVisitInfo': 'c',
    });
  });
}
