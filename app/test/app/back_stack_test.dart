// Back always has somewhere to go (FR-17-49).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/router.dart';

GoRouter _router(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Text('home page')),
        GoRoute(
          path: '/transaction/:id',
          builder: (_, s) => Text('tx ${s.pathParameters['id']}'),
        ),
      ],
    );

void main() {
  testWidgets('an inner page opened alone gets Home underneath',
      (tester) async {
    final r = _router('/transaction/5');
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();
    expect(r.canPop(), isFalse);

    expect(ensureBackStack(r), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('tx 5'), findsOneWidget);
    expect(r.canPop(), isTrue);

    r.pop();
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
    expect(ensureBackStack(r), isFalse);
  });

  testWidgets('a tab root is left alone; openWithBack stacks over Home',
      (tester) async {
    final r = _router('/home');
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();
    expect(ensureBackStack(r), isFalse);

    openWithBack(r, '/transaction/9');
    await tester.pumpAndSettle();
    expect(find.text('tx 9'), findsOneWidget);
    expect(r.canPop(), isTrue);
    r.pop();
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
  });
}
