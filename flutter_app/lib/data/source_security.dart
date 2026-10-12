import '../domain/models.dart';

const maxResponseBytes = 2 * 1024 * 1024;

/// Checks user-configured endpoints without including credentials in errors.
Uri validateSource(CustomApiSource source) {
  final uri = Uri.tryParse(source.url.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException('地址需要完整的 HTTPS URL，且不能含账号密码或片段。');
  }
  if (uri.queryParameters.keys.any(
    (key) => RegExp(
      r'(^|[-_])(api[-_]?key|access[-_]?token|token|secret|password|auth|authorization|signature|key)([-_]|$)',
      caseSensitive: false,
    ).hasMatch(key),
  )) {
    throw const FormatException('密钥不能写在地址中。请使用受保护的请求头。');
  }
  if (source.headers.length + source.secretHeaderRefs.length > 64) {
    throw const FormatException('请求头数量超过 64 个上限。');
  }
  for (final entry in source.headers.entries) {
    validateHeader(entry.key, entry.value);
    if (isSensitiveHeader(entry.key)) {
      throw const FormatException('认证请求头需要使用密钥存储引用。');
    }
  }
  for (final entry in source.secretHeaderRefs.entries) {
    validateHeader(entry.key, '');
    if (entry.value.trim().isEmpty) throw const FormatException('密钥存储引用不能为空。');
  }
  if (source.fields.length > 500) {
    throw const FormatException('字段数量超过 500 个上限。');
  }
  final ids = <String>{};
  for (final field in source.fields) {
    if (field.id.isEmpty || !ids.add(field.id)) {
      throw const FormatException('字段 ID 不能为空或重复。');
    }
  }
  return uri;
}

void validateHeader(String name, String value) {
  if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(name) ||
      RegExp(r'[\r\n\x00]').hasMatch(value)) {
    throw const FormatException('请求头名称或内容无效。');
  }
  if (const {
    'host',
    'content-length',
    'transfer-encoding',
    'connection',
    'proxy-authorization',
  }.contains(name.toLowerCase())) {
    throw const FormatException('此请求头由安全网络连接管理。');
  }
}
