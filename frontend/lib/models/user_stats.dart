// Re-exports UserStats/SlotStats so `models/user_stats.dart` (named in the
// spec's suggested structure) is a valid import path on its own, while the
// actual class definitions live alongside AppUser in user.dart to avoid a
// circular-import split between two tightly coupled models.
export 'user.dart' show UserStats, SlotStats;
