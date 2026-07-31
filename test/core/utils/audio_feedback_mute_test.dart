import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/utils/audio_feedback.dart';

/// Roadmap Phase 3b · the voice coach's mute switch.
///
/// The property under test is narrow and absolute: when muted, nothing
/// reaches the TTS engine. It is enforced at the single [speak] gate
/// rather than at the dozen call sites that speak (rep milestones,
/// pacing, form warnings, rest checkpoints, tutorial guidance) — a mute
/// each of them had to remember to honour is a mute that leaks, and the
/// user finds the leak in a quiet gym.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      // `getLanguages` must look like a real device list or init()
      // takes the fallback branch; everything else is a no-op ack.
      if (call.method == 'getLanguages') return <String>['tr-TR', 'en-US'];
      return 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<MethodCall> speakCalls() =>
      calls.where((c) => c.method == 'speak').toList();

  test('defaults to unmuted — the coach speaks unless told not to', () {
    expect(AudioFeedback().muted, isFalse);
  });

  test('a muted instance sends nothing to the platform', () async {
    final audio = AudioFeedback()..muted = true;
    await audio.speak('Son iki tekrar, sık dişini!');
    expect(speakCalls(), isEmpty);
  });

  test(
      'muting is checked before init — it cannot be defeated by speaking '
      'before the engine is ready', () async {
    final audio = AudioFeedback()..muted = true;
    await audio.speak('Kalçanı düz tut!');
    // Not even the setup handshake should run: a muted user should not
    // pay for a TTS engine they have switched off.
    expect(calls.where((c) => c.method == 'setLanguage'), isEmpty);
    expect(speakCalls(), isEmpty);
  });

  test('a muted instance blocks even the highest priority', () async {
    final audio = AudioFeedback()..muted = true;
    // Form warnings are the one class of speech that pre-empts everything
    // else. Mute still wins — the user asked for silence, not for
    // silence-except-when-we-think-it-matters.
    await audio.speak('Dizini içeri alma!', priority: SpeechPriority.warning);
    expect(speakCalls(), isEmpty);
  });

  test('unmuting restores speech', () async {
    final audio = AudioFeedback()..muted = true;
    await audio.speak('Yarıladın!');
    expect(speakCalls(), isEmpty);

    audio.muted = false;
    await audio.speak('Yarıladın!');
    expect(speakCalls(), hasLength(1));
    expect(speakCalls().single.arguments, 'Yarıladın!');
  });

  test(
      'muting mid-utterance stops the engine rather than letting the '
      'queue drain', () async {
    final audio = AudioFeedback();
    await audio.speak('Sıradaki hareket: Squat.');
    expect(speakCalls(), hasLength(1));

    calls.clear();
    audio.muted = true;
    // The user pressed mute because someone walked in; a burst that
    // finishes playing afterwards is exactly the failure the toggle
    // exists to prevent.
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'stop'), isNotEmpty);
  });

  test('setting the same mute value twice does not re-stop the engine',
      () async {
    final audio = AudioFeedback()..muted = true;
    await Future<void>.delayed(Duration.zero);
    calls.clear();

    audio.muted = true;
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'stop'), isEmpty);
  });

  test('an empty phrase is still a no-op when unmuted', () async {
    final audio = AudioFeedback();
    await audio.speak('');
    expect(speakCalls(), isEmpty);
  });
}
