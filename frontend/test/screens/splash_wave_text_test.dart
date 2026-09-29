import 'package:clausulazos/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _word = 'CLAUSULAZOS';
const _n = _word.length;

/// Phase at which the crest sits exactly on letter `index` (inverse of the crest position used by
/// `SplashWaveText.intensity`: it runs from 3 letters before the first to 3 after the last).
double _phaseAt(double index) => (index + 3) / (_n - 1 + 6);

void main() {
  group('SplashWaveText.intensity', () {
    test('peaks on the letter under the crest', () {
      for (var i = 0; i < _n; i++) {
        final phase = _phaseAt(i.toDouble());
        expect(SplashWaveText.intensity(i, _n, phase), closeTo(1, 1e-9));
        for (var j = 0; j < _n; j++) {
          if (j != i) {
            expect(SplashWaveText.intensity(j, _n, phase), lessThan(1));
          }
        }
      }
    });

    test('neighbours overlap, so it reads as one travelling wave', () {
      // Halfway between letters 4 and 5 both are lit, and so, more faintly, are 3 and 6.
      final phase = _phaseAt(4.5);
      final l4 = SplashWaveText.intensity(4, _n, phase);
      final l5 = SplashWaveText.intensity(5, _n, phase);
      expect(l4, closeTo(l5, 1e-9));
      expect(l4, greaterThan(0.8));
      expect(SplashWaveText.intensity(3, _n, phase), greaterThan(0.2));
      expect(SplashWaveText.intensity(6, _n, phase), greaterThan(0.2));
      // Letters far from the crest stay at rest.
      expect(SplashWaveText.intensity(0, _n, phase), lessThan(0.01));
      expect(SplashWaveText.intensity(10, _n, phase), lessThan(0.01));
    });

    test('moves left to right', () {
      double crestAt(double phase) {
        var best = 0;
        for (var i = 1; i < _n; i++) {
          if (SplashWaveText.intensity(i, _n, phase) >
              SplashWaveText.intensity(best, _n, phase)) {
            best = i;
          }
        }
        return best.toDouble();
      }

      var last = -1.0;
      for (var phase = 0.2; phase <= 0.8; phase += 0.05) {
        final crest = crestAt(phase);
        expect(crest, greaterThanOrEqualTo(last));
        last = crest;
      }
      expect(crestAt(0.2), lessThan(crestAt(0.8)));
    });

    test('loops seamlessly: every letter is at rest at both ends of a pass',
        () {
      for (var i = 0; i < _n; i++) {
        expect(SplashWaveText.intensity(i, _n, 0), lessThan(0.02));
        expect(SplashWaveText.intensity(i, _n, 1), lessThan(0.02));
      }
    });

    test('one pass lasts between 2.5 and 3.5 seconds', () {
      expect(SplashWaveText.cycle.inMilliseconds, inInclusiveRange(2500, 3500));
    });
  });

  testWidgets('renders every letter, lifting only those near the crest',
      (tester) async {
    const style = TextStyle(fontSize: 30, letterSpacing: 4);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SplashWaveText(
          text: _word,
          style: style,
          animation: AlwaysStoppedAnimation(_phaseAt(2)),
        ),
      ),
    ));

    final letters = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(letters.map((t) => t.data).join(), _word);

    // The letter under the crest (index 2, "A") is lifted and glowing; a far one ("S", last) is untouched.
    final lifted = tester
        .widgetList<Transform>(find.ancestor(
            of: find.text('A').first, matching: find.byType(Transform)))
        .first;
    expect(lifted.transform.getTranslation().y, lessThan(-2.5));
    expect(letters[2].style?.shadows, isNotEmpty);
    expect(letters.last.style?.shadows, isNull);
    expect(letters.last.style, style);
  });
}
