import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/categorization/domain/brand_logos.dart';
import 'package:hisaab/shared/widgets/brand_logo.dart';

void main() {
  const cases = <String, String?>{
    'Myntra Designs Pvt Ltd': 'myntra',
    'AMAZON PAY INDIA': 'amazonpay',
    'Amazon Seller Services': 'amazon',
    'AMZN Marketplace': 'amazon',
    'Swiggy Instamart': 'instamart',
    'BUNDL TECHNOLOGIES': 'swiggy',
    'Ola Cabs': 'ola',
    'Coca Cola Stores': null,
    'Olam Agro': null,
    'Audible India': 'audible',
    'Google Pay': 'gpay',
    'Google One storage': 'google',
    'GOOGLE*YouTube Premium': 'youtube',
    'Seashell Resort': null,
    'Booking.com Hotel': 'booking',
    'Reliance Fresh': 'relianceretail',
    'Zoomcar India': 'zoomcar',
    'Prime Video': 'primevideo',
  };

  test('FR-09-32 merchant names map to the expected logo', () {
    cases.forEach(
      (name, key) => expect(BrandLogos.merchant(name), key, reason: name),
    );
    expect(BrandLogos.merchant(null), isNull);
  });

  test('FR-09-32 bank names map to logos', () {
    expect(BrandLogos.bank('HDFC Bank'), 'hdfc');
    expect(BrandLogos.bank('SBI Card'), 'sbicard');
    expect(BrandLogos.bank('State Bank of India'), 'sbi');
    expect(BrandLogos.bank('Test Bank'), isNull);
  });

  test('FR-09-32 every rule key has a bundled asset', () {
    final missing = [
      for (final k in BrandLogos.allKeys)
        if (!File(BrandLogos.assetPath(k)).existsSync()) k,
    ];
    expect(missing, isEmpty);
  });

  testWidgets('FR-09-32 BrandLogo falls back to a letter', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            BrandLogo(label: 'zed shop'),
            BrandLogo(label: 'x', logoKey: 'nope-missing'),
          ],
        ),
      ),
    );
    await t.pump();
    expect(find.text('Z'), findsOneWidget);
    expect(find.byKey(const Key('brand-letter')), findsWidgets);
  });
}
