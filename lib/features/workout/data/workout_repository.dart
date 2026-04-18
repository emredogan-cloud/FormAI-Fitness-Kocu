import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';
import '../models/workout_plan_model.dart';

class WorkoutRepository {
  WorkoutRepository(this._prefs, {SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SharedPreferences _prefs;
  final SupabaseClient _client;

  static const String _completedKey = 'sixpack.completed_days';
  static const String _progressTable = 'user_progress';

  // ==========================================================================
  // ASSET PATH SHORTCUTS — keeps the plans list below readable. Each value
  // resolves to a file inside one of the docs/<region>/ folders declared
  // under flutter.assets in pubspec.yaml; the long base64-ish basenames
  // come straight from the cloud-storage exports the user dropped in.
  // ==========================================================================

  static const String _coreImg1 = 'docs/Core (Karın & Stabilite)/1.jpeg';
  static const String _coreImg2 =
      'docs/Core (Karın & Stabilite)/4h-GfJgN9a4wzOi5dyPr4KKzTpZDl4vlTe5qrgdfbu-YomsCs9IxRfwX4C59yrMzFmdH7q33bMBU1PJYM5epPdc577HOU-8pc5rS85ayDzJXt4fVp-wlwgBGgugxDyqag-U0zX4sqMe7Y9QendQX0aT-fDYsYfdHW73PvxmVmUQ.jpeg';
  static const String _chestImg1 =
      'docs/Göğüs (Chest)/E9CjEna37nJKbG4xizXoq8r0-UFei_q8TvZdsf28rQ2PdTO6IBfn3JcyHsTjZ0ajMUdYONm0IeJQWI9pooHrWaGFoom5UFezanHoyFq6HfhXF9ogvwCKCavQTTFbWRmW4I4VNSHWuUtdTSnr2EOND47p9xBtkeBs-gckcnCkkL4.jpeg';
  static const String _chestImg2 =
      'docs/Göğüs (Chest)/JpJrp6V8ApIDIbjyWcwl8EJd2H7nBHQIFvkwuTE19rWpeyzFxljASLhwIZdMn13phGSSHZ0pZDF7h-y4fNyuxtQs5OW9jOZvbRZbhmvfukC8TsmQU2iU39rgs_HHtlWvfOY5VNWriZxRvjHn5TRdDT_MmlFpFWkfNHlfABZm4oY.jpeg';
  static const String _chestImg3 =
      'docs/Göğüs (Chest)/QrerRX4gKZal4Q9UdGhjHMhe2DzMZRnPy_xPSArSoSdTnlDM-vQVcrCRsVxrtc_Hw71PYdlclsmuFmQH7len4atYL2PGluwc_MziOps4Cotfrh7tLxpFCm1IEzFlvEOYwJnYjRs4PRGXc2gxWZvN-gbX6pwV7M2_ato-6QG2Axv90-TUqpnr2eYw_X5FYcWe.jpeg';
  static const String _chestImg4 =
      'docs/Göğüs (Chest)/uigcgXRDQbphmZcD8AMJWlg-3h0BYRX1MI9oVj3WH8PNKgTSg_XzebzZ-avafXT8SoNbqw5bOcmvK6XyGoTakHAVzAfzA1GfjXwaHWffCwD9gXxuIRTdXNKYP3krRR-8Mkx0BqD9iErK7digcfORT0WYCFD4pVs9QFPIyrew20SvvD_DIke6uGROLFxxIqmJ.jpeg';
  static const String _backImg1 =
      'docs/Sırt (Back)/DkFE86-g1pS0UaNntjAY3IhaCb3hfF5FekQ0gN893pveagV3LGBjzihc_ld5V0aCEK8OPrrfoJu16CKXdUTFUWo4dpHCXJ3ZbBGTNNExEW9bJIEGUpbK6WNuvWq2487WAcT6dLkmSGml6s_ePD-eKi_ZzGQYL-mRcXkXcFWm8LRmdJAgxrurFP1xzG4Hgu8C.jpeg';
  static const String _backImg2 =
      'docs/Sırt (Back)/w4hPxE1QE3qK9OO5j67xk8JC_oRqz7zsfq187sTHrrlyCKAgSJsU7rTCzQvXjRtdXc7FCw6o04lEq039fzeemachfR6vbCyoNctqNRMNDDGkj0Sl7-D81DyG3sd167H2HQ6xLZu3AokrngJnwk2udZO-Q_JesVDmdmcUhb393YKUjfSL7ikBOXM1RKuG9DX2.jpeg';
  static const String _legsImg1 =
      'docs/Bacak (Legs)/eWCp_hOV3FeP_erhHbLTS0w6Pakbs-zsH-UnvBu9gg8vuU1jbNU6zD9Qp5SP3ZrBefkEJCbSRjSTp-LxUOKxu8DXVk_48yoAKE3ZpO9eauuKRQCmKyxaEwdcbk6oLUOtQev6uEPhWf7VbcUdBvcCyhjOom6sAfz-WvDrV2qqCqhS0U925QACge33ReoCk7M9.jpeg';
  static const String _legsImg2 =
      'docs/Bacak (Legs)/FZyPUHF5w9TgElI1Kw16ybexSiSrCRiB7df4hpPOidOpdT6Cx5u0x7fLVgDrm9uc1sP08OCBFzwt8Son5ltNtOlVnfO6tJqm7Dv37y0x_58Xq44pOfSqWYDBnVpYZy9nWy1oMNLyGBBtQ5YymatFD5sXltkC-ZMrMJlVtmFAUc_kAoN7LON64py17VwT2Yhv.jpeg';
  static const String _legsImg3 =
      'docs/Bacak (Legs)/KaA4Q9qGOCwN0JArCU6QJyZ6_q8cLE90vhWZuR_HjqCF6EEziCkyKM1F2KbuahMkyQLC9su_lOdog-2IBklawVhoR3vvlm72kTzKzfAD43cs6c8Le-xGiV0Ypzhv5wwTGU4ng9CnWkleAU5XSD7wGDGvBUAYYsNUdeQxgwiZhGRZOnQ7aTS5MhmOI9gf71vU.jpeg';
  static const String _legsImg4 =
      'docs/Bacak (Legs)/sjz2Ldz3yNj2c7FGkLTGjcPWnchkO_6VAYmu1Z6spiiFrM-LmwREsOseQ7lWCcMfESKItiRHZp6oa1HxyZxFfj4KCyo3PQN3-2p6hwSFlHNRfcHeyrVcJNWi0fVClqm1d9-r8_Tqz011bzj0qSfUnxynWxHfRXOXhn0c6mF7kxr2BlLamVxyVMD9-428zHl_.jpeg';
  static const String _shouldersImg1 =
      'docs/Omuz (Shoulders)/OIxKG1D5mR7xAsyUT_Dn-bZVmWjgZdrAjyw0dS8qzZQ_05dDiOslH-dk6kujsNr7pKfDmjMtyjQcuwZDmQGX9iAoDUEZpbVuaTFIcI8--oeXX0oG5Hcv22YY9LULxcAEAX8g-WKat6Ml48MdY4Sik_Zjur5ym8c7xPbF6sFjxBwjO48FyW-Lz9bhp8prsNaB.jpeg';
  static const String _shouldersImg2 =
      'docs/Omuz (Shoulders)/bR94XbUWi4IyC-1NM4S3IBBCLtrqpjmQ-3HSgCzuzisth-sZSQJTYIHbfJQYrloDtp_3EqZ9tcq440lUPETrjAQow8yVIBmpwej6PkfRRbGpML_JgYQItiBpdYqEbdX1Vbn1UW_z_7JNBVzEOQkKAQmfRFwg2G-Y--17SmvfpgiCEPEEeUwMaLwfv4JurFXf.jpeg';
  static const String _shouldersImg3 =
      'docs/Omuz (Shoulders)/shtCkPS2UX6ieJfejUFF4q9HSgv566ndemhoU6q0IXgKiANuQZ4dxeazZiMnNPk4S-L52kxNNfXHngl2NLsYOtHW4Hivs_FzSq-1WgB39lJhdjRYAEsd4PzoA-qLcg5LephEKe-Hhw_ag7Nt7VWmSEdCuPVGH8hLLe4ZWSLJ-_ygAocCBUojxEepLccJm1Me.jpeg';
  static const String _armsImg1 =
      'docs/Kol (Arms)/bSLUGrV7-P_4L6oIyHstsUMJkYGDxDxsQXJ_JGTR7cTF8xmadysiHCF8k5rfBQLq2X1UuHpCKc-J6SL0wB41a9BCLWc5s_-jFSXp8Mf1B0WqsrB-nFrgl6cHO18e03gAyuhRA8ssqpqXh34-1v8aFvEXIc6nG0ZEyOeRLjkPXyCY6InQ2hBwtLtrQ2LuQsW5.jpeg';
  static const String _armsImg2 =
      'docs/Kol (Arms)/nYGKt7WaHa0zaslGOH2qfSTGHTb4dOHCsBIlQ-IZhG9A6hb_fSOyHH9mUZiu1bXxtUXIIKp-QXA1g7QKhJHGH7SImV0CoP00_IJmynl_wF_ypR1ELZfnnjOBox3MZDY4V8y4-VcGg7PsU3BvXwPwR0rvZru8NrSBS-68El53f35dXMzdsf7tZRsDg1ykGSNP.jpeg';
  static const String _armsImg3 =
      'docs/Kol (Arms)/r1xK7LMYZuJ_eYSsWsLeBWjf9ydstrCx6UEH49bE3NaJ1PdAkQvR1YIPHzgtrS7LZgSSSkewrKhI9wAJQRfKtXGJ4QSO9wylZ8EH9oMHpsChhYayme_JYqQYQdqrXU5qOF22brbZtAWrGkPQUyRgsVA0NUAsi5HSDfIKqfBu0xCZRhQEyL4lBgyQB1niOjX0.jpeg';
  static const String _cardioImg1 =
      'docs/Kardiyo & Full Body/9HOfBbb87p7h6T5pJE0EL8cPdPegtFKeMIf2E6kcLIwKxci8E5vhrqTHpM_wU_L_-3MOZ726uxkSAlgoWckfpLVfm03A1RoQSfHaWwwG2WXiyddOCPjwK6cUUGLe9B3EwJZxWaKApR0jCAzlNzdIhsSSjMKlniBvTv-B0IIfFPo8gNJ7ZtLMyyq5pBXgl4le.jpeg';
  static const String _cardioImg2 =
      'docs/Kardiyo & Full Body/GMo8yQ1NhdkXbArhN0A68-4Q-aLOk28_JXM_bN676Gk4tmI7UZkLeANINxoiIcYpX6s-AZW6aZiKYW_4Qu0p7IHX_jAWbwc2gCRHbJTJxLTGLNPJUUGHkxQfG2ByFNpMX2WSNfjGHyEewqzNl5-GBXxnegwcsSMr92lhPIC0d31cgDYqVX3H6mAtT4qhC5yR.jpeg';
  static const String _cardioImg3 =
      'docs/Kardiyo & Full Body/GW932TbHYkRV0PBVAZO6THafyZIWeJrAkeb3NwyM3kn7YglCp111ovv3zSeAaIj3wRR9pmaUAn-ccuSKFB-jQFHlFfnCeJduslMeqrUE3HMkurOpPc3NndI1CqIFyMTIr0RqxjM_1fpyCoZYohcSmz3XDsv0CxJQ0xjFlQRvMK8tAupxbkAMx1ZMfrrGAS23.jpeg';

  // ==========================================================================
  // CORE (Karın & Stabilite)
  // ==========================================================================

  static const Exercise _crunch = Exercise(
    id: 'crunch',
    name: 'Mekik',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    videoAsset: 'assets/videos/crunch_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Mekik. Yere uzan, ellerini başının arkasına koy ve başla.',
  );

  static const Exercise _situp = Exercise(
    id: 'situp',
    name: 'Sit-up',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 35,
    videoAsset: 'assets/videos/crunch_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Sit-up. Tüm gövdeni yukarı kaldır, dizlerine kadar gel.',
  );

  static const Exercise _plank = Exercise(
    id: 'plank',
    name: 'Plank',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 40,
    sets: 3,
    restDurationInSeconds: 45,
    videoAsset: 'assets/videos/plank_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Plank. Dirseklerin üzerinde sabit kal, kalçanı düz tut.',
  );

  static const Exercise _legRaise = Exercise(
    id: 'leg_raise',
    name: 'Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    videoAsset: 'assets/videos/leg_raise_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Bacak Kaldırma. Bacaklarını 90 dereceye kaldır.',
  );

  static const Exercise _hangingLegRaise = Exercise(
    id: 'hanging_leg_raise',
    name: 'Asılı Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Asılı Bacak Kaldırma. Bara tutun ve bacaklarını yukarı çek.',
  );

  static const Exercise _russianTwist = Exercise(
    id: 'russian_twist',
    name: 'Rus Dönüşü',
    type: ExerciseType.repBased,
    targetReps: 20,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Rus Dönüşü. Otur, hafif geri yaslan ve gövdeni sağa sola döndür.',
  );

  static const Exercise _mountainClimber = Exercise(
    id: 'mountain_climber',
    name: 'Mountain Climber',
    type: ExerciseType.repBased,
    targetReps: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Mountain Climber. Plank pozisyonunda dizlerini hızla göğsüne çek.',
  );

  static const Exercise _bicycleCrunch = Exercise(
    id: 'bicycle_crunch',
    name: 'Bisiklet Mekiği',
    type: ExerciseType.repBased,
    targetReps: 16,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Bisiklet Mekiği. Karşıt dirsek ve dizini birleştir.',
  );

  static const Exercise _flutterKick = Exercise(
    id: 'flutter_kick',
    name: 'Flutter Kick',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Flutter Kick. Sırt üstü uzan ve bacaklarını kısa, hızlı tempoda değiştir.',
  );

  // ==========================================================================
  // GÖĞÜS (Chest)
  // ==========================================================================

  static const Exercise _pushUp = Exercise(
    id: 'push_up',
    name: 'Şınav',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Şınav. Şınav pozisyonu al, eller omuz hizasında ve başla.',
  );

  static const Exercise _inclinePushUp = Exercise(
    id: 'incline_push_up',
    name: 'Yokuş Yukarı Şınav',
    type: ExerciseType.repBased,
    targetReps: 14,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Yokuş Yukarı Şınav. Ellerin yüksek bir yüzeye dayalı, şınava başla.',
  );

  static const Exercise _declinePushUp = Exercise(
    id: 'decline_push_up',
    name: 'Yokuş Aşağı Şınav',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Yokuş Aşağı Şınav. Ayaklarını yüksek tut, kontrollü in ve çık.',
  );

  static const Exercise _chestDip = Exercise(
    id: 'chest_dip',
    name: 'Göğüs Dip',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Göğüs Dip. Paralel barlarda göğsünü öne eğerek aşağı in.',
  );

  static const Exercise _benchPress = Exercise(
    id: 'bench_press',
    name: 'Dambıl Bench Press',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Dambıl Bench Press. Bench üzerinde uzan ve dambılları yukarı it.',
  );

  static const Exercise _chestFly = Exercise(
    id: 'chest_fly',
    name: 'Chest Fly',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Chest Fly. Kollarını yana aç ve göğüs üstünde kontrollü kapat.',
  );

  // ==========================================================================
  // BACAK (Legs)
  // ==========================================================================

  static const Exercise _squat = Exercise(
    id: 'squat',
    name: 'Squat',
    type: ExerciseType.repBased,
    targetReps: 15,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    startCommand:
        'Sıradaki hareket: Squat. Ayakların omuz hizasında, dizlerini bük ve kontrollü çık.',
  );

  static const Exercise _lunge = Exercise(
    id: 'lunge',
    name: 'Lunge',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    startCommand:
        'Sıradaki hareket: Lunge. Geniş bir adım at, ön diz dik açıya kadar in.',
  );

  static const Exercise _bulgarianSplitSquat = Exercise(
    id: 'bulgarian_split_squat',
    name: 'Bulgar Split Squat',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.legs,
    startCommand:
        'Sıradaki hareket: Bulgar Split Squat. Arka ayağını yüksek bir yere koy ve in çık.',
  );

  static const Exercise _legPress = Exercise(
    id: 'leg_press',
    name: 'Leg Press',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.legs,
    startCommand:
        'Sıradaki hareket: Leg Press. Sırtını desteğe yasla, dizlerini kilitlemeden it.',
  );

  static const Exercise _calfRaise = Exercise(
    id: 'calf_raise',
    name: 'Calf Raise',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 35,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.legs,
    startCommand:
        'Sıradaki hareket: Calf Raise. Parmak ucunda yüksel ve yavaşça in.',
  );

  static const Exercise _wallSit = Exercise(
    id: 'wall_sit',
    name: 'Wall Sit',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 45,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    startCommand:
        'Sıradaki hareket: Wall Sit. Sırtını duvara yasla, dizler 90 derecede sabit kal.',
  );

  // ==========================================================================
  // SIRT (Back)
  // ==========================================================================

  static const Exercise _pullUp = Exercise(
    id: 'pull_up',
    name: 'Pull-up',
    type: ExerciseType.repBased,
    targetReps: 8,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.back,
    startCommand:
        'Sıradaki hareket: Pull-up. Bara avuçlar dışta tutun, çeneni bara çek.',
  );

  static const Exercise _chinUp = Exercise(
    id: 'chin_up',
    name: 'Chin-up',
    type: ExerciseType.repBased,
    targetReps: 8,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.back,
    startCommand:
        'Sıradaki hareket: Chin-up. Avuç içlerin sana dönük, kontrollü çek ve in.',
  );

  static const Exercise _latPulldown = Exercise(
    id: 'lat_pulldown',
    name: 'Lat Pulldown',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.back,
    startCommand:
        'Sıradaki hareket: Lat Pulldown. Barı göğüs hizasına çek, kürek kemiklerini sık.',
  );

  static const Exercise _barbellRow = Exercise(
    id: 'barbell_row',
    name: 'Barbell Row',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.back,
    startCommand:
        'Sıradaki hareket: Barbell Row. Sırtın düz, halteri göbek hizana çek.',
  );

  static const Exercise _superman = Exercise(
    id: 'superman',
    name: 'Superman',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 25,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.back,
    startCommand:
        'Sıradaki hareket: Superman. Yüz üstü uzan, kollar ve bacakları kaldır, sabit tut.',
  );

  // ==========================================================================
  // OMUZ (Shoulders)
  // ==========================================================================

  static const Exercise _shoulderPress = Exercise(
    id: 'shoulder_press',
    name: 'Shoulder Press',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.shoulders,
    startCommand:
        'Sıradaki hareket: Shoulder Press. Dambılları omuz hizasından tam yukarı it.',
  );

  static const Exercise _lateralRaise = Exercise(
    id: 'lateral_raise',
    name: 'Lateral Raise',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.shoulders,
    startCommand:
        'Sıradaki hareket: Lateral Raise. Kolları yana doğru omuz seviyesine kadar kaldır.',
  );

  static const Exercise _frontRaise = Exercise(
    id: 'front_raise',
    name: 'Front Raise',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.shoulders,
    startCommand:
        'Sıradaki hareket: Front Raise. Kolları öne doğru omuz seviyesine kadar kaldır.',
  );

  static const Exercise _arnoldPress = Exercise(
    id: 'arnold_press',
    name: 'Arnold Press',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.shoulders,
    startCommand:
        'Sıradaki hareket: Arnold Press. Avuçları çevirerek dambılı yukarı bas.',
  );

  static const Exercise _pikePushUp = Exercise(
    id: 'pike_push_up',
    name: 'Pike Şınav',
    type: ExerciseType.repBased,
    targetReps: 8,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.shoulders,
    startCommand:
        'Sıradaki hareket: Pike Şınav. Kalçayı kaldır, başın iki elin arasında inip çıksın.',
  );

  // ==========================================================================
  // KOL (Arms)
  // ==========================================================================

  static const Exercise _bicepsCurl = Exercise(
    id: 'biceps_curl',
    name: 'Biceps Curl',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.arms,
    startCommand:
        'Sıradaki hareket: Biceps Curl. Dirseklerini sabit tut, dambılı omuza çek.',
  );

  static const Exercise _hammerCurl = Exercise(
    id: 'hammer_curl',
    name: 'Hammer Curl',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.arms,
    startCommand:
        'Sıradaki hareket: Hammer Curl. Avuç içleri içeride, dambılı kontrollü çek.',
  );

  static const Exercise _tricepsDip = Exercise(
    id: 'triceps_dip',
    name: 'Triceps Dip',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.arms,
    startCommand:
        'Sıradaki hareket: Triceps Dip. Sandalyenin kenarına dayan, dirseklerini bükerek in.',
  );

  static const Exercise _tricepsPushdown = Exercise(
    id: 'triceps_pushdown',
    name: 'Triceps Pushdown',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.arms,
    startCommand:
        'Sıradaki hareket: Triceps Pushdown. Halatı aşağı it, kollarını tam aç.',
  );

  static const Exercise _closeGripPushUp = Exercise(
    id: 'close_grip_push_up',
    name: 'Yakın Tutuş Şınav',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.arms,
    startCommand:
        'Sıradaki hareket: Yakın Tutuş Şınav. Elleri daralt, dirseklerini gövdeye yakın tut.',
  );

  // ==========================================================================
  // KARDİYO & FULL BODY
  // ==========================================================================

  static const Exercise _burpee = Exercise(
    id: 'burpee',
    name: 'Burpee',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.fullBody,
    startCommand:
        'Sıradaki hareket: Burpee. Aşağı in, plank al, geri zıpla. Tempolu gidelim!',
  );

  static const Exercise _jumpingJack = Exercise(
    id: 'jumping_jack',
    name: 'Jumping Jack',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    startCommand:
        'Sıradaki hareket: Jumping Jack. Aç ve kapat, ritmik bir tempoda.',
  );

  static const Exercise _highKnees = Exercise(
    id: 'high_knees',
    name: 'High Knees',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    startCommand:
        'Sıradaki hareket: High Knees. Dizleri kalçanı geçecek şekilde hızla yukarı çek.',
  );

  static const Exercise _jumpSquat = Exercise(
    id: 'jump_squat',
    name: 'Jump Squat',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.fullBody,
    startCommand:
        'Sıradaki hareket: Jump Squat. Squat\'a in, patlayıcı şekilde zıpla ve yumuşak in.',
  );

  static const Exercise _skippingRope = Exercise(
    id: 'skipping_rope',
    name: 'İp Atlama',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 45,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    startCommand:
        'Sıradaki hareket: İp Atlama. Hafif tempoda zıpla, ritmi kaybetme.',
  );

  // ==========================================================================
  // "SINIRLARINI ZORLA" DASHBOARD CARDS
  // Exposed as top-level static const so the dashboard strip can reference
  // them directly (and push them into /plan-detail via `extra:`).
  // ==========================================================================

  static const WorkoutPlan pushLimitsAbsHiit = WorkoutPlan(
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

  static const WorkoutPlan pushLimitsStrongerCore = WorkoutPlan(
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
    image:
        'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&w=600&q=80',
  );

  static const WorkoutPlan pushLimitsIronPack = WorkoutPlan(
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

  static const WorkoutPlan pushLimitsAthleticCore = WorkoutPlan(
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
    image:
        'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=600&q=80',
  );

  // ==========================================================================
  // REGIONAL PLANS — surfaced on the dashboard's category filter strip.
  // Each plan groups the exercises above by body region. Empty exercise
  // lists render as "coming soon" tiles so the chip layout stays
  // populated even before bespoke routines exist for those regions.
  // ==========================================================================

  static const List<WorkoutPlan> allPlans = [
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
  // ==========================================================================

  static const List<WorkoutDay> _staticProgram = [
    WorkoutDay(
      dayNumber: 1,
      exercises: [_crunch, _plank, _legRaise],
    ),
    WorkoutDay(
      dayNumber: 2,
      exercises: [_situp, _bicycleCrunch, _plank],
    ),
    WorkoutDay(
      dayNumber: 3,
      exercises: [_crunch, _russianTwist, _legRaise],
    ),
    WorkoutDay(
      dayNumber: 4,
      exercises: [_pushUp, _inclinePushUp, _chestFly],
    ),
    WorkoutDay(
      dayNumber: 5,
      exercises: [_mountainClimber, _flutterKick, _plank],
    ),
    WorkoutDay(
      dayNumber: 6,
      exercises: [_benchPress, _chestDip, _declinePushUp],
    ),
    WorkoutDay(
      dayNumber: 7,
      exercises: [
        _crunch,
        _bicycleCrunch,
        _hangingLegRaise,
        _flutterKick,
      ],
    ),
  ];

  Future<List<WorkoutDay>> loadProgram() async {
    final completed = await _completedDays();
    return _staticProgram
        .map((day) =>
            day.copyWith(isCompleted: completed.contains(day.dayNumber)))
        .toList(growable: false);
  }

  Future<void> markDayCompleted(int dayNumber) async {
    final merged = _localCompleted()..add(dayNumber);
    await _saveLocal(merged);

    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from(_progressTable).upsert(
        {
          'user_id': user.id,
          'day_number': dayNumber,
          'is_completed': true,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,day_number',
      );
    } catch (_) {
      // Offline or network error — local cache will re-sync on next load.
    }
  }

  Future<void> resetProgress() async {
    await _prefs.remove(_completedKey);
  }

  Future<Set<int>> _completedDays() async {
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
