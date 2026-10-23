import '../../domain/models.dart';
import '../../l10n/l10n.dart';
import 'ti_settings_schema.dart';

/// Declared appearance settings.
///
/// This is the whole page for the appearance section: labels, hints, defaults,
/// ranges and how each value is read from and written to [AppConfig]. No widget
/// code lives here - the view renders whatever this declares.
///
/// Blocks keep the three panels that are genuinely custom (theme picker, price
/// colour rules, header composer). They stay widgets, but they sit in the
/// declared order like everything else.
TiSettingsCatalog buildAppearanceCatalog(
  AppLocalizations l10n, {
  required bool floating,
}) {
  final zh = l10n.localeName.startsWith('zh');
  String t(String cn, String en) => zh ? cn : en;

  return TiSettingsCatalog(
    groups: [
      TiSettingGroup(
        id: 'general.language',
        section: TiSettingSection.general,
        title: t('语言', 'Language'),
        items: [
          TiSettingSpec.choice(
            key: 'general.language',
            label: t('界面语言', 'Language'),
            hint: t('跟随系统，或固定成某一种语言。', 'Follow the system or pin one language.'),
            defaultValue: 'system',
            options: [
              TiSettingOption('system', t('跟随系统', 'System')),
              const TiSettingOption('zh', '简体中文'),
              const TiSettingOption('en', 'English'),
            ],
            read: (config) => config.language,
            write: (config, value) => config.copyWith(language: value),
          ),
        ],
      ),
      TiSettingGroup(
        id: 'appearance.theme',
        section: TiSettingSection.appearance,
        title: t('主题', 'Theme'),
        description: t(
          '明暗模式与配色方案，可自己调一套存下来。',
          'Light or dark, plus any scheme you build yourself.',
        ),
        items: [
          const TiSettingBlock(
            id: 'appearance.theme-picker',
            title: 'Theme picker',
          ),
        ],
      ),
      TiSettingGroup(
        id: 'appearance.text',
        section: TiSettingSection.appearance,
        title: t('文字', 'Text'),
        description: t(
          '字号和行距对所有显示位置生效。',
          'Size and spacing apply to every display.',
        ),
        items: [
          TiSettingSpec.range(
            key: 'appearance.fontSize',
            label: t('字号', 'Font size'),
            hint: t('面板里所有文字一起缩放。', 'Scales every label in the panel.'),
            min: 10,
            max: 32,
            step: 1,
            unit: ' px',
            defaultValue: AppConfig.defaults.fontSize,
            read: (config) => config.fontSize,
            write: (config, value) => config.copyWith(fontSize: value),
          ),
          TiSettingSpec.range(
            key: 'appearance.rowSpacing',
            label: t('行距', 'Row spacing'),
            hint: t('行与行之间的空隙，0 会挤在一起。', 'Gap between rows. Zero stacks them tight.'),
            min: 0,
            max: 24,
            step: 1,
            unit: ' px',
            defaultValue: AppConfig.defaults.rowSpacing,
            read: (config) => config.rowSpacing,
            write: (config, value) => config.copyWith(rowSpacing: value),
          ),
          TiSettingSpec(
            key: 'appearance.fontFamily',
            type: TiSettingType.font,
            label: t('正文字体', 'Text font'),
            hint: t('标签和说明文字用的字体。', 'Used for labels and captions.'),
            level: TiSettingLevel.advanced,
            defaultValue: AppConfig.defaults.fontFamily,
            read: (config) => config.fontFamily,
            write: (config, value) =>
                config.copyWith(fontFamily: '${value ?? config.fontFamily}'),
          ),
          TiSettingSpec(
            key: 'appearance.numberFontFamily',
            type: TiSettingType.font,
            label: t('数字字体', 'Number font'),
            hint: t(
              '等宽字体能让价格跳动时不左右晃。',
              'A tabular font stops prices from jittering as digits change.',
            ),
            level: TiSettingLevel.advanced,
            defaultValue: AppConfig.defaults.numberFontFamily,
            read: (config) => config.numberFontFamily,
            write: (config, value) => config.copyWith(
              numberFontFamily: '${value ?? config.numberFontFamily}',
            ),
          ),
          const TiSettingBlock(
            id: 'appearance.font-preview',
            title: 'Font preview',
          ),
        ],
      ),
      TiSettingGroup(
        id: 'appearance.colors',
        section: TiSettingSection.appearance,
        title: t('涨跌颜色', 'Price colours'),
        description: t(
          '红涨绿跌或反过来，以及数值的着色方式。',
          'Red-up or red-down, and how values are tinted.',
        ),
        items: [
          const TiSettingBlock(
            id: 'appearance.price-colors',
            title: 'Price colours',
          ),
        ],
      ),
      if (floating)
        TiSettingGroup(
          id: 'appearance.window',
          section: TiSettingSection.appearance,
          title: t('悬浮窗外观', 'Panel look'),
          items: [
            TiSettingSpec.range(
              key: 'appearance.transparency',
              label: t('透明度', 'Transparency'),
              hint: t(
                '越高越透明，能看见背后的窗口。',
                'Higher means more see-through.',
              ),
              min: 0,
              max: 60,
              step: 1,
              unit: '%',
              defaultValue: (1 - AppConfig.defaults.opacity) * 100,
              read: (config) => (1 - config.opacity) * 100,
              write: (config, value) =>
                  config.copyWith(opacity: 1 - value / 100),
            ),
          ],
        ),
      if (floating)
        TiSettingGroup(
          id: 'appearance.header',
          section: TiSettingSection.appearance,
          title: t('页头', 'Header'),
          items: [
            const TiSettingBlock(id: 'appearance.header', title: 'Header'),
          ],
        ),
    ],
  );
}
