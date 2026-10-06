/// Formats only request location and non-secret response metadata.
/// Never include query parameters, response body, Cookie or Set-Cookie.
String formatWebsiteFailure(Uri request, Map<String, dynamic> response) {
  final status = (response['status'] as num).toInt();
  final challenge = response['challenge'] == true;
  final ray = response['ray'];
  final safeRay = ray is String &&
      RegExp(r'^[0-9a-fA-F]{8,64}(?:-[A-Z0-9]{2,8})?$').hasMatch(ray)
      ? ray
      : '未提供';
  final reason = challenge
      ? '网站返回 Cloudflare 验证页，应用未能读取所需数据。'
      : status == 403
          ? '网站拒绝本次请求；尚不能确定是否为 IP 限制。'
          : '网站返回 HTTP 错误。';
  return '$reason\n'
      'HTTP：$status\n'
      '请求：${request.host}${request.path}\n'
      '验证页标记：${challenge ? "cf-mitigated: challenge" : "未收到"}\n'
      '请求编号：$safeRay';
}
