import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/models.dart';
import '../../engine/parser.dart';
import '../app_state.dart';
import '../routes.dart';
import '../schedule_summary.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import '../widgets/surfaces.dart';
import 'block_sheet.dart';

/// Opens "Make one with AI": three steps, Copy prompt and Paste schedule.
/// Enso never calls any AI itself; it only copies and pastes text.
Future<void> showMakeWithAiSheet(BuildContext context) => Navigator.of(context).push(
  BlockSheetRoute<void>(
    scrim: EnsoPalette.of(context).scrim,
    builder: (_) => const MakeWithAiSheet(),
  ),
);

/// Reads the clipboard, parses it and shows the result screen.
Future<void> pasteFromClipboard(BuildContext context) async {
  final navigator = Navigator.of(context);
  final text = await readClipboard();
  navigator.push(EnsoPageRoute<void>(builder: (_) => PasteResultScreen(initialText: text)));
}

/// Plain text on the clipboard, or an empty string.
Future<String> readClipboard() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  return data?.text ?? '';
}

class MakeWithAiSheet extends StatefulWidget {
  const MakeWithAiSheet({super.key});

  @override
  State<MakeWithAiSheet> createState() => _MakeWithAiSheetState();
}

class _MakeWithAiSheetState extends State<MakeWithAiSheet> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final prompt = await DefaultAssetBundle.of(context).loadString(kAiPromptAsset);
    await Clipboard.setData(ClipboardData(text: prompt));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _paste() async {
    final navigator = Navigator.of(context);
    final text = await readClipboard();
    navigator.pop();
    navigator.push(EnsoPageRoute<void>(builder: (_) => PasteResultScreen(initialText: text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Glass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      shadows: Elevation.sheet(p),
      padding: EdgeInsets.fromLTRB(24, 12, 24, Space.bottomInset(context) - 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 24),
          Text('Make one with AI', style: EnsoType.heading.copyWith(color: p.ink)),
          const SizedBox(height: 8),
          Text(
            'Use any assistant you like. Enso never sends anything itself.',
            style: EnsoType.bodySmall.copyWith(color: p.ink2),
          ),
          const SizedBox(height: 24),
          Glass(
            tone: GlassTone.sunk,
            radius: Radii.small,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              children: [
                _Step(
                  number: 1,
                  done: _copied,
                  first: true,
                  title: 'Copy the prompt',
                  body: 'It explains how an Enso schedule is written.',
                ),
                const _Step(
                  number: 2,
                  title: 'Paste it into any AI assistant',
                  body: 'Then describe your day in your own words.',
                ),
                const _Step(
                  number: 3,
                  title: 'Copy the answer back',
                  body: 'Return here and tap Paste schedule.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SecondaryButton(label: 'Paste schedule', fontSize: 15, onTap: _paste),
          const SizedBox(height: 12),
          PrimaryButton(
            label: _copied ? 'Copied' : 'Copy prompt',
            soft: _copied,
            icon: _copied ? LineIcons.check : null,
            onTap: _copy,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.first = false,
    this.done = false,
  });

  final int number;
  final String title;
  final String body;

  /// The first step's number sits on the accent; the others on accentSoft.
  final bool first;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final fg = first ? p.onAccent : p.accentInk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: first ? p.accent : p.accentSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: Motion.replanDuration,
              child: done
                  ? LineIcon(LineIcons.check, key: const ValueKey('done'), size: 16, color: fg)
                  : Text(
                      '$number',
                      key: const ValueKey('n'),
                      style: EnsoType.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        fontFeatures: EnsoType.tabular,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: EnsoType.row.copyWith(color: p.ink, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: EnsoType.bodySmall.copyWith(fontSize: 14, height: 1.45, color: p.ink2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// File name for a pasted schedule, from its first heading:
/// "# Ansh's routine" → "anshs-routine.md".
String pastedFileName(String text) {
  final heading = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(text)?.group(1);
  final slug = (heading ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'my-schedule' : slug}.md';
}

/// What "Paste schedule" shows: valid, no schedule found, or errors. The
/// current schedule keeps running until one is used.
class PasteResultScreen extends StatefulWidget {
  const PasteResultScreen({super.key, required this.initialText});

  final String initialText;

  @override
  State<PasteResultScreen> createState() => _PasteResultScreenState();
}

class _PasteResultScreenState extends State<PasteResultScreen> {
  late String _text = widget.initialText;
  late ParseResult _result = parseSchedule(_text);

  Future<void> _pasteAgain() async {
    final text = await readClipboard();
    if (!mounted) return;
    setState(() {
      _text = text;
      _result = parseSchedule(text);
    });
  }

  void _use(Schedule s) {
    AppScope.read(context).useSchedule(s, name: pastedFileName(_text));
    HapticFeedback.mediumImpact();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _result.schedule;
    final Widget body;
    final List<Widget> actions;
    final cancel = TextAction(label: 'Cancel', onTap: () => Navigator.of(context).maybePop());
    if (schedule != null) {
      body = _Valid(schedule: schedule);
      actions = [PrimaryButton(label: 'Use this schedule', onTap: () => _use(schedule)), cancel];
    } else if (_text.trim().isEmpty || _result.hasNoRoutineBlock) {
      body = const _NotFound();
      actions = [
        PrimaryButton(label: 'Try again', onTap: _pasteAgain),
        TextAction(
          label: 'See the steps',
          onTap: () {
            Navigator.of(context).pop();
            showMakeWithAiSheet(context);
          },
        ),
      ];
    } else {
      body = _Errors(errors: _result.errors, blocks: countBlockLines(_text));
      actions = [PrimaryButton(label: 'Paste again', onTap: _pasteAgain), cancel];
    }
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader(title: 'Pasted schedule'),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.replanDuration,
              child: KeyedSubtree(key: ValueKey(_text), child: body),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.md,
              Space.sm,
              Space.md,
              Space.bottomInset(context) - 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                actions.first,
                const SizedBox(height: 4),
                Center(child: SizedBox(height: 48, child: actions.last)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Valid extends StatelessWidget {
  const _Valid({required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context) => BottomFade(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(Space.md, 8, Space.md, 48),
      children: [
        SourceCard(
          icon: LineIcons.clipboard,
          title: 'From your clipboard',
          subtitle: '${scheduleCounts(schedule)} · ready to use',
        ),
        const SizedBox(height: 12),
        BlocksAndRules(schedule: schedule),
      ],
    ),
  );
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Glass(
            tone: GlassTone.sunk,
            radius: 32,
            child: SizedBox.square(
              dimension: 64,
              child: Center(child: LineIcon(LineIcons.clipboard, size: 28, color: p.ink2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('No schedule found', style: EnsoType.heading.copyWith(color: p.ink)),
          const SizedBox(height: 20),
          Text(
            'The copied text has no Enso schedule in it. '
            'Copy the assistant’s whole answer, then try again.',
            style: EnsoType.body.copyWith(height: 1.55, color: p.ink2),
          ),
        ],
      ),
    );
  }
}

class _Errors extends StatelessWidget {
  const _Errors({required this.errors, required this.blocks});

  final List<ScheduleError> errors;
  final int blocks;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final lines = {for (final e in errors) e.line}.length;
    final counts = [
      if (blocks > 0) '$blocks ${blocks == 1 ? 'block' : 'blocks'}',
      '$lines ${lines == 1 ? 'line needs' : 'lines need'} a fix',
    ].join(' · ');
    return BottomFade(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, 8, Space.md, 48),
        children: [
          SourceCard(icon: LineIcons.clipboard, title: 'From your clipboard', subtitle: counts),
          for (final e in errors) ...[const SizedBox(height: 12), ErrorCard(error: e)],
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
            child: Text(
              'Ask your assistant to fix these and paste again. Nothing changes until the schedule is valid.',
              style: EnsoType.bodySmall.copyWith(fontSize: 14, color: p.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
