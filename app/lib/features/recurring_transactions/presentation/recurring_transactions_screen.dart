import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/recurring_transactions/domain/bills_view.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/features/recurring_transactions/presentation/bills_calendar.dart';
import 'package:hisaab/features/recurring_transactions/presentation/recurring_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Bills & insurance: summary, month calendar and the list of regular
/// payments (FR-12-03, 04, 06, 09, 10). Route `/bills`.
class RecurringTransactionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RecurringTransactionsScreen({super.key});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Bills & insurance')),
      floatingActionButton: FloatingActionButton(
        key: const Key('bills-add'),
        tooltip: 'Add regular payment',
        onPressed: _sheet,
        child: const Icon(Icons.add),
      ),
      body: bills.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load bills')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat_outlined,
              title: 'Nothing found yet',
              hint: 'Repeats show after two months. Or add one.',
            );
          }
          final today = Ist.dateOf(DateTime.now().millisecondsSinceEpoch);
          final shown = _day == null
              ? items
              : BillsView.onDay(items, _day!, RecurringDetector.occursOn);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Summary(items: items, today: today, masked: masked),
              const SizedBox(height: 12),
              AppCard(
                child: BillsCalendar(
                  items: items,
                  month: _month,
                  selected: _day,
                  onMonth: (d) => setState(() {
                    _month = DateTime.utc(_month.year, _month.month + d);
                    _day = null;
                  }),
                  onSelect: (d) => setState(() => _day = _day == d ? null : d),
                ),
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      Text('Nothing on this day', key: Key('bills-day-empty')),
                ),
              for (final r in shown)
                _Row(
                  r: r,
                  today: today,
                  masked: masked,
                  onTap: () => r.loanKey != null
                      ? context
                          .push('/loans/${Uri.encodeComponent(r.loanKey!)}')
                      : _sheet(r),
                ),
            ],
          );
        },
      ),
    );
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
    final text = Theme.of(context).textTheme;
    Widget cell(String label, int minor, Key k) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelMedium),
              Text(
                formatAmount(minor, masked: masked, paise: false),
                key: k,
                style: text.titleLarge,
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
    required this.today,
    required this.masked,
    required this.onTap,
  });

  final Recurring r;
  final DateTime today;
  final bool masked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = r.nextDue.difference(today).inDays;
    final due = days == 0
        ? 'Due today'
        : days == 1
            ? 'Due tomorrow'
            : 'Due in $days days';
    final paid = BillsView.paid(r, today);
    final tag = r.loanKey != null
        ? 'EMI'
        : r.manualId == null
            ? 'Detected'
            : r.yearly
                ? 'Yearly'
                : null;
    return ListTile(
      key: Key('bill-${r.name}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.circle,
        size: 12,
        color: BillsCalendar.markColor(context, r),
      ),
      title: Text(r.name),
      subtitle: Text(
        [
          if (paid) 'Paid' else due,
          '${r.nextDue.day}/${r.nextDue.month}/${r.nextDue.year}',
          if (tag != null) tag,
        ].join(' · '),
      ),
      trailing: Text(
        formatAmount(r.amountMinor, masked: masked, paise: false),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      onTap: onTap,
    );
  }
}
