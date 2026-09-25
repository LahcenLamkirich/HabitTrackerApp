/// Calendar-day arithmetic for habit history.
///
/// Every date in Daily Check is a *calendar day*, normalised to local
/// midnight, and days are compared with `==`. That makes `Duration`-based
/// arithmetic unsafe: adding `Duration(days: 1)` adds exactly 24 hours, so
/// across a daylight-saving transition it lands on 23:00 or 01:00 rather
/// than midnight. Such a date no longer equals any stored day, which
/// silently breaks streaks and history grids twice a year.
///
/// These helpers step by calendar day instead, via the [DateTime]
/// constructor's own overflow handling (day 0 rolls into the previous
/// month, day 32 into the next), so the result is always local midnight.
library;

/// Local midnight on the calendar day containing [dt].
DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// [days] calendar days after the day containing [dt] (negative goes back),
/// normalised to local midnight.
DateTime addDays(DateTime dt, int days) =>
    DateTime(dt.year, dt.month, dt.day + days);

/// The calendar day before the one containing [dt].
DateTime previousDay(DateTime dt) => addDays(dt, -1);

/// Whole calendar days from [from] to [to], ignoring clock changes.
///
/// Uses the rounded hour difference rather than [Duration.inDays], which
/// truncates a 23-hour DST day down to 0.
int calendarDaysBetween(DateTime from, DateTime to) {
  final hours = startOfDay(to).difference(startOfDay(from)).inHours;
  return (hours / 24).round();
}
