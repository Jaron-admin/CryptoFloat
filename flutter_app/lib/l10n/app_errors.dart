import 'package:flutter/widgets.dart';

import 'l10n.dart';

/// Maps known app messages to the current locale without displaying raw
/// external errors, which can contain local paths or request credentials.
String localizeAppError(BuildContext context, Object? error) {
  final l10n = context.l10n;
  final message =
      (error is FormatException ? error.message : error?.toString() ?? '')
          .replaceFirst(
            RegExp(r'^(?:Bad state: |FormatException: |Exception: )'),
            '',
          )
          .trim();
  final status =
      RegExp(r'^数据源返回 HTTP (\d{3})。$').firstMatch(message) ??
      RegExp(r'^The data source returned HTTP (\d{3})\.$').firstMatch(message);
  if (status != null) return l10n.errorHttpStatus(int.parse(status.group(1)!));
  final limit =
      RegExp(r'^数据源响应超过 (\d+) MB 上限。$').firstMatch(message) ??
      RegExp(r'^The data source response exceeds the (\d+) MB limit\.$')
          .firstMatch(message);
  if (limit != null) {
    final size = int.tryParse(limit.group(1)!);
    if (size != null) return l10n.errorResponseLimit(size);
  }
  return switch (message) {
    "设置文件无法读取，已使用默认布局。原文件仍保留。" ||
    "The settings file could not be read. The default layout is in use and the original file has been kept." =>
      l10n.errorStartupDefaultLayout,
    "已保存的字体无法加载，请在外观设置中重新选择字体。" ||
    "A saved font could not be loaded. Choose another font in Appearance." =>
      l10n.errorStartupFont,
    "窗口设置未能应用，可继续使用并在设置中重试。" ||
    "Window settings could not be applied. You can continue using the app and try again in Settings." =>
      l10n.errorStartupWindow,
    "数值无效，保留原值和单位。" ||
    "The value is invalid. The original value and unit have been kept." =>
      l10n.errorInvalidValue,
    "自定义倍率无效，保留原值和单位。" ||
    "The custom multiplier is invalid. The original value and unit have been kept." =>
      l10n.errorInvalidMultiplier,
    "换算结果超出范围。" ||
    "The converted value is out of range." => l10n.errorConversionOverflow,
    "汇率未获取、已过期或无效，保留原值和单位。" ||
    "The exchange rate is missing, expired, or invalid. The original value and unit have been kept." =>
      l10n.errorExchangeRateUnavailable,
    "设置正在保存，请稍候。" ||
    "Settings are being saved. Please wait." => l10n.errorSaving,
    "设置已保存；窗口置顶未能应用，重新打开可重试。" ||
    "Settings were saved, but always on top could not be applied. Reopen the app to try again." =>
      l10n.errorSavedTopmost,
    "设置已保存；窗口透明度未能应用，重新打开可重试。" ||
    "Settings were saved, but window transparency could not be applied. Reopen the app to try again." =>
      l10n.errorSavedOpacity,
    "暂时无法创建托盘图标，窗口保持显示。请稍后重试。" ||
    "The tray icon could not be created. The window will remain visible. Try again later." =>
      l10n.errorTrayUnavailable,
    "图标图片不能超过 1 MB。" ||
    "The icon image must be no larger than 1 MB." => l10n.errorIconTooLarge,
    "请选择不超过 1 MB 的图片。" ||
    "Choose an image no larger than 1 MB." => l10n.errorChooseSmallImage,
    "图标图片尺寸过大，请选择较小的图片。" ||
    "The icon image dimensions are too large. Choose a smaller image." =>
      l10n.errorImageDimensions,
    "图片无法读取。" || "The image could not be read." => l10n.errorImageUnreadable,
    "图片无法读取，请选择 PNG、JPEG、GIF、WebP、BMP 或 ICO 图片。" ||
    "The image could not be read. Choose a PNG, JPEG, GIF, WebP, BMP, or ICO image." =>
      l10n.errorImageUnsupported,
    "数据连接已关闭。" ||
    "The data connection has been closed." => l10n.errorConnectionClosed,
    "网络连接超时，请稍后重试。" || "The network connection timed out. Try again later." =>
      l10n.errorNetworkTimeout,
    "无法建立网络连接，请检查网络设置。" ||
    "A network connection could not be established. Check your network settings." =>
      l10n.errorNetworkSettings,
    "数据连接需要完整的 HTTPS 地址，且不能包含账号密码或片段。" ||
    "Enter a complete HTTPS address without credentials or a fragment." =>
      l10n.errorHttpsRequired,
    "币种目录地址不受支持。" ||
    "This market catalog address is not supported." => l10n.errorCatalogUrl,
    "请求超时，请稍后重试。" ||
    "The request timed out. Try again later." => l10n.errorRequestTimeout,
    "暂时无法连接数据源，请检查网络连接。" ||
    "The data source could not be reached. Check your network connection." =>
      l10n.errorSourceConnection,
    "HTTPS 证书验证失败。" ||
    "HTTPS certificate verification failed." => l10n.errorCertificate,
    "数据连接失败，请检查地址或网络设置。" ||
    "The data connection failed. Check the address and network settings." =>
      l10n.errorConnectionFailed,
    "响应不是有效的 UTF-8 JSON。" ||
    "The response is not valid UTF-8 JSON." => l10n.errorInvalidJson,
    "数据源发生跳转。请填写最终的 HTTPS 地址。" ||
    "The data source redirected the request. Enter the final HTTPS address." =>
      l10n.errorRedirect,
    "数据源限制请求频率，请稍后重试或增大刷新间隔。" ||
    "The data source is limiting requests. Try later or increase the refresh interval." =>
      l10n.errorRateLimited,
    "JSON 路径含有空字段名。" ||
    "The JSON path contains an empty field name." => l10n.errorJsonEmptyField,
    "JSON 字段之间需要点或方括号。" ||
    "Use a dot or brackets between JSON fields." => l10n.errorJsonSeparator,
    "JSON 路径缺少右方括号。" || "The JSON path is missing a closing bracket." =>
      l10n.errorJsonClosingBracket,
    "JSON 路径缺少引号。" ||
    "The JSON path is missing a quotation mark." => l10n.errorJsonQuote,
    "JSON 路径中的引号或转义无效。" ||
    "The JSON path contains an invalid quotation mark or escape sequence." =>
      l10n.errorJsonEscape,
    "数组索引需要非负整数。" || "An array index must be a non-negative integer." =>
      l10n.errorJsonArrayIndex,
    "JSON 路径无效。" || "The JSON path is invalid." => l10n.errorJsonPath,
    "JSON 数组索引不存在。" ||
    "The JSON array index does not exist." => l10n.errorJsonIndexMissing,
    "JSON 字段路径不存在。" ||
    "The JSON field path does not exist." => l10n.errorJsonFieldMissing,
    "地址需要完整的 HTTPS URL，且不能含账号密码或片段。" ||
    "Enter a complete HTTPS URL without credentials or a fragment." =>
      l10n.errorSourceUrl,
    "密钥不能写在地址中。请使用受保护的请求头。" ||
    "Do not put keys in the URL. Use a protected request header." =>
      l10n.errorKeyInUrl,
    "请求头数量超过 64 个上限。" ||
    "A source can have at most 64 request headers." => l10n.errorTooManyHeaders,
    "认证请求头需要使用密钥存储引用。" ||
    "Authentication headers must use a reference to protected key storage." =>
      l10n.errorProtectedHeader,
    "密钥存储引用不能为空。" || "The key storage reference must not be empty." =>
      l10n.errorEmptyKeyReference,
    "字段数量超过 500 个上限。" ||
    "A source can have at most 500 fields." => l10n.errorTooManyFields,
    "字段 ID 不能为空或重复。" ||
    "Field IDs must not be empty or duplicated." => l10n.errorDuplicateField,
    "请求头名称或内容无效。" ||
    "A request header name or value is invalid." => l10n.errorInvalidHeader,
    "此请求头由安全网络连接管理。" ||
    "This header is managed by the secure network connection." =>
      l10n.errorManagedHeader,
    "汇率响应无效，保留原值和单位。" ||
    "The exchange rate response is invalid. The original value and unit have been kept." =>
      l10n.errorInvalidRateResponse,
    "汇率基准无效，保留原值和单位。" ||
    "The exchange rate base is invalid. The original value and unit have been kept." =>
      l10n.errorInvalidRateBase,
    "无法读取系统代理，请检查 Windows 网络设置。" ||
    "System proxy settings could not be read. Check Windows network settings." =>
      l10n.errorProxyRead,
    "当前程序未提供系统代理功能，请使用完整的新版本程序。" ||
    "System proxy support is unavailable. Use the complete, current app package." =>
      l10n.errorProxyUnavailable,
    "暂不支持当前网络连接类型，请检查系统网络设置。" ||
    "This network connection type is not supported. Check system network settings." =>
      l10n.errorNetworkType,
    "系统网络设置无效，请检查后重试。" ||
    "System network settings are invalid. Check them and try again." =>
      l10n.errorInvalidSystemNetwork,
    "无法应用系统网络设置，请检查后重试。" ||
    "System network settings could not be applied. Check them and try again." =>
      l10n.errorApplySystemNetwork,
    "设置已更新，等待新行情。" ||
    "Settings updated. Waiting for new quotes." => l10n.errorWaitingForData,
    "此数据源已停用。" || "This data source is disabled." => l10n.errorSourceDisabled,
    "所选字段需要单个数字、文本或布尔值。" ||
    "The selected field must contain a single number, text value, or boolean." =>
      l10n.errorScalarField,
    "所选字段暂无有效数据。" ||
    "The selected field has no valid data yet." => l10n.errorFieldUnavailable,
    "响应中没有可选择的字段。" ||
    "The response has no selectable fields." => l10n.errorNoResponseFields,
    "此数据源缺少受保护的请求头。请在设置中重新填写密钥。" ||
    "A protected request header is missing. Re-enter the key in Settings." =>
      l10n.errorMissingProtectedHeader,
    "读取受保护的请求头超时，请重试。" ||
    "Reading a protected request header timed out. Try again." =>
      l10n.errorKeyReadTimeout,
    "无法完成数据请求。请检查数据源、密钥和网络设置。" ||
    "The data request could not be completed. Check the source, key, and network settings." =>
      l10n.errorRequestFailed,
    "代理端口需要在 1 到 65535 之间。" ||
    "The proxy port must be between 1 and 65535." => l10n.errorProxyPort,
    "系统代理返回了无效的连接设置。" ||
    "The system proxy returned invalid connection settings." =>
      l10n.errorProxyInvalidSettings,
    "系统代理返回的候选地址过多。" ||
    "The system proxy returned too many candidate addresses." =>
      l10n.errorProxyTooManyAddresses,
    "暂不支持当前网络连接类型，请使用 HTTP 或混合代理端口。" ||
    "This connection type is not supported. Use an HTTP or mixed proxy port." =>
      l10n.errorProxyUnsupportedType,
    "系统代理格式暂不支持，请使用 HTTP 代理或混合代理端口。" ||
    "This system proxy format is not supported. Use an HTTP or mixed proxy port." =>
      l10n.errorProxyUnsupportedFormat,
    "代理地址无效，请填写主机名或 IP 地址。" ||
    "The proxy address is invalid. Enter a hostname or IP address." =>
      l10n.errorProxyHost,
    "代理 IPv6 地址无效。" ||
    "The proxy IPv6 address is invalid." => l10n.errorProxyIpv6,
    "代理地址无效，请只填写主机名或 IP，不要填写协议、路径或账号密码。" ||
    "Enter only the proxy hostname or IP, without a scheme, path, or credentials." =>
      l10n.errorProxyAddress,
    "设置文件无法读取，已恢复上次备份。原文件保留。" ||
    "The settings file could not be read. The previous backup was restored and the original file was kept." =>
      l10n.errorConfigRestored,
    "设置文件无法读取，已使用默认设置。原文件保留。" ||
    "The settings file could not be read. Default settings are in use and the original file was kept." =>
      l10n.errorConfigDefaults,
    "设置文件过大。" || "The settings file is too large." => l10n.errorConfigTooLarge,
    "设置文件需要 JSON 对象。" ||
    "The settings file must contain a JSON object." => l10n.errorConfigObject,
    "设置文件版本比本应用更新。" ||
    "The settings file was created by a newer app version." =>
      l10n.errorConfigNewerVersion,
    "设置内容超过 2 MB。" ||
    "Settings exceed the 2 MB limit." => l10n.errorConfigSizeLimit,
    "旧版设置文件超过 2 MB。" || "The legacy settings file exceeds the 2 MB limit." =>
      l10n.errorLegacyConfigSize,
    "旧版设置文件需要 JSON 对象。" ||
    "The legacy settings file must contain a JSON object." =>
      l10n.errorLegacyConfigObject,
    "旧版设置文件不是有效的 JSON 设置对象。" ||
    "The legacy settings file is not a valid JSON settings object." =>
      l10n.errorLegacyConfigInvalid,
    "目录已更新，但本地缓存无法保存。" ||
    "The catalog was updated, but its local cache could not be saved." =>
      l10n.errorCatalogCacheSave,
    "币种目录暂时无法更新，请稍后重试。" ||
    "The market catalog could not be updated. Try again later." =>
      l10n.errorCatalogUpdate,
    "币种目录缓存超过大小上限。" || "The market catalog cache exceeds its size limit." =>
      l10n.errorCatalogCacheSize,
    "交易所未返回有效的币种目录。" || "The exchange did not return a valid market catalog." =>
      l10n.errorCatalogEmpty,
    "币种目录格式或数量不受支持。" ||
    "The market catalog format or number of entries is not supported." =>
      l10n.errorCatalogFormat,
    "币种目录格式不正确。" ||
    "The market catalog format is invalid." => l10n.errorCatalogInvalid,
    "币种目录来源不受支持。" || "This market catalog provider is not supported." =>
      l10n.errorCatalogProvider,
    "交易所暂未返回可用的现货交易对，已保留现有目录。" ||
    "The exchange returned no available spot pairs. The existing catalog was kept." =>
      l10n.errorCatalogNoPairs,
    "币种目录包含无效的交易对代码。" ||
    "The market catalog contains an invalid trading pair symbol." =>
      l10n.errorCatalogSymbol,
    "币种目录包含无效的名称或代码。" ||
    "The market catalog contains an invalid name or symbol." =>
      l10n.errorCatalogName,
    "此资产的数据源尚不支持。" ||
    "The data provider for this instrument is not supported." =>
      l10n.errorAssetProvider,
    "OKX 未返回有效行情，请检查交易对或地区可用性。" ||
    "OKX returned no valid quote. Check the trading pair and regional availability." =>
      l10n.errorOkxQuote,
    "KuCoin 未返回有效行情，请检查交易对。" ||
    "KuCoin returned no valid quote. Check the trading pair." =>
      l10n.errorKucoinQuote,
    "Yahoo Finance 未返回有效行情，请检查股票代码或稍后重试。" ||
    "Yahoo Finance returned no valid quote. Check the symbol or try again later." =>
      l10n.errorYahooQuote,
    "Yahoo Finance 非官方接口；行情可能延迟。" ||
    "Unofficial Yahoo Finance API. Quotes may be delayed." =>
      l10n.errorYahooNotice,
    "行情响应结构无效。" ||
    "The quote response structure is invalid." => l10n.errorQuoteStructure,
    "数据源未返回此资产的行情。" ||
    "The data source returned no quote for this instrument." =>
      l10n.errorQuoteMissing,
    "数据源没有有效的最新价格。" ||
    "The data source has no valid latest price." => l10n.errorPriceMissing,
    _ => l10n.errorUnknown,
  };
}
