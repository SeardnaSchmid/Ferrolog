import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'findings.dart';
import 'language.dart';
import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'stats_colors.dart';
import 'training_card.dart';

/// "7,3" / "7.3": sets with one decimal below 10.
String _sets(double v) => decimal(v.toStringAsFixed(v < 10 ? 1 : 0));

String _upper(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Positions along the guide, from the first muscle group (0) to the second (1).
class _BalanceAxis {
  final Balance balance;
  const _BalanceAxis(this.balance);

  bool get singleLimit => balance.low == balance.high;
  double get start => singleLimit ? .5 : .35;
  double get end => singleLimit ? .5 : .65;

  static double _share(double ratio) => 1 - 1 / (1 + ratio);

  // Stretch each section independently to center the guide while keeping extreme ratios visible.
  double position(double ratio) {
    final value = _share(ratio);
    final low = _share(balance.low), high = _share(balance.high);
    if (value < low) return start * value / low;
    if (value > high) return end + (1 - end) * (value - high) / (1 - high);
    if (low == high) return start;
    return start + (end - start) * (value - low) / (high - low);
  }
}

/// The rows of the balance card: every pair as a scale, warnings first; tap one for the verdict, the
/// advice (the same as on the home card), the numbers and its history. Below, the strength ratios.
class BalanceBody extends StatefulWidget {
  final List<Balance> pairs;
  final List<Session> recent;
  final List<(String, double, double)> trends;
  final List<Session> sessions;
  final DateTime from, now;

  /// The pair a finding points to: tinted and open.
  final Pair? focus;
  const BalanceBody(this.pairs, this.recent, this.trends,
      {required this.sessions, required this.from, required this.now, this.focus, super.key});

  @override
  State<BalanceBody> createState() => _BalanceBodyState();
}

class _BalanceBodyState extends State<BalanceBody> {
  late final open = {?widget.focus};
  bool trendOpen = false;

  @override
  void didUpdateWidget(BalanceBody old) {
    super.didUpdateWidget(old);
    if (widget.focus case final p? when p != old.focus) open.add(p);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, height: 1.45, color: c.onSurfaceVariant);
    final warn = [
      for (final b in widget.pairs)
        if (b.lagging != null) b,
    ];
    final ok = [
      for (final b in widget.pairs)
        if (b.lagging == null) b,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (warn.isNotEmpty) ...[
                TextSpan(
                  text: tr.hintsCount(warn.length),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.referenceAmber),
                ),
                TextSpan(text: tr.pairsBalanced(ok.length, widget.pairs.length)),
              ] else
                TextSpan(text: tr.allPairsBalanced),
            ],
          ),
          style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        for (final (i, b) in [...warn, ...ok].indexed) ...[
          if (warn.isNotEmpty && i == warn.length) Divider(height: 1, color: c.outlineVariant),
          _row(b, c, small),
        ],
        const SizedBox(height: 8),
        Text(
          tr.balanceScaleHint,
          style: small,
        ),
        if (widget.trends.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: c.outlineVariant),
          InkWell(
            onTap: () => setState(() => trendOpen = !trendOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr.strengthTrend,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                    ),
                  ),
                  Icon(trendOpen ? Icons.expand_less : Icons.expand_more, size: 18, color: c.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (trendOpen) ...[
            for (final (name, start, now) in widget.trends)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                    Text(
                      '${start.round()} → ${now.round()} %',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        now.round() - start.round() >= 2
                            ? tr.trendUp
                            : start.round() - now.round() >= 2
                            ? tr.trendDown
                            : tr.trendFlat,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              tr.strengthTrendHint,
              style: small,
            ),
          ],
        ],
      ],
    );
  }

  Widget _row(Balance b, ColorScheme c, TextStyle small) {
    final lagging = b.lagging;
    final isOpen = open.contains(b.pair);
    final strongA = b.laggingSide == 1, strongB = b.laggingSide == 0;
    TextStyle name(bool strong) => TextStyle(
      fontSize: 13,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      color: strong ? c.referenceAmber : c.onSurface.withValues(alpha: .8),
    );
    final ratio = b.ratio.isFinite ? '${(b.ratio * 100).floor()} %' : '–';
    final note = b.pair.note == null ? '' : ' (${b.pair.note})';
    final detail = tr.balanceDetail(
        _upper(b.a), _sets(b.aValue), b.b, _sets(b.bValue), note, b.bGroup, ratio, guideRange(b.low, b.high));
    final marked = widget.focus == b.pair;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => isOpen ? open.remove(b.pair) : open.add(b.pair)),
      // The tint reaches a little past the text on both sides, into the card's padding.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (marked)
            Positioned(
              left: -8,
              right: -8,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.referenceAmber.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(b.aGroup, style: name(strongA))),
                    Text(b.bGroup, style: name(strongB)),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: c.surfaceContainerHighest, shape: BoxShape.circle),
                      child: Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 16, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Padding(padding: const EdgeInsets.only(right: 28), child: _Scale(b)),
                if (isOpen) ...[
                  const SizedBox(height: 10),
                  if (lagging != null)
                    Text(
                      tr.balanceImbalance(lagging),
                      style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: c.referenceAmber),
                    )
                  else
                    Text(
                      tr.balanced,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.referenceGreen),
                    ),
                  const SizedBox(height: 8),
                  Text(detail, style: small),
                  const SizedBox(height: 12),
                  _BalanceHistory(
                    key: ValueKey(b.pair),
                    balance: b,
                    history: balanceHistory(b.pair, widget.sessions, widget.from, widget.now),
                    small: small,
                  ),
                  if (balanceAdvice(b, widget.recent, store.workouts) case final a?) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.cardAdvice,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .6,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(a.advice, style: const TextStyle(fontSize: 14, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHistory extends StatefulWidget {
  final Balance balance;
  final List<(DateTime, Balance?)> history;
  final TextStyle small;

  const _BalanceHistory({
    required this.balance,
    required this.history,
    required this.small,
    super.key,
  });

  @override
  State<_BalanceHistory> createState() => _BalanceHistoryState();
}

class _BalanceHistoryState extends State<_BalanceHistory> {
  int samplesBack = 0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final b = widget.balance;
    final history = widget.history;
    final selected = (history.length - 1 - samplesBack).clamp(0, history.length - 1);
    String summaryAt(int index) {
      final (date, sample) = history[index];
      final status = switch (sample) {
        null => tr.balanceHistoryNoSets,
        Balance(:final lagging?) => tr.balanceImbalance(lagging),
        _ => tr.balanced,
      };
      if (sample == null) return '${dateLabel(date)} · $status';
      final ratio = sample.ratio.isFinite ? '${(sample.ratio * 100).floor()} %' : '∞';
      return '${dateLabel(date)} · $status · ${b.bGroup} / ${b.aGroup} $ratio';
    }
    final summary = summaryAt(selected);
    final guide = tr.balanceHistoryGuide(guideRange(b.low, b.high));
    final hasEarlier = selected > 0, hasLater = selected < history.length - 1;
    final day = history.first.$1.year == history.last.$1.year ? DateFormat.Md(appLocale.languageCode) : null;
    String axisDate(DateTime date) => day?.format(date) ?? dateLabel(date);
    void select(int index) => setState(() => samplesBack = history.length - 1 - index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(tr.balanceHistory, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(guide, style: widget.small),
          ],
        ),
        const SizedBox(height: 6),
        Text(b.aGroup, style: widget.small),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final labelWidth = MediaQuery.textScalerOf(context).scale(day == null ? 76 : 52);
            final start = history.first.$1, end = history.last.$1;
            final span = end.difference(start);
            final steps = (width ~/ labelWidth - 1).clamp(1, span.inDays.clamp(1, 4));
            final dates = DateUtils.isSameDay(start, end)
                ? [end]
                : [
                    for (var i = 0; i <= steps; i++)
                      start.add(Duration(microseconds: (span.inMicroseconds * i / steps).round())),
                  ];
            final plot = _BalanceHistoryPlot(b, history, dates, selected, c);
            void pick(double x) => select(plot.nearest(x, width));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: tr.balanceHistory,
                  value: summary,
                  decreasedValue: hasEarlier ? summaryAt(selected - 1) : null,
                  increasedValue: hasLater ? summaryAt(selected + 1) : null,
                  onDecrease: hasEarlier ? () => select(selected - 1) : null,
                  onIncrease: hasLater ? () => select(selected + 1) : null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapUp: (event) => pick(event.localPosition.dx),
                    onHorizontalDragStart: (event) => pick(event.localPosition.dx),
                    onHorizontalDragUpdate: (event) => pick(event.localPosition.dx),
                    child: SizedBox(height: 118, child: CustomPaint(painter: plot)),
                  ),
                ),
                Text(b.bGroup, style: widget.small),
                if (dates.length == 1)
                  Text(axisDate(dates.single), style: widget.small, textAlign: TextAlign.center)
                else
                  Stack(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(axisDate(dates.first), style: widget.small)),
                          Flexible(child: Text(axisDate(dates.last), style: widget.small, textAlign: TextAlign.end)),
                        ],
                      ),
                      for (final date in dates.skip(1).take(dates.length - 2))
                        Positioned(
                          left: plot.x(date, width) - labelWidth / 2,
                          width: labelWidth,
                          child: Text(axisDate(date), style: widget.small, textAlign: TextAlign.center),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          style: widget.small.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(tr.balanceHistoryHint(balanceDays), style: widget.small),
      ],
    );
  }
}

class _BalanceHistoryPlot extends CustomPainter {
  static const _inset = 6.0;
  final Balance balance;
  final List<(DateTime, Balance?)> history;
  final List<DateTime> dates;
  final int selected;
  final ColorScheme colors;

  _BalanceHistoryPlot(this.balance, this.history, this.dates, this.selected, this.colors);

  double x(DateTime date, double width) {
    final start = history.first.$1;
    final span = history.last.$1.difference(start).inMilliseconds;
    return span == 0
        ? width / 2
        : _inset + (width - 2 * _inset) * date.difference(start).inMilliseconds / span;
  }

  int nearest(double pointerX, double width) {
    var closest = 0;
    for (var i = 1; i < history.length; i++) {
      if ((x(history[i].$1, width) - pointerX).abs() <= (x(history[closest].$1, width) - pointerX).abs()) {
        closest = i;
      }
    }
    return closest;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = (Offset.zero & size).deflate(_inset);
    final axis = _BalanceAxis(balance);
    double y(double position) => plot.top + plot.height * position;

    final guide = Paint()..color = colors.referenceGreen.withValues(alpha: .7);
    final band = colors.balanceBand;
    canvas.drawRect(plot, Paint()..color = colors.surfaceContainerHighest.withValues(alpha: .35));
    final region = Rect.fromLTRB(plot.left, y(axis.start), plot.right, y(axis.end));
    if (!axis.singleLimit) {
      canvas.drawRect(region, Paint()..color = band);
      canvas.drawLine(region.bottomLeft, region.bottomRight, guide);
    }
    canvas.drawLine(region.topLeft, region.topRight, guide);

    final grid = Paint()..color = colors.outlineVariant;
    if (dates.length > 1) {
      for (final date in dates) {
        final tick = x(date, size.width);
        canvas.drawLine(Offset(tick, plot.top), Offset(tick, plot.bottom), grid);
      }
    }
    final cursor = x(history[selected].$1, size.width);
    canvas.drawLine(
      Offset(cursor, plot.top),
      Offset(cursor, plot.bottom),
      Paint()..color = colors.outline,
    );
    final points = [
      for (final (date, sample) in history)
        sample == null
            ? null
            : Offset(
                x(date, size.width),
                y(axis.position(sample.ratio)),
              ),
    ];
    final line = Paint()
      ..color = colors.onSurfaceVariant
      ..strokeWidth = 1.5;
    for (var i = 1; i < points.length; i++) {
      if ((points[i - 1], points[i]) case (final a?, final b?)) {
        canvas.drawLine(a, b, line);
      }
    }
    for (final (i, point) in points.indexed) {
      if (point == null) continue;
      final fill = Paint()
        ..color = history[i].$2!.laggingSide == null
            ? colors.referenceGreen
            : colors.referenceAmber;
      if (i == selected) {
        canvas.drawCircle(point, 5.5, Paint()..color = colors.surface);
      }
      canvas.drawCircle(point, i == selected ? 4 : 2.5, fill);
    }
  }

  @override
  bool shouldRepaint(_BalanceHistoryPlot old) =>
      old.balance != balance ||
      old.history != history ||
      old.dates != dates ||
      old.selected != selected ||
      old.colors != colors;
}

/// The same guide as the history chart, laid out horizontally.
class _Scale extends StatelessWidget {
  final Balance balance;
  const _Scale(this.balance);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final card = Theme.of(context).cardTheme.color ?? c.surfaceContainerLow;
    final axis = _BalanceAxis(balance);
    final pos = axis.position(balance.ratio);
    final lagging = balance.laggingSide;
    final band = lagging == null ? c.referenceGreen.withValues(alpha: .55) : c.balanceBand;
    final dot = lagging == null ? c.referenceGreen : c.referenceAmber;
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, box) {
          double x(double position) => box.maxWidth * position;
          final edge = lagging == 1 ? axis.start : axis.end;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              if (axis.start != axis.end)
                Positioned(
                  left: x(axis.start),
                  width: x(axis.end) - x(axis.start),
                  top: 4,
                  height: 6,
                  child: ColoredBox(color: band),
                ),
              for (final limit in [axis.start, if (!axis.singleLimit) axis.end])
                Positioned(
                  left: x(limit) - 1,
                  width: 2,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(color: c.outline),
                ),
              if (lagging != null)
                Positioned(
                  left: x(pos < edge ? pos : edge),
                  width: (x(pos) - x(edge)).abs(),
                  top: 4,
                  height: 6,
                  child: ColoredBox(color: dot),
                ),
              Positioned(
                left: x(pos) - 7,
                top: 0,
                width: 14,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: card, spreadRadius: 2)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// What research says about the pairs and their guide values, behind the (i) of the balance card.
void showBalanceInfo(BuildContext context) {
  final c = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  Widget heading(String s) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(s, style: text.titleSmall?.copyWith(color: c.primary)),
  );
  Widget point(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(s, style: text.bodyMedium)),
      ],
    ),
  );
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(tr.balanceInfoTitle, style: text.titleLarge),
          heading(tr.infoProven),
          point(tr.infoProven1),
          point(tr.infoProven2),
          heading(tr.infoUncertain),
          point(tr.infoUncertain1),
          point(tr.infoUncertain2),
          point(tr.infoUncertain3),
          heading(tr.infoGuides),
          point(tr.infoGuides1),
          point(tr.infoGuides2),
          point(tr.infoGuides3),
          point(tr.infoGuides4),
          point(tr.infoGuides5),
          point(tr.infoGuideRanges),
          heading(tr.infoMath),
          point(tr.infoMath1),
          point(tr.infoMath2),
          point(tr.infoMath3),
          point(tr.infoMath4),
          heading(tr.infoScale),
          point(tr.infoScale1),
          point(tr.infoScale2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 40)),
              onPressed: () => showGuideEditor(context),
              child: Text(tr.adjustGuides),
            ),
          ),
          const Divider(height: 28),
          Text(tr.sources, style: text.labelSmall?.copyWith(letterSpacing: .6, color: c.onSurfaceVariant)),
          const SizedBox(height: 6),
          for (final (i, (label, url)) in _sources().indexed)
            InkWell(
              onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '[${i + 1}] $label',
                  style: text.bodySmall?.copyWith(color: c.primary, decoration: TextDecoration.underline),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Edit the lower and upper guide values for each pair.
void showGuideEditor(BuildContext context) {
  void changed(Pair p, double low, double high) {
    setBalanceGuide(p, low, high);
    findingsVersion.value++;
  }

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ValueListenableBuilder(
      valueListenable: balanceGuides,
      builder: (context, _, _) {
        final text = Theme.of(context).textTheme;
        Widget guideEditor(Pair p) {
          final (low, high) = guideOf(p);
          final limit = max(2.0, high);
          return Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('${p.a} ↔ ${p.b}', style: text.titleSmall)),
                  Text(guideRange(low, high), style: text.bodyMedium),
                ],
              ),
              RangeSlider(
                values: RangeValues(low, high),
                min: .2,
                max: limit,
                divisions: ((limit - .2) * 20).round(),
                onChanged: (v) => changed(p, v.start, v.end),
              ),
            ],
          );
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          maxChildSize: .92,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              Text(tr.guides, style: text.titleLarge),
              const SizedBox(height: 4),
              Text(tr.guidesHint, style: text.bodyMedium),
              for (final p in Pair.values) guideEditor(p),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: balanceGuides.value.isEmpty
                      ? null
                      : () {
                          setBalanceGuide(null);
                          findingsVersion.value++;
                        },
                  child: Text(tr.resetDefaults),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Sources behind the info sheet, numbered as cited there.
List<(String, String)> _sources() => [
  ('Schoenfeld et al. 2016', 'https://synapsesocial.com/papers/W2506937591'),
  ('Pelland et al. 2025 (via Biolayne)', 'https://biolayne.com/reps/issue-31/the-king-of-volume-metas/'),
  ('Kellis et al.', 'https://pmc.ncbi.nlm.nih.gov/articles/PMC10199143'),
  (
    'Bodybuilding.com',
    'https://www.bodybuilding.com/content/safe-strong-upper-body-lifting-begins-with-these-two-ratios.html',
  ),
  ('Systematic Review 2025, H:Q', 'https://lida.sport-iat.de/ta/Record/4090445?lng=en'),
  ('Negrete et al. 2013', 'https://nsuworks.nova.edu/hpd_pt_facarticles/151'),
  (
    tr.sourceShoulderNorms,
    'https://scholars.georgiasouthern.edu/en/publications/hand-held-dynamometer-testing-of-the-internal-and-external-rotato/',
  ),
  (
    tr.sourceTrunk,
    'https://e-space.mmu.ac.uk/630014/7/Trunk%20static%20and%20dynamic%20sagittal%20endurance%20in%20healthy%20young%20Nigerian%20adults.pdf',
  ),
  ('Ivanac 2026', 'https://medscimonit.com/abstract/full/idArt/951651'),
];
