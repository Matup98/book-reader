import 'package:flutter/material.dart';

import '../models/theme_mode_preference.dart';

enum ThemeModePickerVariant {
  /// Icon button + popup menu, meant for AppBar actions.
  compact,

  /// Column of [RadioListTile]s for settings sheets/panels.
  expanded,
}

/// Selector for the app color scheme with two layouts sharing the same
/// options and callback.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.variant,
  });

  final ThemeModePreference mode;
  final ValueChanged<ThemeModePreference> onChanged;
  final ThemeModePickerVariant variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case ThemeModePickerVariant.compact:
        return _CompactPicker(mode: mode, onChanged: onChanged);
      case ThemeModePickerVariant.expanded:
        return _ExpandedPicker(mode: mode, onChanged: onChanged);
    }
  }
}

class _CompactPicker extends StatelessWidget {
  const _CompactPicker({required this.mode, required this.onChanged});

  final ThemeModePreference mode;
  final ValueChanged<ThemeModePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ThemeModePreference>(
      icon: Icon(_iconFor(mode)),
      tooltip: 'Tema',
      initialValue: mode,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in ThemeModePreference.values)
          PopupMenuItem<ThemeModePreference>(
            value: option,
            child: Row(
              children: [
                Icon(_iconFor(option)),
                const SizedBox(width: 12),
                Text(_labelFor(option)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExpandedPicker extends StatelessWidget {
  const _ExpandedPicker({required this.mode, required this.onChanged});

  final ThemeModePreference mode;
  final ValueChanged<ThemeModePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in ThemeModePreference.values)
          RadioListTile<ThemeModePreference>(
            title: Text(_labelFor(option)),
            secondary: Icon(_iconFor(option)),
            value: option,
            groupValue: mode,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
      ],
    );
  }
}

IconData _iconFor(ThemeModePreference mode) {
  switch (mode) {
    case ThemeModePreference.system:
      return Icons.brightness_auto;
    case ThemeModePreference.light:
      return Icons.light_mode;
    case ThemeModePreference.dark:
      return Icons.dark_mode;
  }
}

String _labelFor(ThemeModePreference mode) {
  switch (mode) {
    case ThemeModePreference.system:
      return 'Seguir sistema';
    case ThemeModePreference.light:
      return 'Claro';
    case ThemeModePreference.dark:
      return 'Oscuro';
  }
}
