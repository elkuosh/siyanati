import 'package:flutter_test/flutter_test.dart';
import 'package:garage_log/utils.dart';

void main() {
  test('addMonths clamps to month end', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
  });

  test('parse Arabic digits', () {
    expect(parseInt('١٢٬٥٠٠'), 12500);
    expect(parseDouble('٣٫٥'), 3.5);
  });
}
