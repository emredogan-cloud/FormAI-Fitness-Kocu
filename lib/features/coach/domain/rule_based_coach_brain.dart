import 'coach_brain.dart';
import 'coach_context.dart';

/// The current coach brain. It is genuinely context-aware — every answer is
/// derived from the real [CoachContext] (today's day, streak, goal, BMI,
/// progress) — but it does NOT pretend to be a general AI: unmatched input
/// gets an honest "here's what I can help with" reply, never fabricated
/// free-form text. This is the intelligence we can truthfully ship today;
/// the LLM brain slots in behind the same [CoachBrain] interface later.
class RuleBasedCoachBrain implements CoachBrain {
  const RuleBasedCoachBrain();

  @override
  String greeting(CoachContext ctx) {
    final hi = ctx.hour < 12
        ? 'Günaydın'
        : (ctx.hour < 18 ? 'Merhaba' : 'İyi akşamlar');
    final who = ctx.firstName.isNotEmpty ? ' ${ctx.firstName}' : '';
    final b = StringBuffer('$hi$who! Ben Form, kişisel koçun. ');
    if (ctx.todayDayNumber != null && !ctx.todayIsCompleted) {
      b.write('Bugün ${ctx.todayDayNumber}. günündesin — '
          '${ctx.todayExerciseCount} egzersiz seni bekliyor. ');
    } else if (ctx.todayIsCompleted) {
      b.write('Bugünkü antrenmanı çoktan bitirdin, tebrikler! ');
    }
    b.write('Ne konuşmak istersin?');
    return b.toString();
  }

  @override
  List<CoachSuggestion> suggestions(CoachContext ctx) => const [
        CoachSuggestion('Bugün ne yapmalıyım?', 'today'),
        CoachSuggestion('Nasıl gidiyorum?', 'progress'),
        CoachSuggestion('Beslenme', 'nutrition'),
        CoachSuggestion('Motive et beni', 'motivate'),
      ];

  @override
  Future<String> respond(
    CoachContext ctx,
    List<CoachTurn> history,
    String message,
  ) async {
    final m = message.toLowerCase().trim();
    if (_hits(m, ['today', 'bugün', 'ne yap', 'antrenman', 'workout'])) {
      return _today(ctx);
    }
    if (_hits(m, ['progress', 'nasıl gid', 'ilerle', 'gelişim', 'durum'])) {
      return _progress(ctx);
    }
    if (_hits(
        m, ['nutrition', 'beslenme', 'yemek', 'diyet', 'kalori', 'öğün'])) {
      return _nutrition(ctx);
    }
    if (_hits(
        m, ['motiv', 'motive', 'isteksiz', 'yorgun', 'vazgeç', 'bırak'])) {
      return _motivate(ctx);
    }
    if (_hits(m, ['streak', 'seri'])) {
      return ctx.streakDays > 0
          ? '${ctx.streakDays} günlük serin var — bunu bozma! '
              'Bugün 10 dakikalık bir oturum bile seriyi korur.'
          : 'Henüz bir serin yok. Bugün başla, yarın devam et — '
              'seri iki günde kurulur.';
    }
    if (_hits(m, ['injury', 'sakat', 'ağrı', 'acı', 'incin'])) {
      return 'Bir ağrın varsa o bölgeyi zorlama ve gerekirse bir sağlık '
          'uzmanına danış. FormAI genel rehberlik sunar; tıbbi tavsiye '
          'vermez. Ağrısız hareketlerle devam edebiliriz.';
    }
    if (_hits(m, ['merhaba', 'selam', 'hey', 'hi', 'hello', 'naber'])) {
      return greeting(ctx);
    }
    if (_hits(m, ['teşekkür', 'sağol', 'thanks', 'eyvallah'])) {
      return 'Ne demek! Her adımda buradayım. Hazır olduğunda başlayalım. 💪';
    }
    // Honest fallback — no fabricated intelligence.
    return 'Şu an sana şu konularda yardımcı olabilirim: bugünkü antrenmanın, '
        'ilerlemen, beslenme ve motivasyon. Hangisini konuşalım?';
  }

  bool _hits(String m, List<String> keys) => keys.any(m.contains);

  String _today(CoachContext ctx) {
    if (ctx.todayDayNumber == null) {
      return 'Planın hazırlanıyor. Bir bağlantı sorunun yoksa birazdan '
          'bugünkü antrenmanın burada olacak.';
    }
    if (ctx.todayIsCompleted) {
      return 'Bugünü tamamladın — harikasın! Yarına enerji toplamak için '
          'bol su iç ve iyi uyu. İstersen ekstra bir hareket de ekleyebiliriz.';
    }
    final eq = ctx.hasEquipment == true
        ? 'Ekipmanların olduğu için programına birkaç yüklü hareket de kattım. '
        : '';
    return '${ctx.todayDayNumber}. gün: ${ctx.todayExerciseCount} egzersiz. '
        '${eq}Kameranı aç, ben formunu izleyeyim — her tekrarını doğru '
        'yapman, sayısından daha önemli. Başlayalım mı?';
  }

  String _progress(CoachContext ctx) {
    final pct = ctx.totalDays > 0
        ? (100 * ctx.completedDays / ctx.totalDays).round()
        : 0;
    final streak = ctx.streakDays > 0
        ? '${ctx.streakDays} günlük serin sürüyor. '
        : 'Seriyi bugün yeniden başlatabilirsin. ';
    return '${ctx.completedDays}/${ctx.totalDays} gün tamamlandı (%$pct). '
        '${streak}Seviye ${ctx.level}, ${ctx.xp} XP ve ${ctx.badgeCount} rozet. '
        'İstikrar, hızdan daha önemli — bu tempoyu koru.';
  }

  String _nutrition(CoachContext ctx) {
    final bmi = ctx.bmi;
    final bmiLine =
        bmi != null ? 'BMI değerin ${bmi.toStringAsFixed(1)}. ' : '';
    final goal = ctx.goalLabel != null ? '"${ctx.goalLabel}" ' : '';
    return '$bmiLine${goal}hedefin için beslenme, antrenman kadar önemli. '
        'Beslenme sekmesinde damak zevkine ve kalori ihtiyacına göre '
        'seçilmiş tarifler var. Öğünlerini düzenli tutmak sonucu hızlandırır. '
        '(Beslenme önerileri bilgilendirme amaçlıdır, tıbbi tavsiye değildir.)';
  }

  String _motivate(CoachContext ctx) {
    final who = ctx.firstName.isNotEmpty ? '${ctx.firstName}, ' : '';
    if (ctx.streakDays >= 3) {
      return '$who${ctx.streakDays} gündür buradasın — bu disiplin çoğu '
          'kişide yok. Bugün de göster kendine neler yapabileceğini. 🔥';
    }
    if (ctx.completedDays == 0) {
      return '${who}en zor kısım başlamaktır, gerisi gelir. Sadece 10 '
          'dakika ayır; bittiğinde bambaşka hissedeceksin. Hadi. 💪';
    }
    return '${who}sonuçlar görünür olmadan önce hissedilir. Bugün bir adım '
        'daha at — gelecekteki sen bunun için teşekkür edecek.';
  }
}
