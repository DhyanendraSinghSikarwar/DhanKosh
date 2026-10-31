import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/home_card_marks_provider.dart';
import 'package:hisaab/app/di/sip_providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/recurring_transactions/domain/bills_view.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/features/recurring_transactions/presentation/bills_calendar.dart';
import 'package:hisaab/features/recurring_transactions/presentation/recurring_sheet.dart';
import 'package:hisaab/features/recurring_transactions/presentation/sip_section.dart';
import 'package:hisaab/features/recurring_transactions/presentation/sip_setup_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Bills & insurance: summary, month calendar and the list of regular
/// payments (FR-12-03, 04, 06, 09, 10). Route `/bills`.
class RecurringTransactionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RecurringTransactionsScreen({this.extraSection, super.key});

  /// Optional section composed by the router under the calendar, for the
  /// shown month and selected day (card dues with Mark paid, FR-12-09).
  final Widget Function(DateTime month, DateTime? day)? extraSection;

  @override
  ConsumerState<RecurringTransactionsScreen> createState() => _State();
}

class _State extends ConsumerState<RecurringTransactionsScreen> {
  late DateTime _month;
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    final t = Ist.dateOf(DateTime.now().millisecondsSinceEpoch);
    _month = DateTime.utc(t.year, t.month);
  }

  Future<void> _sheet([Recurring? r]) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => RecurringSheet(source: r),
      );

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(billsProvider);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final cardDays = ref.watch(cardDueDatesProvider);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('bills-back'),
            onPressed: () => context.pop(),
            child: const Text('‹ Back'),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Bills and recurring',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            key: const Key('sip-add'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const SipSetupSheet(),
            ),
            child: const Text('Add SIP'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('bills-add'),
        heroTag: null,
        tooltip: 'Add regular payment',
        onPressed: _sheet,
        child: const Icon(Icons.add),
      ),
      body: bills.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load bills')),
        data: (items) {
          if (items.isEmpty && (ref.watch(sipsProvider).value ?? []).isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat_outlined,
              title: 'Nothing found yet',
              hint: 'Repeats show after two months. Or add one.',
            );
          }
          final today = Ist.dateOf(DateTime.now().millisecondsSinceEpoch);
          final events = _events(items);
          final total = events
              .where((e) => !e.r.income)
              .fold<int>(0, (s, e) => s + e.r.amountMinor);
          final day = _day;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
            children: [
              BillsCalendar(
                items: items,
                month: _month,
                selected: _day,
                cardDays: cardDays,
                onMonth: (d) => setState(() {
                  _month = DateTime.utc(_month.year, _month.month + d);
                  _day = null;
                }),
                onSelect: (d) => setState(() => _day = _day == d ? null : d),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                child: Row(
                  children: [
                    Text(
                      day == null
                          ? 'All of ${monthName(_month.month)}'
                          : '${day.day} ${monthName(day.month).substring(0, 3)}',
                      key: const Key('bills-list-title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (day == null)
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Total '),
                            TextSpan(
                              text: formatAmount(
                                total,
                                masked: masked,
                                paise: false,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        style: MockText.small(context),
                      )
                    else
                      MoreLink(
                        'Show all',
                        key: const Key('bills-show-all'),
                        onTap: () => setState(() => _day = null),
                      ),
                  ],
                ),
              ),
              if (widget.extraSection != null)
                widget.extraSection!(_month, _day),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      Text('Nothing on this day', key: Key('bills-day-empty')),
                )
              else
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, e) in events.indexed)
                        _Row(
                          r: e.r,
                          date: e.date,
                          today: today,
                          masked: masked,
                          divider: i < events.length - 1,
                          onTap: () => e.r.loanKey != null
                              ? context.push(
                                  '/loans/${Uri.encodeComponent(e.r.loanKey!)}',
                                )
                              : _sheet(e.r),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (_day == null) const SipSection(),
              if (_day == null) const SizedBox(height: 12),
              _Summary(items: items, today: today, masked: masked),
            ],
          );
        },
      ),
    );
  }

  /// Recurring items falling in the shown month (or on the selected day),
  /// by date.
  List<({DateTime date, Recurring r})> _events(List<Recurring> items) {
    final len = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final out = <({DateTime date, Recurring r})>[];
    for (var d = 1; d <= len; d++) {
      final date = DateTime.utc(_month.year, _month.month, d);
      if (_day != null && _day != date) continue;
      for (final r in items) {
        if (RecurringDetector.occursOn(r, date)) out.add((date: date, r: r));
      }
    }
    return out;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.items,
    required this.today,
    required this.masked,
  });

  final List<Recurring> items;
  final DateTime today;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int minor, Key k) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MockText.small(context)),
              Text(
                formatAmount(minor, masked: masked, paise: false),
                key: k,
                style: MockText.mid(context),
              ),
            ],
          ),
        );
    return AppCard(
      child: Row(
        children: [
          cell(
            'Due in 30 days',
            BillsView.dueIn30(items, today),
            const Key('sum-30'),
          ),
          cell(
            'Every month',
            BillsView.everyMonth(items),
            const Key('sum-month'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.r,
    required this.date,
    required this.today,
    required this.masked,
    required this.divider,
    required this.onTap,
  });

  final Recurring r;
  final DateTime date;
  final DateTime today;
  final bool masked;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = date.difference(today).inDays;
    final paid = date == r.nextDue
        ? BillsView.paid(r, today)
        : days < 0 && r.lastPaid != null && !r.lastPaid!.isBefore(date);
    final tag = r.loanKey != null
        ? 'EMI'
        : r.manualId == null
            ? 'Detected'
            : r.yearly
                ? 'Yearly'
                : null;
    final when = '${monthName(date.month).substring(0, 3)} ${date.day}';
    return InkWell(
      key: Key('bill-${r.name}'),
      onTap: onTap,
      child: IconAmountRow(
        divider: divider,
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BillsCalendar.markColor(context, r),
            ),
          ),
        ),
        title: r.name,
        subtitle: [
          if (paid) 'Paid' else 'Due',
          when,
          if (tag != null) tag,
        ].join(' · '),
        amount: formatAmount(r.amountMinor, masked: masked, paise: false),
        trailing: paid
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check, size: 16, color: scheme.primary),
              )
            : null,
      ),
    );
  }
}
