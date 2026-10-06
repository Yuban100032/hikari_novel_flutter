import 'dart:convert';
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
  test('comma-separated analytics cookie does not break login', () async {
    final session = encodeBrowserSession(origin, {
      'jieqiUserInfo': 'user',
      'jieqiVisitInfo': 'visit',
      'cf_clearance': 'verified',
      'Hm_lvt_analytics': '1700000000,1700000010,1700000020',
    });
    final saved = jsonDecode(session) as Map<String, dynamic>;
    expect((saved['cookies'] as Map).containsKey('Hm_lvt_analytics'), isFalse);
    final jar = CookieJar();
    await jar.saveFromResponse(origin, decodeBrowserSession(session, origin));
    final cookies = await jar.loadForRequest(origin.resolve('/userdetail.php'));
    expect({for (final c in cookies) c.name: c.value}, {
      'jieqiUserInfo': 'user', 'jieqiVisitInfo': 'visit', 'cf_clearance': 'verified',
    });
  });
  test('previously saved sessions ignore invalid analytics cookies', () {
    final session = jsonEncode({'host': origin.host, 'cookies': {
      'jieqiUserInfo': 'user', 'jieqiVisitInfo': 'visit',
      'cf_clearance': 'verified', 'Hm_lvt_analytics': '1700000000,1700000010',
    }});
    expect(decodeBrowserSession(session, origin).map((c) => c.name),
        ['jieqiUserInfo', 'jieqiVisitInfo', 'cf_clearance']);
    expect(decodeBrowserSession('jieqiUserInfo=user; Hm_lvt_analytics=1,2', origin)
        .map((c) => c.name), ['jieqiUserInfo']);
  });
  test('invalid session cookie errors do not expose the cookie value', () {
    try {
      decodeBrowserSession(encodeBrowserSession(origin, {'cf_clearance': 'private,token'}), origin);
      fail('Expected a format error');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains('private,token')));
      expect(error.toString(), contains('cf_clearance'));
    }
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
