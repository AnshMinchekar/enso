import 'package:flutter/material.dart';

import '../../engine/models.dart';
import '../app_state.dart';
import '../format.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import '../widgets/surfaces.dart';
import '../widgets/wake_picker.dart';
import 'block_sheet.dart';
import 'onboarding_screen.dart';
import 'schedule_file_screen.dart';

/// Heads-up choices, in minutes before a block ends.
const List<int> kHeadsUpChoices = [2, 5, 10, 15];

/// Notification sounds offered in Settings. Step 4 wires them to the channel.
const List<String> kSounds = [kDefaultSound, 'Silent'];

/// Kept short: bedtime, heads-up, sound and the schedule file. No theme
/// selector; the look follows the time of day.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<T?> _sheet<T>(BuildContext context, Widget child) =>
      Navigator.of(context)
          .push<T>(BlockSheetRoute<T>(scrim: EnsoPalette.of(context).scrim, builder: (_) => child));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = EnsoPalette.of(context);
    final bedtime = state.bedtime;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader(title: 'Settings'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.md),
              children: [
                const GroupLabel('Day', top: 0),
                const SizedBox(height: 12),
                RowGroup(
                  children: [
                    SettingRow(
                      label: 'Bedtime',
                      value: bedtime?.toString() ?? '–',
                      onTap: state.schedule == null
                          ? null
                          : () => _sheet<void>(context, const _BedtimeSheet()),
                    ),
                    SettingRow(
                      label: 'Heads-up before a block ends',
                      value: formatDuration(state.headsUpMinutes),
                      onTap: () async {
                        final m = await _sheet<int>(
                          context,
                          _ChoiceSheet<int>(
                            title: 'Heads-up',
                            subtitle: 'A gentle note before a block ends.',
                            options: kHeadsUpChoices,
                            selected: state.headsUpMinutes,
                            label: (m) => '${formatDuration(m)} before',
                          ),
                        );
                        if (m != null) state.setHeadsUpMinutes(m);
                      },
                    ),
                    SettingRow(
                      label: 'Notification sound',
                      value: state.sound,
                      onTap: () async {
                        final s = await _sheet<String>(
                          context,
                          _ChoiceSheet<String>(
                            title: 'Notification sound',
                            options: kSounds,
                            selected: state.sound,
                            label: (s) => s,
                          ),
                        );
                        if (s != null) state.setSound(s);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const GroupLabel('Schedule', top: 20),
                const SizedBox(height: 12),
                RowGroup(
                  children: [
                    SettingRow(
                      label: 'Schedule file',
                      subtitle: state.scheduleName,
                      icon: LineIcons.file,
                      minHeight: 72,
                      onTap: () => pushScreen<void>(context, const ScheduleFileScreen()),
                    ),
                  ],
                ),
                if (kDevTools) ...[
                  const SizedBox(height: 12),
                  const GroupLabel('Test builds only', top: 20),
                  const SizedBox(height: 12),
                  RowGroup(
                    children: [
                      SettingRow(
                        label: 'Show onboarding',
                        onTap: () => pushScreen<void>(context, const OnboardingScreen()),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.xl,
              Space.md,
              Space.xl,
              Space.bottomInset(context) + 8,
            ),
            child: Text(
              'Everything runs on this phone. No account, no server.',
              textAlign: TextAlign.center,
              style: EnsoType.caption.copyWith(height: 1.5, color: p.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bedtime wheel. Choosing the file's own bedtime clears the override.
class _BedtimeSheet extends StatefulWidget {
  const _BedtimeSheet();

  @override
  State<_BedtimeSheet> createState() => _BedtimeSheetState();
}

class _BedtimeSheetState extends State<_BedtimeSheet> {
  late ClockTime _value;

  @override
  void initState() {
    super.initState();
    final b = AppScope.read(context).bedtime!;
    _value = ClockTime(b.hour, b.minute - b.minute % kPickerMinuteStep);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final fileBedtime = state.schedule!.bedtime;
    return _SheetShell(
      title: 'Bedtime',
      subtitle: 'From your file: $fileBedtime. A time set here wins on this phone.',
      children: [
        WakePicker(value: _value, onChanged: (v) => setState(() => _value = v)),
        const SizedBox(height: 24),
        if (state.bedtimeOverride != null) ...[
          SecondaryButton(
            label: 'Use the file’s bedtime',
            fontSize: 15,
            onTap: () {
              state.setBedtime(null);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
        ],
        PrimaryButton(
          label: 'Save',
          onTap: () {
            state.setBedtime(_value);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<T> options;
  final T selected;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) => _SheetShell(
    title: title,
    subtitle: subtitle,
    children: [
      for (final o in options) ...[
        ChoiceRow(
          label: label(o),
          selected: o == selected,
          onTap: () => Navigator.of(context).pop(o),
        ),
        if (o != options.last) const SizedBox(height: 12),
      ],
    ],
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Glass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      live: true,
      shadows: Elevation.sheet(p),
      padding: EdgeInsets.fromLTRB(24, 12, 24, Space.bottomInset(context) - 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 24),
          Text(title, style: EnsoType.heading.copyWith(color: p.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: EnsoType.bodySmall.copyWith(color: p.ink2)),
          ],
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
