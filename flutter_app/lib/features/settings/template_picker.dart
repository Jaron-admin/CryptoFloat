import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/l10n.dart';
import 'fluent_controls.dart';
import '../../domain/template_presets.dart';

Future<AppConfig?> showTemplatePicker(
  BuildContext context, {
  required AppConfig config,
}) => f.showDialog<AppConfig>(
  context: context,
  builder: (_) => _TemplateDialog(config: config),
);

Map<TemplateKind, String> _titles(AppLocalizations l10n) => {
  TemplateKind.weather: l10n.editTemplateWeather,
  TemplateKind.exchangeRates: l10n.editTemplateRates,
  TemplateKind.github: l10n.editTemplateGithub,
  TemplateKind.marketBar: l10n.editTemplateMarket,
  TemplateKind.reminder: l10n.editTemplateReminder,
};
Map<TemplateKind, String> _details(AppLocalizations l10n) => {
  TemplateKind.weather: l10n.editTemplateWeatherHelp,
  TemplateKind.exchangeRates: l10n.editTemplateRatesHelp,
  TemplateKind.github: l10n.editTemplateGithubHelp,
  TemplateKind.marketBar: l10n.editTemplateMarketHelp,
  TemplateKind.reminder: l10n.editTemplateReminderHelp,
};

TemplateStrings _templateStrings(AppLocalizations l10n) => TemplateStrings(
  cityLabels: {
    '北京': l10n.editCityBeijing,
    '上海': l10n.editCityShanghai,
    '广州': l10n.editCityGuangzhou,
    '深圳': l10n.editCityShenzhen,
    '杭州': l10n.editCityHangzhou,
    '成都': l10n.editCityChengdu,
    '武汉': l10n.editCityWuhan,
    '西安': l10n.editCityXian,
  },
  weatherName: l10n.editTemplateWeatherName,
  invalidCity: l10n.editTemplateCityInvalid,
  temperature: l10n.editTemplateTemperature,
  feelsLike: l10n.editTemplateFeelsLike,
  humidity: l10n.editTemplateHumidity,
  usdRates: l10n.editTemplateUsdRates,
  usdCny: l10n.editTemplateUsdCny,
  usdEur: l10n.editTemplateUsdEur,
  usdUsdt: l10n.editTemplateUsdUsdt,
  referenceRates: l10n.editTemplateRates,
  invalidRepository: l10n.editTemplateRepoInvalid,
  openIssues: l10n.editTemplateOpenIssues,
  open: l10n.editTemplateOpen,
  emptyWatchlist: l10n.editTemplateMarketEmpty,
  emptyText: l10n.editTemplateTextEmpty,
);

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.config});
  final AppConfig config;
  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  TemplateKind _kind = TemplateKind.weather;
  String _city = '北京';
  String? _error;
  final _owner = TextEditingController(text: 'flutter');
  final _repo = TextEditingController(text: 'flutter');
  final _text = TextEditingController();
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _text.text = context.l10n.editTemplateDefaultReminder;
  }

  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _text.dispose();
    super.dispose();
  }

  void _add() {
    try {
      final draft = appendTemplate(
        widget.config,
        _kind,
        city: _city,
        owner: _owner.text,
        repository: _repo.text,
        text: _text.text,
        strings: _templateStrings(context.l10n),
      );
      Navigator.pop(context, draft);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => FDialog(
    child: SizedBox(
      width: 560,
      height: max(160, min(480, MediaQuery.sizeOf(context).height - 48)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.editTemplateAdd,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                FIconButton(
                  tooltip: context.l10n.editTemplateClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kind in TemplateKind.values)
                        FChoiceChip(
                          label: Text(_titles(context.l10n)[kind]!),
                          selected: kind == _kind,
                          onSelected: (_) => setState(() {
                            _kind = kind;
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _details(context.l10n)[_kind]!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_kind == TemplateKind.weather)
                    FDropdown<String>(
                      initialValue: _city,
                      decoration: InputDecoration(
                        labelText: context.l10n.editCity,
                      ),
                      items: [
                        for (final city in weatherCities.keys)
                          FDropdownItem(
                            value: city,
                            child: Text(
                              _templateStrings(context.l10n).cityLabel(city),
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _city = value!),
                    ),
                  if (_kind == TemplateKind.github) ...[
                    FTextField(
                      controller: _owner,
                      decoration: InputDecoration(
                        labelText: context.l10n.editRepoOwner,
                        hintText: context.l10n.editRepoOwnerHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FTextField(
                      controller: _repo,
                      decoration: InputDecoration(
                        labelText: context.l10n.editRepoName,
                        hintText: context.l10n.editRepoNameHint,
                      ),
                    ),
                  ],
                  if (_kind == TemplateKind.reminder)
                    FTextField(
                      controller: _text,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.l10n.editDisplayText,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const f.Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FTextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.editCancel),
                ),
                const SizedBox(width: 8),
                FFilledButton(
                  onPressed: _add,
                  child: Text(context.l10n.editAddToDisplay),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
