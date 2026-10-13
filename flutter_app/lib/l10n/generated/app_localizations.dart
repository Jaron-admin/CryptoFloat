import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @editCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editCancel;

  /// No description provided for @editSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editSave;

  /// No description provided for @editAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get editAdd;

  /// No description provided for @editDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get editDelete;

  /// No description provided for @editAddToDisplay.
  ///
  /// In en, this message translates to:
  /// **'Add to panel'**
  String get editAddToDisplay;

  /// No description provided for @editRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get editRemove;

  /// No description provided for @editSourceNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this data source.'**
  String get editSourceNameRequired;

  /// No description provided for @editSourceUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS API URL. Put API keys in the request headers.'**
  String get editSourceUrlInvalid;

  /// No description provided for @editSourceIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'The refresh interval must be between 15 and 3600 seconds.'**
  String get editSourceIntervalInvalid;

  /// No description provided for @editSourceDuplicateHeader.
  ///
  /// In en, this message translates to:
  /// **'A request header name is duplicated. Keep only one entry.'**
  String get editSourceDuplicateHeader;

  /// No description provided for @editSourceFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one field to display.'**
  String get editSourceFieldsRequired;

  /// No description provided for @editSetField.
  ///
  /// In en, this message translates to:
  /// **'Set up display field'**
  String get editSetField;

  /// No description provided for @editField.
  ///
  /// In en, this message translates to:
  /// **'Edit display field'**
  String get editField;

  /// No description provided for @editFieldName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get editFieldName;

  /// No description provided for @editFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Account balance or Outdoor temperature'**
  String get editFieldNameHint;

  /// No description provided for @editFieldUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit (optional)'**
  String get editFieldUnit;

  /// No description provided for @editFieldUnitHint.
  ///
  /// In en, this message translates to:
  /// **'For example: USD, °C or people'**
  String get editFieldUnitHint;

  /// No description provided for @editFieldPath.
  ///
  /// In en, this message translates to:
  /// **'Path in the response'**
  String get editFieldPath;

  /// No description provided for @editFieldPathHint.
  ///
  /// In en, this message translates to:
  /// **'For example: data.balance or items[0].price'**
  String get editFieldPathHint;

  /// No description provided for @editSourceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add custom API'**
  String get editSourceAdd;

  /// No description provided for @editSourceEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit custom API'**
  String get editSourceEdit;

  /// No description provided for @editSourceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable this source'**
  String get editSourceEnabled;

  /// No description provided for @editConnectSource.
  ///
  /// In en, this message translates to:
  /// **'Connect a data source'**
  String get editConnectSource;

  /// No description provided for @editSourceName.
  ///
  /// In en, this message translates to:
  /// **'Source name'**
  String get editSourceName;

  /// No description provided for @editSourceNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: My account or Weather'**
  String get editSourceNameHint;

  /// No description provided for @editSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'HTTPS API URL'**
  String get editSourceUrl;

  /// No description provided for @editSourceInterval.
  ///
  /// In en, this message translates to:
  /// **'Refresh interval (seconds)'**
  String get editSourceInterval;

  /// No description provided for @editSourceIntervalHelp.
  ///
  /// In en, this message translates to:
  /// **'15–3600 seconds. Follow the API rate limits.'**
  String get editSourceIntervalHelp;

  /// No description provided for @editSourceHeaders.
  ///
  /// In en, this message translates to:
  /// **'Request headers / API keys (if needed)'**
  String get editSourceHeaders;

  /// No description provided for @editSourceHeadersOptional.
  ///
  /// In en, this message translates to:
  /// **'Skip this for APIs that do not require keys'**
  String get editSourceHeadersOptional;

  /// No description provided for @editHeaderName.
  ///
  /// In en, this message translates to:
  /// **'Header name'**
  String get editHeaderName;

  /// No description provided for @editHeaderSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret value'**
  String get editHeaderSecret;

  /// No description provided for @editHeaderValue.
  ///
  /// In en, this message translates to:
  /// **'Header value'**
  String get editHeaderValue;

  /// No description provided for @editHeaderRetain.
  ///
  /// In en, this message translates to:
  /// **'Saved. Leave blank to keep the current value'**
  String get editHeaderRetain;

  /// No description provided for @editHeaderTokenHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Bearer your-token'**
  String get editHeaderTokenHint;

  /// No description provided for @editHeaderSecure.
  ///
  /// In en, this message translates to:
  /// **'Store securely as a secret'**
  String get editHeaderSecure;

  /// No description provided for @editHeaderAdd.
  ///
  /// In en, this message translates to:
  /// **'Add header'**
  String get editHeaderAdd;

  /// No description provided for @editReadFields.
  ///
  /// In en, this message translates to:
  /// **'Read response fields'**
  String get editReadFields;

  /// No description provided for @editDisplayFields.
  ///
  /// In en, this message translates to:
  /// **'Display fields'**
  String get editDisplayFields;

  /// No description provided for @editReadFieldsHelp.
  ///
  /// In en, this message translates to:
  /// **'After loading the response, select a value and give it a display name and unit.'**
  String get editReadFieldsHelp;

  /// No description provided for @editSelectedFields.
  ///
  /// In en, this message translates to:
  /// **'Selected fields'**
  String get editSelectedFields;

  /// No description provided for @editRemoveField.
  ///
  /// In en, this message translates to:
  /// **'Remove field'**
  String get editRemoveField;

  /// No description provided for @editAdvancedField.
  ///
  /// In en, this message translates to:
  /// **'Advanced: enter a field path'**
  String get editAdvancedField;

  /// No description provided for @editAddFieldPath.
  ///
  /// In en, this message translates to:
  /// **'Add field path'**
  String get editAddFieldPath;

  /// No description provided for @editFieldSymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get editFieldSymbol;

  /// No description provided for @editFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editFieldLabel;

  /// No description provided for @editFieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get editFieldPrice;

  /// No description provided for @editFieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get editFieldCurrency;

  /// No description provided for @editFieldChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get editFieldChange;

  /// No description provided for @editFieldProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get editFieldProvider;

  /// No description provided for @editFieldUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated at'**
  String get editFieldUpdatedAt;

  /// No description provided for @editSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'Source not found'**
  String get editSourceMissing;

  /// No description provided for @editDisplayText.
  ///
  /// In en, this message translates to:
  /// **'Display text'**
  String get editDisplayText;

  /// No description provided for @editWantedText.
  ///
  /// In en, this message translates to:
  /// **'Text to display'**
  String get editWantedText;

  /// No description provided for @editWantedTextHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Today’s price:  or  My balance '**
  String get editWantedTextHint;

  /// No description provided for @editComposeRow.
  ///
  /// In en, this message translates to:
  /// **'Compose display row'**
  String get editComposeRow;

  /// No description provided for @editCloseEditor.
  ///
  /// In en, this message translates to:
  /// **'Close editor'**
  String get editCloseEditor;

  /// No description provided for @editComposeRowHelp.
  ///
  /// In en, this message translates to:
  /// **'Text and fields appear from left to right. Add spaces and punctuation as needed.'**
  String get editComposeRowHelp;

  /// No description provided for @editAddText.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get editAddText;

  /// No description provided for @editAddDataField.
  ///
  /// In en, this message translates to:
  /// **'Add data field'**
  String get editAddDataField;

  /// No description provided for @editEmptyRow.
  ///
  /// In en, this message translates to:
  /// **'No text or fields added yet'**
  String get editEmptyRow;

  /// No description provided for @editDisplayPreview.
  ///
  /// In en, this message translates to:
  /// **'Display preview'**
  String get editDisplayPreview;

  /// No description provided for @editSaveRow.
  ///
  /// In en, this message translates to:
  /// **'Save row'**
  String get editSaveRow;

  /// No description provided for @editMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get editMoveLeft;

  /// No description provided for @editMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get editMoveRight;

  /// No description provided for @editEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Empty text'**
  String get editEmptyText;

  /// No description provided for @editAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get editAutomatic;

  /// No description provided for @editSelectField.
  ///
  /// In en, this message translates to:
  /// **'Select display field'**
  String get editSelectField;

  /// No description provided for @editSelectSourceFirst.
  ///
  /// In en, this message translates to:
  /// **'Select an item in Watchlist or add a custom API first.'**
  String get editSelectSourceFirst;

  /// No description provided for @editFieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get editFieldSource;

  /// No description provided for @editFieldSelection.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get editFieldSelection;

  /// No description provided for @editNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get editNumberFormat;

  /// No description provided for @editDecimalsTwo.
  ///
  /// In en, this message translates to:
  /// **'2 decimal places'**
  String get editDecimalsTwo;

  /// No description provided for @editDecimalsFour.
  ///
  /// In en, this message translates to:
  /// **'4 decimal places'**
  String get editDecimalsFour;

  /// No description provided for @editDecimalsSigned.
  ///
  /// In en, this message translates to:
  /// **'Sign + 2 decimal places'**
  String get editDecimalsSigned;

  /// No description provided for @editRawValue.
  ///
  /// In en, this message translates to:
  /// **'Original API value'**
  String get editRawValue;

  /// No description provided for @editThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get editThemeMode;

  /// No description provided for @editSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get editSystem;

  /// No description provided for @editLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get editLight;

  /// No description provided for @editDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get editDark;

  /// No description provided for @editLightPreview.
  ///
  /// In en, this message translates to:
  /// **'Light preview'**
  String get editLightPreview;

  /// No description provided for @editDarkPreview.
  ///
  /// In en, this message translates to:
  /// **'Dark preview'**
  String get editDarkPreview;

  /// No description provided for @editMyThemes.
  ///
  /// In en, this message translates to:
  /// **'My themes'**
  String get editMyThemes;

  /// No description provided for @editSaveThemeAs.
  ///
  /// In en, this message translates to:
  /// **'Save current colors as a theme'**
  String get editSaveThemeAs;

  /// No description provided for @editThemesHelp.
  ///
  /// In en, this message translates to:
  /// **'Save your favorite colors and switch between them.'**
  String get editThemesHelp;

  /// No description provided for @editCustomBackground.
  ///
  /// In en, this message translates to:
  /// **'Custom background'**
  String get editCustomBackground;

  /// No description provided for @editDarkPalette.
  ///
  /// In en, this message translates to:
  /// **'Dark palette'**
  String get editDarkPalette;

  /// No description provided for @editLightPalette.
  ///
  /// In en, this message translates to:
  /// **'Light palette'**
  String get editLightPalette;

  /// No description provided for @editDarkBackground.
  ///
  /// In en, this message translates to:
  /// **'Dark background'**
  String get editDarkBackground;

  /// No description provided for @editLightBackground.
  ///
  /// In en, this message translates to:
  /// **'Light background'**
  String get editLightBackground;

  /// No description provided for @editChooseColor.
  ///
  /// In en, this message translates to:
  /// **'Choose color'**
  String get editChooseColor;

  /// No description provided for @editDeleteTheme.
  ///
  /// In en, this message translates to:
  /// **'Delete theme'**
  String get editDeleteTheme;

  /// No description provided for @editThemeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a theme name'**
  String get editThemeNameRequired;

  /// No description provided for @editThemeNew.
  ///
  /// In en, this message translates to:
  /// **'Save new theme'**
  String get editThemeNew;

  /// No description provided for @editThemeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit theme'**
  String get editThemeEdit;

  /// No description provided for @editThemeName.
  ///
  /// In en, this message translates to:
  /// **'Theme name'**
  String get editThemeName;

  /// No description provided for @editThemeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name this color palette'**
  String get editThemeNameHint;

  /// No description provided for @editThemePalette.
  ///
  /// In en, this message translates to:
  /// **'Palette to edit'**
  String get editThemePalette;

  /// No description provided for @editColorRole.
  ///
  /// In en, this message translates to:
  /// **'Color role'**
  String get editColorRole;

  /// No description provided for @editHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get editHue;

  /// No description provided for @editBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get editBrightness;

  /// No description provided for @editSaveTheme.
  ///
  /// In en, this message translates to:
  /// **'Save theme'**
  String get editSaveTheme;

  /// No description provided for @editApplyColor.
  ///
  /// In en, this message translates to:
  /// **'Apply color'**
  String get editApplyColor;

  /// No description provided for @editRoleBackground.
  ///
  /// In en, this message translates to:
  /// **'Window background'**
  String get editRoleBackground;

  /// No description provided for @editRoleSurface.
  ///
  /// In en, this message translates to:
  /// **'Card background'**
  String get editRoleSurface;

  /// No description provided for @editRoleForeground.
  ///
  /// In en, this message translates to:
  /// **'Primary text'**
  String get editRoleForeground;

  /// No description provided for @editRoleSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary text'**
  String get editRoleSecondary;

  /// No description provided for @editRoleBorder.
  ///
  /// In en, this message translates to:
  /// **'Borders and dividers'**
  String get editRoleBorder;

  /// No description provided for @editRoleAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get editRoleAccent;

  /// No description provided for @editRolePositive.
  ///
  /// In en, this message translates to:
  /// **'Positive change'**
  String get editRolePositive;

  /// No description provided for @editRoleNegative.
  ///
  /// In en, this message translates to:
  /// **'Negative change'**
  String get editRoleNegative;

  /// No description provided for @editTemplateWeather.
  ///
  /// In en, this message translates to:
  /// **'City weather'**
  String get editTemplateWeather;

  /// No description provided for @editTemplateRates.
  ///
  /// In en, this message translates to:
  /// **'Reference exchange rates'**
  String get editTemplateRates;

  /// No description provided for @editTemplateGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub repository'**
  String get editTemplateGithub;

  /// No description provided for @editTemplateMarket.
  ///
  /// In en, this message translates to:
  /// **'Compact market ticker'**
  String get editTemplateMarket;

  /// No description provided for @editTemplateReminder.
  ///
  /// In en, this message translates to:
  /// **'Text reminder'**
  String get editTemplateReminder;

  /// No description provided for @editTemplateWeatherHelp.
  ///
  /// In en, this message translates to:
  /// **'Temperature, feels-like temperature and humidity. Refreshes every 15 minutes. Powered by Open-Meteo for personal use.'**
  String get editTemplateWeatherHelp;

  /// No description provided for @editTemplateRatesHelp.
  ///
  /// In en, this message translates to:
  /// **'Reference rates from USD to CNY, EUR and USDT. Refreshes every 5 minutes.'**
  String get editTemplateRatesHelp;

  /// No description provided for @editTemplateGithubHelp.
  ///
  /// In en, this message translates to:
  /// **'Stars and open issues / pull requests for a public repository. Refreshes every 10 minutes.'**
  String get editTemplateGithubHelp;

  /// No description provided for @editTemplateMarketHelp.
  ///
  /// In en, this message translates to:
  /// **'Combines the first 3 watchlist items into one row using your unit settings.'**
  String get editTemplateMarketHelp;

  /// No description provided for @editTemplateReminderHelp.
  ///
  /// In en, this message translates to:
  /// **'Displays text without a network connection. You can add data fields later in the row editor.'**
  String get editTemplateReminderHelp;

  /// No description provided for @editTemplateDefaultReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder: Take a walk and drink some water'**
  String get editTemplateDefaultReminder;

  /// No description provided for @editTemplateAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a template'**
  String get editTemplateAdd;

  /// No description provided for @editTemplateClose.
  ///
  /// In en, this message translates to:
  /// **'Close templates'**
  String get editTemplateClose;

  /// No description provided for @editCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get editCity;

  /// No description provided for @editRepoOwner.
  ///
  /// In en, this message translates to:
  /// **'Repository owner'**
  String get editRepoOwner;

  /// No description provided for @editRepoOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'For example: flutter'**
  String get editRepoOwnerHint;

  /// No description provided for @editRepoName.
  ///
  /// In en, this message translates to:
  /// **'Repository name'**
  String get editRepoName;

  /// No description provided for @editRepoNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: MetricPerch'**
  String get editRepoNameHint;

  /// No description provided for @editHeaderMissingSecret.
  ///
  /// In en, this message translates to:
  /// **'Enter the secret for {name}.'**
  String editHeaderMissingSecret(String name);

  /// No description provided for @editHeaderCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 header} other{{count} headers}}'**
  String editHeaderCount(int count);

  /// No description provided for @editRowFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: {format}'**
  String editRowFormat(String format);

  /// No description provided for @editThemeEditNamed.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editThemeEditNamed(String name);

  /// No description provided for @editThemeCopyNamed.
  ///
  /// In en, this message translates to:
  /// **'Copy {name}'**
  String editThemeCopyNamed(String name);

  /// No description provided for @editThemeDeleteNamed.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String editThemeDeleteNamed(String name);

  /// No description provided for @editThemeCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String editThemeCopyName(String name);

  /// No description provided for @editThemeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? Any active palette will switch to Fluent Blue.'**
  String editThemeDeleteConfirm(String name);

  /// No description provided for @editThemeBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom {mode} background'**
  String editThemeBackgroundTitle(String mode);

  /// No description provided for @editThemeFluent.
  ///
  /// In en, this message translates to:
  /// **'Fluent Blue'**
  String get editThemeFluent;

  /// No description provided for @editThemeNord.
  ///
  /// In en, this message translates to:
  /// **'Nord'**
  String get editThemeNord;

  /// No description provided for @editThemeSolarized.
  ///
  /// In en, this message translates to:
  /// **'Solarized'**
  String get editThemeSolarized;

  /// No description provided for @editCityBeijing.
  ///
  /// In en, this message translates to:
  /// **'Beijing'**
  String get editCityBeijing;

  /// No description provided for @editCityShanghai.
  ///
  /// In en, this message translates to:
  /// **'Shanghai'**
  String get editCityShanghai;

  /// No description provided for @editCityGuangzhou.
  ///
  /// In en, this message translates to:
  /// **'Guangzhou'**
  String get editCityGuangzhou;

  /// No description provided for @editCityShenzhen.
  ///
  /// In en, this message translates to:
  /// **'Shenzhen'**
  String get editCityShenzhen;

  /// No description provided for @editCityHangzhou.
  ///
  /// In en, this message translates to:
  /// **'Hangzhou'**
  String get editCityHangzhou;

  /// No description provided for @editCityChengdu.
  ///
  /// In en, this message translates to:
  /// **'Chengdu'**
  String get editCityChengdu;

  /// No description provided for @editCityWuhan.
  ///
  /// In en, this message translates to:
  /// **'Wuhan'**
  String get editCityWuhan;

  /// No description provided for @editCityXian.
  ///
  /// In en, this message translates to:
  /// **'Xi’an'**
  String get editCityXian;

  /// No description provided for @editTemplateCityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a city from the list. You can edit the source URL after adding it.'**
  String get editTemplateCityInvalid;

  /// No description provided for @editTemplateTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get editTemplateTemperature;

  /// No description provided for @editTemplateFeelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get editTemplateFeelsLike;

  /// No description provided for @editTemplateHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get editTemplateHumidity;

  /// No description provided for @editTemplateUsdRates.
  ///
  /// In en, this message translates to:
  /// **'USD reference rates'**
  String get editTemplateUsdRates;

  /// No description provided for @editTemplateUsdCny.
  ///
  /// In en, this message translates to:
  /// **'USD to CNY'**
  String get editTemplateUsdCny;

  /// No description provided for @editTemplateUsdEur.
  ///
  /// In en, this message translates to:
  /// **'USD to EUR'**
  String get editTemplateUsdEur;

  /// No description provided for @editTemplateUsdUsdt.
  ///
  /// In en, this message translates to:
  /// **'USD to USDT'**
  String get editTemplateUsdUsdt;

  /// No description provided for @editTemplateRepoInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the owner and name of a public repository, for example flutter / flutter.'**
  String get editTemplateRepoInvalid;

  /// No description provided for @editTemplateOpenIssues.
  ///
  /// In en, this message translates to:
  /// **'Open issues and pull requests'**
  String get editTemplateOpenIssues;

  /// No description provided for @editTemplateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get editTemplateOpen;

  /// No description provided for @editTemplateMarketEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select at least one coin or stock first.'**
  String get editTemplateMarketEmpty;

  /// No description provided for @editTemplateTextEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter some text to display.'**
  String get editTemplateTextEmpty;

  /// No description provided for @editTemplateWeatherName.
  ///
  /// In en, this message translates to:
  /// **'{city} weather'**
  String editTemplateWeatherName(String city);

  /// No description provided for @editMyTheme.
  ///
  /// In en, this message translates to:
  /// **'My theme'**
  String get editMyTheme;

  /// No description provided for @editMenuHide.
  ///
  /// In en, this message translates to:
  /// **'Hide to tray'**
  String get editMenuHide;

  /// No description provided for @editMenuShow.
  ///
  /// In en, this message translates to:
  /// **'Show floating panel'**
  String get editMenuShow;

  /// No description provided for @editMenuRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get editMenuRefresh;

  /// No description provided for @editMenuTopmost.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get editMenuTopmost;

  /// No description provided for @editMenuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get editMenuSettings;

  /// No description provided for @editMenuExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get editMenuExit;

  /// No description provided for @errorStartupDefaultLayout.
  ///
  /// In en, this message translates to:
  /// **'The settings file could not be read. The default layout is in use and the original file has been kept.'**
  String get errorStartupDefaultLayout;

  /// No description provided for @errorStartupFont.
  ///
  /// In en, this message translates to:
  /// **'A saved font could not be loaded. Choose another font in Appearance.'**
  String get errorStartupFont;

  /// No description provided for @errorStartupWindow.
  ///
  /// In en, this message translates to:
  /// **'Window settings could not be applied. You can continue using the app and try again in Settings.'**
  String get errorStartupWindow;

  /// No description provided for @errorInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'The value is invalid. The original value and unit have been kept.'**
  String get errorInvalidValue;

  /// No description provided for @errorInvalidMultiplier.
  ///
  /// In en, this message translates to:
  /// **'The custom multiplier is invalid. The original value and unit have been kept.'**
  String get errorInvalidMultiplier;

  /// No description provided for @errorConversionOverflow.
  ///
  /// In en, this message translates to:
  /// **'The converted value is out of range.'**
  String get errorConversionOverflow;

  /// No description provided for @errorExchangeRateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The exchange rate is missing, expired, or invalid. The original value and unit have been kept.'**
  String get errorExchangeRateUnavailable;

  /// No description provided for @errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Settings are being saved. Please wait.'**
  String get errorSaving;

  /// No description provided for @errorSavedTopmost.
  ///
  /// In en, this message translates to:
  /// **'Settings were saved, but always on top could not be applied. Reopen the app to try again.'**
  String get errorSavedTopmost;

  /// No description provided for @errorSavedOpacity.
  ///
  /// In en, this message translates to:
  /// **'Settings were saved, but window transparency could not be applied. Reopen the app to try again.'**
  String get errorSavedOpacity;

  /// No description provided for @errorTrayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The tray icon could not be created. The window will remain visible. Try again later.'**
  String get errorTrayUnavailable;

  /// No description provided for @errorIconTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The icon image must be no larger than 1 MB.'**
  String get errorIconTooLarge;

  /// No description provided for @errorChooseSmallImage.
  ///
  /// In en, this message translates to:
  /// **'Choose an image no larger than 1 MB.'**
  String get errorChooseSmallImage;

  /// No description provided for @errorImageDimensions.
  ///
  /// In en, this message translates to:
  /// **'The icon image dimensions are too large. Choose a smaller image.'**
  String get errorImageDimensions;

  /// No description provided for @errorImageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The image could not be read.'**
  String get errorImageUnreadable;

  /// No description provided for @errorImageUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The image could not be read. Choose a PNG, JPEG, GIF, WebP, BMP, or ICO image.'**
  String get errorImageUnsupported;

  /// No description provided for @errorConnectionClosed.
  ///
  /// In en, this message translates to:
  /// **'The data connection has been closed.'**
  String get errorConnectionClosed;

  /// No description provided for @errorNetworkTimeout.
  ///
  /// In en, this message translates to:
  /// **'The network connection timed out. Try again later.'**
  String get errorNetworkTimeout;

  /// No description provided for @errorNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'A network connection could not be established. Check your network settings.'**
  String get errorNetworkSettings;

  /// No description provided for @errorHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete HTTPS address without credentials or a fragment.'**
  String get errorHttpsRequired;

  /// No description provided for @errorCatalogUrl.
  ///
  /// In en, this message translates to:
  /// **'This market catalog address is not supported.'**
  String get errorCatalogUrl;

  /// No description provided for @errorRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Try again later.'**
  String get errorRequestTimeout;

  /// No description provided for @errorSourceConnection.
  ///
  /// In en, this message translates to:
  /// **'The data source could not be reached. Check your network connection.'**
  String get errorSourceConnection;

  /// No description provided for @errorCertificate.
  ///
  /// In en, this message translates to:
  /// **'HTTPS certificate verification failed.'**
  String get errorCertificate;

  /// No description provided for @errorConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'The data connection failed. Check the address and network settings.'**
  String get errorConnectionFailed;

  /// No description provided for @errorInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'The response is not valid UTF-8 JSON.'**
  String get errorInvalidJson;

  /// No description provided for @errorRedirect.
  ///
  /// In en, this message translates to:
  /// **'The data source redirected the request. Enter the final HTTPS address.'**
  String get errorRedirect;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The data source is limiting requests. Try later or increase the refresh interval.'**
  String get errorRateLimited;

  /// No description provided for @errorJsonEmptyField.
  ///
  /// In en, this message translates to:
  /// **'The JSON path contains an empty field name.'**
  String get errorJsonEmptyField;

  /// No description provided for @errorJsonSeparator.
  ///
  /// In en, this message translates to:
  /// **'Use a dot or brackets between JSON fields.'**
  String get errorJsonSeparator;

  /// No description provided for @errorJsonClosingBracket.
  ///
  /// In en, this message translates to:
  /// **'The JSON path is missing a closing bracket.'**
  String get errorJsonClosingBracket;

  /// No description provided for @errorJsonQuote.
  ///
  /// In en, this message translates to:
  /// **'The JSON path is missing a quotation mark.'**
  String get errorJsonQuote;

  /// No description provided for @errorJsonEscape.
  ///
  /// In en, this message translates to:
  /// **'The JSON path contains an invalid quotation mark or escape sequence.'**
  String get errorJsonEscape;

  /// No description provided for @errorJsonArrayIndex.
  ///
  /// In en, this message translates to:
  /// **'An array index must be a non-negative integer.'**
  String get errorJsonArrayIndex;

  /// No description provided for @errorJsonPath.
  ///
  /// In en, this message translates to:
  /// **'The JSON path is invalid.'**
  String get errorJsonPath;

  /// No description provided for @errorJsonIndexMissing.
  ///
  /// In en, this message translates to:
  /// **'The JSON array index does not exist.'**
  String get errorJsonIndexMissing;

  /// No description provided for @errorJsonFieldMissing.
  ///
  /// In en, this message translates to:
  /// **'The JSON field path does not exist.'**
  String get errorJsonFieldMissing;

  /// No description provided for @errorSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete HTTPS URL without credentials or a fragment.'**
  String get errorSourceUrl;

  /// No description provided for @errorKeyInUrl.
  ///
  /// In en, this message translates to:
  /// **'Do not put keys in the URL. Use a protected request header.'**
  String get errorKeyInUrl;

  /// No description provided for @errorTooManyHeaders.
  ///
  /// In en, this message translates to:
  /// **'A source can have at most 64 request headers.'**
  String get errorTooManyHeaders;

  /// No description provided for @errorProtectedHeader.
  ///
  /// In en, this message translates to:
  /// **'Authentication headers must use a reference to protected key storage.'**
  String get errorProtectedHeader;

  /// No description provided for @errorEmptyKeyReference.
  ///
  /// In en, this message translates to:
  /// **'The key storage reference must not be empty.'**
  String get errorEmptyKeyReference;

  /// No description provided for @errorTooManyFields.
  ///
  /// In en, this message translates to:
  /// **'A source can have at most 500 fields.'**
  String get errorTooManyFields;

  /// No description provided for @errorDuplicateField.
  ///
  /// In en, this message translates to:
  /// **'Field IDs must not be empty or duplicated.'**
  String get errorDuplicateField;

  /// No description provided for @errorInvalidHeader.
  ///
  /// In en, this message translates to:
  /// **'A request header name or value is invalid.'**
  String get errorInvalidHeader;

  /// No description provided for @errorManagedHeader.
  ///
  /// In en, this message translates to:
  /// **'This header is managed by the secure network connection.'**
  String get errorManagedHeader;

  /// No description provided for @errorInvalidRateResponse.
  ///
  /// In en, this message translates to:
  /// **'The exchange rate response is invalid. The original value and unit have been kept.'**
  String get errorInvalidRateResponse;

  /// No description provided for @errorInvalidRateBase.
  ///
  /// In en, this message translates to:
  /// **'The exchange rate base is invalid. The original value and unit have been kept.'**
  String get errorInvalidRateBase;

  /// No description provided for @errorProxyRead.
  ///
  /// In en, this message translates to:
  /// **'System proxy settings could not be read. Check Windows network settings.'**
  String get errorProxyRead;

  /// No description provided for @errorProxyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'System proxy support is unavailable. Use the complete, current app package.'**
  String get errorProxyUnavailable;

  /// No description provided for @errorNetworkType.
  ///
  /// In en, this message translates to:
  /// **'This network connection type is not supported. Check system network settings.'**
  String get errorNetworkType;

  /// No description provided for @errorInvalidSystemNetwork.
  ///
  /// In en, this message translates to:
  /// **'System network settings are invalid. Check them and try again.'**
  String get errorInvalidSystemNetwork;

  /// No description provided for @errorApplySystemNetwork.
  ///
  /// In en, this message translates to:
  /// **'System network settings could not be applied. Check them and try again.'**
  String get errorApplySystemNetwork;

  /// No description provided for @errorWaitingForData.
  ///
  /// In en, this message translates to:
  /// **'Settings updated. Waiting for new quotes.'**
  String get errorWaitingForData;

  /// No description provided for @errorSourceDisabled.
  ///
  /// In en, this message translates to:
  /// **'This data source is disabled.'**
  String get errorSourceDisabled;

  /// No description provided for @errorScalarField.
  ///
  /// In en, this message translates to:
  /// **'The selected field must contain a single number, text value, or boolean.'**
  String get errorScalarField;

  /// No description provided for @errorFieldUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected field has no valid data yet.'**
  String get errorFieldUnavailable;

  /// No description provided for @errorNoResponseFields.
  ///
  /// In en, this message translates to:
  /// **'The response has no selectable fields.'**
  String get errorNoResponseFields;

  /// No description provided for @errorMissingProtectedHeader.
  ///
  /// In en, this message translates to:
  /// **'A protected request header is missing. Re-enter the key in Settings.'**
  String get errorMissingProtectedHeader;

  /// No description provided for @errorKeyReadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Reading a protected request header timed out. Try again.'**
  String get errorKeyReadTimeout;

  /// No description provided for @errorRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The data request could not be completed. Check the source, key, and network settings.'**
  String get errorRequestFailed;

  /// No description provided for @errorProxyPort.
  ///
  /// In en, this message translates to:
  /// **'The proxy port must be between 1 and 65535.'**
  String get errorProxyPort;

  /// No description provided for @errorProxyInvalidSettings.
  ///
  /// In en, this message translates to:
  /// **'The system proxy returned invalid connection settings.'**
  String get errorProxyInvalidSettings;

  /// No description provided for @errorProxyTooManyAddresses.
  ///
  /// In en, this message translates to:
  /// **'The system proxy returned too many candidate addresses.'**
  String get errorProxyTooManyAddresses;

  /// No description provided for @errorProxyUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'This connection type is not supported. Use an HTTP or mixed proxy port.'**
  String get errorProxyUnsupportedType;

  /// No description provided for @errorProxyUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'This system proxy format is not supported. Use an HTTP or mixed proxy port.'**
  String get errorProxyUnsupportedFormat;

  /// No description provided for @errorProxyHost.
  ///
  /// In en, this message translates to:
  /// **'The proxy address is invalid. Enter a hostname or IP address.'**
  String get errorProxyHost;

  /// No description provided for @errorProxyIpv6.
  ///
  /// In en, this message translates to:
  /// **'The proxy IPv6 address is invalid.'**
  String get errorProxyIpv6;

  /// No description provided for @errorProxyAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter only the proxy hostname or IP, without a scheme, path, or credentials.'**
  String get errorProxyAddress;

  /// No description provided for @errorConfigRestored.
  ///
  /// In en, this message translates to:
  /// **'The settings file could not be read. The previous backup was restored and the original file was kept.'**
  String get errorConfigRestored;

  /// No description provided for @errorConfigDefaults.
  ///
  /// In en, this message translates to:
  /// **'The settings file could not be read. Default settings are in use and the original file was kept.'**
  String get errorConfigDefaults;

  /// No description provided for @errorConfigTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The settings file is too large.'**
  String get errorConfigTooLarge;

  /// No description provided for @errorConfigObject.
  ///
  /// In en, this message translates to:
  /// **'The settings file must contain a JSON object.'**
  String get errorConfigObject;

  /// No description provided for @errorConfigNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'The settings file was created by a newer app version.'**
  String get errorConfigNewerVersion;

  /// No description provided for @errorConfigSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Settings exceed the 2 MB limit.'**
  String get errorConfigSizeLimit;

  /// No description provided for @errorLegacyConfigSize.
  ///
  /// In en, this message translates to:
  /// **'The legacy settings file exceeds the 2 MB limit.'**
  String get errorLegacyConfigSize;

  /// No description provided for @errorLegacyConfigObject.
  ///
  /// In en, this message translates to:
  /// **'The legacy settings file must contain a JSON object.'**
  String get errorLegacyConfigObject;

  /// No description provided for @errorLegacyConfigInvalid.
  ///
  /// In en, this message translates to:
  /// **'The legacy settings file is not a valid JSON settings object.'**
  String get errorLegacyConfigInvalid;

  /// No description provided for @errorCatalogCacheSave.
  ///
  /// In en, this message translates to:
  /// **'The catalog was updated, but its local cache could not be saved.'**
  String get errorCatalogCacheSave;

  /// No description provided for @errorCatalogUpdate.
  ///
  /// In en, this message translates to:
  /// **'The market catalog could not be updated. Try again later.'**
  String get errorCatalogUpdate;

  /// No description provided for @errorCatalogCacheSize.
  ///
  /// In en, this message translates to:
  /// **'The market catalog cache exceeds its size limit.'**
  String get errorCatalogCacheSize;

  /// No description provided for @errorCatalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'The exchange did not return a valid market catalog.'**
  String get errorCatalogEmpty;

  /// No description provided for @errorCatalogFormat.
  ///
  /// In en, this message translates to:
  /// **'The market catalog format or number of entries is not supported.'**
  String get errorCatalogFormat;

  /// No description provided for @errorCatalogInvalid.
  ///
  /// In en, this message translates to:
  /// **'The market catalog format is invalid.'**
  String get errorCatalogInvalid;

  /// No description provided for @errorCatalogProvider.
  ///
  /// In en, this message translates to:
  /// **'This market catalog provider is not supported.'**
  String get errorCatalogProvider;

  /// No description provided for @errorCatalogNoPairs.
  ///
  /// In en, this message translates to:
  /// **'The exchange returned no available spot pairs. The existing catalog was kept.'**
  String get errorCatalogNoPairs;

  /// No description provided for @errorCatalogSymbol.
  ///
  /// In en, this message translates to:
  /// **'The market catalog contains an invalid trading pair symbol.'**
  String get errorCatalogSymbol;

  /// No description provided for @errorCatalogName.
  ///
  /// In en, this message translates to:
  /// **'The market catalog contains an invalid name or symbol.'**
  String get errorCatalogName;

  /// No description provided for @errorAssetProvider.
  ///
  /// In en, this message translates to:
  /// **'The data provider for this instrument is not supported.'**
  String get errorAssetProvider;

  /// No description provided for @errorOkxQuote.
  ///
  /// In en, this message translates to:
  /// **'OKX returned no valid quote. Check the trading pair and regional availability.'**
  String get errorOkxQuote;

  /// No description provided for @errorKucoinQuote.
  ///
  /// In en, this message translates to:
  /// **'KuCoin returned no valid quote. Check the trading pair.'**
  String get errorKucoinQuote;

  /// No description provided for @errorYahooQuote.
  ///
  /// In en, this message translates to:
  /// **'Yahoo Finance returned no valid quote. Check the symbol or try again later.'**
  String get errorYahooQuote;

  /// No description provided for @errorYahooNotice.
  ///
  /// In en, this message translates to:
  /// **'Unofficial Yahoo Finance API. Quotes may be delayed.'**
  String get errorYahooNotice;

  /// No description provided for @errorQuoteStructure.
  ///
  /// In en, this message translates to:
  /// **'The quote response structure is invalid.'**
  String get errorQuoteStructure;

  /// No description provided for @errorQuoteMissing.
  ///
  /// In en, this message translates to:
  /// **'The data source returned no quote for this instrument.'**
  String get errorQuoteMissing;

  /// No description provided for @errorPriceMissing.
  ///
  /// In en, this message translates to:
  /// **'The data source has no valid latest price.'**
  String get errorPriceMissing;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'The action could not be completed. Check your settings and try again.'**
  String get errorUnknown;

  /// No description provided for @errorHttpStatus.
  ///
  /// In en, this message translates to:
  /// **'The data source returned HTTP {status}.'**
  String errorHttpStatus(int status);

  /// No description provided for @errorResponseLimit.
  ///
  /// In en, this message translates to:
  /// **'The data source response exceeds the {size} MB limit.'**
  String errorResponseLimit(int size);

  /// No description provided for @errorPortableDirectory.
  ///
  /// In en, this message translates to:
  /// **'Cannot write user_data beside the app. Move the app to a writable folder with enough free space.'**
  String get errorPortableDirectory;

  /// No description provided for @appMoutai.
  ///
  /// In en, this message translates to:
  /// **'Kweichow Moutai'**
  String get appMoutai;

  /// No description provided for @appPingAn.
  ///
  /// In en, this message translates to:
  /// **'Ping An Bank'**
  String get appPingAn;

  /// No description provided for @appCatl.
  ///
  /// In en, this message translates to:
  /// **'CATL'**
  String get appCatl;

  /// No description provided for @panelUnpin.
  ///
  /// In en, this message translates to:
  /// **'Turn off always on top'**
  String get panelUnpin;

  /// No description provided for @panelPin.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get panelPin;

  /// No description provided for @panelSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get panelSettings;

  /// No description provided for @panelNoSources.
  ///
  /// In en, this message translates to:
  /// **'No sources configured'**
  String get panelNoSources;

  /// No description provided for @panelLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get panelLive;

  /// No description provided for @panelWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first update'**
  String get panelWaiting;

  /// No description provided for @panelLastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last updated {time}'**
  String panelLastUpdate(String time);

  /// No description provided for @panelPending.
  ///
  /// In en, this message translates to:
  /// **'Last updated {time} · {count} pending'**
  String panelPending(String time, int count);

  /// No description provided for @panelAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **' · Auto-refresh {interval}'**
  String panelAutoRefresh(String interval);

  /// No description provided for @panelMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String panelMinutes(int count);

  /// No description provided for @panelSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count}s'**
  String panelSeconds(int count);

  /// No description provided for @panelRatesPending.
  ///
  /// In en, this message translates to:
  /// **' · Rates unavailable'**
  String get panelRatesPending;

  /// No description provided for @panelSourceInterval.
  ///
  /// In en, this message translates to:
  /// **'Every {seconds}s'**
  String panelSourceInterval(int seconds);

  /// No description provided for @panelLastFetch.
  ///
  /// In en, this message translates to:
  /// **'Last fetched {time}'**
  String panelLastFetch(String time);

  /// No description provided for @panelRatesInterval.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates refresh every 5 minutes'**
  String get panelRatesInterval;

  /// No description provided for @panelLiveNote.
  ///
  /// In en, this message translates to:
  /// **'Live means requests are up to date; upstream quotes may be delayed.'**
  String get panelLiveNote;

  /// No description provided for @panelQuoteTime.
  ///
  /// In en, this message translates to:
  /// **'Quote time {time}'**
  String panelQuoteTime(String time);

  /// No description provided for @panelOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original {value} {currency}'**
  String panelOriginal(String value, String currency);

  /// No description provided for @panelUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String panelUpdated(String time);

  /// No description provided for @panelChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose what to follow'**
  String get panelChoose;

  /// No description provided for @panelAdd.
  ///
  /// In en, this message translates to:
  /// **'Add instruments or API'**
  String get panelAdd;

  /// No description provided for @panelRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed item'**
  String get panelRemoved;

  /// No description provided for @panelNoData.
  ///
  /// In en, this message translates to:
  /// **'No data. Check the watchlist or source.'**
  String get panelNoData;

  /// No description provided for @panelStale.
  ///
  /// In en, this message translates to:
  /// **'Stale data {time}'**
  String panelStale(String time);

  /// No description provided for @panelConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get panelConnectionError;

  /// No description provided for @panelNeverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Never updated'**
  String get panelNeverUpdated;

  /// No description provided for @settingUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get settingUnsavedChanges;

  /// No description provided for @settingSaveBeforeExit.
  ///
  /// In en, this message translates to:
  /// **'Save your changes before quitting, or discard them.'**
  String get settingSaveBeforeExit;

  /// No description provided for @settingSaveBeforeReturn.
  ///
  /// In en, this message translates to:
  /// **'Save to apply your changes to the panel, or discard them.'**
  String get settingSaveBeforeReturn;

  /// No description provided for @settingKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get settingKeepEditing;

  /// No description provided for @settingDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get settingDiscardChanges;

  /// No description provided for @settingSaveAndQuit.
  ///
  /// In en, this message translates to:
  /// **'Save and quit'**
  String get settingSaveAndQuit;

  /// No description provided for @settingSaveAndReturn.
  ///
  /// In en, this message translates to:
  /// **'Save and return'**
  String get settingSaveAndReturn;

  /// No description provided for @settingActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to complete the action'**
  String get settingActionFailed;

  /// No description provided for @settingReturnToPanel.
  ///
  /// In en, this message translates to:
  /// **'Return to panel'**
  String get settingReturnToPanel;

  /// No description provided for @settingTitle.
  ///
  /// In en, this message translates to:
  /// **'MetricPerch Settings'**
  String get settingTitle;

  /// No description provided for @settingSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get settingSaving;

  /// No description provided for @settingUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get settingUnsaved;

  /// No description provided for @settingSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get settingSaved;

  /// No description provided for @settingSearch.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingSearch;

  /// No description provided for @settingClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get settingClearSearch;

  /// No description provided for @settingUnitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Units & conversion'**
  String get settingUnitsTitle;

  /// No description provided for @settingUnitsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the quote currency and unit labels. Use custom multipliers for other values.'**
  String get settingUnitsDescription;

  /// No description provided for @settingNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching settings. Try “font”, “units”, or “always on top”.'**
  String get settingNoSearchResults;

  /// No description provided for @settingStorage.
  ///
  /// In en, this message translates to:
  /// **'Import & data location'**
  String get settingStorage;

  /// No description provided for @settingImportLegacy.
  ///
  /// In en, this message translates to:
  /// **'Import legacy settings'**
  String get settingImportLegacy;

  /// No description provided for @settingWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get settingWatchlist;

  /// No description provided for @settingWatchlistDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your watchlist and search for currencies, stocks, and ETFs.'**
  String get settingWatchlistDescription;

  /// No description provided for @settingAddAsset.
  ///
  /// In en, this message translates to:
  /// **'Add instruments'**
  String get settingAddAsset;

  /// No description provided for @settingSearchAsset.
  ///
  /// In en, this message translates to:
  /// **'Search name, symbol, or provider'**
  String get settingSearchAsset;

  /// No description provided for @settingAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get settingAll;

  /// No description provided for @settingCrypto.
  ///
  /// In en, this message translates to:
  /// **'Cryptocurrencies'**
  String get settingCrypto;

  /// No description provided for @settingStocks.
  ///
  /// In en, this message translates to:
  /// **'Stocks / ETFs'**
  String get settingStocks;

  /// No description provided for @settingProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingProvider;

  /// No description provided for @settingAllProviders.
  ///
  /// In en, this message translates to:
  /// **'All providers'**
  String get settingAllProviders;

  /// No description provided for @settingYahoo.
  ///
  /// In en, this message translates to:
  /// **'Yahoo Finance'**
  String get settingYahoo;

  /// No description provided for @settingAddSymbol.
  ///
  /// In en, this message translates to:
  /// **'Add symbol'**
  String get settingAddSymbol;

  /// No description provided for @settingUpdatingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Updating catalog'**
  String get settingUpdatingCatalog;

  /// No description provided for @settingRefreshCatalog.
  ///
  /// In en, this message translates to:
  /// **'Refresh catalog'**
  String get settingRefreshCatalog;

  /// No description provided for @settingSymbolNotFound.
  ///
  /// In en, this message translates to:
  /// **'Symbol not found. Use “Add symbol” to add it manually.'**
  String get settingSymbolNotFound;

  /// No description provided for @settingPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get settingPreviousPage;

  /// No description provided for @settingNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get settingNextPage;

  /// No description provided for @settingAddFromCatalog.
  ///
  /// In en, this message translates to:
  /// **'Add instruments from the catalog below.'**
  String get settingAddFromCatalog;

  /// No description provided for @settingDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get settingDragToReorder;

  /// No description provided for @settingCatalogFailed.
  ///
  /// In en, this message translates to:
  /// **'The catalog could not be updated. Try again later.'**
  String get settingCatalogFailed;

  /// No description provided for @settingImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Load the watchlist and compatible layout into this draft. Save to apply.'**
  String get settingImportDescription;

  /// No description provided for @settingLegacyPath.
  ///
  /// In en, this message translates to:
  /// **'Legacy configuration path'**
  String get settingLegacyPath;

  /// No description provided for @settingLegacyPathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the full path to the legacy crypto_config.json file'**
  String get settingLegacyPathHint;

  /// No description provided for @settingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingCancel;

  /// No description provided for @settingRead.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get settingRead;

  /// No description provided for @settingCustomContent.
  ///
  /// In en, this message translates to:
  /// **'Custom content'**
  String get settingCustomContent;

  /// No description provided for @settingCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to an API and choose the fields to display.'**
  String get settingCustomDescription;

  /// No description provided for @settingAddApi.
  ///
  /// In en, this message translates to:
  /// **'Add custom API'**
  String get settingAddApi;

  /// No description provided for @settingThreeSteps.
  ///
  /// In en, this message translates to:
  /// **'Add an API in three steps'**
  String get settingThreeSteps;

  /// No description provided for @settingApiSecurity.
  ///
  /// In en, this message translates to:
  /// **'Supports public APIs and keys in request headers. Keys are stored in system-protected storage.'**
  String get settingApiSecurity;

  /// No description provided for @settingEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get settingEdit;

  /// No description provided for @settingRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingRemove;

  /// No description provided for @settingEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settingEnabled;

  /// No description provided for @settingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get settingDisabled;

  /// No description provided for @settingLayout.
  ///
  /// In en, this message translates to:
  /// **'Display layout'**
  String get settingLayout;

  /// No description provided for @settingLayoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Combine quote fields and text to create your own layout.'**
  String get settingLayoutDescription;

  /// No description provided for @settingDefaultRows.
  ///
  /// In en, this message translates to:
  /// **'Show default quotes'**
  String get settingDefaultRows;

  /// No description provided for @settingDefaultRowsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show names, prices, units, and changes for your watchlist. Custom rows remain when this is off.'**
  String get settingDefaultRowsDescription;

  /// No description provided for @settingAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add custom row'**
  String get settingAddRow;

  /// No description provided for @settingAddTemplate.
  ///
  /// In en, this message translates to:
  /// **'Add template'**
  String get settingAddTemplate;

  /// No description provided for @settingDefaultRowsKept.
  ///
  /// In en, this message translates to:
  /// **'Default quotes will remain visible alongside custom rows.'**
  String get settingDefaultRowsKept;

  /// No description provided for @settingMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get settingMoveUp;

  /// No description provided for @settingMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get settingMoveDown;

  /// No description provided for @settingDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingDelete;

  /// No description provided for @settingAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingAppearance;

  /// No description provided for @settingAppearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Language, themes, panel transparency, fonts, and title.'**
  String get settingAppearanceDescription;

  /// No description provided for @settingOpacity.
  ///
  /// In en, this message translates to:
  /// **'Panel transparency'**
  String get settingOpacity;

  /// No description provided for @settingTextFont.
  ///
  /// In en, this message translates to:
  /// **'Text font'**
  String get settingTextFont;

  /// No description provided for @settingChooseFont.
  ///
  /// In en, this message translates to:
  /// **'Choose system font'**
  String get settingChooseFont;

  /// No description provided for @settingNumberFont.
  ///
  /// In en, this message translates to:
  /// **'Number font'**
  String get settingNumberFont;

  /// No description provided for @settingFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingFontSize;

  /// No description provided for @settingRowSpacing.
  ///
  /// In en, this message translates to:
  /// **'Row spacing'**
  String get settingRowSpacing;

  /// No description provided for @settingFontPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: Bitcoin · Price & change'**
  String get settingFontPreview;

  /// No description provided for @settingWindow.
  ///
  /// In en, this message translates to:
  /// **'Window & tray'**
  String get settingWindow;

  /// No description provided for @settingWindowDescription.
  ///
  /// In en, this message translates to:
  /// **'Always on top, movement, and system tray.'**
  String get settingWindowDescription;

  /// No description provided for @settingAlwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Keep above other windows'**
  String get settingAlwaysOnTop;

  /// No description provided for @settingHidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide panel'**
  String get settingHidePanel;

  /// No description provided for @settingHideDescription.
  ///
  /// In en, this message translates to:
  /// **'Double-click the panel background or title to hide it to the system tray.'**
  String get settingHideDescription;

  /// No description provided for @settingRestorePanel.
  ///
  /// In en, this message translates to:
  /// **'Restore from tray'**
  String get settingRestorePanel;

  /// No description provided for @settingRestoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Click the tray icon to restore the panel above other windows.'**
  String get settingRestoreDescription;

  /// No description provided for @settingIconChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get settingIconChart;

  /// No description provided for @settingIconBitcoin.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get settingIconBitcoin;

  /// No description provided for @settingIconStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get settingIconStar;

  /// No description provided for @settingIconBolt.
  ///
  /// In en, this message translates to:
  /// **'Lightning'**
  String get settingIconBolt;

  /// No description provided for @settingIconHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get settingIconHeart;

  /// No description provided for @settingTitlePreview.
  ///
  /// In en, this message translates to:
  /// **'Title preview'**
  String get settingTitlePreview;

  /// No description provided for @settingIconPreview.
  ///
  /// In en, this message translates to:
  /// **'Icon preview'**
  String get settingIconPreview;

  /// No description provided for @settingShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Show title'**
  String get settingShowTitle;

  /// No description provided for @settingTitleName.
  ///
  /// In en, this message translates to:
  /// **'Title text'**
  String get settingTitleName;

  /// No description provided for @settingShowIcon.
  ///
  /// In en, this message translates to:
  /// **'Show title icon'**
  String get settingShowIcon;

  /// No description provided for @settingIconStyle.
  ///
  /// In en, this message translates to:
  /// **'Icon style'**
  String get settingIconStyle;

  /// No description provided for @settingCustomEmoji.
  ///
  /// In en, this message translates to:
  /// **'Custom emoji'**
  String get settingCustomEmoji;

  /// No description provided for @settingEmojiInput.
  ///
  /// In en, this message translates to:
  /// **'Enter an emoji or character'**
  String get settingEmojiInput;

  /// No description provided for @settingEmojiHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 🌙'**
  String get settingEmojiHint;

  /// No description provided for @settingImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This image cannot be displayed. Choose another image.'**
  String get settingImageUnavailable;

  /// No description provided for @settingChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose icon image'**
  String get settingChooseImage;

  /// No description provided for @settingClearImage.
  ///
  /// In en, this message translates to:
  /// **'Clear icon image'**
  String get settingClearImage;

  /// No description provided for @settingImageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an image up to 1 MB. It will take priority over the selected icon.'**
  String get settingImageDescription;

  /// No description provided for @settingImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get settingImages;

  /// No description provided for @settingImageImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The image could not be imported. Choose another image.'**
  String get settingImageImportFailed;

  /// No description provided for @settingUnitLabels.
  ///
  /// In en, this message translates to:
  /// **'Unit labels'**
  String get settingUnitLabels;

  /// No description provided for @settingUnitLabelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose full names, short labels, or your own labels'**
  String get settingUnitLabelsDescription;

  /// No description provided for @settingFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get settingFull;

  /// No description provided for @settingCompact.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get settingCompact;

  /// No description provided for @settingCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingCustom;

  /// No description provided for @settingDisplayCurrency.
  ///
  /// In en, this message translates to:
  /// **'Quote display currency'**
  String get settingDisplayCurrency;

  /// No description provided for @settingCurrencyDescription.
  ///
  /// In en, this message translates to:
  /// **'Convert prices using available exchange rates'**
  String get settingCurrencyDescription;

  /// No description provided for @settingOriginalCurrency.
  ///
  /// In en, this message translates to:
  /// **'Original currency'**
  String get settingOriginalCurrency;

  /// No description provided for @settingConversionDescription.
  ///
  /// In en, this message translates to:
  /// **'Prices use available exchange rates. If a rate is unavailable, the original currency is kept with a notice. Use custom multipliers for other units.'**
  String get settingConversionDescription;

  /// No description provided for @settingDeleteUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete unit label'**
  String get settingDeleteUnitLabel;

  /// No description provided for @settingAddUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Add unit label'**
  String get settingAddUnitLabel;

  /// No description provided for @settingDeleteUnitRule.
  ///
  /// In en, this message translates to:
  /// **'Delete multiplier rule'**
  String get settingDeleteUnitRule;

  /// No description provided for @settingAddUnitRule.
  ///
  /// In en, this message translates to:
  /// **'Add multiplier rule'**
  String get settingAddUnitRule;

  /// No description provided for @settingCustomUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom unit label'**
  String get settingCustomUnitLabel;

  /// No description provided for @settingSourceUnit.
  ///
  /// In en, this message translates to:
  /// **'Source unit'**
  String get settingSourceUnit;

  /// No description provided for @settingUsdtHint.
  ///
  /// In en, this message translates to:
  /// **'For example, USDT'**
  String get settingUsdtHint;

  /// No description provided for @settingDisplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Display label'**
  String get settingDisplayLabel;

  /// No description provided for @settingUHint.
  ///
  /// In en, this message translates to:
  /// **'For example, U'**
  String get settingUHint;

  /// No description provided for @settingUnitLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a source unit and a display label.'**
  String get settingUnitLabelRequired;

  /// No description provided for @settingSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save label'**
  String get settingSaveLabel;

  /// No description provided for @settingCustomConversion.
  ///
  /// In en, this message translates to:
  /// **'Custom conversion'**
  String get settingCustomConversion;

  /// No description provided for @settingOunceHint.
  ///
  /// In en, this message translates to:
  /// **'For example, oz'**
  String get settingOunceHint;

  /// No description provided for @settingTargetUnit.
  ///
  /// In en, this message translates to:
  /// **'Target unit'**
  String get settingTargetUnit;

  /// No description provided for @settingGramHint.
  ///
  /// In en, this message translates to:
  /// **'For example, g'**
  String get settingGramHint;

  /// No description provided for @settingMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Multiplier'**
  String get settingMultiplier;

  /// No description provided for @settingMultiplierHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 28.3495'**
  String get settingMultiplierHint;

  /// No description provided for @settingUnitRuleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter both units and a valid multiplier greater than 0.'**
  String get settingUnitRuleRequired;

  /// No description provided for @settingSaveRule.
  ///
  /// In en, this message translates to:
  /// **'Save rule'**
  String get settingSaveRule;

  /// No description provided for @settingFontLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'This font could not be loaded. Choose another font.'**
  String get settingFontLoadFailed;

  /// No description provided for @settingInvalidSymbol.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid symbol.'**
  String get settingInvalidSymbol;

  /// No description provided for @settingAddSymbolDialog.
  ///
  /// In en, this message translates to:
  /// **'Add instrument symbol'**
  String get settingAddSymbolDialog;

  /// No description provided for @settingYahooMarkets.
  ///
  /// In en, this message translates to:
  /// **'Yahoo · US / Chinese stocks'**
  String get settingYahooMarkets;

  /// No description provided for @settingSymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get settingSymbol;

  /// No description provided for @settingYahooHint.
  ///
  /// In en, this message translates to:
  /// **'AAPL, 600519.SS, or 600519'**
  String get settingYahooHint;

  /// No description provided for @settingOptionalName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get settingOptionalName;

  /// No description provided for @settingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get settingAdd;

  /// No description provided for @settingSearchFonts.
  ///
  /// In en, this message translates to:
  /// **'Search fonts'**
  String get settingSearchFonts;

  /// No description provided for @settingNoFonts.
  ///
  /// In en, this message translates to:
  /// **'No matching fonts'**
  String get settingNoFonts;

  /// No description provided for @settingFontUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This font could not be loaded. Choose another font.'**
  String get settingFontUnavailable;

  /// No description provided for @settingFontSample.
  ///
  /// In en, this message translates to:
  /// **'Price 83,342.30 · AaBb 123'**
  String get settingFontSample;

  /// No description provided for @settingApiSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Paste the API URL\n2. Select “Read response fields”\n3. Choose fields, name them, and set their units'**
  String get settingApiSteps;

  /// No description provided for @settingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String settingSaveFailed(String error);

  /// No description provided for @settingSearchCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String settingSearchCount(int count);

  /// No description provided for @settingSettingsFile.
  ///
  /// In en, this message translates to:
  /// **'Settings file: {path}'**
  String settingSettingsFile(String path);

  /// No description provided for @settingCatalogCounts.
  ///
  /// In en, this message translates to:
  /// **'{selected} selected · {total} in catalog · {matched} matches'**
  String settingCatalogCounts(int selected, int total, int matched);

  /// No description provided for @settingCatalogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The {providers} catalog has not updated. Existing instruments are still available.'**
  String settingCatalogUnavailable(String providers);

  /// No description provided for @settingPageCount.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total} · {size} per page'**
  String settingPageCount(int page, int total, int size);

  /// No description provided for @settingWatchlistCount.
  ///
  /// In en, this message translates to:
  /// **'Watchlist · {count}'**
  String settingWatchlistCount(int count);

  /// No description provided for @settingDragAsset.
  ///
  /// In en, this message translates to:
  /// **'Drag {name} to reorder'**
  String settingDragAsset(String name);

  /// No description provided for @settingMoveAssetUp.
  ///
  /// In en, this message translates to:
  /// **'Move {name} up'**
  String settingMoveAssetUp(String name);

  /// No description provided for @settingMoveAssetDown.
  ///
  /// In en, this message translates to:
  /// **'Move {name} down'**
  String settingMoveAssetDown(String name);

  /// No description provided for @settingUnfollowAsset.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from watchlist'**
  String settingUnfollowAsset(String name);

  /// No description provided for @settingImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String settingImportFailed(String error);

  /// No description provided for @settingSourceSummary.
  ///
  /// In en, this message translates to:
  /// **'{status} · Refresh every {seconds}s · {count} display fields'**
  String settingSourceSummary(String status, int seconds, int count);

  /// No description provided for @settingRowNumber.
  ///
  /// In en, this message translates to:
  /// **'Row {number}'**
  String settingRowNumber(int number);

  /// No description provided for @settingMultiplierSummary.
  ///
  /// In en, this message translates to:
  /// **'Value × {multiplier}'**
  String settingMultiplierSummary(double multiplier);

  /// No description provided for @settingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingLanguage;

  /// No description provided for @settingLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingLanguageSystem;

  /// No description provided for @settingCatalogAssets.
  ///
  /// In en, this message translates to:
  /// **'Choose instruments'**
  String get settingCatalogAssets;

  /// No description provided for @settingCatalogOrder.
  ///
  /// In en, this message translates to:
  /// **'Watchlist order'**
  String get settingCatalogOrder;

  /// No description provided for @settingCatalogApi.
  ///
  /// In en, this message translates to:
  /// **'Custom APIs'**
  String get settingCatalogApi;

  /// No description provided for @settingCatalogRows.
  ///
  /// In en, this message translates to:
  /// **'Custom rows & templates'**
  String get settingCatalogRows;

  /// No description provided for @settingCatalogFonts.
  ///
  /// In en, this message translates to:
  /// **'Text & number fonts'**
  String get settingCatalogFonts;

  /// No description provided for @settingCatalogSpacing.
  ///
  /// In en, this message translates to:
  /// **'Font size & row spacing'**
  String get settingCatalogSpacing;

  /// No description provided for @settingCatalogThemes.
  ///
  /// In en, this message translates to:
  /// **'Light & dark themes'**
  String get settingCatalogThemes;

  /// No description provided for @settingCatalogHeader.
  ///
  /// In en, this message translates to:
  /// **'Title & icon'**
  String get settingCatalogHeader;

  /// No description provided for @settingCatalogUnits.
  ///
  /// In en, this message translates to:
  /// **'Units & display currency'**
  String get settingCatalogUnits;

  /// No description provided for @settingCatalogWindow.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get settingCatalogWindow;

  /// No description provided for @settingCatalogTray.
  ///
  /// In en, this message translates to:
  /// **'Hide & restore from tray'**
  String get settingCatalogTray;

  /// No description provided for @theme120Saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get theme120Saturation;

  /// No description provided for @theme120Spectrum.
  ///
  /// In en, this message translates to:
  /// **'Saturation and brightness'**
  String get theme120Spectrum;

  /// No description provided for @theme120SpectrumHint.
  ///
  /// In en, this message translates to:
  /// **'Use arrow keys to adjust saturation and brightness. Hold Shift for larger steps.'**
  String get theme120SpectrumHint;

  /// No description provided for @theme120InvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Enter six hexadecimal digits.'**
  String get theme120InvalidHex;

  /// No description provided for @theme120InvalidRgb.
  ///
  /// In en, this message translates to:
  /// **'Use a number from 0 to 255.'**
  String get theme120InvalidRgb;

  /// No description provided for @theme120ColorValue.
  ///
  /// In en, this message translates to:
  /// **'Selected color'**
  String get theme120ColorValue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
