import 'package:flutter_test/flutter_test.dart';
import 'package:hikari_novel_flutter/service/network_diagnostic.dart';

void main() {
  test('ordinary 403 does not claim a Cloudflare or IP ban', () {
    final text = formatWebsiteFailure(Uri.parse('https://www.wenku8.net/userdetail.php'),
        {'status': 403, 'challenge': false});
    expect(text, contains('尚不能确定是否为 IP 限制'));
    expect(text, contains('验证页标记：未收到'));
    expect(text, isNot(contains('Cloudflare 验证页')));
  });
  test('challenge marker is recognized even for non-403 status', () {
    final text = formatWebsiteFailure(Uri.parse('https://www.wenku8.cc/userdetail.php'),
        {'status': 503, 'challenge': true, 'ray': 'abcdef0123456789-HKG'});
    expect(text, contains('Cloudflare 验证页'));
    expect(text, contains('HTTP：503'));
    expect(text, contains('abcdef0123456789-HKG'));
  });
  test('credentials, queries and HTML never enter the diagnostic', () {
    final text = formatWebsiteFailure(
        Uri.parse('https://username:secret@www.wenku8.net/userdetail.php?token=secret#secret'),
        {'status': 403, 'challenge': false, 'ray': 'cookie=secret',
         'body': 'secret', 'cookie': 'secret'});
    expect(text, contains('请求：www.wenku8.net/userdetail.php'));
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('username')));
    expect(text, contains('请求编号：未提供'));
  });
}
