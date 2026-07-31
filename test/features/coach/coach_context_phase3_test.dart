import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/coach/domain/coach_context.dart';

/// Roadmap Phase 3 (AI work) · the two facts the camera tutorial hands
/// the coach.
///
/// `toPromptContext()` is the string the LLM is literally given, so these
/// tests are about what the coach is allowed to believe. Getting either
/// wrong produces the specific failure that makes an AI coach feel fake:
/// promising form feedback to someone training without a camera, or
/// greeting a user as a stranger sixty seconds after walking them
/// through calibration.
CoachContext _ctx({
  bool firstCameraSession = false,
  String workoutMode = 'camera',
}) =>
    CoachContext(
      hour: 9,
      name: 'Deniz',
      completedDays: 0,
      firstCameraSession: firstCameraSession,
      workoutMode: workoutMode,
    );

void main() {
  group('defaults', () {
    test('a context built without the Phase 3 fields is camera, not-first', () {
      const ctx = CoachContext(hour: 9);
      expect(ctx.firstCameraSession, isFalse);
      expect(ctx.workoutMode, 'camera');
    });

    test('neither line appears in the prompt by default', () {
      final prompt = _ctx().toPromptContext();
      expect(prompt, isNot(contains('Kamera kurulumunu az önce')));
      expect(prompt, isNot(contains('kamerasız')));
    });
  });

  group('firstCameraSession', () {
    test(
        'adds the just-calibrated line so the coach can reference the '
        'moment the user just lived through', () {
      final prompt = _ctx(firstCameraSession: true).toPromptContext();
      expect(prompt, contains('Kamera kurulumunu az önce tamamladı'));
      expect(prompt, contains('henüz ilk seansını'));
    });

    test('the line is absent once it is false again', () {
      // It is a transient state — true only between calibration and the
      // first logged session — so it must not linger in the prompt.
      expect(
        _ctx().toPromptContext(),
        isNot(contains('Kamera kurulumunu az önce tamamladı')),
      );
    });
  });

  group('workoutMode', () {
    test('manual mode states plainly that no form analysis is happening', () {
      final prompt = _ctx(workoutMode: 'manual').toPromptContext();
      // The coach must not offer form feedback it cannot have. Saying so
      // in the prompt is the only place that guarantee can live.
      expect(prompt, contains('kamerasız'));
      expect(prompt, contains('form analizi yapılmıyor'));
    });

    test('camera mode adds no mode line — the default needs no caveat', () {
      expect(
        _ctx(workoutMode: 'camera').toPromptContext(),
        isNot(contains('form analizi yapılmıyor')),
      );
    });

    test('an unrecognised mode is treated as camera rather than caveated', () {
      // Defensive: a future mode token must not make the coach announce
      // a limitation that may not apply.
      expect(
        _ctx(workoutMode: 'something_new').toPromptContext(),
        isNot(contains('form analizi yapılmıyor')),
      );
    });
  });

  group('both flags together', () {
    test('a manual-mode user is never told they just calibrated a camera', () {
      // The provider derives firstCameraSession from camera mode, so this
      // combination should not occur; the prompt stays coherent even if
      // it somehow did.
      final prompt = _ctx(workoutMode: 'manual').toPromptContext();
      expect(prompt, contains('kamerasız'));
      expect(prompt, isNot(contains('Kamera kurulumunu az önce tamamladı')));
    });

    test('the rest of the profile is untouched by either flag', () {
      final base = _ctx().toPromptContext();
      final withFlags = _ctx(firstCameraSession: true, workoutMode: 'manual')
          .toPromptContext();
      // Additive only: the existing profile block the coach already
      // relies on must survive verbatim.
      for (final line in base.split('\n')) {
        expect(withFlags, contains(line));
      }
    });
  });
}
