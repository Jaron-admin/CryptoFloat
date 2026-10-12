part of 'settings_page.dart';

class _AssetDialog extends StatefulWidget {
  const _AssetDialog();
  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  String _provider = 'OKX';
  final _symbol = TextEditingController();
  final _name = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _symbol.dispose();
    _name.dispose();
    super.dispose();
  }

  void _accept() {
    var symbol = _symbol.text.trim().toUpperCase();
    if (symbol.isEmpty || !RegExp(r'^[A-Z0-9.^=\-]{1,32}$').hasMatch(symbol)) {
      setState(() => _error = '请输入正确的行情代码。');
      return;
    }
    if (_provider == 'YAHOO' && RegExp(r'^\d{6}$').hasMatch(symbol)) {
      symbol = '$symbol.${symbol.startsWith('6') ? 'SS' : 'SZ'}';
    }
    final equity = _provider == 'YAHOO';
    final currency = inferCurrency(_provider, symbol);
    Navigator.pop(
      context,
      Asset(
        id: '$_provider:$symbol',
        provider: _provider,
        symbol: symbol,
        name: _name.text.trim().isEmpty ? symbol : _name.text.trim(),
        kind: equity ? MarketKind.equity : MarketKind.crypto,
        currency: currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FAlertDialog(
    title: const Text('添加行情代码'),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FDropdown<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: '数据源'),
            items: const [
              FDropdownItem(value: 'OKX', child: Text('OKX')),
              FDropdownItem(value: 'BINANCE', child: Text('Binance')),
              FDropdownItem(value: 'KUCOIN', child: Text('KuCoin')),
              FDropdownItem(value: 'YAHOO', child: Text('Yahoo · 美股 / A 股')),
            ],
            onChanged: (value) => setState(() => _provider = value!),
          ),
          const SizedBox(height: 14),
          FTextField(
            controller: _symbol,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '行情代码',
              hintText: _provider == 'YAHOO'
                  ? 'AAPL、600519.SS 或 600519'
                  : _provider == 'BINANCE'
                  ? 'BTCUSDT'
                  : 'BTC-USDT',
            ),
          ),
          const SizedBox(height: 14),
          FTextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '显示名称（可选）'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      FTextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FFilledButton(onPressed: _accept, child: const Text('添加')),
    ],
  );
}

class _FontDialog extends StatefulWidget {
  const _FontDialog({required this.fonts, required this.current});
  final List<String> fonts;
  final String current;
  @override
  State<_FontDialog> createState() => _FontDialogState();
}

class _FontDialogState extends State<_FontDialog> {
  String _search = '';
  final _loads = <String, Future<void>>{};
  @override
  Widget build(BuildContext context) {
    final fonts = widget.fonts
        .where((font) => font.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return FAlertDialog(
      title: const Text('选择系统字体'),
      content: SizedBox(
        width: 480,
        height: (MediaQuery.sizeOf(context).height - 220).clamp(160.0, 420.0),
        child: Column(
          children: [
            FTextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '搜索字体',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: fonts.isEmpty
                  ? const Center(child: Text('未找到匹配的字体'))
                  : ListView.builder(
                      itemCount: fonts.length,
                      itemBuilder: (context, index) => FutureBuilder<void>(
                        future: _loads.putIfAbsent(
                          fonts[index],
                          () => SystemFonts.ensureLoaded(fonts[index]),
                        ),
                        builder: (context, snapshot) => FListTile(
                          selected: fonts[index] == widget.current,
                          title: Text(
                            fonts[index],
                            style: TextStyle(
                              fontFamily: SystemFonts.family(fonts[index]),
                            ),
                          ),
                          subtitle: snapshot.hasError
                              ? Text(
                                  '字体无法加载，请选择其他字体',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                )
                              : Text(
                                  '价格 83,342.30 · AaBb 123',
                                  style: TextStyle(
                                    fontFamily: SystemFonts.family(
                                      fonts[index],
                                    ),
                                  ),
                                ),
                          trailing:
                              snapshot.connectionState == ConnectionState.done
                              ? null
                              : const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: f.ProgressRing(strokeWidth: 2),
                                ),
                          onTap:
                              snapshot.connectionState !=
                                      ConnectionState.done ||
                                  snapshot.hasError
                              ? null
                              : () => Navigator.pop(context, fonts[index]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FTextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
