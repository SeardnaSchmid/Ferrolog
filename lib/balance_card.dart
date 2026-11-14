import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'findings.dart';
import 'language.dart';
import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'training_card.dart';

/// "7,3" / "7.3": sets with one decimal below 10.
String _sets(double v) => decimal(v.toStringAsFixed(v < 10 ? 1 : 0));

String _upper(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Half the width of the balanced field around the middle of the scale, in percent of the scale.
const _field = 15.0;

/// Where the dot sits on the scale, -50 (all side a) to 50 (all side b): inside the field while
/// balanced, outside up to the ends the further off it is (half the guide off reaches the end).
/// Above an open guide the dot stays at the field's edge: more of side b is never off.
double _position(Balance b) {
  final r = b.ratio, lo = b.low, hi = b.high.isFinite ? b.high : b.low * 1.5;
  if (r < lo) return -_field - ((lo - r) / lo / .5).clamp(0, 1) * (50 - _field);
  if (r > hi) {
    if (!b.high.isFinite) return _field;
    return _field + (r.isFinite ? ((r - hi) / hi / .5).clamp(0, 1) : 1) * (50 - _field);
  }
  return hi <= lo ? 0 : -_field + (r - lo) / (hi - lo) * 2 * _field;
}

/// The rows of the balance card: every pair as a scale, warnings first; tap one for the verdict, the
/// advice (the same as on the home card) and the numbers. Below, the strength ratios as a course.
class BalanceBody extends StatefulWidget {
  final List<Balance> pairs;
  final List<Session> recent;
  final List<(String, double, double)> trends;

  /// The pair a finding points to: tinted and open.
  final Pair? focus;
  const BalanceBody(this.pairs, this.recent, this.trends, {this.focus, super.key});

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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.tertiary),
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
    final pos = _position(b);
    final aStrong = pos < 0;
    final strongA = lagging != null && aStrong, strongB = lagging != null && !aStrong;
    TextStyle name(bool strong) => TextStyle(
      fontSize: 13,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      color: strong ? c.tertiary : c.onSurface.withValues(alpha: .8),
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
                  color: c.tertiaryContainer.withValues(alpha: .35),
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
                Padding(padding: const EdgeInsets.only(right: 28), child: _Scale(pos, lagging != null)),
                if (isOpen) ...[
                  const SizedBox(height: 10),
                  if (lagging != null)
                    Text(
                      _verdict(b, aStrong),
                      style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: c.tertiary),
                    )
                  else
                    Text(
                      tr.balanced,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.primary),
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
                  const SizedBox(height: 8),
                  Text(detail, style: small),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Schultern deutlich mehr trainiert als Latissimus": the side with more sets first.
  String _verdict(Balance b, bool aStrong) {
    final r = b.ratio;
    final off = !r.isFinite
        ? 1.0
        : r < b.low
        ? (b.low - r) / b.low
        : (r - b.high) / b.high;
    // Mid-sentence: German keeps its nouns capitalised, only the adjectives go small.
    final weak = appLocale.languageCode == 'de'
        ? (aStrong ? b.bGroup : b.aGroup)
            .replaceFirstMapped(RegExp('^(Oberer|Unterer|Hintere|Vordere)'), (m) => m[0]!.toLowerCase())
        : (aStrong ? b.bGroup : b.aGroup).toLowerCase();
    return (off < .15 ? tr.verdictSlightly : tr.verdictClearly)(aStrong ? b.aGroup : b.bGroup, weak);
  }
}

/// A pair's scale: a track with the balanced field in the middle, a tick at the centre and the dot;
/// when off, the stretch from the field's edge to the dot in orange.
class _Scale extends StatelessWidget {
  final double pos;
  final bool warn;
  const _Scale(this.pos, this.warn);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final card = Theme.of(context).cardTheme.color ?? c.surfaceContainerLow;
    final dot = warn ? c.tertiary : c.primary;
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, box) {
          double x(double p) => box.maxWidth * (50 + p) / 100;
          final edge = pos < 0 ? -_field : _field;
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
              Positioned(
                left: x(-_field),
                width: x(_field) - x(-_field),
                top: 4,
                height: 6,
                child: ColoredBox(color: c.primary.withValues(alpha: .22)),
              ),
              Positioned(
                left: x(0) - 1,
                width: 2,
                top: 0,
                bottom: 0,
                child: ColoredBox(color: c.outline),
              ),
              if (warn)
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

/// Every pair's guide values to change: a range, or a lower bound where more of side b is never off.
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
              for (final p in Pair.values) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text('${p.a} ↔ ${p.b}', style: text.titleSmall)),
                    Text(guideRange(guideOf(p).$1, guideOf(p).$2), style: text.bodyMedium),
                  ],
                ),
                if (p.high.isFinite)
                  RangeSlider(
                    values: RangeValues(guideOf(p).$1, guideOf(p).$2),
                    min: .2,
                    max: 2,
                    divisions: 36,
                    onChanged: (v) => changed(p, v.start, v.end),
                  )
                else
                  Slider(
                    value: guideOf(p).$1,
                    min: .2,
                    max: 2,
                    divisions: 36,
                    onChanged: (v) => changed(p, v, double.infinity),
                  ),
              ],
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
