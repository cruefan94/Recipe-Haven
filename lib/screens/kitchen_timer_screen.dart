import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/kitchen_timer_service.dart';

/// Manually match an oven's duration; local notifications are scheduled by
/// Android so the phone can alert outside this app when permitted.
class KitchenTimerScreen extends StatefulWidget {
  const KitchenTimerScreen({
    super.key,
    this.storage,
    this.notifications,
  });
  final KitchenTimerStorage? storage;
  final KitchenTimerNotifications? notifications;
  @override
  State<KitchenTimerScreen> createState() => _KitchenTimerScreenState();
}

class _KitchenTimerScreenState extends State<KitchenTimerScreen>
    with WidgetsBindingObserver {
  final _label = TextEditingController(text: 'Oven');
  final _hours = TextEditingController(text: '0');
  final _minutes = TextEditingController(text: '30');
  final _progressCustom = TextEditingController(text: '10');
  final _overdueCustom = TextEditingController(text: '10');
  late final KitchenTimerStorage _storage;
  late final KitchenTimerNotifications _notifications;
  KitchenTimerSaved? _current;
  Timer? _ticker;
  bool _working = false;
  bool _finish = true, _sound = true, _vibrate = true;
  int _progress = 0, _overdue = 0;
  String? _error;
  static const _intervals = [0, 5, 10, 15, 30, -1];

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? KitchenTimerStorage();
    _notifications = widget.notifications ?? KitchenTimerNotifications();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _current != null && !_current!.paused) setState(() {});
    });
  }

  Future<void> _restore() async {
    try {
      final state = await _storage.read();
      if (!mounted) return;
      setState(() {
        _current = state;
        if (state != null) {
          _label.text = state.settings.label;
          _progress = state.settings.progressMinutes;
          _overdue = state.settings.overdueMinutes;
          _finish = state.settings.finishAlert;
          _sound = state.settings.sound;
          _vibrate = state.settings.vibrate;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not restore the timer.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _label.dispose();
    _hours.dispose();
    _minutes.dispose();
    _progressCustom.dispose();
    _overdueCustom.dispose();
    super.dispose();
  }

  int? _interval(int choice, TextEditingController custom) {
    if (choice != -1) return choice;
    final value = int.tryParse(custom.text.trim());
    if (value == null || value < 1 || value > 60) return null;
    return value;
  }

  void _warn(String text) {
    setState(() => _error = text);
  }

  Future<void> _start() async {
    final hours = int.tryParse(_hours.text.trim());
    final mins = int.tryParse(_minutes.text.trim());
    if (hours == null || mins == null || hours < 0 ||
        mins < 0 || mins > 59 || hours * 60 + mins < 1 ||
        hours * 60 + mins > 240) {
      _warn('Enter a timer between 1 minute and 4 hours.');
      return;
    }
    final progress = _interval(_progress, _progressCustom);
    final overdue = _interval(_overdue, _overdueCustom);
    if (progress == null || overdue == null) {
      _warn('Custom reminder intervals must be 1–60 minutes.');
      return;
    }
    final duration = Duration(hours: hours, minutes: mins);
    final config = KitchenTimerSettings(
      label: _label.text.trim().isEmpty ? 'Oven' : _label.text.trim(),
      durationSeconds: duration.inSeconds,
      progressMinutes: progress, overdueMinutes: overdue,
      finishAlert: _finish, sound: _sound, vibrate: _vibrate,
    );
    await _activate(config);
  }

  Future<void> _activate(KitchenTimerSettings config) async {
    setState(() { _working = true; _error = null; });
    final start = DateTime.now();
    final end = start.add(Duration(seconds: config.durationSeconds));
    try {
      var state = KitchenTimerSaved(
        settings: config, endAt: end, pausedSeconds: 0, paused: false,
        alertStatus: 'Starting alerts…',
      );
      await _storage.save(state);
      if (mounted) setState(() => _current = state);
      String status;
      try {
        status = await _notifications.schedule(config, start);
      } catch (_) {
        // Avoid leaving some partial reminders active after a plugin failure.
        try { await _notifications.cancel(); } catch (_) {}
        status = 'The timer is running, but phone alerts could not be '
            'scheduled. Check app permissions and use another alarm.';
      }
      state = KitchenTimerSaved(
        settings: config, endAt: end, pausedSeconds: 0, paused: false,
        alertStatus: status,
      );
      await _storage.save(state);
      if (mounted) setState(() => _current = state);
    } catch (_) {
      if (mounted) _warn('Could not save this timer. Please try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pause() async {
    final active = _current;
    if (active == null || _working) return;
    setState(() => _working = true);
    try {
      final seconds = active.remainingAt(DateTime.now());
      await _notifications.cancel();
      final paused = KitchenTimerSaved(
        settings: active.settings, endAt: active.endAt,
        pausedSeconds: seconds, paused: true,
        alertStatus: 'Paused. Scheduled notifications were cancelled.',
      );
      await _storage.save(paused);
      if (mounted) setState(() => _current = paused);
    } catch (_) {
      if (mounted) _warn('Could not pause notifications. Try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resume() async {
    final active = _current;
    if (active == null || !active.paused || _working) return;
    final remaining = active.pausedSeconds;
    if (remaining < 1) return;
    final old = active.settings;
    await _activate(KitchenTimerSettings(
      label: old.label, durationSeconds: remaining,
      progressMinutes: old.progressMinutes,
      overdueMinutes: old.overdueMinutes,
      finishAlert: old.finishAlert,
      sound: old.sound,
      vibrate: old.vibrate,
    ));
  }

  Future<void> _stop() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _notifications.cancel();
      await _storage.clear();
      if (mounted) setState(() { _current = null; _error = null; });
    } catch (_) {
      if (mounted) _warn('Could not cancel the timer alerts. Try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _clock(int secs) {
    final hours = secs ~/ 3600;
    final minutes = (secs % 3600) ~/ 60;
    final seconds = secs % 60;
    return hours.toString().padLeft(2, '0') + ':' +
      minutes.toString().padLeft(2, '0') + ':' +
      seconds.toString().padLeft(2, '0');
  }

  Widget _intervalField(String label, int value, ValueChanged<int> onChanged,
      TextEditingController custom) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text(label),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        key: ValueKey(label),
        initialValue: value == 0 || value == -1 || _intervals.contains(value)
            ? value : -1,
        isExpanded: true,
        decoration: const InputDecoration(),
        items: _intervals.map((v) => DropdownMenuItem(
          value: v,
          child: Text(v == 0 ? 'Off' : (v == -1 ? 'Custom interval'
              : 'Every ' + v.toString() + ' minutes')),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
      if (value == -1 || (value != 0 && !_intervals.contains(value))) ...[
        const SizedBox(height: 8),
        TextField(
          controller: custom,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Minutes (1–60)'),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final active = _current;
    final remaining = active?.remainingAt(DateTime.now()) ?? 0;
    final complete = active != null && !active.paused && remaining == 0;
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Oven & Kitchen Timer',
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      const Text('Match the same time shown on your oven. The app does not '
          'connect to or control your oven.'),
      const SizedBox(height: 12),
      if (active == null) ...[
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Timer name', hintText: 'e.g. Bread, Roast, Oven'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            key: const ValueKey('timer-hours'), controller: _hours,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Hours'),
          )),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            key: const ValueKey('timer-minutes'), controller: _minutes,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Minutes (0–59)'),
          )),
        ]),
        const SizedBox(height: 12),
        const Text('Optional phone alerts', style: TextStyle(fontWeight: FontWeight.bold)),
        SwitchListTile(
          value: _finish,
          onChanged: (v) => setState(() => _finish = v),
          title: const Text('Notify me when done'),
          subtitle: const Text('A finish notification on your phone'),
        ),
        _intervalField('Progress reminders before finishing',
            _progress, (v) => setState(() => _progress = v), _progressCustom),
        _intervalField('Repeat alerts after finishing (up to 1 hour)',
            _overdue, (v) => setState(() => _overdue = v), _overdueCustom),
        SwitchListTile(
          value: _sound, onChanged: (v) => setState(() => _sound = v),
          title: const Text('Play a notification sound'),
        ),
        SwitchListTile(
          value: _vibrate, onChanged: (v) => setState(() => _vibrate = v),
          title: const Text('Vibrate'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('start-kitchen-timer'),
          onPressed: _working ? null : _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start timer'),
        ),
      ] else ...[
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text(active.settings.label,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(complete ? "Time's up!" : _clock(remaining),
              key: const ValueKey('timer-countdown'),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: complete ? scheme.error : scheme.primary,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 10),
            Text(active.paused ? 'Paused'
                : (complete ? 'Check your oven' : 'Running')),
            const SizedBox(height: 8),
            if (!active.paused && !complete)
              Text('Finishes at ' +
                  TimeOfDay.fromDateTime(active.endAt).format(context)),
          ]),
        )),
        const SizedBox(height: 10),
        if (!complete) Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _working ? null : (active.paused ? _resume : _pause),
            icon: Icon(active.paused ? Icons.play_arrow : Icons.pause),
            label: Text(active.paused ? 'Resume' : 'Pause'),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(
            onPressed: _working ? null : _stop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          )),
        ]),
        if (complete) FilledButton.icon(
          onPressed: _working ? null : _stop,
          icon: const Icon(Icons.check),
          label: const Text('Dismiss and stop reminders'),
        ),
        const SizedBox(height: 10),
        Text(active.alertStatus, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        const Text('Leaving the app does not stop scheduled alerts. '
          'Pausing or stopping the timer cancels outstanding alerts.'),
      ],
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
        child: Text(_error!, style: TextStyle(color: scheme.error))),
      const SizedBox(height: 18),
      const Text('Important: Android notification permissions, Do Not Disturb, '
        'volume, battery restrictions and exact-alarm settings affect phone '
        'alerts. Test notifications before relying on them, and do not use '
        'this phone timer as your only cooking or fire-safety safeguard.'),
    ]);
  }
}
