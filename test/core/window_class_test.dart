import 'package:flutter_test/flutter_test.dart';
import 'package:paper/core/window_class.dart';
import 'package:paper/theme/paper_tokens.dart';

void main() {
  test('without a previous class it matches the token resolver', () {
    for (final w in <double>[0, 599, 600, 839, 840, 1199, 1200, 1599, 1600]) {
      expect(resolveWindowClass(w), PaperWindowClass.of(w), reason: '$w');
    }
  });

  test('growing commits only 8dp past the boundary', () {
    const prev = PaperWindowClass.compact;
    expect(resolveWindowClass(600, previous: prev), PaperWindowClass.compact);
    expect(resolveWindowClass(607, previous: prev), PaperWindowClass.compact);
    expect(resolveWindowClass(608, previous: prev), PaperWindowClass.medium);
  });

  test('shrinking commits only 8dp past the boundary', () {
    const prev = PaperWindowClass.large;
    expect(resolveWindowClass(1199, previous: prev), PaperWindowClass.large);
    expect(resolveWindowClass(1192, previous: prev), PaperWindowClass.large);
    expect(resolveWindowClass(1191, previous: prev), PaperWindowClass.expanded);
  });

  test('large jumps skip classes', () {
    expect(
      resolveWindowClass(2000, previous: PaperWindowClass.compact),
      PaperWindowClass.extraLarge,
    );
    expect(
      resolveWindowClass(400, previous: PaperWindowClass.extraLarge),
      PaperWindowClass.compact,
    );
  });
}
