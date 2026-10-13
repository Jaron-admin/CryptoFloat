// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get editCancel => '取消';

  @override
  String get editSave => '保存';

  @override
  String get editAdd => '添加';

  @override
  String get editDelete => '删除';

  @override
  String get editAddToDisplay => '加入显示';

  @override
  String get editRemove => '移除';

  @override
  String get editSourceNameRequired => '请为这个数据源起个名字。';

  @override
  String get editSourceUrlInvalid => '请输入 HTTPS 数据接口地址，密钥请放在请求头中。';

  @override
  String get editSourceIntervalInvalid => '刷新间隔应在 15 到 3600 秒之间。';

  @override
  String get editSourceDuplicateHeader => '请求头名称重复，请保留一项。';

  @override
  String get editSourceFieldsRequired => '请至少选择一个显示字段。';

  @override
  String get editSetField => '设置显示字段';

  @override
  String get editField => '编辑显示字段';

  @override
  String get editFieldName => '显示名称';

  @override
  String get editFieldNameHint => '例如：账户余额、室外温度';

  @override
  String get editFieldUnit => '单位（可选）';

  @override
  String get editFieldUnitHint => '例如：USD、°C、人';

  @override
  String get editFieldPath => '返回数据中的位置';

  @override
  String get editFieldPathHint => '例如：data.balance 或 items[0].price';

  @override
  String get editSourceAdd => '添加自定义 API';

  @override
  String get editSourceEdit => '编辑自定义 API';

  @override
  String get editSourceEnabled => '启用这个数据源';

  @override
  String get editConnectSource => '连接数据源';

  @override
  String get editSourceName => '数据源名称';

  @override
  String get editSourceNameHint => '例如：我的账户、天气';

  @override
  String get editSourceUrl => 'HTTPS 接口地址';

  @override
  String get editSourceInterval => '刷新间隔（秒）';

  @override
  String get editSourceIntervalHelp => '15–3600 秒，请遵循接口的调用频率限制。';

  @override
  String get editSourceHeaders => '请求头 / API 密钥（需要时填写）';

  @override
  String get editSourceHeadersOptional => '免密钥接口可以跳过';

  @override
  String get editHeaderName => '请求头名称';

  @override
  String get editHeaderSecret => '密钥内容';

  @override
  String get editHeaderValue => '请求头值';

  @override
  String get editHeaderRetain => '已保存，留空保留原值';

  @override
  String get editHeaderTokenHint => '例如：Bearer your-token';

  @override
  String get editHeaderSecure => '作为密钥，由系统保护存储';

  @override
  String get editHeaderAdd => '添加请求头';

  @override
  String get editReadFields => '读取返回字段';

  @override
  String get editDisplayFields => '显示字段';

  @override
  String get editReadFieldsHelp => '读取成功后，点击某个返回值，为它起显示名称并填写单位。';

  @override
  String get editSelectedFields => '已选择的显示字段';

  @override
  String get editRemoveField => '移除字段';

  @override
  String get editAdvancedField => '高级：手动指定字段位置';

  @override
  String get editAddFieldPath => '添加字段位置';

  @override
  String get editFieldSymbol => '代码';

  @override
  String get editFieldLabel => '名称';

  @override
  String get editFieldPrice => '价格';

  @override
  String get editFieldCurrency => '货币单位';

  @override
  String get editFieldChange => '涨跌幅';

  @override
  String get editFieldProvider => '数据源';

  @override
  String get editFieldUpdatedAt => '更新时间';

  @override
  String get editSourceMissing => '未找到的数据源';

  @override
  String get editDisplayText => '显示文字';

  @override
  String get editWantedText => '想显示的文字';

  @override
  String get editWantedTextHint => '例如：今天的价格：  或  我的余额 ';

  @override
  String get editComposeRow => '组合显示行';

  @override
  String get editCloseEditor => '关闭编辑器';

  @override
  String get editComposeRowHelp => '文字与字段从左到右显示，可加入空格和标点。';

  @override
  String get editAddText => '添加文字';

  @override
  String get editAddDataField => '添加数据字段';

  @override
  String get editEmptyRow => '尚未添加文字或字段';

  @override
  String get editDisplayPreview => '最终显示预览';

  @override
  String get editSaveRow => '保存这一行';

  @override
  String get editMoveLeft => '左移';

  @override
  String get editMoveRight => '右移';

  @override
  String get editEmptyText => '空文字';

  @override
  String get editAutomatic => '自动';

  @override
  String get editSelectField => '选择显示字段';

  @override
  String get editSelectSourceFirst => '请先在“关注内容”中选择行情，或添加自定义 API。';

  @override
  String get editFieldSource => '来自哪个内容？';

  @override
  String get editFieldSelection => '显示什么？';

  @override
  String get editNumberFormat => '数字格式';

  @override
  String get editDecimalsTwo => '2 位小数';

  @override
  String get editDecimalsFour => '4 位小数';

  @override
  String get editDecimalsSigned => '正负号 + 2 位小数';

  @override
  String get editRawValue => '保留接口原值';

  @override
  String get editThemeMode => '主题模式';

  @override
  String get editSystem => '跟随系统';

  @override
  String get editLight => '浅色';

  @override
  String get editDark => '深色';

  @override
  String get editLightPreview => '浅色预览';

  @override
  String get editDarkPreview => '深色预览';

  @override
  String get editMyThemes => '我的主题';

  @override
  String get editSaveThemeAs => '将当前配色另存为主题';

  @override
  String get editThemesHelp => '保存喜欢的配色，随时切换使用。';

  @override
  String get editCustomBackground => '自定义背景';

  @override
  String get editDarkPalette => '深色配色';

  @override
  String get editLightPalette => '浅色配色';

  @override
  String get editDarkBackground => '深色背景';

  @override
  String get editLightBackground => '浅色背景';

  @override
  String get editChooseColor => '选择颜色';

  @override
  String get editDeleteTheme => '删除主题';

  @override
  String get editThemeNameRequired => '请输入主题名称';

  @override
  String get editThemeNew => '保存新主题';

  @override
  String get editThemeEdit => '编辑主题';

  @override
  String get editThemeName => '主题名称';

  @override
  String get editThemeNameHint => '为这套配色命名';

  @override
  String get editThemePalette => '编辑配色';

  @override
  String get editColorRole => '颜色用途';

  @override
  String get editHue => '色相';

  @override
  String get editBrightness => '亮度';

  @override
  String get editSaveTheme => '保存主题';

  @override
  String get editApplyColor => '应用颜色';

  @override
  String get editRoleBackground => '窗口背景';

  @override
  String get editRoleSurface => '卡片背景';

  @override
  String get editRoleForeground => '主要文字';

  @override
  String get editRoleSecondary => '次要文字';

  @override
  String get editRoleBorder => '边框与分隔线';

  @override
  String get editRoleAccent => '强调色';

  @override
  String get editRolePositive => '上涨颜色';

  @override
  String get editRoleNegative => '下跌颜色';

  @override
  String get editTemplateWeather => '城市天气';

  @override
  String get editTemplateRates => '参考汇率';

  @override
  String get editTemplateGithub => 'GitHub 仓库';

  @override
  String get editTemplateMarket => '简洁行情条';

  @override
  String get editTemplateReminder => '文字提醒';

  @override
  String get editTemplateWeatherHelp =>
      '气温、体感温度和湿度；15 分钟刷新。由 Open-Meteo 提供，适合个人使用。';

  @override
  String get editTemplateRatesHelp => '美元兑人民币、欧元、USDT 的参考汇率；5 分钟刷新。';

  @override
  String get editTemplateGithubHelp => '公开仓库的 Stars 和未解决议题与 PR 数量；10 分钟刷新。';

  @override
  String get editTemplateMarketHelp => '把关注列表的前 3 个行情组合成一行，跟随单位设置。';

  @override
  String get editTemplateReminderHelp => '直接显示一段文字，不需要网络。也可以用显示行编辑器继续加入数据字段。';

  @override
  String get editTemplateDefaultReminder => '提醒：起来走走，喝杯水';

  @override
  String get editTemplateAdd => '添加实用模板';

  @override
  String get editTemplateClose => '关闭模板';

  @override
  String get editCity => '城市';

  @override
  String get editRepoOwner => '仓库拥有者';

  @override
  String get editRepoOwnerHint => '例如 flutter';

  @override
  String get editRepoName => '仓库名称';

  @override
  String get editRepoNameHint => '例如 MetricPerch';

  @override
  String editHeaderMissingSecret(String name) {
    return '请填写 $name 的密钥。';
  }

  @override
  String editHeaderCount(int count) {
    return '$count 个请求头';
  }

  @override
  String editRowFormat(String format) {
    return '格式：$format';
  }

  @override
  String editThemeEditNamed(String name) {
    return '编辑 $name';
  }

  @override
  String editThemeCopyNamed(String name) {
    return '复制 $name';
  }

  @override
  String editThemeDeleteNamed(String name) {
    return '删除 $name';
  }

  @override
  String editThemeCopyName(String name) {
    return '$name 副本';
  }

  @override
  String editThemeDeleteConfirm(String name) {
    return '删除“$name”？正在使用的配色将切换为 Fluent 蓝。';
  }

  @override
  String editThemeBackgroundTitle(String mode) {
    return '$mode自定义背景';
  }

  @override
  String get editThemeFluent => 'Fluent 蓝';

  @override
  String get editThemeNord => 'Nord 北欧';

  @override
  String get editThemeSolarized => 'Solarized 护眼';

  @override
  String get editCityBeijing => '北京';

  @override
  String get editCityShanghai => '上海';

  @override
  String get editCityGuangzhou => '广州';

  @override
  String get editCityShenzhen => '深圳';

  @override
  String get editCityHangzhou => '杭州';

  @override
  String get editCityChengdu => '成都';

  @override
  String get editCityWuhan => '武汉';

  @override
  String get editCityXian => '西安';

  @override
  String get editTemplateCityInvalid => '请选择列表中的城市。添加后可在数据源中调整地址。';

  @override
  String get editTemplateTemperature => '气温';

  @override
  String get editTemplateFeelsLike => '体感';

  @override
  String get editTemplateHumidity => '湿度';

  @override
  String get editTemplateUsdRates => '美元参考汇率';

  @override
  String get editTemplateUsdCny => '美元兑人民币';

  @override
  String get editTemplateUsdEur => '美元兑欧元';

  @override
  String get editTemplateUsdUsdt => '美元兑 USDT';

  @override
  String get editTemplateRepoInvalid => '请填写公开仓库的拥有者和仓库名，例如 flutter / flutter。';

  @override
  String get editTemplateOpenIssues => '未解决议题与 PR';

  @override
  String get editTemplateOpen => '未解决';

  @override
  String get editTemplateMarketEmpty => '请先选择至少一个币种或股票。';

  @override
  String get editTemplateTextEmpty => '请填写要显示的文字。';

  @override
  String editTemplateWeatherName(String city) {
    return '$city天气';
  }

  @override
  String get editMyTheme => '我的主题';

  @override
  String get editMenuHide => '隐藏到托盘';

  @override
  String get editMenuShow => '显示悬浮窗';

  @override
  String get editMenuRefresh => '立即刷新';

  @override
  String get editMenuTopmost => '窗口置顶';

  @override
  String get editMenuSettings => '设置';

  @override
  String get editMenuExit => '退出';

  @override
  String get errorStartupDefaultLayout => '设置文件无法读取，已使用默认布局。原文件仍保留。';

  @override
  String get errorStartupFont => '已保存的字体无法加载，请在外观设置中重新选择字体。';

  @override
  String get errorStartupWindow => '窗口设置未能应用，可继续使用并在设置中重试。';

  @override
  String get errorInvalidValue => '数值无效，保留原值和单位。';

  @override
  String get errorInvalidMultiplier => '自定义倍率无效，保留原值和单位。';

  @override
  String get errorConversionOverflow => '换算结果超出范围。';

  @override
  String get errorExchangeRateUnavailable => '汇率未获取、已过期或无效，保留原值和单位。';

  @override
  String get errorSaving => '设置正在保存，请稍候。';

  @override
  String get errorSavedTopmost => '设置已保存；窗口置顶未能应用，重新打开可重试。';

  @override
  String get errorSavedOpacity => '设置已保存；窗口透明度未能应用，重新打开可重试。';

  @override
  String get errorTrayUnavailable => '暂时无法创建托盘图标，窗口保持显示。请稍后重试。';

  @override
  String get errorIconTooLarge => '图标图片不能超过 1 MB。';

  @override
  String get errorChooseSmallImage => '请选择不超过 1 MB 的图片。';

  @override
  String get errorImageDimensions => '图标图片尺寸过大，请选择较小的图片。';

  @override
  String get errorImageUnreadable => '图片无法读取。';

  @override
  String get errorImageUnsupported =>
      '图片无法读取，请选择 PNG、JPEG、GIF、WebP、BMP 或 ICO 图片。';

  @override
  String get errorConnectionClosed => '数据连接已关闭。';

  @override
  String get errorNetworkTimeout => '网络连接超时，请稍后重试。';

  @override
  String get errorNetworkSettings => '无法建立网络连接，请检查网络设置。';

  @override
  String get errorHttpsRequired => '数据连接需要完整的 HTTPS 地址，且不能包含账号密码或片段。';

  @override
  String get errorCatalogUrl => '币种目录地址不受支持。';

  @override
  String get errorRequestTimeout => '请求超时，请稍后重试。';

  @override
  String get errorSourceConnection => '暂时无法连接数据源，请检查网络连接。';

  @override
  String get errorCertificate => 'HTTPS 证书验证失败。';

  @override
  String get errorConnectionFailed => '数据连接失败，请检查地址或网络设置。';

  @override
  String get errorInvalidJson => '响应不是有效的 UTF-8 JSON。';

  @override
  String get errorRedirect => '数据源发生跳转。请填写最终的 HTTPS 地址。';

  @override
  String get errorRateLimited => '数据源限制请求频率，请稍后重试或增大刷新间隔。';

  @override
  String get errorJsonEmptyField => 'JSON 路径含有空字段名。';

  @override
  String get errorJsonSeparator => 'JSON 字段之间需要点或方括号。';

  @override
  String get errorJsonClosingBracket => 'JSON 路径缺少右方括号。';

  @override
  String get errorJsonQuote => 'JSON 路径缺少引号。';

  @override
  String get errorJsonEscape => 'JSON 路径中的引号或转义无效。';

  @override
  String get errorJsonArrayIndex => '数组索引需要非负整数。';

  @override
  String get errorJsonPath => 'JSON 路径无效。';

  @override
  String get errorJsonIndexMissing => 'JSON 数组索引不存在。';

  @override
  String get errorJsonFieldMissing => 'JSON 字段路径不存在。';

  @override
  String get errorSourceUrl => '地址需要完整的 HTTPS URL，且不能含账号密码或片段。';

  @override
  String get errorKeyInUrl => '密钥不能写在地址中。请使用受保护的请求头。';

  @override
  String get errorTooManyHeaders => '请求头数量超过 64 个上限。';

  @override
  String get errorProtectedHeader => '认证请求头需要使用密钥存储引用。';

  @override
  String get errorEmptyKeyReference => '密钥存储引用不能为空。';

  @override
  String get errorTooManyFields => '字段数量超过 500 个上限。';

  @override
  String get errorDuplicateField => '字段 ID 不能为空或重复。';

  @override
  String get errorInvalidHeader => '请求头名称或内容无效。';

  @override
  String get errorManagedHeader => '此请求头由安全网络连接管理。';

  @override
  String get errorInvalidRateResponse => '汇率响应无效，保留原值和单位。';

  @override
  String get errorInvalidRateBase => '汇率基准无效，保留原值和单位。';

  @override
  String get errorProxyRead => '无法读取系统代理，请检查 Windows 网络设置。';

  @override
  String get errorProxyUnavailable => '当前程序未提供系统代理功能，请使用完整的新版本程序。';

  @override
  String get errorNetworkType => '暂不支持当前网络连接类型，请检查系统网络设置。';

  @override
  String get errorInvalidSystemNetwork => '系统网络设置无效，请检查后重试。';

  @override
  String get errorApplySystemNetwork => '无法应用系统网络设置，请检查后重试。';

  @override
  String get errorWaitingForData => '设置已更新，等待新行情。';

  @override
  String get errorSourceDisabled => '此数据源已停用。';

  @override
  String get errorScalarField => '所选字段需要单个数字、文本或布尔值。';

  @override
  String get errorFieldUnavailable => '所选字段暂无有效数据。';

  @override
  String get errorNoResponseFields => '响应中没有可选择的字段。';

  @override
  String get errorMissingProtectedHeader => '此数据源缺少受保护的请求头。请在设置中重新填写密钥。';

  @override
  String get errorKeyReadTimeout => '读取受保护的请求头超时，请重试。';

  @override
  String get errorRequestFailed => '无法完成数据请求。请检查数据源、密钥和网络设置。';

  @override
  String get errorProxyPort => '代理端口需要在 1 到 65535 之间。';

  @override
  String get errorProxyInvalidSettings => '系统代理返回了无效的连接设置。';

  @override
  String get errorProxyTooManyAddresses => '系统代理返回的候选地址过多。';

  @override
  String get errorProxyUnsupportedType => '暂不支持当前网络连接类型，请使用 HTTP 或混合代理端口。';

  @override
  String get errorProxyUnsupportedFormat => '系统代理格式暂不支持，请使用 HTTP 代理或混合代理端口。';

  @override
  String get errorProxyHost => '代理地址无效，请填写主机名或 IP 地址。';

  @override
  String get errorProxyIpv6 => '代理 IPv6 地址无效。';

  @override
  String get errorProxyAddress => '代理地址无效，请只填写主机名或 IP，不要填写协议、路径或账号密码。';

  @override
  String get errorConfigRestored => '设置文件无法读取，已恢复上次备份。原文件保留。';

  @override
  String get errorConfigDefaults => '设置文件无法读取，已使用默认设置。原文件保留。';

  @override
  String get errorConfigTooLarge => '设置文件过大。';

  @override
  String get errorConfigObject => '设置文件需要 JSON 对象。';

  @override
  String get errorConfigNewerVersion => '设置文件版本比本应用更新。';

  @override
  String get errorConfigSizeLimit => '设置内容超过 2 MB。';

  @override
  String get errorLegacyConfigSize => '旧版设置文件超过 2 MB。';

  @override
  String get errorLegacyConfigObject => '旧版设置文件需要 JSON 对象。';

  @override
  String get errorLegacyConfigInvalid => '旧版设置文件不是有效的 JSON 设置对象。';

  @override
  String get errorCatalogCacheSave => '目录已更新，但本地缓存无法保存。';

  @override
  String get errorCatalogUpdate => '币种目录暂时无法更新，请稍后重试。';

  @override
  String get errorCatalogCacheSize => '币种目录缓存超过大小上限。';

  @override
  String get errorCatalogEmpty => '交易所未返回有效的币种目录。';

  @override
  String get errorCatalogFormat => '币种目录格式或数量不受支持。';

  @override
  String get errorCatalogInvalid => '币种目录格式不正确。';

  @override
  String get errorCatalogProvider => '币种目录来源不受支持。';

  @override
  String get errorCatalogNoPairs => '交易所暂未返回可用的现货交易对，已保留现有目录。';

  @override
  String get errorCatalogSymbol => '币种目录包含无效的交易对代码。';

  @override
  String get errorCatalogName => '币种目录包含无效的名称或代码。';

  @override
  String get errorAssetProvider => '此资产的数据源尚不支持。';

  @override
  String get errorOkxQuote => 'OKX 未返回有效行情，请检查交易对或地区可用性。';

  @override
  String get errorKucoinQuote => 'KuCoin 未返回有效行情，请检查交易对。';

  @override
  String get errorYahooQuote => 'Yahoo Finance 未返回有效行情，请检查股票代码或稍后重试。';

  @override
  String get errorYahooNotice => 'Yahoo Finance 非官方接口；行情可能延迟。';

  @override
  String get errorQuoteStructure => '行情响应结构无效。';

  @override
  String get errorQuoteMissing => '数据源未返回此资产的行情。';

  @override
  String get errorPriceMissing => '数据源没有有效的最新价格。';

  @override
  String get errorUnknown => '未能完成操作，请检查设置后重试。';

  @override
  String errorHttpStatus(int status) {
    return '数据源返回 HTTP $status。';
  }

  @override
  String errorResponseLimit(int size) {
    return '数据源响应超过 $size MB 上限。';
  }

  @override
  String get errorPortableDirectory =>
      '无法写入程序旁的 user_data。请将软件放在有写入权限且空间充足的文件夹中。';

  @override
  String get appMoutai => '贵州茅台';

  @override
  String get appPingAn => '平安银行';

  @override
  String get appCatl => '宁德时代';

  @override
  String get panelUnpin => '取消窗口置顶';

  @override
  String get panelPin => '窗口始终置顶';

  @override
  String get panelSettings => '设置…';

  @override
  String get panelNoSources => '未设置数据源';

  @override
  String get panelLive => '实时';

  @override
  String get panelWaiting => '等待首次更新';

  @override
  String panelLastUpdate(String time) {
    return '上次更新于 $time';
  }

  @override
  String panelPending(String time, int count) {
    return '上次更新于 $time · $count项待更新';
  }

  @override
  String panelAutoRefresh(String interval) {
    return ' · 自动刷新 $interval';
  }

  @override
  String panelMinutes(int count) {
    return '$count分';
  }

  @override
  String panelSeconds(int count) {
    return '$count秒';
  }

  @override
  String get panelRatesPending => ' · 汇率未更新';

  @override
  String panelSourceInterval(int seconds) {
    return '每$seconds秒';
  }

  @override
  String panelLastFetch(String time) {
    return '上次获取 $time';
  }

  @override
  String get panelRatesInterval => '换算汇率每5分钟刷新';

  @override
  String get panelLiveNote => '实时表示按期获取成功；上游行情可能延迟。';

  @override
  String panelQuoteTime(String time) {
    return '行情时间 $time';
  }

  @override
  String panelOriginal(String value, String currency) {
    return '原价 $value $currency';
  }

  @override
  String panelUpdated(String time) {
    return '更新于 $time';
  }

  @override
  String get panelChoose => '选择你想关注的内容';

  @override
  String get panelAdd => '添加行情或 API';

  @override
  String get panelRemoved => '已移除的内容';

  @override
  String get panelNoData => '暂无数据，请检查关注内容或数据源';

  @override
  String panelStale(String time) {
    return '过期数据 $time';
  }

  @override
  String get panelConnectionError => '连接异常';

  @override
  String get panelNeverUpdated => '未更新';

  @override
  String get settingUnsavedChanges => '有未保存的更改';

  @override
  String get settingSaveBeforeExit => '退出前保存更改，或放弃这次更改。';

  @override
  String get settingSaveBeforeReturn => '保存后应用到悬浮窗，或放弃这次更改。';

  @override
  String get settingKeepEditing => '继续编辑';

  @override
  String get settingDiscardChanges => '放弃更改';

  @override
  String get settingSaveAndQuit => '保存并退出';

  @override
  String get settingSaveAndReturn => '保存并返回';

  @override
  String get settingActionFailed => '未能完成操作';

  @override
  String get settingReturnToPanel => '返回悬浮窗';

  @override
  String get settingTitle => 'MetricPerch 设置';

  @override
  String get settingSaving => '保存中…';

  @override
  String get settingUnsaved => '未保存';

  @override
  String get settingSaved => '已保存';

  @override
  String get settingSearch => '搜索设置';

  @override
  String get settingClearSearch => '清除搜索';

  @override
  String get settingUnitsTitle => '单位与换算';

  @override
  String get settingUnitsDescription => '选择行情货币和单位标签；自定义倍率可用于其他数值。';

  @override
  String get settingNoSearchResults => '没有匹配的设置，试试“字体”“单位”或“置顶”。';

  @override
  String get settingStorage => '导入与数据位置';

  @override
  String get settingImportLegacy => '导入旧版设置副本';

  @override
  String get settingWatchlist => '关注行情';

  @override
  String get settingWatchlistDescription => '管理关注列表，搜索更多币种、股票与 ETF。';

  @override
  String get settingAddAsset => '添加行情';

  @override
  String get settingSearchAsset => '搜索名称、代码或数据源';

  @override
  String get settingAll => '全部';

  @override
  String get settingCrypto => '加密货币';

  @override
  String get settingStocks => '股票 / ETF';

  @override
  String get settingProvider => '数据源';

  @override
  String get settingAllProviders => '全部来源';

  @override
  String get settingYahoo => 'Yahoo 财经';

  @override
  String get settingAddSymbol => '添加代码';

  @override
  String get settingUpdatingCatalog => '正在更新目录';

  @override
  String get settingRefreshCatalog => '刷新目录';

  @override
  String get settingSymbolNotFound => '没有找到这个代码，可以用“添加代码”手动加入。';

  @override
  String get settingPreviousPage => '上一页';

  @override
  String get settingNextPage => '下一页';

  @override
  String get settingAddFromCatalog => '从下方目录添加行情。';

  @override
  String get settingDragToReorder => '拖动排序';

  @override
  String get settingCatalogFailed => '目录更新失败，请稍后重试。';

  @override
  String get settingImportDescription => '将行情选择和可兼容的布局读入当前草稿；点击保存后应用。';

  @override
  String get settingLegacyPath => '旧版配置文件位置';

  @override
  String get settingLegacyPathHint => '选择旧版 crypto_config.json 的完整路径';

  @override
  String get settingCancel => '取消';

  @override
  String get settingRead => '读取';

  @override
  String get settingCustomContent => '自定义内容';

  @override
  String get settingCustomDescription => '连接数据接口，选择需要显示的字段。';

  @override
  String get settingAddApi => '添加自定义 API';

  @override
  String get settingThreeSteps => '添加只需三步';

  @override
  String get settingApiSecurity => '支持免密钥接口和请求头密钥。密钥保存在系统保护的存储中。';

  @override
  String get settingEdit => '编辑';

  @override
  String get settingRemove => '移除';

  @override
  String get settingEnabled => '已启用';

  @override
  String get settingDisabled => '已停用';

  @override
  String get settingLayout => '显示布局';

  @override
  String get settingLayoutDescription => '组合行情字段与文字，创建自己的显示布局。';

  @override
  String get settingDefaultRows => '显示默认行情';

  @override
  String get settingDefaultRowsDescription =>
      '显示已关注代码的名称、价格、单位和涨跌幅；关闭后保留自由显示行。';

  @override
  String get settingAddRow => '添加自由显示行';

  @override
  String get settingAddTemplate => '添加实用模板';

  @override
  String get settingDefaultRowsKept => '默认行情已开启，添加自由显示行后仍会保留。';

  @override
  String get settingMoveUp => '上移';

  @override
  String get settingMoveDown => '下移';

  @override
  String get settingDelete => '删除';

  @override
  String get settingAppearance => '外观';

  @override
  String get settingAppearanceDescription => '主题、悬浮窗透明度、字体与标题。';

  @override
  String get settingOpacity => '悬浮窗透明度';

  @override
  String get settingTextFont => '文字字体';

  @override
  String get settingChooseFont => '选择系统字体';

  @override
  String get settingNumberFont => '数字字体';

  @override
  String get settingFontSize => '字号';

  @override
  String get settingRowSpacing => '行间距';

  @override
  String get settingFontPreview => '中文预览：比特币 · 价格与涨跌';

  @override
  String get settingWindow => '窗口与托盘';

  @override
  String get settingWindowDescription => '置顶、移动和系统托盘。';

  @override
  String get settingAlwaysOnTop => '保持在其他窗口上方';

  @override
  String get settingHidePanel => '隐藏悬浮窗';

  @override
  String get settingHideDescription => '双击悬浮窗空白处或标题，隐藏到系统托盘。';

  @override
  String get settingRestorePanel => '从托盘恢复';

  @override
  String get settingRestoreDescription => '单击托盘图标恢复悬浮窗，并置于其他窗口上方。';

  @override
  String get settingIconChart => '行情图';

  @override
  String get settingIconBitcoin => '比特币';

  @override
  String get settingIconStar => '星标';

  @override
  String get settingIconBolt => '闪电';

  @override
  String get settingIconHeart => '爱心';

  @override
  String get settingTitlePreview => '标题预览';

  @override
  String get settingIconPreview => '图标预览';

  @override
  String get settingShowTitle => '显示标题名称';

  @override
  String get settingTitleName => '标题名称';

  @override
  String get settingShowIcon => '显示标题图标';

  @override
  String get settingIconStyle => '图标样式';

  @override
  String get settingCustomEmoji => '自定义表情';

  @override
  String get settingEmojiInput => '输入表情或字符';

  @override
  String get settingEmojiHint => '例如 🌙';

  @override
  String get settingImageUnavailable => '图片无法显示，请重新选择';

  @override
  String get settingChooseImage => '选择图片图标';

  @override
  String get settingClearImage => '清除图片图标';

  @override
  String get settingImageDescription => '选择不超过 1 MB 的图片；图片图标会优先显示。';

  @override
  String get settingImages => '图片';

  @override
  String get settingImageImportFailed => '图片未能导入，请重新选择。';

  @override
  String get settingUnitLabels => '单位标签';

  @override
  String get settingUnitLabelsDescription => '选择完整名称、简写或自己的标签';

  @override
  String get settingFull => '完整';

  @override
  String get settingCompact => '简写';

  @override
  String get settingCustom => '自定义';

  @override
  String get settingDisplayCurrency => '行情显示货币';

  @override
  String get settingCurrencyDescription => '行情价格按可用汇率换算';

  @override
  String get settingOriginalCurrency => '保留原币';

  @override
  String get settingConversionDescription =>
      '行情货币按可用汇率换算；汇率不可用时保留原币并显示提示。自定义倍率用于其他单位。';

  @override
  String get settingDeleteUnitLabel => '删除单位标签';

  @override
  String get settingAddUnitLabel => '添加单位标签';

  @override
  String get settingDeleteUnitRule => '删除倍率规则';

  @override
  String get settingAddUnitRule => '添加倍率规则';

  @override
  String get settingCustomUnitLabel => '自定义单位标签';

  @override
  String get settingSourceUnit => '原单位';

  @override
  String get settingUsdtHint => '例如 USDT';

  @override
  String get settingDisplayLabel => '显示标签';

  @override
  String get settingUHint => '例如 U';

  @override
  String get settingUnitLabelRequired => '请填写原单位和显示标签。';

  @override
  String get settingSaveLabel => '保存标签';

  @override
  String get settingCustomConversion => '自定义倍率换算';

  @override
  String get settingOunceHint => '例如 oz';

  @override
  String get settingTargetUnit => '目标单位';

  @override
  String get settingGramHint => '例如 g';

  @override
  String get settingMultiplier => '倍率';

  @override
  String get settingMultiplierHint => '例如 28.3495';

  @override
  String get settingUnitRuleRequired => '请填写两个单位和大于 0 的有效倍率。';

  @override
  String get settingSaveRule => '保存规则';

  @override
  String get settingFontLoadFailed => '字体无法加载，请重新选择其他字体。';

  @override
  String get settingInvalidSymbol => '请输入正确的行情代码。';

  @override
  String get settingAddSymbolDialog => '添加行情代码';

  @override
  String get settingYahooMarkets => 'Yahoo · 美股 / A 股';

  @override
  String get settingSymbol => '行情代码';

  @override
  String get settingYahooHint => 'AAPL、600519.SS 或 600519';

  @override
  String get settingOptionalName => '显示名称（可选）';

  @override
  String get settingAdd => '添加';

  @override
  String get settingSearchFonts => '搜索字体';

  @override
  String get settingNoFonts => '未找到匹配的字体';

  @override
  String get settingFontUnavailable => '字体无法加载，请选择其他字体';

  @override
  String get settingFontSample => '价格 83,342.30 · AaBb 123';

  @override
  String get settingApiSteps => '1. 粘贴数据接口地址\n2. 点击“读取返回字段”\n3. 勾选字段，为它起名并填写单位';

  @override
  String settingSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String settingSearchCount(int count) {
    return '$count 项结果';
  }

  @override
  String settingSettingsFile(String path) {
    return '设置文件：$path';
  }

  @override
  String settingCatalogCounts(int selected, int total, int matched) {
    return '已选 $selected 项 · 目录 $total 项 · 匹配 $matched 项';
  }

  @override
  String settingCatalogUnavailable(String providers) {
    return '$providers 目录暂未更新，仍可选择已有项目。';
  }

  @override
  String settingPageCount(int page, int total, int size) {
    return '第 $page / $total 页 · 每页 $size 项';
  }

  @override
  String settingWatchlistCount(int count) {
    return '已关注 · $count';
  }

  @override
  String settingDragAsset(String name) {
    return '拖动 $name 排序';
  }

  @override
  String settingMoveAssetUp(String name) {
    return '上移 $name';
  }

  @override
  String settingMoveAssetDown(String name) {
    return '下移 $name';
  }

  @override
  String settingUnfollowAsset(String name) {
    return '取消关注 $name';
  }

  @override
  String settingImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String settingSourceSummary(String status, int seconds, int count) {
    return '$status · 每 $seconds 秒刷新 · $count 个显示字段';
  }

  @override
  String settingRowNumber(int number) {
    return '第 $number 行';
  }

  @override
  String settingMultiplierSummary(double multiplier) {
    return '数值 × $multiplier';
  }

  @override
  String get settingLanguage => '语言';

  @override
  String get settingLanguageSystem => '跟随系统';

  @override
  String get settingCatalogAssets => '选择行情';

  @override
  String get settingCatalogOrder => '行情显示顺序';

  @override
  String get settingCatalogApi => '自定义 API';

  @override
  String get settingCatalogRows => '自由显示行与模板';

  @override
  String get settingCatalogFonts => '文字与数字字体';

  @override
  String get settingCatalogSpacing => '字号与行间距';

  @override
  String get settingCatalogThemes => '浅色与深色主题';

  @override
  String get settingCatalogHeader => '窗口标题与图标';

  @override
  String get settingCatalogUnits => '单位与显示货币';

  @override
  String get settingCatalogWindow => '窗口置顶';

  @override
  String get settingCatalogTray => '隐藏与托盘恢复';

  @override
  String get theme120Saturation => '饱和度';

  @override
  String get theme120Spectrum => '饱和度与亮度';

  @override
  String get theme120SpectrumHint => '使用方向键调整饱和度和亮度，按住 Shift 可加大调整幅度。';

  @override
  String get theme120InvalidHex => '请输入六位十六进制颜色。';

  @override
  String get theme120InvalidRgb => '请输入 0 到 255 的整数。';

  @override
  String get theme120ColorValue => '当前颜色';
}
