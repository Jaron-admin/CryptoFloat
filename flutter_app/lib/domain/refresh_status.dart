enum RefreshState { noSources, waiting, live, stale }

class RefreshStatus {
  const RefreshStatus({
    required this.state,
    this.lastUpdatedAt,
    this.intervalsSeconds = const [],
    this.staleSourceCount = 0,
    this.waitingSourceCount = 0,
  });

  final RefreshState state;
  final DateTime? lastUpdatedAt;
  final List<int> intervalsSeconds;
  final int staleSourceCount;
  final int waitingSourceCount;
  bool get isLive => state == RefreshState.live;
}

RefreshStatus calculateRefreshStatus({
  required DateTime now,
  required Map<String, int> sourceIntervals,
  required Map<String, DateTime> lastSuccessfulFetchAt,
}) {
  if (sourceIntervals.isEmpty) {
    return const RefreshStatus(state: RefreshState.noSources);
  }
  var stale = 0;
  var waiting = 0;
  DateTime? oldest;
  for (final entry in sourceIntervals.entries) {
    final success = lastSuccessfulFetchAt[entry.key];
    if (success == null ||
        success.millisecondsSinceEpoch <= 0 ||
        success.isAfter(now)) {
      waiting++;
      continue;
    }
    if (oldest == null || success.isBefore(oldest)) oldest = success;
    if (now.difference(success) > Duration(seconds: entry.value)) stale++;
  }
  final intervals = sourceIntervals.values.toSet().toList()..sort();
  return RefreshStatus(
    state: stale > 0
        ? RefreshState.stale
        : waiting > 0
        ? RefreshState.waiting
        : RefreshState.live,
    lastUpdatedAt: oldest,
    intervalsSeconds: List.unmodifiable(intervals),
    staleSourceCount: stale,
    waitingSourceCount: waiting,
  );
}
