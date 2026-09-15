import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StoreTimingsScreen extends StatefulWidget {
  const StoreTimingsScreen({
    super.key,
    required this.storeId,
    required this.initialData,
  });

  final String storeId;
  final Map<String, dynamic> initialData;

  @override
  State<StoreTimingsScreen> createState() => _StoreTimingsScreenState();
}

class _StoreTimingsScreenState extends State<StoreTimingsScreen> {
  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late TimeOfDay _openTime;
  late TimeOfDay _closeTime;
  late bool _isOpen;
  late Set<String> _closedDays;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _openTime = _parseTime(data['openTime'], const TimeOfDay(hour: 9, minute: 0));
    _closeTime = _parseTime(
      data['closeTime'],
      const TimeOfDay(hour: 21, minute: 0),
    );
    _isOpen = data['isOpen'] != false;
    _closedDays = {
      ...?(data['closedDays'] as List<dynamic>?)?.map((day) => day.toString()),
    };
  }

  static TimeOfDay _parseTime(Object? value, TimeOfDay fallback) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store timings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              value: _isOpen,
              onChanged: (value) => setState(() => _isOpen = value),
              title: const Text('Accepting orders'),
              subtitle: Text(
                _isOpen
                    ? 'Customers can order during opening hours'
                    : 'Store is shown as closed regardless of hours',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Opening hours',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Opens at'),
                  trailing: Text(
                    _openTime.format(context),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _pickTime(isOpening: true),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.nightlight_outlined),
                  title: const Text('Closes at'),
                  trailing: Text(
                    _closeTime.format(context),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _pickTime(isOpening: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Weekly off',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in _days)
                    FilterChip(
                      label: Text(day.substring(0, 3)),
                      selected: _closedDays.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _closedDays.add(day);
                        } else {
                          _closedDays.remove(day);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selected days are treated as holidays.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save timings'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime({required bool isOpening}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? _openTime : _closeTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isOpening) {
        _openTime = picked;
      } else {
        _closeTime = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .update({
            'openTime': _format(_openTime),
            'closeTime': _format(_closeTime),
            'isOpen': _isOpen,
            'closedDays': _closedDays.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store timings saved.')),
      );
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the timings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
