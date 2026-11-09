// Charts fit the phone they are on (FR-37-13).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/shared/widgets/charts/chart_sizing.dart';
import 'package:hisaab/shared/widgets/charts/donut_chart.dart';
import 'package:hisaab/shared/widgets/charts/line_chart_view.dart';

Widget _app(Size size, Widget child) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  test('scale follows the width within limits', () {
    expect(ChartSizing.scaleFor(390), 1);
    expect(ChartSizing.scaleFor(200), 0.8);
    expect(ChartSizing.scaleFor(900), 1.4);
  });

  testWidgets('a donut and a line chart shrink on a narrow phone',
      (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const Size(320, 568),
        Column(
          children: [
            const DonutChart(
              key: Key('donut'),
              parts: [DonutPart(5, Colors.green), DonutPart(3, Colors.red)],
              centerTop: 'Total',
              centerBottom: '8',
            ),
            LineChartView(
              key: const Key('line'),
              series: const [
                LineSeries([1, 2, 3], Colors.blue),
              ],
              yLabel: (v) => '$v',
            ),
          ],
        ),
      ),
    );
    final donut = tester.getSize(find.byKey(const Key('donut')));
    // 140 design dp scaled by 320/390, never more than 45% of the width.
    expect(donut.width, lessThanOrEqualTo(320 * 0.45));
    expect(donut.width, lessThan(140));
    final line = tester.getSize(find.byKey(const Key('line')));
    expect(line.height, lessThan(150));
    expect(line.height, lessThanOrEqualTo(568 * 0.33 + 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide screen grows charts, capped by the height',
      (tester) async {
    tester.view
      ..physicalSize = const Size(800, 400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const Size(800, 400),
        LineChartView(
          key: const Key('line'),
          series: const [
            LineSeries([1, 2, 3], Colors.blue),
          ],
          yLabel: (v) => '$v',
        ),
      ),
    );
    final line = tester.getSize(find.byKey(const Key('line')));
    expect(line.height, closeTo(400 * 0.33, 0.01));
  });
}
