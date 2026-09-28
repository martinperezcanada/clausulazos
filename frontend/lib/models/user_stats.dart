// Re-exports UserStats/SlotStats so `models/user_stats.dart` works as an import path. The classes live
// next to AppUser in user.dart to avoid a circular import.
export 'user.dart' show UserStats, SlotStats;
