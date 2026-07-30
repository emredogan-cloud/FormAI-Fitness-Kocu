/// Roadmap Phase 1 (C30) · in-app help centre content.
///
/// Deflects the questions that otherwise arrive as feedback tickets or,
/// worse, as 1-star reviews that describe a misunderstanding rather
/// than a defect. Camera setup and subscription management are the two
/// highest-volume categories for a product shaped like FormAI, so they
/// lead.
///
/// Kept as data (not widgets) so the whole set is one ARB extraction
/// away from being localisable in roadmap Phase 5, and so the search
/// index in [HelpCenterScreen] can be built generically.
library;

class FaqCategory {
  const FaqCategory({required this.title, required this.entries});

  final String title;
  final List<FaqEntry> entries;
}

class FaqEntry {
  const FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;

  /// Lower-cased haystack used by the help-centre search field.
  String get searchIndex => '$question $answer'.toLowerCase();
}

const List<FaqCategory> kFaqCategories = [
  FaqCategory(
    title: 'ANTRENMAN & KAMERA',
    entries: [
      FaqEntry(
        question: 'Kamera hareketlerimi neden görmüyor?',
        answer: 'Analiz için tüm vücudunun kadraja girmesi gerekir. '
            'Telefonu yere ya da sabit bir yere yaklaşık 2 metre uzağa '
            'koy, kamerayı dikey tut ve ortamın aydınlık olduğundan emin '
            'ol. Ekranda "Kadraja gir" uyarısı varsa biraz geriye git.',
      ),
      FaqEntry(
        question: 'Bazı egzersizlerde telefonu yana koymam mı gerekiyor?',
        answer: 'Evet. Şınav, plank ve kalça hareketi gibi yandan '
            'görülmesi gereken egzersizlerde telefonu yan tarafına '
            'yerleştir. Form koçu bu egzersizlerde sana bir kez sesli '
            'olarak hatırlatır.',
      ),
      FaqEntry(
        question: 'Kamera olmadan antrenman yapabilir miyim?',
        answer: 'Evet. Antrenmanı kamerasız da tamamlayabilirsin; '
            'tekrarları kendin takip edersin. Form analizi yalnızca '
            'kamera açıkken çalışır.',
      ),
      FaqEntry(
        question: 'Antrenman sırasında telefonum çalarsa ne olur?',
        answer: 'Antrenman otomatik olarak duraklar ve kamera güvenli '
            'şekilde kapanır. Uygulamaya döndüğünde kaldığın yerden '
            'devam edebilirsin — ilerlemen kaybolmaz.',
      ),
      FaqEntry(
        question: 'İnternet olmadan antrenman yapabilir miyim?',
        answer: 'Evet. Antrenman ve form analizi tamamen cihazında '
            'çalışır. Bağlantı geri geldiğinde tamamladığın günler '
            'otomatik olarak senkronize edilir.',
      ),
    ],
  ),
  FaqCategory(
    title: 'AI KOÇ',
    entries: [
      FaqEntry(
        question: 'Form kimdir?',
        answer: 'Form, FormAI\'ın yapay zekâ koçu. Antrenman geçmişini, '
            'planını ve hedefini bilir; ona her konuda soru '
            'sorabilirsin. Üstteki avatarına dokunarak sohbeti açabilirsin.',
      ),
      FaqEntry(
        question: 'Form neden bazen kısa cevap veriyor?',
        answer: 'Form yalnızca gerçekten bildiği şeyleri söyler. '
            'Elinde veri olmayan bir konuda tahmin yürütmek yerine kısa '
            've dürüst bir cevap verir.',
      ),
      FaqEntry(
        question: 'Form sağlık tavsiyesi verebilir mi?',
        answer: 'Hayır. FormAI bir antrenman ve beslenme asistanıdır, '
            'tıbbi cihaz değildir. Bir sağlık sorunun, ağrın ya da '
            'kronik rahatsızlığın varsa mutlaka bir hekime danış.',
      ),
    ],
  ),
  FaqCategory(
    title: 'ABONELİK',
    entries: [
      FaqEntry(
        question: 'Aboneliğimi nasıl iptal ederim?',
        answer: 'Profil → Ayarlar → "Aboneliği İptal Et" adımını izle. '
            'İptal işlemi Google Play hesabın üzerinden tamamlanır. '
            'İptal ettikten sonra dönem sonuna kadar Premium '
            'özelliklerini kullanmaya devam edersin.',
      ),
      FaqEntry(
        question: 'Satın alımımı yeni telefonuma nasıl taşırım?',
        answer: 'Aynı Google hesabıyla giriş yap ve ödeme ekranındaki '
            '"Satın alımları geri yükle" bağlantısına dokun. '
            'Aboneliğin hesabına bağlıdır, cihaza değil.',
      ),
      FaqEntry(
        question: 'Premium olmadan neleri kullanabilirim?',
        answer: '30 günlük antrenman programı, gerçek zamanlı form '
            'analizi, AI koç, kalori ve makro hedefin ve tarif '
            'kütüphanesi ücretsizdir. Premium; kişiselleştirilmiş günlük '
            'beslenme planı ve öğün takibi gibi özellikleri açar.',
      ),
    ],
  ),
  FaqCategory(
    title: 'HESAP & VERİ',
    entries: [
      FaqEntry(
        question: 'Verilerim nerede tutuluyor?',
        answer: 'Kamera görüntüleri cihazından hiç çıkmaz — form analizi '
            'tamamen telefonunda yapılır ve hiçbir görüntü kaydedilmez '
            'veya gönderilmez. Antrenman ilerlemen ve profil bilgin '
            'hesabına bağlı olarak güvenli sunucularda saklanır.',
      ),
      FaqEntry(
        question: 'Hesabımı nasıl silerim?',
        answer: 'Profil → Hesap Ayarları → "Hesabı Sil". İşlem kalıcıdır: '
            'antrenman geçmişin, profil bilgin ve tüm verilerin silinir.',
      ),
      FaqEntry(
        question: 'Misafir olarak kullanıyorum, ilerlemem kaybolur mu?',
        answer: 'Misafir ilerlemesi yalnızca bu cihazda tutulur. '
            'Kaybetmemek için Profil ekranından bir hesap oluştur — '
            'mevcut ilerlemen hesabına taşınır.',
      ),
    ],
  ),
  FaqCategory(
    title: 'BİLDİRİM & DİĞER',
    entries: [
      FaqEntry(
        question: 'Hatırlatma bildirimleri gelmiyor.',
        answer: 'Profil → Hesap Ayarları → "Bildirimler" bölümünden bir '
            'saat seçtiğinden emin ol. Ayrıca telefonunun ayarlarında '
            'FormAI için bildirim izninin açık olduğunu ve pil '
            'optimizasyonunun uygulamayı kısıtlamadığını kontrol et.',
      ),
      FaqEntry(
        question: 'Serim (streak) neden sıfırlandı?',
        answer: 'Seri, takvim günlerine göre hesaplanır ve bir dinlenme '
            'gününe tolerans tanır. Üst üste iki günden fazla ara '
            'verirsen seri yeniden başlar.',
      ),
      FaqEntry(
        question: 'Bir hata buldum, nasıl bildirebilirim?',
        answer: 'Profil → Ayarlar → "Destek & Geri Bildirim" ile bize '
            'doğrudan yaz. Her mesaj okunur ve yanıtlanır — '
            'geri bildirimin FormAI\'ı şekillendiriyor.',
      ),
    ],
  ),
];

/// Flat, lower-cased search over every entry in every category.
/// Returns categories containing at least one match, each pruned to
/// only its matching entries, so the grouped layout survives filtering.
List<FaqCategory> searchFaq(String rawQuery) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return kFaqCategories;
  final results = <FaqCategory>[];
  for (final category in kFaqCategories) {
    final matches = category.entries
        .where((e) => e.searchIndex.contains(query))
        .toList(growable: false);
    if (matches.isNotEmpty) {
      results.add(FaqCategory(title: category.title, entries: matches));
    }
  }
  return results;
}
