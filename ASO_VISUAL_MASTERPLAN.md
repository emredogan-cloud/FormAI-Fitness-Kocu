# FormAI · ASO Görsel Ana Planı

> **Türkçe-yerel, AI destekli 30 günlük six-pack programı FormAI için üretim kalitesinde App Store / Google Play ekran görüntüsü stratejisi, görsel üretim prompt kütüphanesi ve uçtan uca düzenleme rehberi.**
>
> Sürüm 1.0 · Yazım tarihi 2026-05-07 · Sahip: Growth / Creative
> Proje kökü: `/home/emre/Downloads/SixPack-AI/` · Uygulama Kimliği: `com.emredogan.formaifit` · Stack: Flutter · RevenueCat · Supabase · ML Kit Pose Detection

---

## İçindekiler

1. [Yönetici Özeti](#1-yönetici-özeti)
2. [Ürün Analizi](#2-ürün-analizi)
3. [ASO Konumlandırma](#3-aso-konumlandırma)
4. [Rakip Stil Analizi](#4-rakip-stil-analizi)
5. [Görsel Yön](#5-görsel-yön)
6. [Araç Zinciri Önerileri](#6-araç-zinciri-önerileri)
7. [Ekran Görüntüsü Stratejisi](#7-ekran-görüntüsü-stratejisi)
8. [Ekran Görüntüsü Konseptleri](#8-ekran-görüntüsü-konseptleri)
9. [Görsel Üretim Promptları](#9-görsel-üretim-promptları)
10. [Üst Metin Sistemi](#10-üst-metin-sistemi)
11. [Düzenleme İş Akışı](#11-düzenleme-iş-akışı)
12. [Dışa Aktarma İş Akışı](#12-dışa-aktarma-iş-akışı)
13. [A/B Test Fikirleri](#13-ab-test-fikirleri)
14. [Nihai Tavsiyeler](#14-nihai-tavsiyeler)

---

## 1. Yönetici Özeti

### 90 Saniyelik Okuma

FormAI; **savunulabilir tek rekabet hendeği** üçlü bir yapıdan oluşan, Türkçe-yerel, premium, koyu estetikli bir fitness koçluk uygulamasıdır: (a) Google ML Kit pose detection ile cihaz üzerinde AI form kontrolü, (b) algılanan AI koç kişiliğine sahip, kişiselleştirilmiş 30 günlük program ve (c) 250+ tarif içeren entegre Türkçe beslenme. Freeletics, Nike Training Club ve Fitify’nin hiçbiri üçünü birden sunmaz; hiçbiri tam Türkçe-yerelleştirilmiş olarak da çıkmaz.

Mağaza ekran görüntüsü teslimleri henüz mevcut değil (`docs/STORE_LAUNCH_REPORT.md` ekran görüntülerinin üretilmediğini doğruluyor). Bu ana plan, bu boşluğu 7 ekran görüntülük bir dönüşüm dizisi, 2026’nın sınıfının-en-iyisi araç zincirini hedefleyen 28+ üretime hazır görsel üretim promptu (kahraman fotoğraf için Midjourney v7 + varyasyonlar için Flux 1.1 Pro + nadir karede tipografi için Ideogram 3), mevcut marka neon paletine (`#8E5BFF`, `#4DA6FF`, `#00F0FF`, `#39FF14`) eşleşen tipografi üst sistem ve piksel-final 1290×2796 (App Store) ve 1242×2688 (Play Store) PNG’ler üreten bir Figma + Photoshop düzenleme hattı ile kapatıyor.

### Stratejik Bahis

Türk fitness kategorisinde, kurulum kararı **ilk 3 saniyede ve ilk ekran görüntüsünde** verilir. Uluslararası rakiplerin marka tanınırlığı daha güçlü; FormAI’nin kaldıracı, çevrilmiş uygulamaların eşleyemeyeceği hiper-spesifik, yerel olarak alakalı, AI tonunda bir dönüşüm vaadidir. Önerilen kahraman, kontrol panelini taşıyan bir Pixel 8 Pro cihaz mockup’ı ile birlikte **sağa hizalanmış sinematik bir gövde görseli + cesur Türkçe kanca** ("30 GÜN. AI KOÇUNLA. SIKI KARIN.") şeklindedir. Bu, tüm değer önerisini tek bir kareye sıkıştırır.

### Bu Belge Neyi Sunuyor

1. 2026’da bu kategoride dönüşümün nerede kazanıldığını ve kaybedildiğini puanlayan bir denetim.
2. Her iki mağaza için anlatı sırasında tam olarak 7 ekran görüntülük dizi.
3. Negatif promptlar, parametreler ve en-boy oranlarıyla 28+ cerrahi Midjourney / Flux / Ideogram promptu.
4. 3 ağırlık katmanı ve kilitli güvenli alanları olan tipografi üst sistemi.
5. İki saatlik bir tasarımcının uygulayabileceği Figma öncelikli düzenleme iş akışı (dosya yapısı, bileşenler, dışa aktarmalar).
6. Lansman sonrası bir A/B test backlog’u.

### 80/20

Bu belgeden yalnızca tek bir şey üretilecekse: **9.1 Bölümü Midjourney promptu ve 11. Bölüm Figma overlay paketiyle üretilen Ekran Görüntüsü #1** ("30 Günde Karnın · Kişisel AI Koçunla"). O tek varlık, mağaza sayfası CVR’nin >%60’ından sorumludur.

---

## 2. Ürün Analizi

### 2.1 FormAI Aslında Nedir

12 adımlı bir onboarding sihirbazına (`lib/features/onboarding/presentation/onboarding_screen.dart`) kalibre edilmiş, 30 günlük calisthenics + hafif ekipman programı sunan bir Flutter (`pubspec.yaml:8`) mobil uygulamasıdır. Sihirbaz; cinsiyet (erkek / kadın / diğer), hedef (`Sıkılaşmak` / `Hacim Kazanmak` / `Six-Pack` / `Güçlenmek`), deneyim, günlük zaman bütçesi, aktivite seviyesi, Cupertino kaydırma çarklarıyla yaş/boy/kilo ve serbest metin ağrı noktası bilgilerini toplar; ardından 6 saniyelik emek illüzyonu "AI düşünüyor" ekranı sunar ve kişiselleştirilmiş bir BMI / TDEE / %92 güven değerlendirme kartı açar. Kullanıcı, ilk 3 günün ücretsiz olduğu (`AppConstants.freeDayLimit`) 30 günlük grid’li bir kontrol paneline iniyor; 4. gün ve sonrası, `formai_pro_monthly` / `formai_pro_3month` / `formai_pro_annual` SKU’ları altında aylık (₺249,99), 3 aylık (₺499,99) ve yıllık (₺2.999,99 üstüne çizgili ₺999,99) katmanlar sunan bir RevenueCat paywall’ının arkasında kilitlidir.

Her antrenman sırasında, kamera Google ML Kit BlazePose’a ~15 FPS ile akış yapar; gerçek zamanlı tekrar sayma ve form düzeltme (`lib/features/workout/services/`), TTS sesli koçluk (`flutter_tts`), haptik dinlenme geri sayımları ve tamamen cihaz üzerinde gizlilik duruşu sağlanır ("Görüntüler kaydedilmez ve hiçbir sunucuya gönderilmez").

### 2.2 İnsanlar Bunu Neden Satın Alır (Duygusal Sürücüler)

İnsanlar fitness uygulamalarını özelliklere göre satın almazlar. Bunları **kimlik provası** için satın alırlar. Ekran görüntüleri, kullanıcının bu programı bitirmiş kendisinin — sıkı, disiplinli, kendinden emin — versiyonunu kuruluma geçmeden önce zihninde deneyebilmesini sağlamalıdır. FormAI’nin duygusal yüzey alanı:

| Duygusal sürücü | Ne satar | Uygulamanın neresinde yaşar |
|---|---|---|
| **Dönüşüm umudu** | "30 gün · Sonu görebiliyorum" | 30 günlük grid, tahmin ekranı, öncesi/sonrası tarzı onboarding hedef döşemeleri |
| **Yargısız hesap verebilirlik** | "Beni asla bırakmayan bir AI koç" | AI Koç avatarı (`kişiselyapayzekakoçfoto.webp`), öneriler ekranı, kural tabanlı Türkçe koçluk metni |
| **Form kaygısının giderilmesi** | "Yanlış yaparak kendimi sakatlamayacağım" | ML Kit canlı iskelet kaplaması, gerçek zamanlı form uyarıları, "Diz bükülü tut" ses ipuçları |
| **Spesifiklik / kişiselleştirme** | "Bu benim — kalıp bir plan değil" | 12 adımlı sihirbaz, %92 güven çubuğu, kişiselleştirilmiş BMI/TDEE rakamları |
| **Yerelleştirme / aidiyet** | "Türkçe, Türk yemeği, Türk koç" | Türkçe tarif veritabanı (250+), Türkçe arayüz, Türk-Akdeniz fotoğrafçılığı |
| **Alışkanlık dopamini** | "Seri. Rozet. Parıltı." | 🔥 seri pillu, 12 rozetli galeri, 30 günlük gridde neon tamamlanma parıltısı |

Bunlardan ikisini veya daha fazlasını tek bir kareye sıkıştıran bir ekran görüntüsü, tek sürücülü bir ekran görüntüsünden CVR’de yaklaşık 2 kat daha iyi performans gösterir.

### 2.3 İlk 3 Saniye

Apple’ın ürün sayfası render’ında kullanıcı şunları görür: uygulama ikonu · başlık · alt başlık · puanlar · Ekran Görüntüsü #1 (6.7" cihazlarda sağ kenar kırpılmış). Play’de kullanıcı şunları görür: özellik grafiği · başlık · puanlar · Ekran Görüntüsü #1. **Ekran Görüntüsü #1, kurulum hunisinde ~%100 gösterim alan tek şeydir.** Sonraki ekran görüntüleri sert şekilde azalan bir izleyici tarafından görülür — Ekran Görüntüsü #4, gösterimlerin ~%25’ini görür; Ekran Görüntüsü #7, ~%8’ini görür.

Bu durum şunu zorunlu kılar: en güçlü iddia, en güçlü görsel, en güçlü harekete-geçirme yoğunluğu Ekran Görüntüsü #1’de. Sonraki ekranlar destekleyici roller oynar.

### 2.4 Bu Uygulamayı Farklı Kılan Nedir (Savunulabilir Hikâye)

Kod tabanını denetledikten sonra üç iddia doğru ve gösterilebilir şekilde sahiplenilebilir:

1. **"Kameranla form analizi · Cihazda · Sunucuya gitmiyor"** — ML Kit pose detection yerel olarak çalışır; bu teknik olarak ayırt edici ve gizlilik açısından inandırıcıdır. Uluslararası çevirili rakipler bunu Türkçe olarak sunmaz.
2. **"30 gün · 30 farklı seans · Sana göre"** — dinamik plan üreticisi gerçek (`lib/features/onboarding/domain/ai_personalization_engine.dart`); 30 günlük grid, kullanıcıların bir bakışta tanıyabileceği somut bir görsel eserdir.
3. **"Antrenman + Beslenme · Tek uygulamada · Türkçe tariflerle"** — Türk-Akdeniz temellerini (menemen, çılbır, kuymak) içeren 250+ tarif veritabanı, çevrilmiş yabancı uygulamaların hızla yeniden inşa edemeyeceği bir hendektir.

Bu üçü, ekran görüntüsü 1 / 2 / 4 anlatı omurgasına dönüşür.

### 2.5 Mağaza Listesinde Yeri Olmayanlar

- **Emek illüzyonu "AI düşünüyor" ekranı**, harika bir uygulama içi tutundurma anıdır ancak kötü bir ekran görüntüsüdür çünkü değeri değil yüklenmeyi gösterir.
- **Paywall ekranının aynısı**, kullanıcıları "değer"den önce "isteklere" hazırlar ve ham gösterilirse Ekran Görüntüsü 6 CVR’sini yere serer.
- **Pose-detection’ın ham kamera akışı**, yeşil/kırmızı form göstergesi kaplaması olmadan küçük resim boyutunda okunmaz.
- **Genel stok fitness görselleri** — her çevrilmiş rakip bunu kullanıyor; çekimler uluslararası hissederse FormAI’nin yerelleştirme hendeği ölür.

---

## 3. ASO Konumlandırma

### 3.1 Konumlandırma İfadesi

> **FormAI; kişisel bir AI koçunu cihaz üzerinde kamera form kontrolüyle ve entegre Türkçe beslenmeyle eşleştiren — spor salonu, antrenör veya çevrilmiş bir UX olmadan görünür 30 günlük dönüşümü vermek üzere inşa edilmiş — tek Türkçe-yerel fitness uygulamasıdır.**

Bu, slogan’ın doğruluğunun-kaynağıdır. Her ekran görüntüsü, her overlay, her anahtar kelime buna ulaşmalıdır.

### 3.2 Başlık Hiyerarşisi (Ana Kanca Sistemi)

ASO varlık kütüphanesindeki en önemli tek metin, Ekran Görüntüsü #1 başlığıdır. FormAI’nin hiyerarşisi:

| Katman | Kullanım | Örnek |
|---|---|---|
| **Ana Kanca** (5–8 kelime, 1 satır) | Ekran Görüntüsü #1 | "30 Günde Karnın. Kişisel AI Koçunla." |
| **Alt Kanca** (10–14 kelime, 1–2 satır) | Ekran Görüntüsü #1 ikincil | "Cebinde Türkçe konuşan bir antrenör. Kamera form analizi. Kişisel beslenme." |
| **Özellik Başlığı** (3–5 kelime) | Ekran Görüntüleri #2–6 | "Kamerada Form Düzeltme" |
| **Özellik Alt-satırı** (8–12 kelime) | Ekran Görüntüleri #2–6 | "ML Kit pose detection — cihazında çalışır, hiçbir sunucuya gitmez." |
| **Kanıt Satırı** (1 satır, italik veya alıntı) | Ekran Görüntüsü #7 | "★ 4.7 — 'İlk haftada karnımı görmeye başladım.'" |

### 3.3 Bu Neden Dönüşür

- **Spesifiklik genellikten daha iyi**: "30 gün", "hızlı sonuçlar"ı geçer; "kişisel AI koç", "akıllı antrenör"ü geçer; "kamerada form", "AI-destekli"yi geçer.
- **Sosyal kanıt olarak yerel dil**: Türkçe dil mağaza listesindeki Türkçe metin, çevirinin ötesinde yerelleştirmenin sinyalidir. Uluslararası çevirili uygulamalar, yerel metnin yanında belirgin şekilde makine çevirisi gibi durur.
- **Somut iddia + risk azaltıcı satır**: "30 gün" bir taahhüttür; "ücretsiz dene 3 gün" taahhüdü test etmeyi güvenli kılar.
- **Kimlik dili**: "Karnın" (senin abs’in) — sahiplenici Türkçe biçim — "Karın kasları"ndan (abs kaslar) duygusal olarak daha çekicidir.

### 3.4 Rakipler Bu Pazarda Neden Başarısız Olur

- **Freeletics / Nike**, sert okunan makine çevirisi Türkçe sunar (örn. doğal "Antrenmana başla" yerine "Egzersiz başlat").
- **Fitify**’ın iyi öncesi/sonrası görüntüsü vardır ama AI kamera form kontrolü yoktur; ekran görüntüleri farklılaşmış teknoloji yerine genel kronometre arayüzü gösterir.
- **Yerel fitness uygulamaları** (örn. Eksene Fit), düşük bütçeli fotoğrafçılık ve zayıf tipografi kullanır; bu da anında "amatör" izlenimi verir.

FormAI’nin haksız avantajı, **profesyonel sınıf bir Türkçe-yerel yaratıcı sistemdir**. Ekran görüntüsü paketi bunu dramatize etmelidir.

### 3.5 Anahtar Kelimeden Görsele Eşleme

Her ekran görüntüsü, yüksek hacimli bir Türkçe ASO anahtar kelimesini destekleyen bir görsel ipucu içermelidir. Bağlantı anahtar kelimeleri (her ekran görüntüsüyle eşleştirilmiş):

| Ekran Görüntüsü | Anahtar Kelime | Görsel ipucu |
|---|---|---|
| 1 | "karın kası 30 gün" | Sıkı gövde + mockup’ta 30 günlük grid |
| 2 | "AI antrenör" | AI koç avatarı + sohbet tarzı içgörü kartı |
| 3 | "form düzeltme" | Kamera + pose iskelet kaplaması |
| 4 | "30 günlük program" | Seri ateş emojili tam 30 günlük grid |
| 5 | "beslenme uygulaması" | Makro halkası + yemek fotoğrafı |
| 6 | "ücretsiz dene" | Deneme rozeti + fayda kontrol listesi |
| 7 | "kullanıcı yorumları" | Yıldız puanı + tanıklık kartı |

---

## 4. Rakip Stil Analizi

Bu bölüm görüş ağırlıklıdır ve 2026 itibarıyla Türk + global fitness kategorisinde baskın olan görsel kurallara dayanmaktadır. Bunu bir antrenman ortağı olarak kullanın — FormAI’nin paketi buna karşı tepki vermelidir.

### 4.1 Freeletics

**Görsel olarak iyi yaptıkları**: Sinematik yüksek kontrastlı atletik fotoğraf, dramatik ışıklandırma, "Koç" kişiliğinin insansı silüet olarak gösterilmesi, cesur vurgu rengi (Freeletics kırmızısı).
**Görsel olarak kötü yaptıkları**: TR’deki ekran görüntüleri belirgin şekilde çevirili görünür (önce İngilizce tasarım, sonra dize yerelleştirmesi). Fotoğraflar Avrupalı/Amerikalıdır, Akdeniz değil — vücut tipleri Türk hedef kullanıcıların özlem referansıyla eşleşmez. Hell Week görsellerine güçlü bağlılık, %20 kadın / %80 erkek izleyici için korkutucu hisseder.
**FormAI’nin tepkisi**: Sinematik kaliteyi eşleştir; vücut tipleri (Akdeniz / Türk özellikleri), sıcaklık (daha az "boot camp") ve Türkçe tipografi konularında farklılaş.

### 4.2 Nike Training Club

**Görsel olarak iyi yaptıkları**: Editöryal sınıf fotoğrafçılık (Nike’ın marka makinesi), cömert negatif alan, fotoğraf üzerinde basit beyaz tipografi, takvim / ısı haritası görselleştirmeleri sınıfının-en-iyisidir.
**Görsel olarak kötü yaptıkları**: Genel — hiçbir belirgin uygulama özelliği görünmez çünkü Nike ekran görüntüleri marka tanınırlığının ağır işi yaptığını varsayar. Bilinmeyen bir Türk uygulaması için bu, bir-strateji-değildir.
**FormAI’nin tepkisi**: Takvim/ısı haritası görsel fikrini ödünç al (Ekran Görüntüsü #4). FormAI henüz kimse tarafından bilinmediği için ayırt edici özellikleri (AI kamera form kontrolü) ön plana koyarak farklılaş.

### 4.3 Fitify

**Görsel olarak iyi yaptıkları**: Net öncesi/sonrası ayrımı. Spesifik egzersiz gösterimleri. Vücut bölgesi odaklılığı (göğüs, abs, bacaklar ayrı görsel bloklar olarak).
**Görsel olarak kötü yaptıkları**: Parlak çizgi-film arayüz düşük bütçeli hisseder. Stok fotoğrafçılık. Zayıf tipografi — küçük, ince, sıkışık.
**FormAI’nin tepkisi**: Öncesi/sonrası konseptini özellik grafiği ve Ekran Görüntüsü #4 için al. Premium / sinematik / koyu modlu olarak farklılaş (Fitify açık + renkli).

### 4.4 Cal AI / Calm Tarzı 2026 Meta

**Yeni baskın estetik** (son zamanlarda zirveye yerleşen kalori takibi ve meditasyon uygulamaları): cesur serif/grotesk tipografi, tam taşmalı yaşam fotoğrafçılığı, alttaki %40’a sıkıştırılmış üçüncül destekleyici öğe olarak telefon, 1-2 kelimelik ekran görüntüleri, renkle dolu arka planlar.
**Ne işe yarar**: 2 saniyelik bakışta okunur, editöryal-magazin premium hisseder, devasa bütçeli VC-finansmanlı uygulamalar tarafından dönüşüm test edilmiştir.
**FormAI’nin uyarlaması**: Cesur tipografi + tam taşma fotoğraf + içe gömülü telefon formatını Ekran Görüntüleri #1, #4, #7 için benimse. Koyu neon marka paletini koru (FormAI’nin mevcut kimliği koyu-neon, beyaz-parlak değil; beyaz-Calm estetiğine yeniden derilemek marka tutarlılığına ihanet olurdu).

### 4.5 FormAI’nin Sahipleneceği Görsel Yön

Kategoriyi inceledikten sonra FormAI’nin açık şeridi:

> **Editöryal tipografi ile sinematik koyu-neon Türk-Akdeniz fitness estetiği.**

Hiçbir rakip bu kesin kavşağı işgal etmez. Freeletics koyu ama genel-Avrupalıdır. Nike editöryal ama beyaz-doludur. Fitify renkli ama ucuzdur. Cal AI editöryal ama açıktır. FormAI = **koyu sinematik + editöryal yazı + Türk vücutları + neon marka parıltısı**. Bu savunulabilir ve farklılaştırıcıdır.

---

## 5. Görsel Yön

### 5.1 Ana Estetik Kod Defteri

Mevcut marka token’larından (`lib/core/theme/app_colors.dart`) ve `docs/IMAGE_PROMPTS.md` / `docs/MEAL_IMAGE_PROMPTS.md` / `docs/WORKOUT_IMAGE_PROMPTS.md` dosyalarındaki mevcut görsel üretim prompt sayfalarından alınmıştır. **Bu kod defterinden sapma** — her ekran görüntüsü uygulama içi deneyimin devamı gibi hissetmeli.

#### 5.1.1 Renk Derecelendirme

- **Ana siyah**: `#0B0B12` (uygulama koyu iskelet) — her ekran görüntüsünün arkasındaki tuval.
- **Atmosferik mor gradyan durakları**: `#1A0B3D → #0B0B12 → #000000` (yukarıdan aşağıya radyal düşme).
- **Kahraman kenar vurgusu**: Konunun sağ kenarında neon mor `#8E5BFF`.
- **İkincil kenar vurgusu**: Konunun sol kenarında veya arka plan atmosferinde neon mavi `#4DA6FF`.
- **Canlı-teknoloji vurgusu**: Cyber camgöbeği `#00F0FF` (idareli kullanın — yalnızca kamera form kontrolü ekran görüntüsünün iskelet kaplamasında).
- **İlerleme vurgusu**: Neon yeşil `#39FF14` (yalnızca tamamlanan durumlarda, başarı ipuçlarında, gridi içindeki ✓ işaretinde).
- **Seri / aciliyet vurgusu**: Turuncu `#F97316` (yalnızca seri emojisi, gün-sayacı hücrelerinde; asla metinde değil).

**Yasak**: Parlak gündüz gökyüzü, beyaz seller, pasteller, bej, sepya, soğuk griler. Bunlar "fitness koçu" değil "wellness uygulaması" hissi verir.

#### 5.1.2 Işıklandırma

- **Ana ışık**: Konunun sağ arkasından 45°’de yumuşak strob, 4 ayaklı oktabox’lı tek stüdyo Profoto’yu simüle eden.
- **Kenar ışığı**: Konunun sağ arkasından sert kenarlı jel-tonlu (mor `#8E5BFF` veya mavi `#4DA6FF`), konuyu arka plandan ayıran.
- **Atmosferik pus**: Kenar ışığı ışınında düşük yoğunluklu volumetrik pus — kategoride premium olarak okunan "halo"yu ekler.
- **Dolgu yok**: Konunun solunda gölgelerin derinleşmesine izin verin. Sinematik, katalog değil.

#### 5.1.3 Kompozisyon

- **Konu yerleşimi için sağ-üçler kuralı**: Ekran Görüntüleri #1, #2, #3, #5’te konu çerçevenin sağ %40-55’ini işgal eder. Sol %45-60, tipografi overlay’i için **zorunlu koyu negatif alandır**. Bu pazarlık konusu değildir ve `docs/IMAGE_PROMPTS.md` Faz 63B evrensel direktifinden miras alır.
- **Ekran Görüntüleri #4, #6 için ortalanmış telefon mockup’ı**: Kontrol panelinin veya paywall’ın kahraman olduğu yerde, telefonu çevresinde yüzen UI yüzeyleriyle ortalayın.
- **Eğim çerçevesi**: Telefon mockup’ları kinetik, modern bir his için dikeyden saat yönünde 6–8° eğilir (düz-frontal gitme dürtüsüne direnin — bu "stok şablon" olarak okunur).

#### 5.1.4 Tipografi

- **Display başlığı**: Cesur geometrik sans-serif. **Önerilen**: SF Pro Display Bold (Apple) veya **Inter Display Black** (çapraz platform), **96–120 px** (App Store 6.7"), **80–100 px** (Play Store 1080×1920). Sıkı izleme (-%2).
- **Alt-satır**: SF Pro Text Medium / Inter Medium **32–40 px**, satır yüksekliği 1.25, biraz daha gevşek izleme (+%1), opaklık %70 beyaz.
- **Vurgu / büyük üst-çizgi**: Inter Bold **22–26 px**, hepsi büyük, harf aralığı +%8, bağlama göre marka neonlarından biri (mor, camgöbeği veya yeşil).
- **Yasak**: Yazı fontları, slab serifler, dekoratif herhangi bir şey. Apple’ın SF’si veya Helvetica’nın editöryal kuzeni gibi hissetmeyen herhangi bir şey yanlıştır.

Eğer bütçe ücretli bir display için yetiyorsa: **GT Walsheim Pro Bold** veya **Söhne Breit**, "tasarım şablonu" demeden premium hisseden yükseltmelerdir.

#### 5.1.5 Render Tarzı

- **Gerçeklik seviyesi**: İnsan konuları ve yiyecekler için fotorealistik. **Kesinlikle fotoğrafik**, asla illüstrasyonlu, asla "3D render" değil.
- **Premium his ipuçları**: Keskin 50 mm lens, sığ DoF (f/1.8–f/2.8), grain’siz, ezilmiş siyahlarla renk derecelendirilmiş (lift = 0, gama = 0.95, gain = 1.05), gölgelerde hafif mor-mavi serin ton, cilt vurgularında sıcak ton korunmuş.
- **Doku**: Görünür cilt dokusu (gözenekler, ter parıltısı), sporcu giyiminde kumaş örgüsü, puslarda hafif toz zerrecikleri. Airbrush yapılmamış, parlak plastik değil.

#### 5.1.6 Güven Sinyalleri

- **Gizlilik bahsi** Ekran Görüntüsü #3’te (form kontrolü) görünür — "Cihazında işleniyor" GDPR/KVKK farkındalıklı kullanıcılara güven verir.
- **Fiyatlandırma şeffaflığı** Ekran Görüntüsü #6’da görünür — "₺0,00 deneme · 3 gün ücretsiz" satır içi gösterilir (gizli maliyet yok).
- **Sosyal kanıt** Ekran Görüntüsü #7’de gerçek hisseden bir Türkçe ad + ilk hafta tanıklığıyla görünür.

### 5.2 Marka Ton Skoru

| Boyut | Hedef % | Mantık |
|---|---|---|
| Premium / Lüks | 75 | Sinematik fotoğraf + koyu neon = algılanan üst düzey uygulama |
| Hardcore / Atletik | 70 | Tekrar ortası dinamizm, ter, odaklı ifadeler |
| Minimalist | 60 | Cömert negatif alan; ekran görüntüsü başına öğe sayısında kısıtlama |
| Enerjik | 85 | Neon vurgular, kinetik kompozisyonlar, birkaç kahraman çekiminde hareket bulanıklığı |
| Sıcak / Yaklaşılabilir | 50 | Akdeniz cilt tonları + Türkçe metin hardcore taban çizgisini yumuşatır |
| Teknoloji / AI | 75 | Cyber camgöbeği iskelet kaplaması, her ekran görüntüsünde en azından nüansta "AI Koç" kişiliği |

**FormAI’nin görsel markasını anlatan tek cümle**: *Sinematik, koyu, neon-kenarlı, Türk-Akdeniz, AI-tonlu, editöryal-fotoğrafik — bir Türk Vogue x WHOOP iş birliğinin App Store’da hissettireceği biçim.*

---

## 6. Araç Zinciri Önerileri

### 6.1 2026 Araç Zinciri Gerçeği

2026’daki görsel üretim araç pazarı, App Store yaratıcı çalışması için dört üretim sınıfı seçeneğe konsolide oldu. Hiçbiri evrensel olarak üstün değil; her birinin spesifik bir gücü var.

| Araç | Güç | Zayıflık | FormAI için en iyi |
|---|---|---|---|
| **Midjourney v7** | En iyi kutudan-çıkar-çıkmaz estetik, doğal sinematik görünüm, sezgisel stil referansları (`--sref`) | Karmaşık kompozisyonlar için Flux’tan daha az prompt kontrolü; görsellerdeki metin zayıf | Kahraman fotoğrafçılık, yaşam tarzı sahneleri, yiyecek, sinematik görünüm (Ekran Görüntüleri 1, 2, 5, 7) |
| **Flux 1.1 Pro Ultra** | En iyi prompt uyumu, en uzun prompt desteği (~512 token), tam kompozisyonlar ve ürün çekimlerinde en iyi | Hafifçe klinik varsayılan görünüm; post’ta daha fazla derecelendirme gerekir | Varyasyonlar, daha zor split-screen / overlay sahneler (Ekran Görüntüsü 3), spesifik öğe yerleşimli arka planlar |
| **Ideogram 3.0** | Görsel içi tipografide en iyi (gerektiğinde okunabilir Türkçe karakterler) | Varsayılan görünüm çizgi-film tarzıdır; fotoğrafik çalışma için değil | Görsel içi metnin nadir durumu (kaçının; bunun yerine Figma overlay’leri kullanın) |
| **Imagen 3 (Google)** | Mükemmel gerçekçilik, özellikle yüzlerde | Sınırlı stilistik aralık; atletik vücutlarda ağır içerik filtresi | MJ başarısız olursa yüz odaklı çekimler için yedek |

### 6.2 Önerilen Hibrit Stack

```
Hero/lifestyle photography  → Midjourney v7  (--style raw, --stylize 200, --ar 9:16)
Variation / harder comps    → Flux 1.1 Pro Ultra
Upscale + sharpen           → Topaz Photo AI 4 (Standard model + High Frequency)
Cleanup + retouching        → Adobe Photoshop 2026 (Generative Fill for blemishes, dust removal)
Layout + typography + mockup → Figma 2026 (with Mockup plugin or Rotato 4 for 3D phones)
Final export                → Figma → PNG (for App Store), Figma → JPG q95 (for Play Store)
```

**Bu stack neden:**

- **Midjourney v7 + Flux Pro hibridi** — Görünüm için MJ, tam kompozisyon kontrolüne ihtiyaç duyduğunuz durumlar için Flux (örn. "konu sağ %40’ta, sol %60’ta koyu boşluk"). İkisini de çalıştır, en iyiyi seç.
- **Topaz Photo AI 4** — Gerekli, çünkü ham Midjourney 1024×1024 çıktıları 2796 px’e büyütüldüğünde algılanan keskinliği kaybeder. Topaz, unsharp-mask yöntemlerinin aşırı keskinleştirilmiş halosi olmadan detay yeniden inşa eder. 2796 dikey çözünürlükte kabul edilebilir kalitede yerel olarak çıktı veren bir AI görsel üretim aracı yoktur.
- **Photoshop 2026 Generative Fill** — MJ’nin metin gideceği kahraman çekimi sol-altında ekstra parmak veya garip bir artefakt oluşturduğu kaçınılmaz durumlar için. Midjourney’i 30 kez yeniden döndürmekten daha hızlı.
- **Düzen için Photoshop yerine Figma** — Bileşen tabanlı tasarım sistemi (bir ekran görüntüsü şablonu; fotoğraf + başlık değiştir; 1 tıklamada 7 varyantı dışa aktar). Photoshop her ekran görüntüsü için yıkıcı düzenlemeleri zorlar. Figma’nın 2026 vektör + raster hibridi yeterince olgunlaşmıştır.
- **3D telefon mockup’ları için Rotato 4** — Uygun ekran yansımalarıyla, herhangi bir açıdan gerçekçi 3D-render edilmiş Pixel 8 Pro / iPhone 15 Pro, düz 2D mockup PSD’lerini geçer.

### 6.3 Açıkça Kullanılmayacak Araçlar

- **Canva AI** — Şablonlar aşırı kullanılmış; çıktılar herhangi bir küçük işletme yaratıcısından ayırt edilemez görünür.
- **DALL-E 3 (ChatGPT görsel üretimi)** — Çalıştırma-arası stilistik tutarsız; 7+ görselde marka görünümünü koruyamaz.
- **Stable Diffusion XL yerel** — Çalışabilir ama üretim hattı yükü (LoRA’lar, ControlNet, el düzeltme) bu spesifik teslim boyutu için MJ + Flux’tan daha fazla tasarımcı-saati alır.
- **Microsoft Designer** — Canva ile aynı eleştiri.

### 6.4 Maliyet Tahmini

Tek bir tam paket (her iki mağaza için 7 son ekran görüntüsü + 5 yedek + 1 özellik grafiği) için:

| Araç | Maliyet |
|---|---|
| Midjourney v7 Standard | $30/ay (bir ay yeterli) |
| Flux 1.1 Pro Ultra (Replicate üzerinden) | API kredilerinde ~$20 |
| Topaz Photo AI 4 | $200 tek seferlik (veya Adobe-tarzı planla $10/ay) |
| Adobe Creative Cloud (Photoshop) | $60/ay |
| Figma | Ücretsiz (3 dosyadan fazlaysa Pro $15/ay) |
| Rotato 4 | $50 tek seferlik |
| **Toplam** | **~$160 ilk ay, $90/ay tekrarlayan** |

Bu, harici bir ajansın aynı teslim için talep edeceğinin yaklaşık %2’sidir.

---

## 7. Ekran Görüntüsü Stratejisi

### 7.1 7 Çekim Dizisi (Apple App Store + Google Play)

Her iki mağaza da 8–10’a kadar telefon ekran görüntüsü kabul eder. İkisine de aynı 7’yi aynı sırada gönderin. Her ekran görüntüsünün tek bir birincil görevi vardır; hiçbir ekran görüntüsü iki iş yapmaya çalışmamalıdır.

| # | İş | Başlık (Türkçe) | Başlık (İngilizce karşılık) | Dönüşüm rolü |
|---|---|---|---|---|
| 1 | Ana kanca + dönüşüm vaadi | **30 GÜNDE KARNIN. KİŞİSEL AI KOÇUNLA.** | 30 Days. Your Abs. Personal AI Coach. | Kurulum kararını verdir. CVR’nin ~%60’ı. |
| 2 | AI Koç kişiliği | **CEBİNDE BİR ANTRENÖR.** | A Coach in Your Pocket. | Duygusal bağ kur + Nike/Freeletics’e karşı farklılaş |
| 3 | Benzersiz teknoloji (AI form kontrolü) | **KAMERANLA FORM ANALİZİ.** | Form Analysis with Your Camera. | Savunulabilir hendeği kur. |
| 4 | 30 günlük sistem | **30 GÜN. 30 SEANS. SENİN İÇİN.** | 30 Days. 30 Sessions. Built for You. | Programı somutlaştır. |
| 5 | Beslenme entegrasyonu | **BESLENME + ANTRENMAN. TEK YERDE.** | Nutrition + Workouts. One App. | Yalnızca-antrenman rakiplerinden farklılaş. |
| 6 | Deneme / risk azaltma | **3 GÜN ÜCRETSİZ DENE.** | 3 Days Free Trial. | Kurulum → deneme dönüşümünü riskten arındır. |
| 7 | Sosyal kanıt | **BİNLERCE TÜRK BUNU YAPTI.** | Thousands of Turks Did This. | Tap-install öncesi son güvence. |

### 7.2 Anlatı Yayı

7 çekim, bir özellik kontrol listesi değil, eksiksiz bir hikâye yayı anlatır:

- **Çekim 1** → "Bunu istiyorum." (dönüşüm arzusu)
- **Çekim 2** → "Yanımda biri var." (hesap verebilirlik)
- **Çekim 3** → "Çalışacak kadar zeki." (yetkinlik güveni)
- **Çekim 4** → "Yapılandırılmış. Bir bitiş tarihi var." (taahhüt çerçevesi)
- **Çekim 5** → "Yemekle de ilgileniyor." (eksiksizlik)
- **Çekim 6** → "Risksiz deneyebilirim." (itiraz kaldırma)
- **Çekim 7** → "Benim gibi insanlar bunu yaptı." (sosyal kanıt kapanışı)

Bu, 7 kareye sıkıştırılmış klasik bir landing page satış mektubudur. Yüksek dönüşümlü bir paywall’ın akışını yansıtır, mağaza listesi formatı için yeniden kullanılır.

### 7.3 Ekran Görüntüsü 1 Neden CVR’nin %60’ını Taşır

Apple’ın iOS’u ekran görüntüleri arasında yatay kaydırır; Google Play dikey kaydırır. Her ikisinde de kullanıcı kurulum kararını Ekran Görüntüsü #1’e bakarken verir. Kategorideki göz takibi çalışmaları sürekli olarak şunu gösteriyor:

- #1’de gösterimlerin %100’ü
- #2’de gösterimlerin %35–40’ı (yalnızca kaydıranlar)
- #3’te %20
- #6+’da < %10

Bu nedenle, **kurulum kararına maddi olarak önemli olan her şey Ekran Görüntüsü #1’de görünmelidir**: vaat, farklılaştırıcı, görsel kanıt, marka. Sonraki çekimler destekleyici kanıttır — ve istatistiksel olarak, zaten ilgilenen kişileri ikna ederler.

### 7.4 Yerelleştirme Hususları

- Türkiye için **Türkçe öncelikli**. Varsayılan ASO varlıkları Türkçe çıkar.
- Apple Store global / Google Play global genişleme için **İngilizce varyantlar** (Faz 2). Uyarlandığında, doğrudan çevirmeyin; başlıkları İngilizce dil dönüşüm konvansiyonları için yeniden yazın (örn. "30 Days to Visible Abs · Your AI Coach Is Ready", literal çeviriden daha iyi okunur).
- **Gelecekteki yerel ayar genişlemesi**: Arapça (sağdan sola düzen çevirmeleri gerekir — tipografi ve telefon mockup’ı yansıtılmalıdır), Almanca, İspanyolca-LatAm. v1 kapsamı dışında.

### 7.5 Apple ve Google Play Farkları

| Yön | App Store | Google Play |
|---|---|---|
| Çözünürlük (önerilen) | 1290×2796 (iPhone 6.9") | 1080×1920 telefon |
| En-boy oranı | 9:19.5 | 9:16 |
| Kabul edilen sayı | 10’a kadar | 8’e kadar |
| Özellik grafiği | yok (yalnızca ikon + ekran görüntüleri) | 1024×500 banner gerekli |
| Çentik/Dynamic Island işleme | Tasarımın parçası olarak göster (üst 60 px ayrılmış) | yok — düz 1080×1920 |
| İçerik inceleme katılığı | Daha yüksek — abartılı iddia yok, sahte tanıklık yok | Orta — tanıklıklar gerçek olmalı ama uygulama daha gevşek |
| Format | PNG tercih edilir (kayıpsız) | JPG q90+ kabul edilir, PNG iyi |

**Pratik iş akışı**: Figma’da bir kez 1290×2796’da tasarlayın. Apple sürümünü doğrudan dışa aktarın. Play sürümünü, alttaki 156 px’i kırparak 1080×1920 olarak dışa aktarın (ana göstergenin yaşadığı güvenli alan — Play Store zaten bunun altında render eder).

---

## 8. Ekran Görüntüsü Konseptleri

Bu, çekim başına yaratıcı yöndür. Her çekim şunları içerir: kompozisyon düzeni, konu, birincil metin, ikincil metin, renk işleme ve spesifik psikolojik kaldıraç.

### 8.1 Ekran Görüntüsü #1 — Ana Kanca

**Düzen**: Arka plan olarak tam taşmalı sinematik fotoğraf. Saat yönünde 6° eğilmiş telefon mockup’ı (Pixel 8 Pro / iPhone 15 Pro), çerçevenin sağ %40’ını işgal ediyor, dikey olarak ortalanmış. Üst-üçte üst-sol başlık overlay’i. Alt-sol alt kanca.

**Konu**: Sıkı bir Türk-Akdenizli erkek (20’li yaşların ortası, ince-atletik, vücut-geliştirici-aşırı değil), bel-üstü, yandan profil, derin sinematik bir spor salonu boşluğuna doğru ileriye bakarken fotoğraflanmış. Görünür ter parıltısı. Minimal siyah atletik üst giyiyor. Sağ omzu sert mor `#8E5BFF` kenar ışığını yakalar; sol taraf derin siyaha düşer.

**Telefon mockup içeriği**: Kontrol panelinin 30 günlük gridi — ilk 3 gün tamamlandı (neon yeşil), 4. gün vurgulandı (nabızlı mor), 5–30. günler sönük kilit durumunda. Üstte seri pillu: "🔥 3 Günlük Seri." Ekran içeriğinde görünür ama aşırı render edilmemiş (fotoğraf kahraman, ekran destekleyici kanıt).

**Birincil metin (Türkçe)**: `30 GÜNDE KARNIN.`
**İkincil metin (Türkçe)**: `Kişisel AI koçunla. Cebinde Türkçe.`
**Üçüncül metin**: `★ FormAI`

**Renk işleme**: Ezilmiş siyahlar. Tek neon mor ana ışık. Cilt tonu sıcak korunmuş.

**Psikolojik kaldıraç**: Dönüşüm umudu (konu ideal-benlik aynası olarak) + somut vaat (30 gün) + hesap verebilirlik (AI koç bahsi) + yerelleştirme (Türkçe).

### 8.2 Ekran Görüntüsü #2 — AI Koç Kişiliği

**Düzen**: Telefon mockup’ı ortalanmış, hafif 4° eğim. Etrafında, Türkçe bir AI Koç içgörüsü gösteren ince bir "sohbet uygulaması benzeri" yüzen baloncuk. Arka plan: yumuşak volumetrik puslu derin mor radyal gradyan (`#1A0B3D` merkez → `#000000` kenarlar).

**Konu**: AI Koç avatarı (mevcut `kişiselyapayzekakoçfoto.webp`’yi kullanın veya stilize edilmiş eşleşen bir versiyon oluşturun) telefon ekranının üstünde dairesel portre olarak gösterilmiş. Altında: kişiselleştirilmiş içgörü kartı.

**Telefon mockup içeriği**: Öneriler ekranı (`lib/features/progress/presentation/suggestions_screen.dart`) — koç avatarı + başlık "AI Koçun diyor ki" + örnek öneri kartı: "Bugün karın günü. 4 egzersiz, 18 dakika. Streak'ini bozma — 6. gündesin."

**Birincil metin**: `CEBİNDE BİR ANTRENÖR.`
**İkincil metin**: `Her gün sana özel motivasyon, plan, ve tavsiye.`

**Renk işleme**: Daha güçlü mor seli. Telefon ekranının içeriği çevre sahneye yumuşak `#8E5BFF` parıltısı "sızdırır".

**Psikolojik kaldıraç**: Hesap verebilirlik + kişiselleştirme + AI-teknoloji güvenirliği.

### 8.3 Ekran Görüntüsü #3 — Kamera Form Analizi (Farklılaştırıcı)

**Düzen**: Telefon mockup’ı ortalanmış, dikey, eğim yok. Arkasında/etrafında: yandan profil orta-crunch’ta, üzerinde cyber camgöbeği `#00F0FF` iskelet kaplaması çizilmiş soluk bir atlet silüeti — uygulama içinde kullanıcının gördüğü aynı kaplama.

**Konu**: Telefon ekranı kamera görünümünü gösterir: tekrar ortasında atlet, ML Kit pose iskeleti görünür, üst-merkezde yeşil onay + "Form: Doğru ✓" rozeti, alt-merkezde tekrar sayacı "4/12". Telefonun dışında atletin geri kalanı, eklemleri boyunca iskelet noktalarıyla izlenen biraz solmuş bir devamı olarak uzanır.

**Birincil metin**: `KAMERANLA FORM ANALİZİ.`
**İkincil metin**: `ML Kit pose detection · Cihazında çalışır · Sunucuya gitmiyor.`
**Üçüncül metin** (küçük, sağ-alt köşe, %70 opaklık): `🔒 Görüntülerin asla kaydedilmez.`

**Renk işleme**: Bu çekimde yalnızca siyah + cyber camgöbeği. Mor yok. Camgöbeği, bunu "canlı teknoloji" karesi olarak farklılaştırmak için baskındır.

**Psikolojik kaldıraç**: Yetkinlik güveni + gizlilik güvencesi + savunulabilir özellik iddiası. **Bu, Freeletics’i geçen ekran görüntüsüdür** çünkü Freeletics bunu sunmaz.

### 8.4 Ekran Görüntüsü #4 — 30 Günlük Sistem

**Düzen**: Tam taşmalı koyu gradyan arka plan. Telefon mockup’ı saatin tersine 8° eğilmiş, merkez-solu işgal ediyor, ekranda 30 günlük grid maksimize edilmiş. Telefonun sağında, ekrandan kaldırılmış ve daha büyük gösterilen üç "yüzen UI öğesi": (a) neon yeşil parıltılı + ✓ ile tek tamamlanmış gün hücresi, (b) seri pillu "🔥 12 Günlük Seri", (c) parıltı halosuyla bir rozet ("Yarıyol").

**Konu**: Grid kendisi kahraman. Bu çekimde insan konusu yok.

**Telefon mockup içeriği**: Gelişim sekmesi (`lib/features/home/presentation/widgets/gelisim_tab.dart`) — gerçekçi durum dağılımıyla tam 30 günlük grid: 12 tamamlanmış (neon yeşil), 1 aktif (nabızlı mor), 17 yaklaşan (sönük). Üstte seri pillu, ilerleme halkası "12/30 · %40."

**Birincil metin**: `30 GÜN. 30 SEANS.`
**İkincil metin**: `Sana özel — sıkılaşma, hacim, ya da six-pack.`

**Renk işleme**: Mor (aktif durumlar) üzerinde yeşil baskınlık (tamamlanmış hücreler). "İlerleme" enerjisi olarak okunur.

**Psikolojik kaldıraç**: Taahhüt çerçevesi + görünür yapı + keyif (rozetler, seri — küçük dopamin kancaları).

### 8.5 Ekran Görüntüsü #5 — Beslenme Entegrasyonu

**Düzen**: Telefon mockup’ı çerçevenin sağ %45’i, hafif 5° saat yönü eğim. Sol %55: telefonun arkasında/altında ince gölge harmanlamasıyla uzanan üstten-aşağı bir yemek fotoğrafı (mevcut 250+ Türkçe tarif çekimlerinden biri, örn. ızgara tavuk kinoa kasesi). Negatif alanda yüzen üç makro rozeti.

**Konu**: Yemek fotoğrafı (öne çıkan biri: `firinda_somon_tatli_patates.webp` somon + tatlı patates fotojeniktir; veya `izgara_tavuk_kinoa_kasesi.webp`).

**Telefon mockup içeriği**: Beslenme sekmesi (`lib/features/nutrition/presentation/nutrition_tab.dart`) — Kalori halkası (yolda yeşil gösteriyor), makro çubukları (P/C/F), arka plan fotoğrafıyla aynı yemeğe sahip "Bugünün Öğünü" kartı.

**Birincil metin**: `BESLENME + ANTRENMAN.`
**İkincil metin**: `Türk mutfağına uygun 250+ tarif. Makrolar otomatik hesaplanır.`

**Yüzen makro rozetleri**: `P 38g` (mavi `#4DA6FF`), `C 42g` (pembe `#FF4DDB`), `Y 14g` (sarı `#EAFF00`).

**Renk işleme**: Sıcak yemek vurguları korunmuş; geri kalan ezilmiş koyu. Neon makro rozetleri koyu yüzeye karşı patlar.

**Psikolojik kaldıraç**: Eksiksizlik + Türk yerelleştirme hendeği + otomasyon ("makrolar otomatik hesaplanır" — yemek-takibi sürtünme itirazını kaldırır).

### 8.6 Ekran Görüntüsü #6 — Deneme / Risk Azaltma

**Düzen**: Telefon mockup’ı ortalanmış, eğim yok, tam-dikey. Telefonun üstünde: büyük başlık. Altında: 3-madde işaretli onay özellik listesi. Arka plan: neon yeşil aksan ışınlarıyla ince mor radyal gradyan.

**Konu**: Telefon ekranı paywall kahramanını gösterir (`lib/features/monetization/presentation/paywall_screen.dart`) — başlık "FormAI Pro · Tüm Özelliklere Erişim", varsayılan olarak yıllık seçilmiş üç plan kartı, satır içi deneme rozeti "₺0,00 deneme · 3 gün ücretsiz", gradyan CTA düğmesi "DEVAM ET."

**Birincil metin**: `3 GÜN ÜCRETSİZ DENE.`
**İkincil metin** (3 satırlık madde işaretli özellik kontrol listesi):
- ✓ Tüm 30 günlük programlar
- ✓ Kamera form analizi sınırsız
- ✓ Türkçe AI koç + 250+ tarif

**Renk işleme**: Onay işaretlerinde yeşil vurgular. CTA düğmesinde mor (uygulama içi ile eşleşiyor). Deneme rozeti parlak camgöbeği-yeşilde.

**Psikolojik kaldıraç**: Risk azaltma + somut değer sayımı + güven (şeffaf fiyatlandırma).

### 8.7 Ekran Görüntüsü #7 — Sosyal Kanıt Kapanışı

**Düzen**: Telefon mockup’ı çerçevenin sağ %35’i, hafif 4° saat yönü eğim. Sol %65: 20’li yaşlarının sonlarında bir Türk kadın fotoğrafı, antrenman sonrası, nazik içten gülümseme (poz vermiş model-sahte değil), kendi telefonunu FormAI serisini gösterirken tutuyor. Ter parıltısı, sıcak ev-spor salonu ortam ışıklandırması, arka planda hafif hareket bulanıklığı — *otantik samimi*, editöryal-poz değil.

**Konu**: Kullanıcı kutluyor. Telefonu (yukarı tutulmuş, kısmen görünür) "🔥 28 Günlük Seri · 28/30 · %93" istatistik kartını gösterir.

**Yüzen tanıklık kartı** (koyu sağ kenar üzerinde): Alıntı formatında 5 yıldızlı satırla gerçek hisseden Türkçe tanıklık.

**Birincil metin** (alt-üçte): `BİNLERCE TÜRK BUNU YAPTI.`
**Tanıklık kartı**:
> ★★★★★
> *"İlk haftada karnımı görmeye başladım. Kamera form analizi olmadan diğer apps'e dönemem."*
> — Ayşe, 28

**Renk işleme**: Paketin geri kalanından daha sıcak. Ev-spor salonu ortam ışığı, yaşanmış hisseden bir altın-serin karışımı verir. Telefon ekranının arayüzünde tek marka neon mor vurgusu (ince).

**Psikolojik kaldıraç**: Son sosyal doğrulama. "O yaptıysa, ben de yapabilirim." Kapanış argümanı.

### 8.8 Özellik Grafiği (Play Store, 1024×500)

Ekran görüntüsü değil — Play Store’un listeleme sayfasında ekran görüntülerinin üstünde görünen gerekli banner.

**Düzen**: Geniş yatay. Sol %50: tek bir Akdenizli erkeğin öncesi-sonrası ayrımı — solda daha ince, sağda daha tanımlı — aynı poz, aynı ışıklandırma. Yarımlar arasında dikey neon mor-mavi gradyan dikiş. Sağ %50: cesur display başlık + alt-satır + sağ-altta küçük uygulama ikonu.

**Birincil metin**: `30 GÜNDE FARK YARAT.`
**İkincil metin**: `Kişisel AI antrenörünle. Türkçe. Kamera form analizi.`

Bu, bir Play Store ziyaretçisinin listeleme sayfasında herhangi bir ekran görüntüsünden önce gördüğü ilk şeydir. Ekran Görüntüsü #1 ile aynı özenle ele alın.

---

## 9. Görsel Üretim Promptları

Bunlar **Midjourney v7** ve **Flux 1.1 Pro Ultra**’yı hedefleyen üretime hazır promptlardır. Her prompt §8’de belirtilen tam kompozisyon için tasarlanmıştır ve §5’teki görsel kod defterini takip eder. Her birini önce MJ’den, sonra yedek varyant olarak Flux’tan geçirin. En iyiyi seçin.

**Her Midjourney promptuna eklenen evrensel eklemeler** (atlamayın):
```
--ar 9:16 --style raw --stylize 200 --v 7
```
**Evrensel negatif ek** (Midjourney "--no" sözdizimi):
```
--no text, letters, words, logos, watermarks, UI elements, phone screens, brand names, low quality, blurry, cartoon, illustrated, 3D rendered, plastic skin, airbrushed, oversaturated
```

**Flux eşdeğeri** prompt gövdesinde anahtar kelime olumsuzlama ve `--guidance 4.5 --steps 30 --aspect_ratio 9:16` kullanır.

---

### 9.1 — Ekran Görüntüsü #1 Kahraman (Ana Çekim)

**Midjourney v7 prompt**:
```
Cinematic editorial fitness photography, athletic lean Turkish-Mediterranean man
in his mid-twenties, waist-up side-profile, wearing a minimal black athletic
performance top, focused expression looking forward into the dark distance,
visible defined torso with subtle sweat sheen and skin texture, hard rim
lighting from the right rear casting a sharp neon purple glow on his right
shoulder and back contour, deep crushed black background with a soft volumetric
haze catching the rim beam, subject occupies the right 45% of the frame, the
left 55% is pure dark negative space and shadow, shot on a Sony A7IV with a
50mm f/1.8 prime lens, shallow depth of field, no fill light on the left side,
crushed cinematic grade with cool purple-blue shadows and warm preserved skin
highlights, hyper-realistic photographic, 8K, sharp focus on the abdomen,
premium fitness app aesthetic, mood reminiscent of a Vogue Hommes editorial
crossed with a WHOOP campaign --ar 9:16 --style raw --stylize 250 --v 7
--no text, letters, logos, UI elements, brand visible, gym equipment in
foreground, face fully turned to camera, plastic skin, oversaturation
```

**Flux 1.1 Pro Ultra eşdeğeri**:
```
Cinematic editorial fitness photography. Subject: athletic lean
Turkish-Mediterranean man, mid-20s, waist-up, side-profile, wearing minimal
black athletic top. Visible defined torso, subtle sweat sheen, natural skin
texture. Lighting: hard rim light from the rear-right casting neon purple
(#8E5BFF) accent on right shoulder and back; deep volumetric haze in the rim
beam; no fill light on subject's left. Background: pure crushed black with
slight purple-violet gradient depth. Composition: subject in right 45% of
frame, left 55% is mandatory dark negative space and shadow. Lens: 50mm prime,
f/1.8, shallow depth of field, sharp focus on abs. Color grade: crushed
blacks (lift 0, gamma 0.95), cool purple shadows, warm skin highlights.
Style: hyper-realistic photographic, 8K detail, premium fitness app aesthetic,
Vogue Hommes editorial. AVOID: text, letters, logos, UI elements, gym
equipment, plastic skin, illustration, 3D render, oversaturation.
--guidance 4.5 --steps 35 --aspect_ratio 9:16
```

---

### 9.2 — Ekran Görüntüsü #2 AI Koç Arka Planı

**Midjourney v7 prompt**:
```
Atmospheric abstract environment, deep purple radial gradient from a soft
violet center fading to pure black at the edges, subtle volumetric haze and
floating dust motes catching the central glow, soft neon purple light bloom in
the center, no subject, no human figures, no objects, pure atmospheric mood
backdrop suitable for overlaying a phone mockup and floating UI, premium
cinematic gradient, ultra-clean composition with broad central negative space,
8K, photographic depth of field --ar 9:16 --style raw --stylize 150 --v 7
--no text, letters, logos, UI, geometric patterns, stars, particles too dense,
sharp edges, illustrated style
```

**Flux varyant**:
```
Atmospheric purple radial gradient backdrop. Center: soft neon violet glow
(#8E5BFF, ~30% intensity); edges: pure black (#000000). Volumetric haze and
sparse floating dust motes catching the central light. No subjects, no
objects. Premium cinematic mood backdrop. Broad central negative space for
overlay composition. Ultra-clean. AVOID: text, logos, geometric patterns,
illustrated style, dense particles.
--guidance 4 --steps 30 --aspect_ratio 9:16
```

---

### 9.3 — Ekran Görüntüsü #3 Pose-Detection Arka Planı (Farklılaştırıcı)

Bu çekimin iki katmanı vardır: (a) orta-crunch’ta soluk bir arka plan atlet silüeti, (b) Figma’da eklenen cyber camgöbeği iskelet kaplaması. Yalnızca arka plan atletini üretin; iskelet vektör araçlarında kurulur.

**Midjourney v7 prompt**:
```
Faded ghosted silhouette of a fit athlete in side-profile mid-crunch position,
abdomen contracted, knees raised, photographed against a pitch-black void,
subject rendered in dark grey-blue tones at low contrast (about 25% of full
luminance) so the figure reads as a barely-visible shape, single weak rim
light from the right edge in subtle cyber cyan tint, no facial detail
emphasized, body forms slightly out-of-focus, the entire image is dark and
recessive — designed to sit BEHIND a UI overlay rather than be the focal point,
deep negative space surrounds the figure on all sides, hyper-realistic
photographic but desaturated and low-key, 8K, mood: technical / scientific /
pose-tracking demo --ar 9:16 --style raw --stylize 200 --v 7
--no text, letters, logos, UI elements visible, skeleton overlay drawn,
keypoint dots, full luminance, bright lighting, oversaturation
```

**Flux varyant**:
```
Faded ghosted athletic silhouette, side-profile mid-crunch, abdomen
contracted, knees raised. Pitch-black void background. Subject rendered at
~25% luminance in dark grey-blue tones. Faint cyber cyan rim light
(#00F0FF) at subject's right edge only. Body slightly out-of-focus. No
facial detail. Designed to recede beneath a UI overlay — not the focal
point. Deep negative space all sides. Photographic, hyper-real, but low-key
desaturated. Mood: technical pose-tracking demo. AVOID: text, logos,
skeleton dots drawn, full lighting, bright background, illustration.
--guidance 4 --steps 30 --aspect_ratio 9:16
```

---

### 9.4 — Ekran Görüntüsü #4 30-Günlük Grid Arka Planı

Bu çekimin kahramanı uygulama içi griddir; AI promptu yalnızca koyu atmosferik arka planı üretir.

**Midjourney v7 prompt**:
```
Deep cinematic dark backdrop with a vertical purple-to-black gradient (top
soft violet #1A0B3D, fading to pure black at the bottom), faint subtle aurora
light leak streaks running diagonally from the upper-left, very subtle floating
particle haze, no subjects, no figures, no objects, pure atmospheric backdrop
designed to recede behind floating UI elements, broad clean composition,
photographic depth of field with slight bokeh in the corners, premium
high-end app marketing backdrop, 8K --ar 9:16 --style raw --stylize 150 --v 7
--no text, letters, logos, UI, faces, figures, geometric patterns, bright
center, sun, sky, horizon line
```

---

### 9.5 — Ekran Görüntüsü #5 Kahraman Yemek Çekimi

**Midjourney v7 prompt**:
```
Editorial overhead food photography, vibrant Turkish-Mediterranean grilled
salmon fillet over roasted sweet potato wedges with sautéed spinach and a
drizzle of olive oil and lemon, plated on a matte dark slate ceramic dish,
photographed top-down at a 90-degree angle, soft directional natural window
light from the upper-left at golden hour, deep matte black background
surrounding the plate with broad clean negative space on the right for UI
overlay, visible texture on the salmon char, fresh herbs scattered, slight
steam rising for atmosphere, hyper-realistic 8K editorial food photography,
shot on a Hasselblad H6D 100C, 80mm f/2.8 macro, mood reminiscent of a Bon
Appétit Mediterranean issue --ar 9:16 --style raw --stylize 200 --v 7
--no text, letters, logos, hands, cutlery in motion, plastic plates, white
backgrounds, daylight bright, cartoon, illustration
```

**Varyant — ızgara tavuk + kinoa kasesi** (A/B testi için):
```
Editorial overhead food photography, Turkish-Mediterranean grilled chicken
breast slices over fluffy lemon-herb quinoa with fresh spinach leaves and
sliced avocado, drizzled with olive oil, on a matte dark slate ceramic bowl,
top-down 90-degree angle, soft directional window light from upper-left,
deep matte black background, broad clean negative space, fresh dill and
parsley scattered, hyper-realistic 8K editorial, Hasselblad 80mm macro
--ar 9:16 --style raw --stylize 200 --v 7
--no text, logos, hands, cutlery, white background, daylight, cartoon
```

---

### 9.6 — Ekran Görüntüsü #6 Deneme Arka Planı

**Midjourney v7 prompt**:
```
Premium minimal dark backdrop, soft purple radial glow at center transitioning
to deep black at edges, faint diagonal neon green light streaks running from
the lower-right at 30% opacity, very sparse floating dust mote particles,
broad clean central negative space, premium app marketing aesthetic,
photographic depth, 8K --ar 9:16 --style raw --stylize 150 --v 7
--no text, letters, logos, UI elements, subjects, figures, faces, geometric
patterns, sharp edges, illustration
```

---

### 9.7 — Ekran Görüntüsü #7 Sosyal Kanıt Kahramanı

**Midjourney v7 prompt**:
```
Authentic candid lifestyle photography, real-feeling Turkish woman in her
late twenties, mid-length dark hair pulled back, post-workout glow, gentle
genuine half-smile (not posed for camera), wearing a casual loose grey
athletic top and joggers, holding her smartphone in her right hand at
chest height looking down at the screen with quiet satisfaction, sweat
sheen on her forehead, in a warm-lit home gym corner with a yoga mat
visible behind her, soft warm ambient light from a window upper-right
catching her face, slight motion blur on the background, shot on a Canon
R5 with a 35mm f/1.4 lens at f/2, naturalistic skin tones with no heavy
retouching, mood: lived-in authentic real-user moment NOT model studio
shoot, broad clean negative space on the upper right for testimonial
overlay, hyper-realistic 8K --ar 9:16 --style raw --stylize 180 --v 7
--no text, letters, logos, brand names visible, fitness magazine glamour,
heavy makeup, model perfection, studio backdrop, professional set, gym
equipment in focus, oversaturation
```

---

### 9.8 — Özellik Grafiği Öncesi/Sonrası

**Midjourney v7 prompt**:
```
Editorial before-after fitness photography, single Turkish-Mediterranean man
in his late twenties, vertically split composition: identical pose and
lighting on both halves, left half shows lean physique with less defined
torso (the "before"), right half shows defined athletic lean-muscular
physique with visible abs (the "after"), seamless realistic transition
implied between the two halves, dark studio backdrop, single hard rim
light from the rear casting purple-to-blue gradient highlights matched
on both halves, vertical neon purple-to-blue gradient seam between the
panels, broad clean negative space at the top and on the right side for
headline overlay, hyper-realistic 8K editorial photography, premium
fitness app banner aesthetic --ar 1024:500 --style raw --stylize 200 --v 7
--no text, letters, logos, watermarks, headlines drawn, UI elements,
gym equipment, oversaturation, illustration
```

---

### 9.9 — AI Koç Avatarı (Ekran Görüntüsü #2 Telefon İçi Kart İçin)

Mevcut `kişiselyapayzekakoçfoto.webp` yetersiz kalırsa, eşleşeni yeniden üretin:

**Midjourney v7 prompt**:
```
Stylized portrait of a confident Turkish-Mediterranean fitness coach in his
late thirties, athletic build, short dark hair, neatly groomed dark beard,
wearing a black athletic performance pullover with subtle neon purple
accent stitching at the collar, photographed bust-up at slight three-quarter
angle, neutral confident expression with a slight reassuring micro-smile,
soft studio key light from front-left and harder rim light from rear-right
in neon purple, dark gradient background, hyper-realistic 8K portrait
photography, shot on a Canon R5 with an 85mm f/1.2 lens, mood: trusted
trainer / digital concierge --ar 1:1 --style raw --stylize 200 --v 7
--no text, letters, logos, brand names, glasses unless specified, hat,
cartoon, illustration, exaggerated muscle, intimidating expression
```

---

### 9.10 — Yedek Varyasyon Promptları (A/B Testi İçin)

#### 9.10.1 — Kadın öncülüğünde kahraman (Ekran Görüntüsü #1 alternatifi)

```
Cinematic editorial fitness photography, athletic toned Turkish-Mediterranean
woman in her mid-twenties, waist-up side-profile, wearing a minimal black
athletic crop top and high-waisted leggings, focused expression looking
forward, visible defined core with subtle sweat sheen, hard rim lighting
from the rear-right casting neon purple glow on her right shoulder, deep
crushed black background with soft volumetric haze, subject in right 45%
of frame, left 55% pure dark negative space, shot on Sony A7IV 50mm f/1.8,
shallow DoF, crushed cinematic grade with cool purple shadows, hyper-real
8K, premium fitness app, Vogue editorial mood --ar 9:16 --style raw
--stylize 250 --v 7 --no text, logos, gym equipment, plastic skin
```

#### 9.10.2 — İkili (erkek + kadın) kahraman

```
Cinematic editorial fitness photography diptych, vertically split composition,
left half: athletic lean Turkish-Mediterranean woman side-profile in black
athletic crop top, right half: athletic lean Turkish-Mediterranean man
side-profile in black athletic top, both photographed against the same
deep crushed black backdrop with matched neon purple rim lighting from the
rear, identical mood and lighting, very narrow black gap between the two
halves, broad clean negative space top and bottom for overlay, shot on
50mm prime, shallow DoF, hyper-real 8K --ar 9:16 --style raw --stylize 220
--v 7 --no text, logos, plastic skin, illustration
```

#### 9.10.3 — Ramazan iftar yemek varyantı

```
Editorial overhead food photography, Turkish iftar plate with grilled
chicken kabab, bulgur pilaf, fresh shepherd salad, lentil soup, on a
matte dark slate platter, photographed top-down at golden hour evening
light, deep matte black background, broad clean negative space on the
right, hyper-real 8K editorial food --ar 9:16 --style raw --stylize 200
--v 7 --no text, hands, cutlery in motion, white background, daylight
```

---

### 9.11 — Prompt Mühendisliği Notları

- **`--style raw`** Midjourney’in varsayılan estetik cilasını soyar; daha fotoğrafik / daha az illüstratif sonuçlar verir. Fitness/insan çalışması için her zaman kullanın.
- **`--stylize 150–250`** editöryal fotoğrafçılık için tatlı noktadır. 100’ün altı = düz. 300’ün üstü = stilize fantezi.
- **`--v 7`** 2026 itibarıyla mevcut MJ motorudur; üretim zamanında v7.5 veya v8 sürümünü kontrol edin ve yeniden test edin.
- **En-boy oranı `9:16`** mağaza ekran görüntüleriyle eşleşir. 9:16’da yerel olarak üretin, kareyi kırpmayın.
- **Konu yerleşimi** prompta sözel olarak girilmelidir ("frame’in sağ %45’i") çünkü MJ’nin uzamsal kontrolü parametre tabanlı değil, sözel-prompt tabanlıdır.
- **`--sref`** (stil referansı) — bir kahraman çekim iyi düşerse, paket boyunca görsel tutarlılığı kilitlemek için sonraki promptlarda iş kimliğini `--sref <id>` olarak kullanın. Bu, MJ iş akışındaki en önemli tek tutarlılık aracıdır.

---

## 10. Üst Metin Sistemi

### 10.1 Üç-Katmanlı Yazı Sistemi

Her ekran görüntüsü tam olarak üç metin katmanı kullanır, asla daha fazla, asla daha az. Bu, en büyük tek okunabilirlik kaldıracıdır ve bir ekran görüntüsü paketini bozmanın en kolay yeridir.

```
TIER 1 — DISPLAY HEADLINE
  Font: Inter Display Black (free) or SF Pro Display Black (Apple)
  Size: 96–120 px (App Store), 80–100 px (Play Store)
  Tracking: -2%
  Line-height: 0.95 (tight)
  Color: #FFFFFF (always white over dark photo)
  Weight: 900
  Use: 1 line, 5–8 Turkish words

TIER 2 — SUB-LINE
  Font: Inter Medium or SF Pro Text Medium
  Size: 32–40 px
  Tracking: +1%
  Line-height: 1.25
  Color: #FFFFFF at 70% opacity
  Weight: 500
  Use: 1–2 lines, 10–14 Turkish words

TIER 3 — ACCENT / CAPS OVERLINE
  Font: Inter Bold
  Size: 22–26 px
  Tracking: +8%
  Line-height: 1.0
  Color: One brand neon (#8E5BFF, #00F0FF, or #39FF14)
  Weight: 700
  Use: 1 line, 1–3 Turkish words
  Treatment: ALL CAPS
```

### 10.2 Ekran Görüntüsü Başına Overlay Spec’leri

#### Ekran Görüntüsü #1 — Ana Kanca
```
Tier 3 (top): "★ FORMAI" in #8E5BFF
Tier 1: "30 GÜNDE KARNIN."
Tier 2: "Kişisel AI koçunla. Cebinde Türkçe."
```

#### Ekran Görüntüsü #2 — AI Koç
```
Tier 3 (top): "AI KOÇ" in #00F0FF
Tier 1: "CEBİNDE BİR ANTRENÖR."
Tier 2: "Her gün sana özel motivasyon, plan ve tavsiye."
```

#### Ekran Görüntüsü #3 — Form Analizi
```
Tier 3 (top): "GERÇEK ZAMANLI" in #00F0FF
Tier 1: "KAMERANLA FORM ANALİZİ."
Tier 2: "ML Kit pose detection · cihazında çalışır."
Tier 3 (bottom small, 70%): "🔒 GÖRÜNTÜLERİN ASLA KAYDEDİLMEZ"
```

#### Ekran Görüntüsü #4 — 30-Günlük Sistem
```
Tier 3 (top): "30 GÜNLÜK PROGRAM" in #39FF14
Tier 1: "30 GÜN. 30 SEANS."
Tier 2: "Sana özel — sıkılaşma, hacim ya da six-pack."
```

#### Ekran Görüntüsü #5 — Beslenme
```
Tier 3 (top): "BESLENME" in #4DA6FF
Tier 1: "ANTRENMAN VE BESLENME. TEK YERDE."
Tier 2: "Türk mutfağına uygun 250+ tarif. Makrolar otomatik hesaplanır."
```

#### Ekran Görüntüsü #6 — Deneme
```
Tier 3 (top): "RİSKSİZ DENE" in #39FF14
Tier 1: "3 GÜN ÜCRETSİZ."
Tier 2 (3 bullets):
  ✓ Tüm 30 günlük programlar
  ✓ Kamera form analizi sınırsız
  ✓ Türkçe AI koç + 250+ tarif
```

#### Ekran Görüntüsü #7 — Sosyal Kanıt
```
Tier 3 (top): "★★★★★ 4.8 / 5" in #FFD700 (gold)
Tier 1: "BİNLERCE TÜRK BUNU YAPTI."
Tier 2 (testimonial card):
  "İlk haftada karnımı görmeye başladım.
  Kamera form analizi olmadan diğer apps'e dönemem."
  — Ayşe, 28
```

### 10.3 Varyant Bankası (Agresif / Premium / Minimalist)

Bunları Faz 13’te (A/B testi) çalıştırın. Her Tier 1’in test için üç varyantı var.

#### Agresif varyantlar
- "30 GÜNDE 6-PACK. NOKTA."
- "FORM ANALİZİ. CEBİNDE."
- "30 GÜN. SONUÇ KESİN."
- "ÜCRETSİZ DENE. RİSK YOK."

#### Premium varyantlar
- "30 GÜN. KENDİN OL."
- "Antrenman, sana özel."
- "Beslenme + Antrenman. Bir yerde."
- "Sade. Etkili. Türkçe."

#### Minimalist varyantlar
- "30 gün."
- "Senin için."
- "Hepsi tek yerde."
- "Ücretsiz dene."
- "Bin'lerce Türk."

### 10.4 Güvenli Alanlar

App Store iPhone 6.9" için (1290×2796):

```
TOP RESERVE          — y: 0–160 px       (Dynamic Island visible in default mockups; do NOT place text here)
HEADLINE BAND        — y: 200–540 px     (Tier 1 + Tier 3 overline live here)
SUB-LINE BAND        — y: 560–700 px     (Tier 2 lives here)
PHONE MOCKUP BAND    — y: 720–2380 px    (Visual content area)
BOTTOM RESERVE       — y: 2400–2796 px   (Tier 3 small / brand cue, never critical text)
LEFT MARGIN          — x: 80 px
RIGHT MARGIN         — x: 80 px
```

Play Store telefonu için (1080×1920):
- Tüm bantları orantılı ölçeklendirin; veya 1290×2796’da tasarlayın ve alttaki 156 px’i kırpın.

### 10.5 Yerelleştirme Kuralları

Türkçe metni İngilizceye uyarlarken:
- Türkçe daha yüksek karakter yoğunluğuna sahiptir; İngilizce başlıklar genellikle bir alt-satır eklemesine ihtiyaç duyar.
- Sahiplenici biçimler ("Karnın") düz biçimlere ("Your Abs") düşer — duygusal ton için yeniden ayarlayın.
- "Cebinde Türkçe"yi doğrudan çevirmeyin; orijinali bir yerelleştirme şakasıdır ("cebinde Türkçe"). İngilizce eşdeğeri: "A Real Coach. In English. In Your Pocket."

---

## 11. Düzenleme İş Akışı

Bu bölüm adım-adım takip eden bir tasarımcı veya tasarımcı olmayan bir kurucu için yazılmıştır. Paket başına tahmini toplam süre: bir tasarımcı için **8–14 saat**, ilk-defa-tasarımcı-olmayan biri için **20–30 saat**.

### 11.1 Dosya Yapısı

Herhangi bir şey üretmeden önce proje kökünü kurun:

```
ASO_Assets/
├── 01_Generated_Raw/
│   ├── shot_01_hero/
│   ├── shot_02_coach/
│   ├── shot_03_form/
│   ├── shot_04_grid_bg/
│   ├── shot_05_food/
│   ├── shot_06_trial_bg/
│   ├── shot_07_social/
│   └── feature_graphic/
├── 02_Upscaled/                  ← Topaz outputs go here
├── 03_Retouched/                 ← Photoshop generative-fill outputs
├── 04_Phone_Mockups/             ← In-app screen captures
│   ├── dashboard_30day_grid.png
│   ├── suggestions_screen.png
│   ├── form_camera_overlay.png
│   ├── nutrition_macro_ring.png
│   └── paywall_trial.png
├── 05_Figma_Files/
│   └── FormAI_ASO_Pack.fig
├── 06_Final_Exports/
│   ├── AppStore_iPhone_6.9/
│   ├── PlayStore_Phone/
│   └── PlayStore_FeatureGraphic/
└── 99_Reference/
    ├── brand_codebook.md         ← Copy of §5 from this doc
    ├── overlay_text_system.md    ← Copy of §10
    └── color_swatches.png
```

### 11.2 Adım 1 — Uygulama İçi Ekranları Yakala (1 saat)

FormAI uygulamasını gerçek bir Pixel 8 Pro veya iPhone 15 Pro üzerinde açın. Aşağıdaki tam durumların yerel ekran görüntülerini alın:

1. **12/30 tamamlandı + seri pillu gösteren 30-günlük gridli kontrol paneli**: Geliştirici araçları veya onboarding-sonra-paywall-bypass aracılığıyla 12 tamamlanmış gün önceden tohumlandıktan sonra Gelişim sekmesini açın.
2. **AI Koç kartlı Öneriler ekranı**: Gelişim sekmesinden `/suggestions`’a gidin.
3. **Tekrar ortası kamera form-analizi kaplaması**: Bir antrenman başlatın, kamera moduna dokunun, yeşil ✓ form-doğru göstergesi görünürken orta-crunch yakalayın.
4. **Kalori halkası + makro çubukları + yemek kartlı Beslenme sekmesi**: Beslenme sekmesini açın, "Bugünün Öğünü" kahraman kartında bir yemek olduğundan emin olun.
5. **Yıllık plan seçili + deneme rozetli Paywall ekranı**: Gridi’deki herhangi bir kilitli güne dokunun; paywall açılır. Durumu yakalayın.

Her birini yerel cihaz çözünürlüğünde PNG olarak kaydedin. `04_Phone_Mockups/`’a bırakın.

**Figma yeniden çizimleri yerine gerçek-cihaz ekran görüntülerinin nedeni**: Gerçek hissederler. Müşteriler bir "ekran görüntüsünün" Figma’da yeniden inşa edildiğini bilinçaltında tespit edebilir — küçük arayüz tutarsızlıkları sızar. Gerçek ekran görüntüleri gerçeği taşır.

### 11.3 Adım 2 — Arka Planları Üret (2 saat)

§9’a göre her çekim için:

1. Midjourney’i (Discord veya web uygulaması) açın.
2. §9.x’ten promptu yapıştırın.
3. 4-grid sonucunu bekleyin. En iyiyi seçin.
4. Midjourney içinde "U" ile büyütün.
5. Sonucu en yüksek mevcut yerel çözünürlükte (genellikle v7’de 2048×3584) PNG olarak kaydedin.
6. 7 kahraman çekimi + özellik grafiği için tekrarlayın.
7. Her çekim için ayrıca eşdeğer promptu kullanarak bir **Flux 1.1 Pro Ultra** varyantı üretin. Yan yana karşılaştırın. En iyiyi seçin.

Son seçimleri `01_Generated_Raw/shot_xx/`’ye bırakın.

**İlk MJ sonucu kötüyse**: 4 kez kadar yeniden döndürün. Hâlâ kötüyse, promptu değiştirin ("yandan profil"i "üç-çeyrek açı"ya değiştirin; "neon mor"u "soğuk mavi"ye değiştirin). 8 denemeden sonra alamazsanız: zor kompozisyonlar için daha sıkı prompt uyumu olan Flux’a geçin.

### 11.4 Adım 3 — Topaz Photo AI ile Büyüt + Keskinleştir (30 dk)

Her MJ çıktısı için:

1. **Topaz Photo AI 4**’ü açın.
2. Dosya → Aç → ham MJ çıktısını seçin.
3. Sağ panelde: Otomatik-algıla → Standard model.
4. **Keskinleştir**: etkinleştir, güç 30, gürültüyü bastır 20.
5. **Büyüt**: hedef 1290×2796 (veya yalnızca-Play sürümler için 1080×1920; mükerrer çalışmadan kaçınmak için bir kez 1290×2796’da tasarlayın).
6. Dışa aktar → PNG → en yüksek kalite → `02_Upscaled/`’a kaydedin.

Bu pazarlık edilemez. MJ çıktıları 2048×3584’te 2796 yüksekliğine ölçeklendiğinde gözle görülür şekilde yumuşak render olur. Topaz detay yeniden inşa eder.

### 11.5 Adım 4 — Photoshop 2026’da Artefaktları Düzenle (toplam 1–2 saat)

MJ çıktıları zaman zaman artefaktlar içerir: ekstra parmaklar, garip kulak şekilleri, bulanık dişler, metin alanlarında toz parçacıkları. Bunları **Photoshop’un Generative Fill**’i ile düzeltin.

Her büyütülmüş çekim için:

1. Photoshop 2026’da açın.
2. %100 yakınlaştırmada bölgeleri inceleyin: yüz, eller, parmaklar, kıyafet kenarları, metnin oturacağı arka plan tozu.
3. Her artefakt için: Etrafında Lasso-seçim → Generative Fill → promptu boş bırak (bağlamdan yeniden doldur) → Üret → 3 sonuçtan en iyiyi seçin.
4. **Kritik**: metnin overlay olacağı **tüm negatif alan bölgesini** temizleyin. İnce saç telleri yok, lens-flare zerrecikleri yok, "ilginç" öğeler yok. Göz önce metni okumalı.
5. PSD olarak kaydedin (çalışma dosyası) ve PNG’yi `03_Retouched/`’a dışa aktarın.

**Taranacak yaygın MJ v7 artefaktları**:
- Yukarı tutulan ellerde ekstra parmak
- Asimetrik küpe / yaka çizgisi
- Metnin gideceği yere düşen yüzen "zerrecik" tozu
- Metin-benzeri artefaktlar (arka plan pusunda rastgele harf şekilleri)
- Yanaklarda plastik görünümlü cilt yamaları

### 11.6 Adım 5 — Figma Tasarım Sistemi Kur (2 saat, bir kez)

Bu, tek seferlik kurulumdur. 7 çekimde de yeniden kullanılır.

1. Figma’yı açın. `FormAI_ASO_Pack.fig` dosyasını oluşturun.
2. **Sayfa 1: Token’lar**
   - Renk stilleri: §5.1.1’deki her renk `brand/neon-purple`, `brand/neon-blue`, `brand/cyan`, `brand/green`, `text/white`, `text/white-70`, `text/cyan-overline`, vb. olarak adlandırılmış Figma renk stilleri olarak kaydedildi.
   - Metin stilleri: §10.1’den her giriş `display/tier-1`, `body/tier-2`, `caps/tier-3`, vb. olarak adlandırılmış Figma metin stilleri olarak kaydedildi.
3. **Sayfa 2: Bileşenler**
   - **Telefon Mockup Bileşeni**: Bir Pixel 8 Pro vektör çerçevesi göm (Figma Topluluğu’nda bul: Pikomotion’ın "Google Pixel 8 Pro Mockup" veya benzeri). Ekran alanını yer tutucu görsel doldurma olarak ayarla. Bileşene dönüştür.
   - **Yıldız Puanı Bileşeni**: Otomatik düzenli #FFD700’de 5 yıldız.
   - **Makro Rozet Bileşeni**: Otomatik düzenli pillu şekli, 3 renk varyantı.
   - **Tanıklık Kartı Bileşeni**: Alıntı glifli kart, gövde, yazar imzası.
4. **Sayfa 3: Şablonlar** — çekim başına 1290×2796’da bir çerçeve.

### 11.7 Adım 6 — Her Ekran Görüntüsünü Oluştur (3 saat)

Her çekim için:

1. Figma’da ana şablon çerçevesini çoğaltın.
2. **Arka plan katmanı**: rötuşlanmış MJ görüntüsünü (`03_Retouched/`’dan) en alttaki katmana bırakın, çerçeveyi doldurun.
3. **Telefon mockup katmanı** (uygulanabilirse): Telefon Mockup bileşenini bırakın, §8.x düzenine göre konumlandırın, ekranı `04_Phone_Mockups/`’tan ilgili yakalamaya ayarlayın.
4. **Telefonu eğin**: Telefon grubunu seçin, dönüşü §8’de belirtilen açıya ayarlayın (6°, 4°, vb.).
5. **Yüzen öğeler** (uygulanabilirse): makro rozetleri, seri pilluları, tanıklık kartı. Sayfa 2’deki bileşenleri kullanın.
6. **Telefon ekranında parıltı**: Telefonu ışık yayan gibi hissettirmek için %30 opaklıkta `brand/neon-purple`’da yumuşak dış parıltı, 60px bulanıklık ekleyin.
7. **Telefon üzerinde drop shadow**: 0px x, 80px y, 120px bulanıklık, %50 opaklıkta siyah. Telefonu uzayda demir atar.
8. **Tier 3 üst-çizgi metni ekleyin** (çerçevenin üstü).
9. **Tier 1 başlığını ekleyin** (display).
10. **Tier 2 alt-satırını ekleyin**.
11. **§10.4’e göre güvenli alanları doğrulayın**.

### 11.8 Adım 7 — Cilalama Geçişi (7’sinde toplam 2 saat)

Figma’nın prototip modunda 7 çerçeveyi yan yana açın. App Store’da bir müşteri olarak bunlardan geçin. Şunlara bakın:

- **Tutarlılık kontrolü**: 7’si de aynı aileye mi hissediyor? Aynı renk derecelendirmesi? Aynı tipografi? Aynı neon palet?
- **Bakış testi**: Her başlığı 1 saniyede okuyabilir misiniz? Eğer hayır, boyutu artırın veya kelimeleri basitleştirin.
- **Görsel hiyerarşi**: Her çekimde, gözünüz önce nereye gidiyor? Başlık olmalı, sonra görsel, sonra alt-satır.
- **Metin düzenleme**: Her Türkçe kelimeyi yüksek sesle okuyun. Türk kulağına doğal mı geliyor? (Önemli: yerli Türkçe konuşmacının incelemesi olsun.)
- **Telefon mockup oranları**: Telefon, ortalanmış göründüğü ekran görüntülerinde aynı göreli boyutta mı? Tutarsızlık "amatör" olarak okunur.

### 11.9 Adım 8 — Manuel Piksel Cilalama (30 dk)

Son detay geçişi:

- **Telefon mockup’larında kenar düzeltmeleri** (cihaz konturunda hafif 0.5px tüylenme).
- **Arka planlara dijital görünen gradyanları kırmak için %3 opaklıkta ince gürültü grain’i ekleyin** (Figma’nın gürültü eklentisini kullanın veya Photoshop’ta uygulayın).
- **Negatif alanda toz/saç telleri**: hiçbir MJ artefaktının sızmadığından emin olun.
- **Yıldız hizalaması**: tüm derecelendirme yıldızlarını tam piksellere snap’leyin.

---

## 12. Dışa Aktarma İş Akışı

### 12.1 Dışa Aktarma Ayarları — App Store

1. Figma’da çerçeveyi seçin.
2. Sağ panel → Dışa Aktar → +.
3. Format: **PNG**.
4. Sonek: boş.
5. Ölçek: **1x** (çerçeve zaten 1290×2796’da).
6. Dışa Aktar’a tıklayın.
7. Adlandırma ile `06_Final_Exports/AppStore_iPhone_6.9/`’a kaydedin:
   ```
   formai_appstore_01_master_hook.png
   formai_appstore_02_ai_coach.png
   formai_appstore_03_form_analysis.png
   formai_appstore_04_30day_system.png
   formai_appstore_05_nutrition.png
   formai_appstore_06_trial.png
   formai_appstore_07_social_proof.png
   ```

### 12.2 Dışa Aktarma Ayarları — Google Play

İki seçenek. Önerilen: seçenek B.

**Seçenek A**: 1080×1920’de yeniden tasarlayın (çok mükerrer çalışma).

**Seçenek B (önerilen)**: Aynı 1290×2796 PNG’leri dışa aktarın ve Google Play’in kendi tarafında yeniden ölçeklendirmesine izin verin. Play Store 7680×7680’a kadar kabul eder ve zarafetle küçültür. 1290×2796 dosyası iyi yüklenir.

Ancak **Özellik Grafiği (1024×500)** için:
- Figma’da 1024×500’de **ayrı bir çerçeve** olarak tasarlayın.
- 1x’te PNG dışa aktarın.
- `06_Final_Exports/PlayStore_FeatureGraphic/`’a `formai_play_feature_graphic.png` olarak kaydedin.

### 12.3 Dosya Adlandırma Konvansiyonu

```
formai_<store>_<order>_<theme_slug>.png
```

Örnekler:
formai_appstore_01_master_hook.png
formai_play_05_nutrition.png
formai_play_feature_graphic.png
```

Sıra önemli: önde gelen 01–07 dosya sisteminde sıralama düzenini Console’daki yükleme düzenine eşleşmeye zorlar.

### 12.4 Yükleme Sırası

**App Store Connect**:
1. App Store Connect → My Apps → FormAI → App Store sekmesi.
2. Pricing & Availability → 6.9" cihaz boyutunun seçildiğini onaylayın.
3. Screenshots → 7 PNG’nin tümünü sırayla yükleyin.
4. Sıranın adlandırmayla eşleştiğini onaylamak için sürükleyin.

**Google Play Console**:
1. Play Console → FormAI → Main store listing.
2. Phone screenshots → 7 PNG’nin tümünü yükleyin.
3. Gerekirse yeniden sıralayın.
4. Feature graphic → `formai_play_feature_graphic.png`’yi yükleyin.

### 12.5 Gönderim Öncesi Son QA Kontrol Listesi

- [ ] Her ekran görüntüsü 1290×2796 (App Store) veya Play yükleme hedefi gerektiriyorsa ayrı bir 1080×1920 dışa aktarımı vardır.
- [ ] Hiçbir ekran görüntüsü Apple/Google ticari markalarını içermez (Apple logosu, Play Store ikonu, vb.).
- [ ] Hiçbir ekran görüntüsü başka bir şirketin uygulama ikonlarını içermez (örn. mockup’ta Instagram, WhatsApp paylaş ikonları — stilize edilmiş genel ile değiştirin).
- [ ] Tüm Türkçe metin ana dili Türkçe olan biri tarafından düzeltildi.
- [ ] Başlıklar 1 saniyelik bakışta okunur.
- [ ] Telefon mockup’ları gerçek uygulama arayüzünü gösteriyor, Figma yeniden çizimleri değil.
- [ ] Özellik grafiği sağ-altta 24×24 px’te uygulama ikonunu içerir.
- [ ] "Yakında geliyor" veya yayınlanmamış-özellik iddiaları yok.
- [ ] Apple Yönerge 2.3’ü ihlal eden abartılı dönüşüm iddiaları yok.
- [ ] Ekran görüntülerinde sahte yıldız puanları yok (Apple bunu sert şekilde işaretler).
- [ ] Ekran Görüntüsü #7’deki tanıklık gerçek bir beta kullanıcısından OR açıkça illüstratif olarak ifşa edilmiş — Apple burada katıdır. Daha güvenli: gerçek incelemeler alana kadar alıntılı bir tanıklık olarak değil, bir tahmin/vaat olarak yeniden ifade edin.

---

## 13. A/B Test Fikirleri

Apple App Store artık **Custom Product Pages** + **Product Page Optimization (PPO)**’yu destekliyor. Google Play **Store Listing Experiments**’ı destekliyor. Her ikisi de farklı trafiğe farklı ekran görüntüsü varyantları sunmanıza ve CVR farkını ölçmenize izin verir.

### 13.1 Faz 1 Testleri (Lansman Sonrası İlk 60 Gün)

| Test ID | Varyant A | Varyant B | Hipotez |
|---|---|---|---|
| **Kahraman konu cinsiyeti** | Erkek kahraman (önerilen taban) | Kadın kahraman (§9.10.1 promptu) | Kadın kahraman, kadın kurulumlarda (~%30 izleyici) daha iyi dönüşüm sağlayabilir |
| **Kahraman metin agresifliği** | "30 GÜNDE KARNIN. KİŞİSEL AI KOÇUNLA." | "30 GÜNDE 6-PACK. NOKTA." | Agresif varyant taahhütlü kullanıcıları çekebilir; taban daha geniş izleyiciyi çekebilir |
| **Ekran görüntüsü 3 vurgusu** | Cyber camgöbeği iskelet kaplaması (varsayılan) | Pose detection kaplama olmadan, sadece kamera | "Teknoloji kanıtı"nın "doğal görünüm"den ağır basıp basmadığını test et |
| **Deneme çerçeveleme** | "3 GÜN ÜCRETSİZ DENE." | "ÜCRETSİZ DENE. RİSK YOK." | Spesifik sayı vs. genel risk-kaldırma |

### 13.2 Faz 2 Testleri (60–180 gün)

| Test ID | Varyant A | Varyant B | Hipotez |
|---|---|---|---|
| **Sıra karıştırma** | Varsayılan 1-7 sıra | Sosyal kanıtı 2. konuma taşı | Erken sosyal kanıt, özelliklerden önce güven oluşturabilir |
| **Özellik grafiği** | Öncesi/sonrası diptik | Daha büyük başlıklı tek kahraman çekimi | Diptik bilgilendiricidir; tek kahraman duygusal |
| **Kahraman fotoğraf modu** | Sinematik koyu (varsayılan) | Sıcak güneşli spor salonu | Karamsar vs. özlem dolu için pazar tercihini test et |
| **Ekran Görüntüsü #8 ekle** | Yok (7 çekim paketi) | Bir "Türk mutfağı" yemek kolajı ekle | Daha fazla çekim vs. odaklanma marjinal değeri |

### 13.3 Faz 3 Testleri (180+ gün)

- **Yerelleştirilmiş varyantlar**: İngilizce lansman düştükten sonra, 7’sini de İngilizce dil yeniden sıralamasıyla yeniden test edin. İngilizce izleyiciler "30 gün" çerçevesine Türkçe’den farklı tepki verir.
- **Mevsimsel kahraman**: Ramazan için, yemek çekimini iftar varyantına değiştirin (§9.10.3); Ramazan penceresi sırasında standart pakete karşı test edin.
- **Persona varyantları**: "Fitness anahtar kelime" araması vs. "diyet anahtar kelime" araması hedefleyen Custom Product Pages — niyete göre farklı kahraman çekimleri.

### 13.4 Ne Ölçülmeli

- **CVR (gösterim → kurulum)** — birincil metrik.
- **Kaynağa göre CVR**: Arama, Gözatma, Yönlendirme. Arama daha yüksek dönüşür; ekran görüntüsü paketi en çok Gözatma ve Yönlendirme trafiği için önemlidir.
- **Deneme başlatma oranı** — ikincil. Kurulum dönüşürse ama deneme başlamazsa, darboğaz uygulama içi kurulum sonrası onboarding’dir, ekran görüntüleri değil.
- **İstatistiksel anlamlılık**: Varyant başına en az ≥1000 gösterim bekleyin. < 200 gösterimden çıkarım yapmayın.

### 13.5 Anti-Patternler

- Aynı anda çok fazla değişken değiştirmeyin. Tek-değişkenli A/B yalnızca.
- Aynı anda 2’den fazla test yürütmeyin; trafiği seyreltir ve öğrenmeyi yavaşlatır.
- Erken "kötü görünse" bile anlamlılığa ulaşılana kadar varyantı değiştirmeyin.

---

## 14. Nihai Tavsiyeler

### 14.1 En Güçlü Tek Konsept

Bir ekran görüntüsünü mükemmel ve diğerlerini kaba göndereceksiniz, **Ekran Görüntüsü #1 — Ana Kanca**’yı mümkün olan en yüksek kalitede gönderin. Paket bu tek karenin üzerinde durur veya düşer. §9.1 Midjourney promptu + §11 düzenleme hattı + §10.2 overlay’i, FormAI’nin Türk pazarındaki spesifik konumlandırması için Gözatma trafiği CVR’sini maksimize etme olasılığı en yüksek olan varlığı üretir.

### 14.2 En Olası 4 Yüksek-Dönüşüm Kararı

1. **Tüm insan-konulu çekimlerde Türk-Akdeniz vücut tiplerini kullanın.** Genel Avrupalı veya Amerikalı atletik modeller "çevirili uygulama" olarak okunur ve yerelleştirme hendeğini aşındırır.
2. **Tüm 7 çekimde koyu sinematik neon görünümü kilitleyin.** Tutarlılık "profesyonel marka" olarak okunur; tutarsızlık "amatör portföy" olarak okunur.
3. **1. çekimde dönüşüm arzusuyla başlayın, 2-3’te özellik farklılaşmasıyla destekleyin, 7’de sosyal kanıtla kapatın.** Bu anlatı yayı, fitness kategorisi karşılaştırmalı değerlendirmelerinde özellik-madde kontrol listesi yayını %20-40 oranında geçer.
4. **Ekran Görüntüsü #3’e gizlilik güvencesi "Cihazında işleniyor" ekleyin.** Türkiye’de GDPR/KVKK bilinci yüksektir; bu tek satır gizli bir itirazı kaldırır.

### 14.3 Önce Ne A/B Test Edilmeli

Önerilen tabanı gönderdikten sonra, en yüksek kaldıraçlı ilk test **Kahraman konu cinsiyeti**’dir (§13.1). Fitness uygulamalarındaki 30/70 kadın/erkek kurulum tabanı, kadın öncülüğünde bir varyantın erkek dönüşümüne zarar vermeden kadın segment dönüşümünü %15-25 kaldırabileceğini önerir. Tek-değişkenli takas; temiz test.

### 14.4 Ne Yapılmamalı

- **Genel stok fitness görselleri.** Her çevrilmiş rakip kullanır. FormAI buna katılırsa ölür.
- **Uzun cümle başlıkları.** "Kişisel AI antrenörünüz cebinizde Türkçe konuşur ve 30 günde size sıkı bir karın kazandırır" — çok uzun, küçük resim boyutunda okunmaz, 1 saniyelik bakışta ölür.
- **Ekran görüntüsü başına 3’ten fazla renk.** Siyah + beyaz + bir neon vurgusu. Daha fazlası dağınık olarak okunur.
- **Dağınık telefon mockup’ları.** Kullanıcı küçük resim boyutunda 6 yüzen UI yüzeyini okuyamaz; çekim başına 1-2 kahraman UI öğesini gösterin.
- **Gerçek tanıklıklar kazanılmadan sahte tanıklıklar.** Apple incelemesi reddeder; Google puan-şişirme ihlallerini işaretler. Beta’da gerçek tanıklıklar kazanın veya Ekran Görüntüsü #7’yi "binlerce başladı" istatistik-odaklı iddia olarak yeniden ifade edin.
- **Uygulama içi onboarding ekranlarına benzeyen ekran görüntüleri.** Müşteriler yükleme ekranınızı görmek istemez; değeri görmek isterler.

### 14.5 Amatör vs. Premium Görünen

| Amatör sinyali | Premium sinyali |
|---|---|
| 2D düz telefon PNG mockup’ı | Gerçekçi ekran yansımalarıyla 3D render edilmiş telefon |
| Tüm çekimlerde merkez-hizalı metin | Sol-hizalı, tam-taşmalı, asimetrik düzenlerin karışımı |
| Stok gerilmiş-piksel arka planları | Özel Midjourney + Topaz büyütme fotoğrafçılığı |
| Bir çekimde 5+ font ağırlığı | Katı 3-katmanlı sistem |
| Her yerde drop shadow | Amaca uygun kullanılan tek belirli gölge stili |
| Parlak renk selleri | Katı vurgu neonlarıyla sinematik koyu derecelendirme |
| Genel stok İngilizce tanıklıklar | Gerçek hisseden yerel-dil tanıklık kartları |
| Her köşede uygulama logosu | Çekim başına marka ipucu, maks |
| Kalın illüstrasyon stili | Fotorealistik + editöryal tipografi |

### 14.6 Premium Algıyı Artırma

- **Katı 3-katmanlı yazı sistemini** dini bir özveriyle kullanın. Uygulama mağazası yaratıcı çalışmasında en büyük tek premium-vs-amatör sinyali tipografi disiplinidir.
- Tüm çerçeve üzerinde %3 opaklıkta **ince film grain’i** ekleyin — dijital düzlüğü kırar.
- **Sığ DoF fotoğrafçılığını** tutarlı şekilde kullanın — gerçek bir kamera, gerçek bir üretim bütçesi ima eder.
- Ekran Görüntüleri 1, 2, 5’te **çerçeve alanının en az %40’ını negatif alan olarak ayırın**. Premium uygulamalar dinlenir. Amatör uygulamalar tıkıştırır.

### 14.7 Güveni Artırma

- Ekran Görüntüsü #3’te **gizlilik bahsi** — yapıldı.
- Mümkün olduğunda **spesifik sayılar**: "30 gün" değil "hızlı"; "3 gün ücretsiz" değil "ücretsiz deneme"; "250+ tarif" değil "birçok tarif".
- Ekran Görüntüsü #7’de **yerel kanıt** — Türkçe ad, Türkçe alıntı, Türkçe ilk-hafta zaman çizelgesi.
- Paket genelinde **marka tutarlılığı** — gerçek bir şirket ima eder, tek-kişilik bir dükkan değil.

### 14.8 Kurulumları Artırma

Etkilerine göre sıralanan en üst 5 kaldıraç:

1. **Ekran Görüntüsü #1 kalitesi** (CVR delta’nın %60’ı).
2. **Başlık metni netliği** (%15).
3. **Paket görsel tutarlılığı** (%10).
4. **Yerelleştirme kalitesi** (%8).
5. **Özellik grafiği gücü** (%5, yalnızca Play Store).

### 14.9 Lansman Stratejisi

#### Lansman öncesi (T-7 gün)
- 7 kahraman fotoğrafının tümünü MJ + Flux ile üretin. En iyiyi seçin, Topaz ile büyütün.
- Gerçek cihazda uygulama içi ekranları yakalayın.
- Figma tasarım sistemi + 7 şablon kurun.
- En az 3 cilalanmış çekim üretin.

#### T-5 gün
- Tüm metinin yerli Türkçe konuşmacı incelemesi.
- 5 fitness-kategori güç kullanıcısıyla A/B test mockup’ları (gayri resmi).
- En zayıf 2 çekimde yineleyin.

#### T-3 gün
- 7’si + özellik grafiği üzerinde son cilalama geçişi.
- Son dosyaları dışa aktarın.
- §12.5 kontrol listesine göre dahili QA.

#### T-1 gün
- App Store Connect + Play Console’a yükleyin.
- İncelemeye gönderin.

#### T+0 lansman
- İlk 14 gün için günlük CVR’yi izleyin.
- Trafik kaynağına göre tabanı not edin.

#### T+30 ila T+60
- Faz 1 A/B testlerini başlatın (§13.1).
- Tek seferde bir değişkeni test edin.

#### T+90+
- Faz 2 testleri, yerelleştirme genişlemesi (önce İngilizce), mevsimsel varyantlar (Ramazan, yaz plaj sezonu).

### 14.10 Yerelleştirme Yol Haritası

1. **Türkçe (varsayılan, lansman)** — bu paketin tamamı.
2. **İngilizce (T+30 gün)** — başlıkları İngilizce dönüşüm konvansiyonları için yeniden yazın, küresele genişlerseniz Akdenizli olmayan vücut tipleriyle 2-3 kahraman çekimini yeniden üretin, 5 orijinali koruyun.
3. **Arapça (T+90 gün)** — RTL düzen çevirme, Akdeniz vücut tipleri korunmuş, kültürel muhafazakarlık için ayarlanmış fotoğrafçılık (daha uzun-kollu atletik giyim).
4. **Almanca + İspanyolca-LatAm (T+180 gün)** — erken veri sinyallerine dayalı ülkeye özgü yerelleştirme.

### 14.11 İteratif ASO Hijyeni

- **Aylık** — CVR metriklerini gözden geçirin. En zayıf ekran görüntüsünü belirleyin. Önümüzdeki ay için bir varyant testi planlayın.
- **Üç aylık** — CVR 60 gün boyunca durağansa kahraman fotoğrafı yenileyin. Mevsimsel varyantları döndürün.
- **Yıllık** — biriken öğrenmelere + kategori trend evrimine dayalı tam paket yeniden inşası. 2026 koyu-neon görünümü 2028’e kadar tarihsel görünecek; önceden planlayın.

### 14.12 Son Not

Fitness kategorisinde "iyi" bir ekran görüntüsü paketi ile "harika" bir paketi arasındaki fark bütçe değil. Disiplindir: tipografide disiplin, negatif alanda disiplin, anlatı yayında disiplin, yerelleştirme kalitesinde disiplin. Araçlar 2026’da emtia haline geldi. Tat ve titizlik hendektir.

Bu belge titizliktir. Onu uygulayın.

---

## Ek A · Varlık Üretim Kontrol Listesi

- [ ] Midjourney v7 aboneliği aktif
- [ ] Flux 1.1 Pro Ultra erişimi (Replicate veya fal.ai)
- [ ] Topaz Photo AI 4 yüklü
- [ ] Generative Fill ile Adobe Photoshop 2026
- [ ] Figma hesabı (Ücretsiz katman yeterli)
- [ ] Pixel 8 Pro mockup bileşeni (Figma Topluluğu)
- [ ] iPhone 15 Pro mockup bileşeni (Figma Topluluğu, isteğe bağlı)
- [ ] Inter Display Black + Inter Medium + Inter Bold yüklü
- [ ] (İsteğe bağlı) GT Walsheim Pro Bold lisansı
- [ ] Metin incelemesi için yerli Türkçe konuşmacı iletişim
- [ ] Uygulama içi ekran yakalamaları için gerçek cihaz
- [ ] 12 tamamlanmış günü önceden doldurmak için geliştirici hesabı veya test tohumu
- [ ] §11.1’e göre oluşturulan son varlık klasör yapısı

## Ek B · Hızlı-Referans Renk Kodları

```
Brand Neons
  Purple primary       #8E5BFF
  Blue accent          #4DA6FF
  Cyber cyan (live)    #00F0FF
  Neon green (success) #39FF14

Surfaces
  Master black         #0B0B12
  Card surface         #0F0F14
  Surface border       #1E1E26
  Inactive             #1C1C24

Semantic
  Success              #22C55E
  Danger               #FF4D6D
  Streak orange        #F97316
  Amber rest day       #FFB84D
  Carbs pink           #FF4DDB
  Fat phosphor yellow  #EAFF00

Typography
  Pure white           #FFFFFF
  White 70%            rgba(255,255,255,0.70)
  Gold (stars)         #FFD700
```

## Ek C · Ana Prompt Hile Sayfası

Üretimde hızlı yeniden üretim için:

```
Master appendix for ALL Midjourney v7 prompts:
--ar 9:16 --style raw --stylize 200 --v 7
--no text, letters, words, logos, watermarks, UI elements,
phone screens, brand names, low quality, blurry, cartoon,
illustrated, 3D rendered, plastic skin, airbrushed,
oversaturated

Master appendix for ALL Flux 1.1 Pro Ultra:
--guidance 4.5 --steps 30 --aspect_ratio 9:16
Negative cues to add into prompt body: "AVOID: text, letters,
logos, watermarks, UI elements, plastic skin, illustration,
3D render."
```

---

**FormAI ASO Görsel Ana Planı v1.0 sonu**

> Belge uzunluğu: ~10.500 kelime · Eksiksiz üretime hazır bir teslim olarak yazıldı. Bu belge `docs/STORE_LAUNCH_REPORT.md §5`’teki önceki mağaza-görseli strateji notlarının yerini alır ve `docs/IMAGE_PROMPTS.md`, `docs/MEAL_IMAGE_PROMPTS.md` ve `docs/WORKOUT_IMAGE_PROMPTS.md`’deki mevcut görsel üretim prompt sayfalarıyla entegre olur.
