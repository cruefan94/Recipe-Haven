import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_haven/services/kitchen_timer_service.dart';

void main() {
  test('45 minute oven timer sends 10 minute progress reminders', () {
    const settings = KitchenTimerSettings(
      label: 'Bread', durationSeconds: 45 * 60,
      progressMinutes: 10, overdueMinutes: 10,
    );
    final events = KitchenTimerPlan.build(settings);
    expect(events.take(4).map((e) => e.offsetSeconds),
        [600, 1200, 1800, 2400]);
    expect(events[4].offsetSeconds, 2700);
    expect(events[5].offsetSeconds, 3300);
    expect(events[4].title, 'Oven timer finished');
  });

  test('notifications can be all disabled by the user', () {
    const settings = KitchenTimerSettings(
      label: 'Oven', durationSeconds: 1200,
      finishAlert: false,
    );
    expect(KitchenTimerPlan.build(settings), isEmpty);
    expect(settings.hasAlerts, false);
  });

  test('timer state survives serialization and counts down by wall clock', () {
    final now = DateTime.utc(2026, 11, 15, 12);
    final state = KitchenTimerSaved(
      settings: const KitchenTimerSettings(
        label: 'Potatoes', durationSeconds: 3600),
      endAt: now.add(const Duration(hours: 1)),
      pausedSeconds: 0, paused: false, alertStatus: 'Scheduled',
    );
    final saved = KitchenTimerSaved.parse(state.serialize())!;
    expect(saved.settings.label, 'Potatoes');
    expect(saved.remainingAt(now.add(const Duration(minutes: 10))), 3000);
  });

  test('timer reminders are bounded for phone OS limits', () {
    const settings = KitchenTimerSettings(
      label: 'Roast', durationSeconds: 4 * 3600,
      progressMinutes: 1, overdueMinutes: 1,
    );
    expect(KitchenTimerPlan.build(settings).length, lessThanOrEqualTo(60));
  });
}
