import 'models.dart';

enum PriceTick { neutral, up, down }

/// Remembers the last successful price so coloring can ignore the 24h change.
class RefreshPriceMemory {
  const RefreshPriceMemory({
    Map<String, double> prices = const {},
    Map<String, PriceTick> ticks = const {},
    Map<String, Object> stamps = const {},
  }) : this._(prices, ticks, stamps);

  const RefreshPriceMemory._(this._prices, this._ticks, this._stamps);

  final Map<String, double> _prices;
  final Map<String, PriceTick> _ticks;
  final Map<String, Object> _stamps;

  PriceTick tickFor(String id) => _ticks[id] ?? PriceTick.neutral;
  double? baselineFor(String id) => _prices[id];

  RefreshPriceMemory observe({
    required String id,
    required DateTime updatedAt,
    required double? price,
    required bool successful,
    Object? sampleId,
  }) {
    if (!successful || price == null || !price.isFinite) {
      if (tickFor(id) == PriceTick.neutral) return this;
      return RefreshPriceMemory(
        prices: _prices,
        ticks: {..._ticks, id: PriceTick.neutral},
        stamps: _stamps,
      );
    }
    final stamp = sampleId ?? updatedAt.microsecondsSinceEpoch;
    if (_stamps[id] == stamp) return this;
    final previous = _prices[id];
    final tick = previous == null
        ? PriceTick.neutral
        : price > previous
        ? PriceTick.up
        : price < previous
        ? PriceTick.down
        : PriceTick.neutral;
    return RefreshPriceMemory(
      prices: {..._prices, id: price},
      ticks: {..._ticks, id: tick},
      stamps: {..._stamps, id: stamp},
    );
  }

  RefreshPriceMemory observeAll(Map<String, MarketQuote> quotes) {
    var next = this;
    for (final quote in quotes.values) {
      final price = quote.price;
      next = next.observe(
        id: quote.assetId,
        updatedAt: quote.updatedAt,
        price: price,
        successful:
            !quote.isFieldStale('price') && price != null && price.isFinite,
        // A provider may return the same market timestamp on consecutive
        // successful fetches. The service replaces its immutable quote after
        // each fetch and reuses that object for unrelated status notifications.
        sampleId: quote,
      );
    }
    return next._retain(quotes.keys.toSet());
  }

  RefreshPriceMemory _retain(Set<String> ids) {
    if (_prices.length == ids.length && _prices.keys.every(ids.contains)) {
      return this;
    }
    double? priceFor(String id) => _prices[id];
    return RefreshPriceMemory(
      prices: {
        for (final id in ids)
          if (priceFor(id) != null) id: priceFor(id)!,
      },
      ticks: {
        for (final id in ids)
          if (_ticks.containsKey(id)) id: _ticks[id]!,
      },
      stamps: {
        for (final id in ids)
          if (_stamps.containsKey(id)) id: _stamps[id]!,
      },
    );
  }
}
