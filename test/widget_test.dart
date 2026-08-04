// Test minimal du thème de l'application.
import 'package:flutter_test/flutter_test.dart';

import 'package:benou_re/theme.dart';

void main() {
  test('Le thème utilise le fond sombre de la Loge', () {
    final theme = buildBrTheme();
    expect(theme.scaffoldBackgroundColor, BrColors.background);
  });
}
