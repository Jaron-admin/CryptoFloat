// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get editCancel => 'Cancel';

  @override
  String get editSave => 'Save';

  @override
  String get editAdd => 'Add';

  @override
  String get editDelete => 'Delete';

  @override
  String get editAddToDisplay => 'Add to panel';

  @override
  String get editRemove => 'Remove';

  @override
  String get editSourceNameRequired => 'Enter a name for this data source.';

  @override
  String get editSourceUrlInvalid =>
      'Enter an HTTPS API URL. Put API keys in the request headers.';

  @override
  String get editSourceIntervalInvalid =>
      'The refresh interval must be between 15 and 3600 seconds.';

  @override
  String get editSourceDuplicateHeader =>
      'A request header name is duplicated. Keep only one entry.';

  @override
  String get editSourceFieldsRequired =>
      'Select at least one field to display.';

  @override
  String get editSetField => 'Set up display field';

  @override
  String get editField => 'Edit display field';

  @override
  String get editFieldName => 'Display name';

  @override
  String get editFieldNameHint =>
      'For example: Account balance or Outdoor temperature';

  @override
  String get editFieldUnit => 'Unit (optional)';

  @override
  String get editFieldUnitHint => 'For example: USD, °C or people';

  @override
  String get editFieldPath => 'Path in the response';

  @override
  String get editFieldPathHint => 'For example: data.balance or items[0].price';

  @override
  String get editSourceAdd => 'Add custom API';

  @override
  String get editSourceEdit => 'Edit custom API';

  @override
  String get editSourceEnabled => 'Enable this source';

  @override
  String get editConnectSource => 'Connect a data source';

  @override
  String get editSourceName => 'Source name';

  @override
  String get editSourceNameHint => 'For example: My account or Weather';

  @override
  String get editSourceUrl => 'HTTPS API URL';

  @override
  String get editSourceInterval => 'Refresh interval (seconds)';

  @override
  String get editSourceIntervalHelp =>
      '15–3600 seconds. Follow the API rate limits.';

  @override
  String get editSourceHeaders => 'Request headers / API keys (if needed)';

  @override
  String get editSourceHeadersOptional =>
      'Skip this for APIs that do not require keys';

  @override
  String get editHeaderName => 'Header name';

  @override
  String get editHeaderSecret => 'Secret value';

  @override
  String get editHeaderValue => 'Header value';

  @override
  String get editHeaderRetain => 'Saved. Leave blank to keep the current value';

  @override
  String get editHeaderTokenHint => 'For example: Bearer your-token';

  @override
  String get editHeaderSecure => 'Store securely as a secret';

  @override
  String get editHeaderAdd => 'Add header';

  @override
  String get editReadFields => 'Read response fields';

  @override
  String get editDisplayFields => 'Display fields';

  @override
  String get editReadFieldsHelp =>
      'After loading the response, select a value and give it a display name and unit.';

  @override
  String get editSelectedFields => 'Selected fields';

  @override
  String get editRemoveField => 'Remove field';

  @override
  String get editAdvancedField => 'Advanced: enter a field path';

  @override
  String get editAddFieldPath => 'Add field path';

  @override
  String get editFieldSymbol => 'Symbol';

  @override
  String get editFieldLabel => 'Name';

  @override
  String get editFieldPrice => 'Price';

  @override
  String get editFieldCurrency => 'Currency';

  @override
  String get editFieldChange => 'Change';

  @override
  String get editFieldProvider => 'Provider';

  @override
  String get editFieldUpdatedAt => 'Updated at';

  @override
  String get editSourceMissing => 'Source not found';

  @override
  String get editDisplayText => 'Display text';

  @override
  String get editWantedText => 'Text to display';

  @override
  String get editWantedTextHint =>
      'For example: Today’s price:  or  My balance ';

  @override
  String get editComposeRow => 'Compose display row';

  @override
  String get editCloseEditor => 'Close editor';

  @override
  String get editComposeRowHelp =>
      'Text and fields appear from left to right. Add spaces and punctuation as needed.';

  @override
  String get editAddText => 'Add text';

  @override
  String get editAddDataField => 'Add data field';

  @override
  String get editEmptyRow => 'No text or fields added yet';

  @override
  String get editDisplayPreview => 'Display preview';

  @override
  String get editSaveRow => 'Save row';

  @override
  String get editMoveLeft => 'Move left';

  @override
  String get editMoveRight => 'Move right';

  @override
  String get editEmptyText => 'Empty text';

  @override
  String get editAutomatic => 'Automatic';

  @override
  String get editSelectField => 'Select display field';

  @override
  String get editSelectSourceFirst =>
      'Select an item in Watchlist or add a custom API first.';

  @override
  String get editFieldSource => 'Source';

  @override
  String get editFieldSelection => 'Field';

  @override
  String get editNumberFormat => 'Number format';

  @override
  String get editDecimalsTwo => '2 decimal places';

  @override
  String get editDecimalsFour => '4 decimal places';

  @override
  String get editDecimalsSigned => 'Sign + 2 decimal places';

  @override
  String get editRawValue => 'Original API value';

  @override
  String get editThemeMode => 'Theme mode';

  @override
  String get editSystem => 'System';

  @override
  String get editLight => 'Light';

  @override
  String get editDark => 'Dark';

  @override
  String get editLightPreview => 'Light preview';

  @override
  String get editDarkPreview => 'Dark preview';

  @override
  String get editMyThemes => 'My themes';

  @override
  String get editSaveThemeAs => 'Save current colors as a theme';

  @override
  String get editThemesHelp =>
      'Save your favorite colors and switch between them.';

  @override
  String get editCustomBackground => 'Custom background';

  @override
  String get editDarkPalette => 'Dark palette';

  @override
  String get editLightPalette => 'Light palette';

  @override
  String get editDarkBackground => 'Dark background';

  @override
  String get editLightBackground => 'Light background';

  @override
  String get editChooseColor => 'Choose color';

  @override
  String get editDeleteTheme => 'Delete theme';

  @override
  String get editThemeNameRequired => 'Enter a theme name';

  @override
  String get editThemeNew => 'Save new theme';

  @override
  String get editThemeEdit => 'Edit theme';

  @override
  String get editThemeName => 'Theme name';

  @override
  String get editThemeNameHint => 'Name this color palette';

  @override
  String get editThemePalette => 'Palette to edit';

  @override
  String get editColorRole => 'Color role';

  @override
  String get editHue => 'Hue';

  @override
  String get editBrightness => 'Brightness';

  @override
  String get editSaveTheme => 'Save theme';

  @override
  String get editApplyColor => 'Apply color';

  @override
  String get editRoleBackground => 'Window background';

  @override
  String get editRoleSurface => 'Card background';

  @override
  String get editRoleForeground => 'Primary text';

  @override
  String get editRoleSecondary => 'Secondary text';

  @override
  String get editRoleBorder => 'Borders and dividers';

  @override
  String get editRoleAccent => 'Accent';

  @override
  String get editRolePositive => 'Positive change';

  @override
  String get editRoleNegative => 'Negative change';

  @override
  String get editTemplateWeather => 'City weather';

  @override
  String get editTemplateRates => 'Reference exchange rates';

  @override
  String get editTemplateGithub => 'GitHub repository';

  @override
  String get editTemplateMarket => 'Compact market ticker';

  @override
  String get editTemplateReminder => 'Text reminder';

  @override
  String get editTemplateWeatherHelp =>
      'Temperature, feels-like temperature and humidity. Refreshes every 15 minutes. Powered by Open-Meteo for personal use.';

  @override
  String get editTemplateRatesHelp =>
      'Reference rates from USD to CNY, EUR and USDT. Refreshes every 5 minutes.';

  @override
  String get editTemplateGithubHelp =>
      'Stars and open issues / pull requests for a public repository. Refreshes every 10 minutes.';

  @override
  String get editTemplateMarketHelp =>
      'Combines the first 3 watchlist items into one row using your unit settings.';

  @override
  String get editTemplateReminderHelp =>
      'Displays text without a network connection. You can add data fields later in the row editor.';

  @override
  String get editTemplateDefaultReminder =>
      'Reminder: Take a walk and drink some water';

  @override
  String get editTemplateAdd => 'Add a template';

  @override
  String get editTemplateClose => 'Close templates';

  @override
  String get editCity => 'City';

  @override
  String get editRepoOwner => 'Repository owner';

  @override
  String get editRepoOwnerHint => 'For example: flutter';

  @override
  String get editRepoName => 'Repository name';

  @override
  String get editRepoNameHint => 'For example: MetricPerch';

  @override
  String editHeaderMissingSecret(String name) {
    return 'Enter the secret for $name.';
  }

  @override
  String editHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count headers',
      one: '1 header',
    );
    return '$_temp0';
  }

  @override
  String editRowFormat(String format) {
    return 'Format: $format';
  }

  @override
  String editThemeEditNamed(String name) {
    return 'Edit $name';
  }

  @override
  String editThemeCopyNamed(String name) {
    return 'Copy $name';
  }

  @override
  String editThemeDeleteNamed(String name) {
    return 'Delete $name';
  }

  @override
  String editThemeCopyName(String name) {
    return '$name copy';
  }

  @override
  String editThemeDeleteConfirm(String name) {
    return 'Delete “$name”? Any active palette will switch to Fluent Blue.';
  }

  @override
  String editThemeBackgroundTitle(String mode) {
    return 'Custom $mode background';
  }

  @override
  String get editThemeFluent => 'Fluent Blue';

  @override
  String get editThemeNord => 'Nord';

  @override
  String get editThemeSolarized => 'Solarized';

  @override
  String get editCityBeijing => 'Beijing';

  @override
  String get editCityShanghai => 'Shanghai';

  @override
  String get editCityGuangzhou => 'Guangzhou';

  @override
  String get editCityShenzhen => 'Shenzhen';

  @override
  String get editCityHangzhou => 'Hangzhou';

  @override
  String get editCityChengdu => 'Chengdu';

  @override
  String get editCityWuhan => 'Wuhan';

  @override
  String get editCityXian => 'Xi’an';

  @override
  String get editTemplateCityInvalid =>
      'Choose a city from the list. You can edit the source URL after adding it.';

  @override
  String get editTemplateTemperature => 'Temperature';

  @override
  String get editTemplateFeelsLike => 'Feels like';

  @override
  String get editTemplateHumidity => 'Humidity';

  @override
  String get editTemplateUsdRates => 'USD reference rates';

  @override
  String get editTemplateUsdCny => 'USD to CNY';

  @override
  String get editTemplateUsdEur => 'USD to EUR';

  @override
  String get editTemplateUsdUsdt => 'USD to USDT';

  @override
  String get editTemplateRepoInvalid =>
      'Enter the owner and name of a public repository, for example flutter / flutter.';

  @override
  String get editTemplateOpenIssues => 'Open issues and pull requests';

  @override
  String get editTemplateOpen => 'Open';

  @override
  String get editTemplateMarketEmpty =>
      'Select at least one coin or stock first.';

  @override
  String get editTemplateTextEmpty => 'Enter some text to display.';

  @override
  String editTemplateWeatherName(String city) {
    return '$city weather';
  }

  @override
  String get editMyTheme => 'My theme';

  @override
  String get editMenuHide => 'Hide to tray';

  @override
  String get editMenuShow => 'Show floating panel';

  @override
  String get editMenuRefresh => 'Refresh now';

  @override
  String get editMenuTopmost => 'Always on top';

  @override
  String get editMenuSettings => 'Settings';

  @override
  String get editMenuExit => 'Exit';

  @override
  String get errorStartupDefaultLayout =>
      'The settings file could not be read. The default layout is in use and the original file has been kept.';

  @override
  String get errorStartupFont =>
      'A saved font could not be loaded. Choose another font in Appearance.';

  @override
  String get errorStartupWindow =>
      'Window settings could not be applied. You can continue using the app and try again in Settings.';

  @override
  String get errorInvalidValue =>
      'The value is invalid. The original value and unit have been kept.';

  @override
  String get errorInvalidMultiplier =>
      'The custom multiplier is invalid. The original value and unit have been kept.';

  @override
  String get errorConversionOverflow => 'The converted value is out of range.';

  @override
  String get errorExchangeRateUnavailable =>
      'The exchange rate is missing, expired, or invalid. The original value and unit have been kept.';

  @override
  String get errorSaving => 'Settings are being saved. Please wait.';

  @override
  String get errorSavedTopmost =>
      'Settings were saved, but always on top could not be applied. Reopen the app to try again.';

  @override
  String get errorSavedOpacity =>
      'Settings were saved, but window transparency could not be applied. Reopen the app to try again.';

  @override
  String get errorTrayUnavailable =>
      'The tray icon could not be created. The window will remain visible. Try again later.';

  @override
  String get errorIconTooLarge => 'The icon image must be no larger than 1 MB.';

  @override
  String get errorChooseSmallImage => 'Choose an image no larger than 1 MB.';

  @override
  String get errorImageDimensions =>
      'The icon image dimensions are too large. Choose a smaller image.';

  @override
  String get errorImageUnreadable => 'The image could not be read.';

  @override
  String get errorImageUnsupported =>
      'The image could not be read. Choose a PNG, JPEG, GIF, WebP, BMP, or ICO image.';

  @override
  String get errorConnectionClosed => 'The data connection has been closed.';

  @override
  String get errorNetworkTimeout =>
      'The network connection timed out. Try again later.';

  @override
  String get errorNetworkSettings =>
      'A network connection could not be established. Check your network settings.';

  @override
  String get errorHttpsRequired =>
      'Enter a complete HTTPS address without credentials or a fragment.';

  @override
  String get errorCatalogUrl => 'This market catalog address is not supported.';

  @override
  String get errorRequestTimeout => 'The request timed out. Try again later.';

  @override
  String get errorSourceConnection =>
      'The data source could not be reached. Check your network connection.';

  @override
  String get errorCertificate => 'HTTPS certificate verification failed.';

  @override
  String get errorConnectionFailed =>
      'The data connection failed. Check the address and network settings.';

  @override
  String get errorInvalidJson => 'The response is not valid UTF-8 JSON.';

  @override
  String get errorRedirect =>
      'The data source redirected the request. Enter the final HTTPS address.';

  @override
  String get errorRateLimited =>
      'The data source is limiting requests. Try later or increase the refresh interval.';

  @override
  String get errorJsonEmptyField =>
      'The JSON path contains an empty field name.';

  @override
  String get errorJsonSeparator => 'Use a dot or brackets between JSON fields.';

  @override
  String get errorJsonClosingBracket =>
      'The JSON path is missing a closing bracket.';

  @override
  String get errorJsonQuote => 'The JSON path is missing a quotation mark.';

  @override
  String get errorJsonEscape =>
      'The JSON path contains an invalid quotation mark or escape sequence.';

  @override
  String get errorJsonArrayIndex =>
      'An array index must be a non-negative integer.';

  @override
  String get errorJsonPath => 'The JSON path is invalid.';

  @override
  String get errorJsonIndexMissing => 'The JSON array index does not exist.';

  @override
  String get errorJsonFieldMissing => 'The JSON field path does not exist.';

  @override
  String get errorSourceUrl =>
      'Enter a complete HTTPS URL without credentials or a fragment.';

  @override
  String get errorKeyInUrl =>
      'Do not put keys in the URL. Use a protected request header.';

  @override
  String get errorTooManyHeaders =>
      'A source can have at most 64 request headers.';

  @override
  String get errorProtectedHeader =>
      'Authentication headers must use a reference to protected key storage.';

  @override
  String get errorEmptyKeyReference =>
      'The key storage reference must not be empty.';

  @override
  String get errorTooManyFields => 'A source can have at most 500 fields.';

  @override
  String get errorDuplicateField =>
      'Field IDs must not be empty or duplicated.';

  @override
  String get errorInvalidHeader => 'A request header name or value is invalid.';

  @override
  String get errorManagedHeader =>
      'This header is managed by the secure network connection.';

  @override
  String get errorInvalidRateResponse =>
      'The exchange rate response is invalid. The original value and unit have been kept.';

  @override
  String get errorInvalidRateBase =>
      'The exchange rate base is invalid. The original value and unit have been kept.';

  @override
  String get errorProxyRead =>
      'System proxy settings could not be read. Check Windows network settings.';

  @override
  String get errorProxyUnavailable =>
      'System proxy support is unavailable. Use the complete, current app package.';

  @override
  String get errorNetworkType =>
      'This network connection type is not supported. Check system network settings.';

  @override
  String get errorInvalidSystemNetwork =>
      'System network settings are invalid. Check them and try again.';

  @override
  String get errorApplySystemNetwork =>
      'System network settings could not be applied. Check them and try again.';

  @override
  String get errorWaitingForData => 'Settings updated. Waiting for new quotes.';

  @override
  String get errorSourceDisabled => 'This data source is disabled.';

  @override
  String get errorScalarField =>
      'The selected field must contain a single number, text value, or boolean.';

  @override
  String get errorFieldUnavailable =>
      'The selected field has no valid data yet.';

  @override
  String get errorNoResponseFields => 'The response has no selectable fields.';

  @override
  String get errorMissingProtectedHeader =>
      'A protected request header is missing. Re-enter the key in Settings.';

  @override
  String get errorKeyReadTimeout =>
      'Reading a protected request header timed out. Try again.';

  @override
  String get errorRequestFailed =>
      'The data request could not be completed. Check the source, key, and network settings.';

  @override
  String get errorProxyPort => 'The proxy port must be between 1 and 65535.';

  @override
  String get errorProxyInvalidSettings =>
      'The system proxy returned invalid connection settings.';

  @override
  String get errorProxyTooManyAddresses =>
      'The system proxy returned too many candidate addresses.';

  @override
  String get errorProxyUnsupportedType =>
      'This connection type is not supported. Use an HTTP or mixed proxy port.';

  @override
  String get errorProxyUnsupportedFormat =>
      'This system proxy format is not supported. Use an HTTP or mixed proxy port.';

  @override
  String get errorProxyHost =>
      'The proxy address is invalid. Enter a hostname or IP address.';

  @override
  String get errorProxyIpv6 => 'The proxy IPv6 address is invalid.';

  @override
  String get errorProxyAddress =>
      'Enter only the proxy hostname or IP, without a scheme, path, or credentials.';

  @override
  String get errorConfigRestored =>
      'The settings file could not be read. The previous backup was restored and the original file was kept.';

  @override
  String get errorConfigDefaults =>
      'The settings file could not be read. Default settings are in use and the original file was kept.';

  @override
  String get errorConfigTooLarge => 'The settings file is too large.';

  @override
  String get errorConfigObject =>
      'The settings file must contain a JSON object.';

  @override
  String get errorConfigNewerVersion =>
      'The settings file was created by a newer app version.';

  @override
  String get errorConfigSizeLimit => 'Settings exceed the 2 MB limit.';

  @override
  String get errorLegacyConfigSize =>
      'The legacy settings file exceeds the 2 MB limit.';

  @override
  String get errorLegacyConfigObject =>
      'The legacy settings file must contain a JSON object.';

  @override
  String get errorLegacyConfigInvalid =>
      'The legacy settings file is not a valid JSON settings object.';

  @override
  String get errorCatalogCacheSave =>
      'The catalog was updated, but its local cache could not be saved.';

  @override
  String get errorCatalogUpdate =>
      'The market catalog could not be updated. Try again later.';

  @override
  String get errorCatalogCacheSize =>
      'The market catalog cache exceeds its size limit.';

  @override
  String get errorCatalogEmpty =>
      'The exchange did not return a valid market catalog.';

  @override
  String get errorCatalogFormat =>
      'The market catalog format or number of entries is not supported.';

  @override
  String get errorCatalogInvalid => 'The market catalog format is invalid.';

  @override
  String get errorCatalogProvider =>
      'This market catalog provider is not supported.';

  @override
  String get errorCatalogNoPairs =>
      'The exchange returned no available spot pairs. The existing catalog was kept.';

  @override
  String get errorCatalogSymbol =>
      'The market catalog contains an invalid trading pair symbol.';

  @override
  String get errorCatalogName =>
      'The market catalog contains an invalid name or symbol.';

  @override
  String get errorAssetProvider =>
      'The data provider for this instrument is not supported.';

  @override
  String get errorOkxQuote =>
      'OKX returned no valid quote. Check the trading pair and regional availability.';

  @override
  String get errorKucoinQuote =>
      'KuCoin returned no valid quote. Check the trading pair.';

  @override
  String get errorYahooQuote =>
      'Yahoo Finance returned no valid quote. Check the symbol or try again later.';

  @override
  String get errorYahooNotice =>
      'Unofficial Yahoo Finance API. Quotes may be delayed.';

  @override
  String get errorQuoteStructure => 'The quote response structure is invalid.';

  @override
  String get errorQuoteMissing =>
      'The data source returned no quote for this instrument.';

  @override
  String get errorPriceMissing => 'The data source has no valid latest price.';

  @override
  String get errorUnknown =>
      'The action could not be completed. Check your settings and try again.';

  @override
  String errorHttpStatus(int status) {
    return 'The data source returned HTTP $status.';
  }

  @override
  String errorResponseLimit(int size) {
    return 'The data source response exceeds the $size MB limit.';
  }

  @override
  String get errorPortableDirectory =>
      'Cannot write user_data beside the app. Move the app to a writable folder with enough free space.';

  @override
  String get appMoutai => 'Kweichow Moutai';

  @override
  String get appPingAn => 'Ping An Bank';

  @override
  String get appCatl => 'CATL';

  @override
  String get panelUnpin => 'Turn off always on top';

  @override
  String get panelPin => 'Always on top';

  @override
  String get panelSettings => 'Settings…';

  @override
  String get panelNoSources => 'No sources configured';

  @override
  String get panelLive => 'Live';

  @override
  String get panelWaiting => 'Waiting for first update';

  @override
  String panelLastUpdate(String time) {
    return 'Last updated $time';
  }

  @override
  String panelPending(String time, int count) {
    return 'Last updated $time · $count pending';
  }

  @override
  String panelAutoRefresh(String interval) {
    return ' · Auto-refresh $interval';
  }

  @override
  String panelMinutes(int count) {
    return '${count}m';
  }

  @override
  String panelSeconds(int count) {
    return '${count}s';
  }

  @override
  String get panelRatesPending => ' · Rates unavailable';

  @override
  String panelSourceInterval(int seconds) {
    return 'Every ${seconds}s';
  }

  @override
  String panelLastFetch(String time) {
    return 'Last fetched $time';
  }

  @override
  String get panelRatesInterval => 'Exchange rates refresh every 5 minutes';

  @override
  String get panelLiveNote =>
      'Live means requests are up to date; upstream quotes may be delayed.';

  @override
  String panelQuoteTime(String time) {
    return 'Quote time $time';
  }

  @override
  String panelOriginal(String value, String currency) {
    return 'Original $value $currency';
  }

  @override
  String panelUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String get panelChoose => 'Choose what to follow';

  @override
  String get panelAdd => 'Add instruments or API';

  @override
  String get panelRemoved => 'Removed item';

  @override
  String get panelNoData => 'No data. Check the watchlist or source.';

  @override
  String panelStale(String time) {
    return 'Stale data $time';
  }

  @override
  String get panelConnectionError => 'Connection error';

  @override
  String get panelNeverUpdated => 'Never updated';

  @override
  String get settingUnsavedChanges => 'Unsaved changes';

  @override
  String get settingSaveBeforeExit =>
      'Save your changes before quitting, or discard them.';

  @override
  String get settingSaveBeforeReturn =>
      'Save to apply your changes to the panel, or discard them.';

  @override
  String get settingKeepEditing => 'Keep editing';

  @override
  String get settingDiscardChanges => 'Discard changes';

  @override
  String get settingSaveAndQuit => 'Save and quit';

  @override
  String get settingSaveAndReturn => 'Save and return';

  @override
  String get settingActionFailed => 'Unable to complete the action';

  @override
  String get settingReturnToPanel => 'Return to panel';

  @override
  String get settingTitle => 'MetricPerch Settings';

  @override
  String get settingSaving => 'Saving…';

  @override
  String get settingUnsaved => 'Unsaved';

  @override
  String get settingSaved => 'Saved';

  @override
  String get settingSearch => 'Search settings';

  @override
  String get settingClearSearch => 'Clear search';

  @override
  String get settingUnitsTitle => 'Units & conversion';

  @override
  String get settingUnitsDescription =>
      'Choose the quote currency and unit labels. Use custom multipliers for other values.';

  @override
  String get settingNoSearchResults =>
      'No matching settings. Try “font”, “units”, or “always on top”.';

  @override
  String get settingStorage => 'Import & data location';

  @override
  String get settingImportLegacy => 'Import legacy settings';

  @override
  String get settingWatchlist => 'Watchlist';

  @override
  String get settingWatchlistDescription =>
      'Manage your watchlist and search for currencies, stocks, and ETFs.';

  @override
  String get settingAddAsset => 'Add instruments';

  @override
  String get settingSearchAsset => 'Search name, symbol, or provider';

  @override
  String get settingAll => 'All';

  @override
  String get settingCrypto => 'Cryptocurrencies';

  @override
  String get settingStocks => 'Stocks / ETFs';

  @override
  String get settingProvider => 'Provider';

  @override
  String get settingAllProviders => 'All providers';

  @override
  String get settingYahoo => 'Yahoo Finance';

  @override
  String get settingAddSymbol => 'Add symbol';

  @override
  String get settingUpdatingCatalog => 'Updating catalog';

  @override
  String get settingRefreshCatalog => 'Refresh catalog';

  @override
  String get settingSymbolNotFound =>
      'Symbol not found. Use “Add symbol” to add it manually.';

  @override
  String get settingPreviousPage => 'Previous page';

  @override
  String get settingNextPage => 'Next page';

  @override
  String get settingAddFromCatalog => 'Add instruments from the catalog below.';

  @override
  String get settingDragToReorder => 'Drag to reorder';

  @override
  String get settingCatalogFailed =>
      'The catalog could not be updated. Try again later.';

  @override
  String get settingImportDescription =>
      'Load the watchlist and compatible layout into this draft. Save to apply.';

  @override
  String get settingLegacyPath => 'Legacy configuration path';

  @override
  String get settingLegacyPathHint =>
      'Enter the full path to the legacy crypto_config.json file';

  @override
  String get settingCancel => 'Cancel';

  @override
  String get settingRead => 'Load';

  @override
  String get settingCustomContent => 'Custom content';

  @override
  String get settingCustomDescription =>
      'Connect to an API and choose the fields to display.';

  @override
  String get settingAddApi => 'Add custom API';

  @override
  String get settingThreeSteps => 'Add an API in three steps';

  @override
  String get settingApiSecurity =>
      'Supports public APIs and keys in request headers. Keys are stored in system-protected storage.';

  @override
  String get settingEdit => 'Edit';

  @override
  String get settingRemove => 'Remove';

  @override
  String get settingEnabled => 'Enabled';

  @override
  String get settingDisabled => 'Disabled';

  @override
  String get settingLayout => 'Display layout';

  @override
  String get settingLayoutDescription =>
      'Combine quote fields and text to create your own layout.';

  @override
  String get settingDefaultRows => 'Show default quotes';

  @override
  String get settingDefaultRowsDescription =>
      'Show names, prices, units, and changes for your watchlist. Custom rows remain when this is off.';

  @override
  String get settingAddRow => 'Add custom row';

  @override
  String get settingAddTemplate => 'Add template';

  @override
  String get settingDefaultRowsKept =>
      'Default quotes will remain visible alongside custom rows.';

  @override
  String get settingMoveUp => 'Move up';

  @override
  String get settingMoveDown => 'Move down';

  @override
  String get settingDelete => 'Delete';

  @override
  String get settingAppearance => 'Appearance';

  @override
  String get settingAppearanceDescription =>
      'Language, themes, panel transparency, fonts, and title.';

  @override
  String get settingOpacity => 'Panel transparency';

  @override
  String get settingTextFont => 'Text font';

  @override
  String get settingChooseFont => 'Choose system font';

  @override
  String get settingNumberFont => 'Number font';

  @override
  String get settingFontSize => 'Font size';

  @override
  String get settingRowSpacing => 'Row spacing';

  @override
  String get settingFontPreview => 'Preview: Bitcoin · Price & change';

  @override
  String get settingWindow => 'Window & tray';

  @override
  String get settingWindowDescription =>
      'Always on top, movement, and system tray.';

  @override
  String get settingAlwaysOnTop => 'Keep above other windows';

  @override
  String get settingHidePanel => 'Hide panel';

  @override
  String get settingHideDescription =>
      'Double-click the panel background or title to hide it to the system tray.';

  @override
  String get settingRestorePanel => 'Restore from tray';

  @override
  String get settingRestoreDescription =>
      'Click the tray icon to restore the panel above other windows.';

  @override
  String get settingIconChart => 'Chart';

  @override
  String get settingIconBitcoin => 'Bitcoin';

  @override
  String get settingIconStar => 'Star';

  @override
  String get settingIconBolt => 'Lightning';

  @override
  String get settingIconHeart => 'Heart';

  @override
  String get settingTitlePreview => 'Title preview';

  @override
  String get settingIconPreview => 'Icon preview';

  @override
  String get settingShowTitle => 'Show title';

  @override
  String get settingTitleName => 'Title text';

  @override
  String get settingShowIcon => 'Show title icon';

  @override
  String get settingIconStyle => 'Icon style';

  @override
  String get settingCustomEmoji => 'Custom emoji';

  @override
  String get settingEmojiInput => 'Enter an emoji or character';

  @override
  String get settingEmojiHint => 'For example, 🌙';

  @override
  String get settingImageUnavailable =>
      'This image cannot be displayed. Choose another image.';

  @override
  String get settingChooseImage => 'Choose icon image';

  @override
  String get settingClearImage => 'Clear icon image';

  @override
  String get settingImageDescription =>
      'Choose an image up to 1 MB. It will take priority over the selected icon.';

  @override
  String get settingImages => 'Images';

  @override
  String get settingImageImportFailed =>
      'The image could not be imported. Choose another image.';

  @override
  String get settingUnitLabels => 'Unit labels';

  @override
  String get settingUnitLabelsDescription =>
      'Choose full names, short labels, or your own labels';

  @override
  String get settingFull => 'Full';

  @override
  String get settingCompact => 'Short';

  @override
  String get settingCustom => 'Custom';

  @override
  String get settingDisplayCurrency => 'Quote display currency';

  @override
  String get settingCurrencyDescription =>
      'Convert prices using available exchange rates';

  @override
  String get settingOriginalCurrency => 'Original currency';

  @override
  String get settingConversionDescription =>
      'Prices use available exchange rates. If a rate is unavailable, the original currency is kept with a notice. Use custom multipliers for other units.';

  @override
  String get settingDeleteUnitLabel => 'Delete unit label';

  @override
  String get settingAddUnitLabel => 'Add unit label';

  @override
  String get settingDeleteUnitRule => 'Delete multiplier rule';

  @override
  String get settingAddUnitRule => 'Add multiplier rule';

  @override
  String get settingCustomUnitLabel => 'Custom unit label';

  @override
  String get settingSourceUnit => 'Source unit';

  @override
  String get settingUsdtHint => 'For example, USDT';

  @override
  String get settingDisplayLabel => 'Display label';

  @override
  String get settingUHint => 'For example, U';

  @override
  String get settingUnitLabelRequired =>
      'Enter a source unit and a display label.';

  @override
  String get settingSaveLabel => 'Save label';

  @override
  String get settingCustomConversion => 'Custom conversion';

  @override
  String get settingOunceHint => 'For example, oz';

  @override
  String get settingTargetUnit => 'Target unit';

  @override
  String get settingGramHint => 'For example, g';

  @override
  String get settingMultiplier => 'Multiplier';

  @override
  String get settingMultiplierHint => 'For example, 28.3495';

  @override
  String get settingUnitRuleRequired =>
      'Enter both units and a valid multiplier greater than 0.';

  @override
  String get settingSaveRule => 'Save rule';

  @override
  String get settingFontLoadFailed =>
      'This font could not be loaded. Choose another font.';

  @override
  String get settingInvalidSymbol => 'Enter a valid symbol.';

  @override
  String get settingAddSymbolDialog => 'Add instrument symbol';

  @override
  String get settingYahooMarkets => 'Yahoo · US / Chinese stocks';

  @override
  String get settingSymbol => 'Symbol';

  @override
  String get settingYahooHint => 'AAPL, 600519.SS, or 600519';

  @override
  String get settingOptionalName => 'Display name (optional)';

  @override
  String get settingAdd => 'Add';

  @override
  String get settingSearchFonts => 'Search fonts';

  @override
  String get settingNoFonts => 'No matching fonts';

  @override
  String get settingFontUnavailable =>
      'This font could not be loaded. Choose another font.';

  @override
  String get settingFontSample => 'Price 83,342.30 · AaBb 123';

  @override
  String get settingApiSteps =>
      '1. Paste the API URL\n2. Select “Read response fields”\n3. Choose fields, name them, and set their units';

  @override
  String settingSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String settingSearchCount(int count) {
    return '$count results';
  }

  @override
  String settingSettingsFile(String path) {
    return 'Settings file: $path';
  }

  @override
  String settingCatalogCounts(int selected, int total, int matched) {
    return '$selected selected · $total in catalog · $matched matches';
  }

  @override
  String settingCatalogUnavailable(String providers) {
    return 'The $providers catalog has not updated. Existing instruments are still available.';
  }

  @override
  String settingPageCount(int page, int total, int size) {
    return 'Page $page of $total · $size per page';
  }

  @override
  String settingWatchlistCount(int count) {
    return 'Watchlist · $count';
  }

  @override
  String settingDragAsset(String name) {
    return 'Drag $name to reorder';
  }

  @override
  String settingMoveAssetUp(String name) {
    return 'Move $name up';
  }

  @override
  String settingMoveAssetDown(String name) {
    return 'Move $name down';
  }

  @override
  String settingUnfollowAsset(String name) {
    return 'Remove $name from watchlist';
  }

  @override
  String settingImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String settingSourceSummary(String status, int seconds, int count) {
    return '$status · Refresh every ${seconds}s · $count display fields';
  }

  @override
  String settingRowNumber(int number) {
    return 'Row $number';
  }

  @override
  String settingMultiplierSummary(double multiplier) {
    return 'Value × $multiplier';
  }

  @override
  String get settingLanguage => 'Language';

  @override
  String get settingLanguageSystem => 'Follow system';

  @override
  String get settingCatalogAssets => 'Choose instruments';

  @override
  String get settingCatalogOrder => 'Watchlist order';

  @override
  String get settingCatalogApi => 'Custom APIs';

  @override
  String get settingCatalogRows => 'Custom rows & templates';

  @override
  String get settingCatalogFonts => 'Text & number fonts';

  @override
  String get settingCatalogSpacing => 'Font size & row spacing';

  @override
  String get settingCatalogThemes => 'Light & dark themes';

  @override
  String get settingCatalogHeader => 'Title & icon';

  @override
  String get settingCatalogUnits => 'Units & display currency';

  @override
  String get settingCatalogWindow => 'Always on top';

  @override
  String get settingCatalogTray => 'Hide & restore from tray';

  @override
  String get theme120Saturation => 'Saturation';

  @override
  String get theme120Spectrum => 'Saturation and brightness';

  @override
  String get theme120SpectrumHint =>
      'Use arrow keys to adjust saturation and brightness. Hold Shift for larger steps.';

  @override
  String get theme120InvalidHex => 'Enter six hexadecimal digits.';

  @override
  String get theme120InvalidRgb => 'Use a number from 0 to 255.';

  @override
  String get theme120ColorValue => 'Selected color';
}
