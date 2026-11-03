import 'package:flutter/material.dart';

import '../app_state.dart';
import '../schedule_summary.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import '../widgets/surfaces.dart';
import 'make_with_ai.dart';

/// The loaded schedule: file name, a readable summary of its blocks and
/// rules, and any errors in a newer version (the previous one keeps running).
class ScheduleFileScreen extends StatelessWidget {
  const ScheduleFileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final schedule = state.schedule;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader(title: 'Schedule file'),
          Expanded(
            child: BottomFade(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.md, 8, Space.md, 48),
                children: [
                  SourceCard(
                    icon: LineIcons.file,
                    title: state.scheduleName,
                    subtitle: schedule == null
                        ? 'No schedule yet'
                        : 'Running since ${sinceLabel(state.scheduleSince)} · ${scheduleCounts(schedule)}',
                  ),
                  for (final e in state.fileErrors) ...[
                    const SizedBox(height: 12),
                    ErrorCard(
                      error: e,
                      overlinePrefix: 'New version',
                      note: 'Your previous schedule keeps running until this is fixed.',
                    ),
                  ],
                  if (schedule != null) ...[
                    const SizedBox(height: 12),
                    BlocksAndRules(schedule: schedule),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.bottomInset(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Paste from clipboard',
                        fontSize: 15,
                        onTap: () => pasteFromClipboard(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Make one with AI',
                        fontSize: 15,
                        onTap: () => showMakeWithAiSheet(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // The system file picker arrives with import in step 6.
                const PrimaryButton(label: 'Import file'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
