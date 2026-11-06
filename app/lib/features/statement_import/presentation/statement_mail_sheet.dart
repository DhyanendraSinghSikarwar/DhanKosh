import 'package:flutter/material.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';

/// Whether [s] came from an email we kept something of (FR-05-30).
bool hasMail(Statement s) =>
    s.source == StatementSource.email &&
    ((s.subject?.trim().isNotEmpty ?? false) ||
        (s.emailText?.trim().isNotEmpty ?? false));

/// The email a statement arrived in: sender, time, subject and the text we
/// kept, so the user can tell what kind of statement it is (FR-05-30).
class StatementMailView extends StatelessWidget {
  /// Creates the view.
  const StatementMailView({required this.statement, super.key});

  /// The statement whose mail to show.
  final Statement statement;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${d.year}, $h:$m '
        '${d.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = statement;
    final body = s.emailText?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (s.subject?.trim().isNotEmpty ?? false) ? s.subject! : '(no subject)',
          key: const Key('mail-subject'),
          style: text.titleSmall,
        ),
        const SizedBox(height: 4),
        Text('From ${s.sender}', style: text.bodySmall),
        Text(_when(s.receivedAt), style: text.bodySmall),
        const Divider(height: 20),
        if (body == null || body.isEmpty)
          Text(
            'No text was kept from this email.',
            key: const Key('mail-empty'),
            style: text.bodySmall,
          )
        else
          SelectableText(body, key: const Key('mail-body')),
      ],
    );
  }
}

/// Opens the email of [s] in a bottom sheet (FR-05-30).
Future<void> showStatementMail(BuildContext context, Statement s) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: StatementMailView(statement: s),
        ),
      ),
    );
