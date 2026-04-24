import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/placeholder_images.dart';
import '../domain/services/workout_generator_service.dart';
import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';
import '../models/workout_plan_model.dart';

class WorkoutRepository {
  WorkoutRepository(this._prefs, {SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SharedPreferences _prefs;
  final SupabaseClient _client;

  static const String _completedKey = 'sixpack.completed_days';
  static const String _pendingSyncKey = 'sixpack.pending_sync_days';
  // Bumped from v1 → v2 in phase 19.5: pre-fix installs cached an
  // all-core plan against an empty goal (the onboarding flow was not
  // saving userMetrics, so the generator fell back to sixpack). A key
  // bump forces every existing install to regenerate on next launch
  // once the goal is actually available.
  static const String _planKey = 'sixpack.user_custom_plan_v2';
  static const String _progressTable = 'user_progress';

  // Videos live in the public Supabase Storage bucket `exercises`. The URL
  // is composed lazily because dotenv.env is empty until main.dart's
  // _BootGate finishes; all static Exercise fields below use `static final`
  // so they're only materialised after boot completes (and therefore after
  // dotenv has loaded SUPABASE_URL).
  static String _videoUrl(String filename) {
    final base = dotenv.env['SUPABASE_URL'] ?? '';
    return '$base/storage/v1/object/public/exercises/$filename';
  }

  // ==========================================================================
  // HERO IMAGE URLS — phase 35 swap. The docs/<region>/ jpegs they used to
  // point at were generic stock, so the Bölgeler strip now pulls cinematic
  // neon-lit Unsplash shots instead. Two IDs (`defaultMuscularPhotoUrl`,
  // `defaultLeanPhotoUrl`) are already validated; the two new literals
  // (`_gymDarkImg`, `_pushUpImg`) are widely-cited fitness stock photos
  // and have a graceful `Image.network` fallback behind them if either
  // ever 404s.
  // ==========================================================================

  /// Moody low-key gym shot with iron-grey tones. Used as the visual
  /// anchor for back / legs / cardio plans — the dark palette lets the
  /// neon-violet card borders pop.
  static const String _gymDarkImg =
      'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=800&q=80';

  /// Dynamic push-up action shot. Paired with chest / arm / explosive
  /// routines because the body-weight pose reads instantly as an active
  /// workout even at thumbnail size.
  static const String _pushUpImg =
      'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80';

  static const String _coreImg1 = defaultLeanPhotoUrl;
  static const String _coreImg2 = _gymDarkImg;
  static const String _chestImg1 = defaultMuscularPhotoUrl;
  static const String _chestImg2 = _pushUpImg;
  static const String _chestImg3 = _gymDarkImg;
  static const String _chestImg4 = defaultMuscularPhotoUrl;
  static const String _backImg1 = _gymDarkImg;
  static const String _backImg2 = defaultMuscularPhotoUrl;
  static const String _legsImg1 = _gymDarkImg;
  static const String _legsImg2 = defaultLeanPhotoUrl;
  static const String _legsImg3 = _gymDarkImg;
  static const String _legsImg4 = _pushUpImg;
  static const String _shouldersImg1 = defaultMuscularPhotoUrl;
  static const String _shouldersImg2 = _gymDarkImg;
  static const String _shouldersImg3 = _pushUpImg;
  static const String _armsImg1 = defaultMuscularPhotoUrl;
  static const String _armsImg2 = _pushUpImg;
  static const String _armsImg3 = _gymDarkImg;
  static const String _cardioImg1 = _pushUpImg;
  static const String _cardioImg2 = _gymDarkImg;
  static const String _cardioImg3 = _pushUpImg;

  // ==========================================================================
  // CORE (Karın & Stabilite)
  // ==========================================================================

  static final Exercise _crunch = Exercise(
    id: 'crunch',
    name: 'Mekik',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('Crunch.mp4'),
    description:
        'Sırt üstü uzan, dizlerini bük ve omuzlarını kontrollü olarak yukarı kaldır.',
    shortTip: 'Boyuna asma, karnınla çek.',
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  );

  static final Exercise _situp = Exercise(
    id: 'situp',
    name: 'Sit-up',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 35,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('SitUp.mp4'),
    description:
        'Sırt üstü uzan, gövdeni dizlerine kadar tam olarak kaldır ve kontrollü in.',
    shortTip: 'Karnını sık, hızı abartma.',
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  );

  static final Exercise _plank = Exercise(
    id: 'plank',
    name: 'Plank',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 40,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('Plank.mp4'),
    description:
        'Dirseklerin üstünde sabit dur, vücudunu omuzdan topuğa düz bir çizgi tut.',
    shortTip: 'Kalçanı düşürme.',
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  );

  static final Exercise _legRaise = Exercise(
    id: 'leg_raise',
    name: 'Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('LegRaise_demo.mp4'),
    description:
        'Sırt üstü uzan, bacaklarını düz tutarak yavaşça 90 dereceye kadar kaldır.',
    shortTip: 'Belini yere bastır.',
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  );

  static final Exercise _hangingLegRaise = Exercise(
    id: 'hanging_leg_raise',
    name: 'Asılı Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('HangingLegRaise.mp4'),
    description:
        'Bara tutun, bacaklarını birleştirip kontrollü olarak göğsüne doğru çek.',
    shortTip: 'Salınımdan kaçın.',
    difficulty: 'advanced',
    targetMuscle: 'core',
    isCardio: false,
  );

  static final Exercise _russianTwist = Exercise(
    id: 'russian_twist',
    name: 'Rus Dönüşü',
    type: ExerciseType.repBased,
    targetReps: 20,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('RussianTwist.mp4'),
    description:
        'Otur, hafifçe geri yaslan ve gövdeni sağdan sola tempolu biçimde döndür.',
    shortTip: 'Karnını sıkı tut.',
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  );

  static final Exercise _mountainClimber = Exercise(
    id: 'mountain_climber',
    name: 'Mountain Climber',
    type: ExerciseType.repBased,
    targetReps: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('MountainClimber.mp4'),
    description:
        'Plank pozisyonunda kal, dizlerini sırayla göğsüne hızla çekiştir.',
    shortTip: 'Kalçayı sabit tut.',
    difficulty: 'intermediate',
    targetMuscle: 'core',
    isCardio: true,
  );

  static final Exercise _bicycleCrunch = Exercise(
    id: 'bicycle_crunch',
    name: 'Bisiklet Mekiği',
    type: ExerciseType.repBased,
    targetReps: 16,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('BicycleCrunch.mp4'),
    description:
        'Sırt üstü uzan, karşıt dirsek ve dizini havada birleştir, taraf değiştir.',
    shortTip: 'Tempolu ama kontrollü.',
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  );

  static final Exercise _flutterKick = Exercise(
    id: 'flutter_kick',
    name: 'Flutter Kick',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    videoUrl: _videoUrl('FlutterKick.mp4'),
    description:
        'Sırt üstü uzan, bacaklarını kısa ve hızlı kanat çırpar gibi değiştir.',
    shortTip: 'Karnını gevşetme.',
    difficulty: 'intermediate',
    targetMuscle: 'core',
    isCardio: false,
  );

  // ==========================================================================
  // GÖĞÜS (Chest)
  // ==========================================================================

  static final Exercise _pushUp = Exercise(
    id: 'push_up',
    name: 'Şınav',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.chest,
    videoUrl: _videoUrl('PushUp.mp4'),
    description:
        'Eller omuz hizasında, gövdeni düz tutarak yere kadar in ve geri it.',
    shortTip: 'Dirseğini gövdene yakın tut.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _inclinePushUp = Exercise(
    id: 'incline_push_up',
    name: 'Yokuş Yukarı Şınav',
    type: ExerciseType.repBased,
    targetReps: 14,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.chest,
    videoUrl: _videoUrl('InclinePushUp.mp4'),
    description:
        'Ellerini yüksek bir yüzeye dayalı tutarak şınav hareketini uygula.',
    shortTip: 'Sırtını düz tut.',
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _declinePushUp = Exercise(
    id: 'decline_push_up',
    name: 'Yokuş Aşağı Şınav',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.chest,
    videoUrl: _videoUrl('DeclinePushUp.mp4'),
    description:
        'Ayaklarını yüksek bir yere koy, üst göğsünü hedefleyerek şınav yap.',
    shortTip: 'Yavaş in, hızlı çık.',
    difficulty: 'advanced',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _chestDip = Exercise(
    id: 'chest_dip',
    name: 'Göğüs Dip',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.chest,
    videoUrl: _videoUrl('ChestDip.mp4'),
    description:
        'Paralel barlarda göğsünü öne eğ, dirseklerini kontrollü olarak büküp aşağı in.',
    shortTip: 'Omuzları çukurlaştırma.',
    difficulty: 'advanced',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _benchPress = Exercise(
    id: 'bench_press',
    name: 'Dambıl Bench Press',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.chest,
    videoUrl: _videoUrl('DumbellBenchPress.mp4'),
    description:
        'Sırtın bench üstünde, dambılları göğsünden başlayıp yukarı doğru kontrollü it.',
    shortTip: 'Bilek düz, dirsek 45°.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _chestFly = Exercise(
    id: 'chest_fly',
    name: 'Chest Fly',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.chest,
    videoUrl: _videoUrl('ChestFly.mp4'),
    description:
        'Sırt üstü uzan, kollarını yana aç ve göğsünün üstünde kontrollü olarak kapat.',
    shortTip: 'Dirseğin hafif bükülü kalsın.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  // ==========================================================================
  // BACAK (Legs)
  // ==========================================================================

  static final Exercise _squat = Exercise(
    id: 'squat',
    name: 'Squat',
    type: ExerciseType.repBased,
    targetReps: 15,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    videoUrl: _videoUrl('Squat.mp4'),
    description:
        'Ayakların omuz hizasında; kalçanı geriye it, dizlerini büküp aşağı in ve kalk.',
    shortTip: 'Topuklarından güç al.',
    difficulty: 'beginner',
    targetMuscle: 'lower_body',
    isCardio: false,
  );

  static final Exercise _lunge = Exercise(
    id: 'lunge',
    name: 'Lunge',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    videoUrl: _videoUrl('Lunge.mp4'),
    description:
        'Geniş bir adım at, ön dizini 90 dereceye kadar büküp kontrollü olarak kalk.',
    shortTip: 'Ön diz parmak ucunu geçmesin.',
    difficulty: 'beginner',
    targetMuscle: 'lower_body',
    isCardio: false,
  );

  static final Exercise _bulgarianSplitSquat = Exercise(
    id: 'bulgarian_split_squat',
    name: 'Bulgar Split Squat',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.legs,
    videoUrl: _videoUrl('BulgarianSplitSquat.mp4'),
    description:
        'Arka ayağını yüksek bir yere koy, ön bacakla aşağı in ve patlayıcı şekilde kalk.',
    shortTip: 'Gövdeni dik tut.',
    difficulty: 'advanced',
    targetMuscle: 'lower_body',
    isCardio: false,
  );

  static final Exercise _legPress = Exercise(
    id: 'leg_press',
    name: 'Leg Press',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.legs,
    videoUrl: _videoUrl('Legpress.mp4'),
    description:
        'Sırtını desteğe yasla, ayaklarını platforma sabitle ve dizleri kilitlemeden it.',
    shortTip: 'Topuklarını basılı tut.',
    difficulty: 'intermediate',
    targetMuscle: 'lower_body',
    isCardio: false,
  );

  static final Exercise _calfRaise = Exercise(
    id: 'calf_raise',
    name: 'Calf Raise',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 35,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.legs,
    videoUrl: _videoUrl('CalfRaise.mp4'),
    description: 'Kalf kaldırma. Parmak uçlarında yüksel ve baldırlarını sık.',
    shortTip: 'Tepe noktasında 1 saniye sık.',
    difficulty: 'beginner',
    targetMuscle: 'lower_body',
    isCardio: false,
  );

  static final Exercise _wallSit = Exercise(
    id: 'wall_sit',
    name: 'Wall Sit',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 45,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    videoUrl: _videoUrl('WallSit.mp4'),
    description:
        'Duvara oturuş. Sırtını duvara daya ve dizlerini doksan derece bükerek bekle.',
    shortTip: 'Topuğunla bas, çakılı kal.',
    difficulty: 'beginner',
    targetMuscle: 'lower_body',
    isCardio: false,
  );

  // ==========================================================================
  // SIRT (Back)
  // ==========================================================================

  static final Exercise _pullUp = Exercise(
    id: 'pull_up',
    name: 'Pull-up',
    type: ExerciseType.repBased,
    targetReps: 8,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.back,
    videoUrl: _videoUrl('PullUp.mp4'),
    description:
        'Bara avuçlar dışta tutun, kürek kemiklerini sıkarak çeneni bara çek.',
    shortTip: 'Önce kürekten çek.',
    difficulty: 'advanced',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _chinUp = Exercise(
    id: 'chin_up',
    name: 'Chin-up',
    type: ExerciseType.repBased,
    targetReps: 8,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.back,
    videoUrl: _videoUrl('ChinUp.mp4'),
    description:
        'Avuç içlerin sana dönük, çeneni bara doğru kontrollü çek ve yavaşça in.',
    shortTip: 'Salınımdan kaçın.',
    difficulty: 'advanced',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _latPulldown = Exercise(
    id: 'lat_pulldown',
    name: 'Lat Pulldown',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.back,
    videoUrl: _videoUrl('LatPulldown.mp4'),
    description:
        'Otur, barı göğüs hizasına çek ve kürek kemiklerini birbirine sıkıştır.',
    shortTip: 'Önce sırt, sonra dirsek.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _barbellRow = Exercise(
    id: 'barbell_row',
    name: 'Barbell Row',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.back,
    videoUrl: _videoUrl('BarbellRow.mp4'),
    description:
        'Sırtın nötr ve düz, halteri göbek hizana doğru kontrollü olarak çek.',
    shortTip: 'Sırtın yuvarlanmasın.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _superman = Exercise(
    id: 'superman',
    name: 'Superman',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 25,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.back,
    videoUrl: _videoUrl('Superman.mp4'),
    description:
        'Superman. Karın üstü yat, kollarını ve bacaklarını aynı anda havaya kaldır.',
    shortTip: 'Boynunu nötr tut.',
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  // ==========================================================================
  // OMUZ (Shoulders)
  // ==========================================================================

  static final Exercise _shoulderPress = Exercise(
    id: 'shoulder_press',
    name: 'Shoulder Press',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.shoulders,
    videoUrl: _videoUrl('ShoulderPress.mp4'),
    description:
        'Dambılları omuz hizasından kontrollü olarak tam yukarı it ve geri indir.',
    shortTip: 'Çekirdek sıkı, bilek nötr.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _lateralRaise = Exercise(
    id: 'lateral_raise',
    name: 'Lateral Raise',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.shoulders,
    videoUrl: _videoUrl('LateralRaise.mp4'),
    description:
        'Kollarını yana doğru omuz seviyesine kadar düz hâlde kontrollü kaldır.',
    shortTip: 'Trapeze değil, omuza yükle.',
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _frontRaise = Exercise(
    id: 'front_raise',
    name: 'Front Raise',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.shoulders,
    videoUrl: _videoUrl('FrontRaise.mp4'),
    description:
        'Kollarını öne doğru omuz seviyesine kadar düz hâlde kontrollü kaldır.',
    shortTip: 'Bel yaylanmasın.',
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _arnoldPress = Exercise(
    id: 'arnold_press',
    name: 'Arnold Press',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.shoulders,
    videoUrl: _videoUrl('ArnoldPress.mp4'),
    description:
        'Dambılları yukarı iterken avuç içlerini içeriden dışarıya doğru çevir.',
    shortTip: 'Dirseğini kilitleme.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _pikePushUp = Exercise(
    id: 'pike_push_up',
    name: 'Pike Şınav',
    type: ExerciseType.repBased,
    targetReps: 8,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.shoulders,
    videoUrl: _videoUrl('PikePushUp.mp4'),
    description:
        'Kalçanı yukarı kaldır, başını iki elin arasında inip çıkacak şekilde itele.',
    shortTip: 'Omuza odaklan, gövdeyi devirme.',
    difficulty: 'advanced',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  // ==========================================================================
  // KOL (Arms)
  // ==========================================================================

  static final Exercise _bicepsCurl = Exercise(
    id: 'biceps_curl',
    name: 'Biceps Curl',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.arms,
    videoUrl: _videoUrl('BicepsCurl.mp4'),
    description:
        'Dirseklerini gövdene sabitle, dambılı omuzuna doğru kontrollü olarak çek.',
    shortTip: 'Salınma, biceps çalışsın.',
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _hammerCurl = Exercise(
    id: 'hammer_curl',
    name: 'Hammer Curl',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.arms,
    videoUrl: _videoUrl('HammerCurl.mp4'),
    description:
        'Avuç içlerin içeriye dönük, dambılı omuza doğru kontrollü olarak çek.',
    shortTip: 'Bilek nötr kalsın.',
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _tricepsDip = Exercise(
    id: 'triceps_dip',
    name: 'Triceps Dip',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.arms,
    videoUrl: _videoUrl('TricepsDip.mp4'),
    description:
        'Sandalye/bar kenarında ellerin destekli; dirseklerini bükerek aşağı in ve geri kalk.',
    shortTip: 'Dirsek geriye, dışarı değil.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _tricepsPushdown = Exercise(
    id: 'triceps_pushdown',
    name: 'Triceps Pushdown',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.arms,
    videoUrl: _videoUrl('TricepsPushdown.mp4'),
    description:
        'Dirseklerin gövdene sabit, halatı veya barı kontrollü olarak aşağı it.',
    shortTip: 'Sadece ön kol çalışsın.',
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  static final Exercise _closeGripPushUp = Exercise(
    id: 'close_grip_push_up',
    name: 'Yakın Tutuş Şınav',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.arms,
    videoUrl: _videoUrl('CloseGripPushUp.mp4'),
    description:
        'Ellerini daralt, dirseklerini gövdene yakın tutarak şınav hareketini uygula.',
    shortTip: 'Dirsek dışa kaçmasın.',
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  );

  // ==========================================================================
  // KARDİYO & FULL BODY
  // ==========================================================================

  static final Exercise _burpee = Exercise(
    id: 'burpee',
    name: 'Burpee',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.fullBody,
    videoUrl: _videoUrl('Burpee.mp4'),
    description:
        'Aşağı in, ellerin yere değdiğinde plank al, ayaklarını öne çekip patlayıcı zıpla.',
    shortTip: 'Sürekli ritim, mola yok.',
    difficulty: 'advanced',
    targetMuscle: 'full_body',
    isCardio: true,
  );

  static final Exercise _jumpingJack = Exercise(
    id: 'jumping_jack',
    name: 'Jumping Jack',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    videoUrl: _videoUrl('JumpingJack.mp4'),
    description:
        'Aç-kapat hareketiyle aynı anda kollarını yukarı kaldırıp ritmik şekilde zıpla.',
    shortTip: 'Yumuşak ayak, sıkı çekirdek.',
    difficulty: 'beginner',
    targetMuscle: 'cardio',
    isCardio: true,
  );

  static final Exercise _highKnees = Exercise(
    id: 'high_knees',
    name: 'High Knees',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    videoUrl: _videoUrl('HighKness.mp4'),
    description:
        'Diz çekme. Olduğun yerde dizlerini göğsüne doğru olabildiğince yüksek çek.',
    shortTip: 'Kollarını da çalıştır.',
    difficulty: 'beginner',
    targetMuscle: 'cardio',
    isCardio: true,
  );

  static final Exercise _jumpSquat = Exercise(
    id: 'jump_squat',
    name: 'Jump Squat',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.fullBody,
    videoUrl: _videoUrl('JumpSquat.mp4'),
    description:
        'Squat pozisyonuna in, patlayıcı biçimde havaya zıpla ve yumuşak iniş yap.',
    shortTip: 'Sessiz iniş, sıkı çekirdek.',
    difficulty: 'intermediate',
    targetMuscle: 'full_body',
    isCardio: true,
  );

  static final Exercise _skippingRope = Exercise(
    id: 'skipping_rope',
    name: 'İp Atlama',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 45,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    videoUrl: _videoUrl('SkippingRope.mp4'),
    description: 'İp atlama. Temponu koru ve ayak uçlarında zıpla.',
    shortTip: 'Diz hafif bükülü, ip kısa.',
    difficulty: 'beginner',
    targetMuscle: 'cardio',
    isCardio: true,
  );

  // ==========================================================================
  // EXERCISE POOL — flat list of every movement the generator service can
  // draw from. Kept in insertion order (core → chest → legs → back →
  // shoulders → arms → cardio/full-body) so rotation through the list
  // gives a balanced default sequence before any goal-specific filtering.
  // ==========================================================================

  static final List<Exercise> allExercises = [
    // Core
    _crunch,
    _situp,
    _plank,
    _legRaise,
    _hangingLegRaise,
    _russianTwist,
    _mountainClimber,
    _bicycleCrunch,
    _flutterKick,
    // Chest
    _pushUp,
    _inclinePushUp,
    _declinePushUp,
    _chestDip,
    _benchPress,
    _chestFly,
    // Legs
    _squat,
    _lunge,
    _bulgarianSplitSquat,
    _legPress,
    _calfRaise,
    _wallSit,
    // Back
    _pullUp,
    _chinUp,
    _latPulldown,
    _barbellRow,
    _superman,
    // Shoulders
    _shoulderPress,
    _lateralRaise,
    _frontRaise,
    _arnoldPress,
    _pikePushUp,
    // Arms
    _bicepsCurl,
    _hammerCurl,
    _tricepsDip,
    _tricepsPushdown,
    _closeGripPushUp,
    // Cardio & Full Body
    _burpee,
    _jumpingJack,
    _highKnees,
    _jumpSquat,
    _skippingRope,
  ];

  // ==========================================================================
  // "SINIRLARINI ZORLA" DASHBOARD CARDS
  // Exposed as top-level static const so the dashboard strip can reference
  // them directly (and push them into /plan-detail via `extra:`).
  // ==========================================================================

  static final WorkoutPlan pushLimitsAbsHiit = WorkoutPlan(
    id: 'push_limits_abs_hiit',
    title: 'Belirgin Karın Kasları HIIT',
    category: ExerciseCategory.core,
    level: 'Orta düzey',
    durationMinutes: 19,
    exercises: [
      _mountainClimber,
      _bicycleCrunch,
      _crunch,
      _legRaise,
      _plank,
    ],
    image: 'photos/sınırlarınızorlabelirginkarınkarınkaslarıHIITnewfoto.webp',
  );

  static final WorkoutPlan pushLimitsStrongerCore = WorkoutPlan(
    id: 'push_limits_stronger_core',
    title: 'Daha Güçlü Şekil ve Çekirdek',
    category: ExerciseCategory.core,
    level: 'Orta düzey',
    durationMinutes: 24,
    exercises: [
      _russianTwist,
      _legRaise,
      _plank,
      _situp,
      _bicycleCrunch,
    ],
    image: defaultMuscularPhotoUrl,
  );

  static final WorkoutPlan pushLimitsIronPack = WorkoutPlan(
    id: 'push_limits_iron_pack',
    title: 'Demir Altı Paket Gücü',
    category: ExerciseCategory.core,
    level: 'İleri',
    durationMinutes: 18,
    exercises: [
      _hangingLegRaise,
      _crunch,
      _russianTwist,
      _plank,
      _flutterKick,
    ],
    image: 'photos/sınırlarınızorlademiraltıpaketgücünewfoto.webp',
  );

  static final WorkoutPlan pushLimitsAthleticCore = WorkoutPlan(
    id: 'push_limits_athletic_core',
    title: 'Atletik Core Kontrolü',
    category: ExerciseCategory.core,
    level: 'Başlangıç',
    durationMinutes: 15,
    exercises: [
      _plank,
      _bicycleCrunch,
      _crunch,
      _flutterKick,
    ],
    image: defaultLeanPhotoUrl,
  );

  // ==========================================================================
  // REGIONAL PLANS — surfaced on the dashboard's category filter strip.
  // Each plan groups the exercises above by body region. Empty exercise
  // lists render as "coming soon" tiles so the chip layout stays
  // populated even before bespoke routines exist for those regions.
  // ==========================================================================

  static final List<WorkoutPlan> allPlans = [
    pushLimitsAbsHiit,
    pushLimitsStrongerCore,
    pushLimitsIronPack,
    pushLimitsAthleticCore,
    // ---- Core ----
    WorkoutPlan(
      id: 'core_steel_abs',
      title: 'Çelik Gibi Karın',
      category: ExerciseCategory.core,
      level: 'Başlangıç',
      durationMinutes: 15,
      exercises: [
        _plank,
        _russianTwist,
        _legRaise,
        _mountainClimber,
        _bicycleCrunch,
      ],
      image: _coreImg1,
    ),
    WorkoutPlan(
      id: 'core_athletic',
      title: 'Atletik Core',
      category: ExerciseCategory.core,
      level: 'Orta düzey',
      durationMinutes: 20,
      exercises: [_crunch, _bicycleCrunch, _legRaise, _flutterKick, _plank],
      image: _coreImg2,
    ),
    // ---- Göğüs (Chest) ----
    WorkoutPlan(
      id: 'chest_dumbbell_fast',
      title: 'Dambıl Hızlı Göğüs Yapma',
      category: ExerciseCategory.chest,
      level: 'Orta düzey',
      durationMinutes: 14,
      exercises: [_benchPress, _chestFly, _pushUp],
      image: _chestImg2,
    ),
    WorkoutPlan(
      id: 'chest_activation_growth',
      title: 'Göğüs Aktivasyonu ve Büyüme',
      category: ExerciseCategory.chest,
      level: 'Başlangıç',
      durationMinutes: 6,
      exercises: [_inclinePushUp, _pushUp],
      image: _chestImg1,
    ),
    WorkoutPlan(
      id: 'chest_full_growth_burst',
      title: 'Tam Göğüs Büyümesi ve Patlaması',
      category: ExerciseCategory.chest,
      level: 'İleri',
      durationMinutes: 22,
      exercises: [
        _pushUp,
        _inclinePushUp,
        _declinePushUp,
        _chestDip,
        _benchPress,
        _chestFly,
      ],
      image: _chestImg3,
    ),
    WorkoutPlan(
      id: 'chest_fat_burn_basic',
      title: 'Göğüs Yağ Yakma Temel Planı',
      category: ExerciseCategory.chest,
      level: 'Orta düzey',
      durationMinutes: 18,
      exercises: [_pushUp, _declinePushUp, _chestDip, _chestFly],
      image: _chestImg4,
    ),
    // ---- Sırt (Back) ----
    WorkoutPlan(
      id: 'back_v_taper',
      title: 'Geniş V-Taper Sırt',
      category: ExerciseCategory.back,
      level: 'Orta düzey',
      durationMinutes: 22,
      exercises: [_pullUp, _chinUp, _latPulldown, _barbellRow],
      image: _backImg1,
    ),
    WorkoutPlan(
      id: 'back_posture_basic',
      title: 'Duruş Düzeltici Temel Sırt',
      category: ExerciseCategory.back,
      level: 'Başlangıç',
      durationMinutes: 12,
      exercises: [_superman, _latPulldown, _barbellRow],
      image: _backImg2,
    ),
    // ---- Omuz (Shoulders) ----
    WorkoutPlan(
      id: 'shoulders_giant',
      title: 'Dev Omuzlar',
      category: ExerciseCategory.shoulders,
      level: 'Orta düzey',
      durationMinutes: 18,
      exercises: [_shoulderPress, _lateralRaise, _frontRaise, _arnoldPress],
      image: _shouldersImg1,
    ),
    WorkoutPlan(
      id: 'shoulders_v_taper',
      title: 'V-Tipi Omuz Şekillendirme',
      category: ExerciseCategory.shoulders,
      level: 'Başlangıç',
      durationMinutes: 14,
      exercises: [_lateralRaise, _frontRaise, _pikePushUp],
      image: _shouldersImg2,
    ),
    WorkoutPlan(
      id: 'shoulders_power_burst',
      title: 'Power Omuz Patlaması',
      category: ExerciseCategory.shoulders,
      level: 'İleri',
      durationMinutes: 22,
      exercises: [
        _arnoldPress,
        _shoulderPress,
        _lateralRaise,
        _pikePushUp,
      ],
      image: _shouldersImg3,
    ),
    // ---- Kol (Arms) ----
    WorkoutPlan(
      id: 'arms_steel',
      title: 'Çelik Kollar',
      category: ExerciseCategory.arms,
      level: 'Orta düzey',
      durationMinutes: 14,
      exercises: [_bicepsCurl, _hammerCurl, _tricepsDip],
      image: _armsImg1,
    ),
    WorkoutPlan(
      id: 'arms_explosive_super',
      title: 'Patlayıcı Kol Süper Setleri',
      category: ExerciseCategory.arms,
      level: 'İleri',
      durationMinutes: 20,
      exercises: [
        _bicepsCurl,
        _hammerCurl,
        _tricepsDip,
        _tricepsPushdown,
        _closeGripPushUp,
      ],
      image: _armsImg2,
    ),
    WorkoutPlan(
      id: 'arms_quick_tone',
      title: 'Hızlı Tonlama Kolları',
      category: ExerciseCategory.arms,
      level: 'Başlangıç',
      durationMinutes: 10,
      exercises: [_bicepsCurl, _hammerCurl, _tricepsPushdown],
      image: _armsImg3,
    ),
    // ---- Bacak (Legs) ----
    WorkoutPlan(
      id: 'legs_quad_strength',
      title: 'Büyük ve Güçlü Quadriceps Şekli',
      category: ExerciseCategory.legs,
      level: 'Orta düzey',
      durationMinutes: 18,
      exercises: [_squat, _lunge, _legPress, _calfRaise],
      image: _legsImg1,
    ),
    WorkoutPlan(
      id: 'legs_power_day',
      title: 'Bacak Gücü Artışı Günü',
      category: ExerciseCategory.legs,
      level: 'İleri',
      durationMinutes: 25,
      exercises: [_squat, _bulgarianSplitSquat, _legPress, _calfRaise],
      image: _legsImg2,
    ),
    WorkoutPlan(
      id: 'legs_cardio_strength',
      title: 'Alt Vücut Kardiyo ve Güç',
      category: ExerciseCategory.legs,
      level: 'Orta düzey',
      durationMinutes: 20,
      exercises: [_squat, _lunge, _calfRaise, _wallSit],
      image: _legsImg3,
    ),
    WorkoutPlan(
      id: 'legs_elite_sculpt',
      title: 'Elit Bacak Şekillendirme',
      category: ExerciseCategory.legs,
      level: 'İleri',
      durationMinutes: 28,
      exercises: [
        _bulgarianSplitSquat,
        _legPress,
        _wallSit,
        _lunge,
        _calfRaise,
      ],
      image: _legsImg4,
    ),
    // ---- Kardiyo & Full Body ----
    WorkoutPlan(
      id: 'cardio_fat_burn',
      title: 'Yağ Yakıcı Kardiyo',
      category: ExerciseCategory.fullBody,
      level: 'Orta düzey',
      durationMinutes: 20,
      exercises: [_burpee, _jumpingJack, _highKnees, _jumpSquat],
      image: _cardioImg1,
    ),
    WorkoutPlan(
      id: 'cardio_full_body_burst',
      title: 'Tam Vücut Patlama',
      category: ExerciseCategory.fullBody,
      level: 'İleri',
      durationMinutes: 25,
      exercises: [
        _burpee,
        _jumpSquat,
        _mountainClimber,
        _skippingRope,
        _jumpingJack,
      ],
      image: _cardioImg2,
    ),
    WorkoutPlan(
      id: 'cardio_morning_quick',
      title: 'Hızlı Sabah Kardiyosu',
      category: ExerciseCategory.fullBody,
      level: 'Başlangıç',
      durationMinutes: 12,
      exercises: [_jumpingJack, _highKnees, _skippingRope],
      image: _cardioImg3,
    ),
  ];

  // ==========================================================================
  // PROGRAM
  // Replaces the former `_staticProgram`: the 30-day schedule is now
  // generated on first load by [WorkoutGeneratorService] from the user's
  // stored goal + level, then cached as JSON in SharedPreferences under
  // [_planKey]. Subsequent launches read the cache so the plan is stable
  // across sessions until the user explicitly resets progress.
  // ==========================================================================

  /// Returns the user's 30-day plan with completion flags overlaid from
  /// local + remote progress. On a cold cache (or when a previous cache
  /// entry is unparseable), falls back to [generator] and persists the
  /// result before returning.
  Future<List<WorkoutDay>> loadOrGenerateProgram({
    required WorkoutGeneratorService generator,
    String? userGoal,
    String? fitnessLevel,
  }) async {
    final completed = await _completedDays();
    final cached = _decodeCachedPlan();
    final plan = cached ??
        generator.generate30DayPlan(
          userGoal: userGoal ?? 'sixpack',
          fitnessLevel: fitnessLevel ?? 'beginner',
        );
    if (cached == null) {
      // Fire-and-forget — cache is advisory; if the write fails we'll
      // simply regenerate the same plan next launch (deterministic).
      unawaited(_cachePlan(plan));
    }
    return plan
        .map((day) =>
            day.copyWith(isCompleted: completed.contains(day.dayNumber)))
        .toList(growable: false);
  }

  /// Reads + decodes the cached plan. Returns null for any failure mode:
  /// missing key, malformed JSON, wrong root type, enum drift, or a
  /// length mismatch — all of which mean "regenerate from scratch".
  List<WorkoutDay>? _decodeCachedPlan() {
    final raw = _prefs.getString(_planKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final days = decoded
          .map((e) => WorkoutDay.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      // A partial write (power loss mid-save, say) would leave fewer
      // than 30 entries — treat as corrupt rather than serving a short
      // plan that silently fails the 30-day UI.
      if (days.length != 30) return null;
      return days;
    } catch (e, st) {
      AppLogger.warning(
        'WorkoutRepository: plan cache decode failed — regenerating',
        category: 'workout',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
      return null;
    }
  }

  Future<void> _cachePlan(List<WorkoutDay> plan) async {
    try {
      final encoded = jsonEncode(
        plan.map((d) => d.toJson()).toList(growable: false),
      );
      await _prefs.setString(_planKey, encoded);
    } catch (e, st) {
      AppLogger.error(
        'WorkoutRepository: plan cache encode failed',
        e,
        stackTrace: st,
        category: 'workout',
      );
    }
  }

  Future<void> markDayCompleted(int dayNumber) async {
    final merged = _localCompleted()..add(dayNumber);
    await _saveLocal(merged);

    final user = _client.auth.currentUser;
    if (user == null) {
      // Not yet signed in (first-run before auth completes, rare). Queue so
      // we can replay as soon as a session exists.
      await _queueSync(dayNumber);
      return;
    }
    if (!await _upsertCompleted(user.id, dayNumber)) {
      // Offline / network error — keep the local cache and remember to
      // flush this to Supabase the next time _completedDays() runs.
      await _queueSync(dayNumber);
    }
  }

  Future<void> resetProgress() async {
    await _prefs.remove(_completedKey);
    await _prefs.remove(_pendingSyncKey);
    // Drop the cached plan too — a full reset should yield a fresh
    // regeneration against whatever the user's current goal/level is.
    await _prefs.remove(_planKey);
  }

  Future<Set<int>> _completedDays() async {
    // Every time the program loads is a chance to retry dropped syncs —
    // cheap when the queue is empty, automatic recovery when it isn't.
    await _flushPending();

    final local = _localCompleted();
    final user = _client.auth.currentUser;
    if (user == null) return local;

    try {
      final rows = await _client
          .from(_progressTable)
          .select('day_number, is_completed')
          .eq('user_id', user.id)
          .eq('is_completed', true);
      final remote = <int>{
        for (final row in rows)
          if (row['day_number'] is int) row['day_number'] as int,
      };
      final merged = {...local, ...remote};
      if (merged.length != local.length) {
        await _saveLocal(merged);
      }
      return merged;
    } catch (_) {
      return local;
    }
  }

  /// Attempts a single upsert, returns true on success. Isolated so both the
  /// live markDayCompleted path and the background flush can share exactly
  /// the same write — no chance of drift between them.
  Future<bool> _upsertCompleted(String userId, int dayNumber) async {
    try {
      await _client.from(_progressTable).upsert(
        {
          'user_id': userId,
          'day_number': dayNumber,
          'is_completed': true,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,day_number',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Set<int> _pendingSync() {
    final raw = _prefs.getStringList(_pendingSyncKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> _savePending(Set<int> days) async {
    if (days.isEmpty) {
      await _prefs.remove(_pendingSyncKey);
      return;
    }
    await _prefs.setStringList(
      _pendingSyncKey,
      days.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _queueSync(int dayNumber) async {
    final pending = _pendingSync()..add(dayNumber);
    await _savePending(pending);
  }

  /// Replays any completions that failed to reach Supabase. Anything that
  /// succeeds is removed from the queue; anything that still fails stays
  /// queued for the next flush. Anonymous→real upgrades keep the same
  /// user_id (see auth_screen._submit), so queued rows sync cleanly once
  /// the user signs up.
  Future<void> _flushPending() async {
    final pending = _pendingSync();
    if (pending.isEmpty) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    final remaining = <int>{};
    for (final dayNumber in pending) {
      final ok = await _upsertCompleted(user.id, dayNumber);
      if (!ok) remaining.add(dayNumber);
    }
    if (remaining.length != pending.length) {
      await _savePending(remaining);
    }
  }

  Set<int> _localCompleted() {
    final raw = _prefs.getStringList(_completedKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> _saveLocal(Set<int> days) async {
    await _prefs.setStringList(
      _completedKey,
      days.map((e) => e.toString()).toList(),
    );
  }
}
