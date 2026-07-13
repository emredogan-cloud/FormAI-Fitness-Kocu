/// Contextual dashboard coach line.
///
/// Today this is a deterministic rule set over the user's local weekly
/// state + time of day — a small, self-contained upgrade from the old
/// hardcoded "Haftayı tam gaz bitir!" string, which said the same thing
/// no matter what the user had actually done.
///
/// It is intentionally a PURE function with a stable signature so a future
/// LLM-backed coach can drop in behind the exact same call site: feed the
/// same state (and later: streak, name, recent history, mood) as context,
/// return a generated line. Keep it side-effect-free and synchronous so
/// the widget never has to change when the brain behind it does.
library;

String weeklyCoachLine({
  required int completed,
  required int target,
  required int hour, // 0–23, local
}) {
  if (target > 0 && completed >= target) {
    return 'Bu haftanın hedefini tamamladın! Harikasın 🔥';
  }
  if (target > 0 && target - completed == 1) {
    return 'Bir antrenman kaldı — haftayı tam gaz bitir!';
  }
  if (completed == 0) {
    if (hour < 12) {
      return 'Güne güçlü başla — ilk antrenman seni bekliyor.';
    }
    if (hour >= 18) {
      return 'Gün bitmeden bir antrenman sığdır, momentum önemli.';
    }
    return 'Bugün ilk hareketi yap — başlamak en zor kısmı.';
  }
  return 'İyi gidiyorsun: $completed/$target. Bir antrenman daha ekle!';
}
