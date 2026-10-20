import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Short, locale-aware "when" for `notesEditedAgo` / `syncLastSynced`:
/// the time today, otherwise the date ("12 Oct" / "Oct 12").
String formatWhen(BuildContext context, DateTime when, {DateTime? now}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = when.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  if (sameDay) return DateFormat.jm(locale).format(local);
  if (local.year == today.year) return DateFormat.MMMd(locale).format(local);
  return DateFormat.yMMMd(locale).format(local);
}
