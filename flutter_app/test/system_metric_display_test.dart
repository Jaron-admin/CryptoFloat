import 'package:cryptofloat/domain/system_metric.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid zero and unavailable samples have distinct display values', () {
    expect(
      formatSystemMetric(
        'cpu.usage',
        const MetricReading(0, '%', 'valid'),
      ).text,
      '0.0%',
    );
    expect(
      formatSystemMetric(
        'cpu.usage',
        const MetricReading(0, '%', 'unavailable'),
      ).text,
      '—',
    );
    expect(
      formatSystemMetric(
        'cpu.usage',
        const MetricReading(17, '%', 'warmingUp'),
      ).text,
      '—',
    );
  });
  test('throughput and capacity use consistent binary units', () {
    expect(
      formatSystemMetric(
        'network.download',
        const MetricReading(1536, 'B/s', 'valid'),
      ).text,
      '1.5 KiB/s',
    );
    expect(
      formatSystemMetric(
        'memory.used',
        const MetricReading(1610612736, 'B', 'valid'),
      ).text,
      '1.5 GiB',
    );
    expect(
      formatSystemMetric(
        'disk.read',
        const MetricReading(0, 'B/s', 'valid'),
      ).text,
      '0 B/s',
    );
  });
  test('invalid and negative telemetry never renders as a real value', () {
    expect(
      formatSystemMetric(
        'gpu.usage',
        MetricReading(double.nan, '%', 'valid'),
      ).text,
      '—',
    );
    expect(
      formatSystemMetric(
        'network.upload',
        const MetricReading(-1, 'B/s', 'valid'),
      ).text,
      '—',
    );
    expect(
      formatSystemMetric(
        'cpu.usage',
        const MetricReading(130, '%', 'valid'),
      ).text,
      '—',
    );
  });
}
