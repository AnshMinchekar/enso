import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import '../widgets/surfaces.dart';
import 'make_with_ai.dart';

/// The starter templates offered in onboarding (files arrive in step 6).
enum StarterTemplate {
  student('Student', 'Lectures, study blocks, a later start'),
  nineToFive('9 to 5', 'Commute, work hours, evenings free'),
  gymFocused('Gym-focused', 'Training first, meals around it, early nights');

  const StarterTemplate(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// Three short steps: welcome, pick a starting point, permissions.
///
/// In this build it is reached from Settings in debug builds only. Step 4
/// requests the permissions and step 6 makes it the real first launch with
/// templates and file import.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  StarterTemplate? _template;

  void _next() => setState(() => _step++);

  // Navigator.pop, not maybePop: the back handler only steps backwards.
  void _finish() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_step) {
      0 => _Welcome(onNext: _next),
      1 => _Template(
        selected: _template,
        onSelect: (t) => setState(() => _template = t),
        onNext: _next,
      ),
      _ => _Permissions(onAllow: _finish, onLater: _finish),
    };
    // Steps cross-fade and rise 24 dp on the check-in spring, like every
    // other screen change. Back returns to the previous step.
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: Motion.checkInDuration,
          reverseDuration: const Duration(milliseconds: 200),
          switchInCurve: Motion.checkIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) =>
                  Transform.translate(offset: Offset(0, 24 * (1 - animation.value)), child: child),
            ),
          ),
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: KeyedSubtree(key: ValueKey(_step), child: page),
        ),
      ),
    );
  }
}

/// Step dots: the current step is a 24-wide accent bar.
class _Dots extends StatelessWidget {
  const _Dots(this.index);

  final int index;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          AnimatedContainer(
            duration: Motion.replanDuration,
            curve: Motion.replan,
            width: i == index ? 24 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? p.accent : p.sunk,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (i < 2) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// The enso mark: a 64 rounded square with an open accent circle.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      alignment: Alignment.center,
      child: CustomPaint(size: const Size.square(36), painter: _EnsoPainter(p.accent)),
    );
  }
}

class _EnsoPainter extends CustomPainter {
  _EnsoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 36;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 13 * s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.25);
    canvas.drawCircle(rect.center, 13 * s, paint);
    // dasharray 52 of a circumference of ~82: about 0.635 of a turn.
    canvas.drawArc(rect, -1.5708, 6.2832 * 52 / 81.68, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_EnsoPainter old) => old.color != color;
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Mark(),
                const SizedBox(height: 24),
                Text(
                  'Your whole day, built from the moment you wake.',
                  style: EnsoType.display.copyWith(color: p.ink),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tell Enso when you got up. It lays out the rest and lets you know when it’s time to switch.',
                  style: EnsoType.body.copyWith(fontSize: 17, height: 1.55, color: p.ink2),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.xl),
          child: _Dots(0),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(Space.md, 28, Space.md, Space.bottomInset(context)),
          child: PrimaryButton(label: 'Get started', onTap: onNext),
        ),
      ],
    );
  }
}

class _Template extends StatelessWidget {
  const _Template({required this.selected, required this.onSelect, required this.onNext});

  final StarterTemplate? selected;
  final ValueChanged<StarterTemplate> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(Space.xl, 24, Space.xl, 0),
                child: _Dots(1),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start from a template', style: EnsoType.heading.copyWith(color: p.ink)),
                    const SizedBox(height: 10),
                    Text(
                      'Every block and rule can be changed later in the file.',
                      style: EnsoType.body.copyWith(color: p.ink2),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.xl, Space.md, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in StarterTemplate.values) ...[
                      ChoiceRow(
                        label: t.title,
                        subtitle: t.subtitle,
                        selected: t == selected,
                        onTap: () => onSelect(t),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: Text(
                        'or',
                        textAlign: TextAlign.center,
                        style: EnsoType.caption.copyWith(color: p.ink3),
                      ),
                    ),
                    // File import arrives in step 6.
                    const _AltRow(
                      icon: LineIcons.file,
                      title: 'Import a schedule file',
                      subtitle: 'A Markdown file on this phone',
                    ),
                    const SizedBox(height: 12),
                    _AltRow(
                      icon: LineIcons.chat,
                      title: 'Make one with AI',
                      subtitle: 'Describe your day to any AI assistant, paste the result back',
                      onTap: () => showMakeWithAiSheet(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Space.md,
                Space.xl,
                Space.md,
                Space.bottomInset(context),
              ),
              child: PrimaryButton(label: 'Continue', onTap: onNext),
            ),
          ),
        ),
      ],
    );
  }
}

class _AltRow extends StatelessWidget {
  const _AltRow({required this.icon, required this.title, required this.subtitle, this.onTap});

  final LineIcons icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Glass(
          tone: GlassTone.sunk,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              LineIcon(icon, size: 24, color: p.ink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: EnsoType.row.copyWith(color: p.ink, height: 1.3)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: EnsoType.caption.copyWith(color: p.ink2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Permissions extends StatelessWidget {
  const _Permissions({required this.onAllow, required this.onLater});

  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    Widget card(LineIcons icon, String title, String body) => Glass(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Glass(
            tone: GlassTone.sunk,
            radius: 22,
            child: SizedBox.square(
              dimension: 44,
              child: Center(child: LineIcon(icon, size: 22, color: p.ink)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: EnsoType.bodyStrong.copyWith(color: p.ink, height: 1.3)),
                const SizedBox(height: 6),
                Text(body, style: EnsoType.bodySmall.copyWith(color: p.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(Space.xl, 24, Space.xl, 0), child: _Dots(2)),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Two small permissions', style: EnsoType.heading.copyWith(color: p.ink)),
              const SizedBox(height: 10),
              Text(
                'So reminders arrive on time, even when the app is closed.',
                style: EnsoType.body.copyWith(color: p.ink2),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xl, Space.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(
                LineIcons.bell,
                'Notifications',
                'To tell you when a block ends and what comes next.',
              ),
              const SizedBox(height: 12),
              card(
                LineIcons.clock,
                'Exact alarms',
                'So a 12:30 reminder arrives at 12:30, not a few minutes later.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Text(
                  'Nothing leaves your phone. No account, no server.',
                  style: EnsoType.bodySmall.copyWith(fontSize: 14, color: p.ink2),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: PrimaryButton(label: 'Allow', onTap: onAllow),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(Space.md, 4, Space.md, Space.bottomInset(context) - 12),
          child: Center(
            child: SizedBox(
              height: 48,
              child: TextAction(label: 'Not now', onTap: onLater),
            ),
          ),
        ),
      ],
    );
  }
}
