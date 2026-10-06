import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';

// Analytics/history cookies are not needed for login and may contain values
// (such as comma-separated timestamps) that dart:io Cookie does not accept.
const _sessionCookieNames = {
  'jieqiUserInfo',
  'jieqiVisitInfo',
  'jieqiUserCharset',
  'PHPSESSID',
  'cf_clearance',
  '__cf_bm',
  '_cfuvid',
  '__cfruid',
};

Map<String, String> _sessionCookies(Map<String, String> cookies) => {
  for (final entry in cookies.entries)
    if (_sessionCookieNames.contains(entry.key)) entry.key: entry.value,
};

/// Keep only account/verification cookies on the host that issued them.
String encodeBrowserSession(Uri origin, Map<String, String> cookies) =>
    jsonEncode({'host': origin.host, 'cookies': _sessionCookies(cookies)});

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
  // Also filter sessions saved by the previous version before constructing Cookies.
  final result = <Cookie>[];
  for (final entry in _sessionCookies(values).entries) {
    try {
      result.add(Cookie(entry.key, entry.value)..path = '/');
    } on FormatException {
      // Never display token contents from Cookie's original exception.
      throw FormatException('Unsupported session cookie format: ${entry.key}. Please sign in again.');
    }
  }
  return result;
}
