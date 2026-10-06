import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';

/// Keep a WebView session on the host that issued it, including verification cookies.
String encodeBrowserSession(Uri origin, Map<String, String> cookies) =>
    jsonEncode({'host': origin.host, 'cookies': cookies});

List<Cookie> decodeBrowserSession(String session, Uri origin) {
  Map<String, String> values;
  if (session.trimLeft().startsWith('{')) {
    final data = jsonDecode(session) as Map<String, dynamic>;
    if (data['host'] != origin.host) return [];
    values = Map<String, String>.from(data['cookies'] as Map);
  } else {
    // Older versions stored only the account cookies as a Cookie header.
    values = {};
    for (final part in session.split(';')) {
      final separator = part.indexOf('=');
      if (separator < 1) continue;
      values[part.substring(0, separator).trim()] = part.substring(separator + 1).trim();
    }
  }
  return values.entries.map((entry) => Cookie(entry.key, entry.value)..path = '/').toList();
}
