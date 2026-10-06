import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../common/constants.dart';

const browserFetchScript = r'''
const target = new URL(requestUrl);
if (target.origin !== location.origin) {
  throw new Error("Session requests must stay on the selected website");
}
const abort = new AbortController();
const timer = setTimeout(() => abort.abort(), 30000);
try {
  const options = {
    method: requestMethod,
    credentials: "same-origin",
    redirect: "follow",
    signal: abort.signal,
    headers: { "Accept": "text/html,application/xhtml+xml" }
  };
  if (requestMethod === "POST") {
    options.headers["Content-Type"] = "application/x-www-form-urlencoded";
    options.body = requestBody;
  }
  const response = await fetch(target.href, options);
  const bytes = new Uint8Array(await response.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.length; i += 8192) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 8192));
  }
  return {
    status: response.status,
    body: btoa(binary),
    challenge: response.headers.get("cf-mitigated") === "challenge"
  };
} finally {
  clearTimeout(timer);
}
''';

/// Requests use the same native cookie store and browser engine as the login page.
class BrowserTransport {
  InAppWebViewController? _loginBrowser;
  HeadlessInAppWebView? _headless;
  Future<InAppWebViewController>? _ready;
  String? _origin;

  void attachLoginBrowser(InAppWebViewController? controller) {
    _loginBrowser = controller;
  }

  Future<void> reset() async {
    _loginBrowser = null;
    _ready = null;
    _origin = null;
    final browser = _headless;
    _headless = null;
    await browser?.dispose();
  }

  Future<InAppWebViewController> _controller(Uri origin) async {
    final login = _loginBrowser;
    if (login != null) return login;
    if (_origin != origin.origin) {
      await reset();
      _origin = origin.origin;
    }
    return _ready ??= _open(origin);
  }

  Future<InAppWebViewController> _open(Uri origin) async {
    final loaded = Completer<InAppWebViewController>();
    final browser = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(origin.resolve('/index.php').toString())),
      initialSettings: InAppWebViewSettings(
        userAgent: kUserAgent['User-Agent'],
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, url) {
        if (!loaded.isCompleted) loaded.complete(controller);
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true && !loaded.isCompleted) {
          loaded.complete(controller);
        }
      },
    );
    _headless = browser;
    try {
      await browser.run();
      return await loaded.future.timeout(const Duration(seconds: 35));
    } catch (_) {
      await reset();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> request(
    Uri origin,
    String url, {
    String method = 'GET',
    String? body,
  }) async {
    final target = Uri.parse(url);
    if (target.origin != origin.origin) {
      throw ArgumentError('Session request must stay on the selected website');
    }
    final controller = await _controller(origin);
    final result = await controller.callAsyncJavaScript(
      functionBody: browserFetchScript,
      arguments: {'requestUrl': url, 'requestMethod': method, 'requestBody': body},
    ).timeout(const Duration(seconds: 35));
    if (result == null || result.error != null || result.value is! Map) {
      throw StateError('Website request failed in the browser session. Please sign in again.');
    }
    return Map<String, dynamic>.from(result.value as Map);
  }

  static Uint8List decodeBody(Map<String, dynamic> response) =>
      base64Decode(response['body'] as String);
}
