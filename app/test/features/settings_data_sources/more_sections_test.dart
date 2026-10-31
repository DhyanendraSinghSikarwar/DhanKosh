import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/activity_log/presentation/activity_tile.dart';
import 'package:hisaab/features/alerts_reminders/presentation/alerts_tile.dart';
import 'package:hisaab/features/backup_export/presentation/backup_tile.dart';
import 'package:hisaab/features/categorization/presentation/rules_tile.dart';
import 'package:hisaab/features/diagnostic_log/presentation/diagnostic_log_tile.dart';
import 'package:hisaab/features/forex_rates/presentation/forex_tile.dart';
import 'package:hisaab/features/loans/presentation/loans_tile.dart';
import 'package:hisaab/features/localization/presentation/language_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/news_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/support_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/updates_tile.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/recurring_transactions/presentation/bills_tile.dart';
import 'package:hisaab/features/savings_goals/presentation/goals_tile.dart';
import 'package:hisaab/features/security_privacy/presentation/security_tile.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_data_sources_screen.dart';
import 'package:hisaab/features/statement_import/presentation/statements_tile.dart';
import 'package:hisaab/features/tax_centre/presentation/tax_tile.dart';
import 'package:hisaab/features/theming_customisation/presentation/customise_tile.dart';

import '../../support/pipeline_fakes.dart';

void main() {
  late PipelineHarness h;
  late ProviderContainer c;

  Future<void> pump(WidgetTester t) async {
    h = PipelineHarness(permission: FakePermission(granted: true));
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 8000);
    addTearDown(t.view.reset);
    c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: SettingsDataSourcesScreen(
            statementsTile: StatementsTile(),
            billsTile: BillsTile(),
            goalsTile: GoalsTile(),
            loansTile: LoansTile(),
            alertsTile: AlertsTile(),
            forexTile: ForexTile(),
            backupTile: BackupTile(),
            taxTile: TaxTile(),
            rulesTile: RulesTile(),
            securityTile: SecurityTile(),
            activityTile: ActivityTile(),
            newsTile: NewsTile(),
            supportTile: SupportTile(upiId: 'dummy@upi'),
            updatesTile: UpdatesTile(),
            diagnosticLogTile: DiagnosticLogTile(),
            customiseTile: CustomiseTile(),
            languageTile: LanguageTile(),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
  }

  tearDown(() => h.dispose());

  // FR-26-32
  testWidgets('every option sits in a section', (t) async {
    await pump(t);
    for (final s in [
      'Book and accounts',
      'Capture',
      'Money tools',
      'Alerts and activity',
      'Appearance',
      'Privacy and security',
      'Data',
      'About',
    ]) {
      expect(find.byKey(Key('section-$s')), findsOneWidget, reason: s);
    }
    for (final k in [
      'profile-tile',
      'book-row',
      'accounts-row',
      'senders-tile',
      'email-tile',
      'statements-tile',
      'bills-tile',
      'goals-tile',
      'loans-tile',
      'tax-tile',
      'rules-tile',
      'forex-tile',
      'news-tile',
      'alerts-tile',
      'activity-tile',
      'diagnostic-log-tile',
      'customise-tile',
      'language-tile',
      'security-tile',
      'hide-amounts',
      'backup-tile',
      'add-sample',
      'clear-all',
      'support-tile',
      'updates-tile',
      'scan-now',
      'paste-body',
    ]) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
  });

  // FR-26-33
  testWidgets('book dropdown changes the global book', (t) async {
    await pump(t);
    expect(c.read(bookProvider), Book.all);
    await t.tap(find.byKey(const Key('book-dropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('Business').last);
    await t.pumpAndSettle();
    expect(c.read(bookProvider), Book.business);
  });
}
