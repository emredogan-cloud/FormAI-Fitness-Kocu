#!/usr/bin/env python3
"""Generates EXERCISE_IMAGE_REGENERATION_GUIDE.html.

Pre-Phase-10 polish. Every file in `photos/exercises/` carries burned-in
instructional text in the pixels — some English, some Turkish — so a
reader of either language meets the other's on some exercises and no
amount of translation fixes it. The 87 replacements have to be generated,
and this script writes the brief for generating them.

Run:  python3 tool/gen_exercise_image_guide.py

It reads `photos/exercises/` for the authoritative file list and cross-
checks it against `ExerciseMediaRegistry._localImageSlugs`, so an image
added without a registry entry (or the reverse) fails the run rather than
producing a guide that quietly omits it.

The per-exercise table below is the only hand-authored part. `moment`,
`setup` and `angle` are what make a prompt produce a usable instructional
frame rather than a generic gym photograph, so they are written per
movement rather than templated.
"""

import glob
import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = 'photos/exercises'
REGISTRY = 'lib/features/workout/data/exercise_media_registry.dart'
OUT = 'EXERCISE_IMAGE_REGENERATION_GUIDE.html'

# The house style, lifted from WORKOUT_BACKGROUND_IMAGE_REQUESTS.md and
# adapted from "background" framing to "instructional" framing: the
# subject is centred and whole rather than pushed to one side, because
# this image IS the content rather than a backdrop for copy.
LOOK = (
    'dark studio cyclorama fading to deep black, cinematic three-point '
    'lighting, violet key light from camera left and a lime-green rim '
    'light separating the athlete from the background, high contrast, '
    'crisp muscle and skin definition, light sweat sheen, background '
    'softly out of focus while the athlete stays tack sharp, ultra '
    'realistic premium fitness photography, colour graded, highly '
    'detailed, 4k'
)

# `BoxFit.cover` plus the guide player's Ken Burns pan-zoom means the
# frame is cropped and drifts, so anything near an edge is not reliably
# on screen. Stated in the prompt rather than trusted to luck.
SAFETY = (
    'full body inside the frame with generous margin on all four sides, '
    'subject centred, nothing important near the edges'
)

NEGATIVE = (
    'No text, no words, no letters, no numbers, no captions, no labels, '
    'no titles, no timers, no arrows, no logos, no watermark, no UI, no '
    'overlay, no graphics, no borders, no split panels, no collage, no '
    'before-and-after layout. A single clean photograph.'
)

# slug -> (display name, moment, setup, angle)
EX = {
    'archer_push_up': ('Archer Push-Up', 'at the bottom, weight stacked over the bent arm while the opposite arm is straight out to the side', 'bare wooden floor, no equipment', 'low three-quarter view from the straight-arm side'),
    'bear_crawl': ('Bear Crawl', 'mid-crawl with one hand and the opposite knee lifted, knees hovering a hand-width off the floor', 'bare wooden floor, no equipment', 'ground-level side view'),
    'bench_dip': ('Bench Dip', 'at the bottom, elbows bent to ninety degrees and hips close to the bench', 'a flat bench, heels on the floor', 'side view level with the shoulders'),
    'bird_dog': ('Bird Dog', 'at full extension, one arm and the opposite leg in a straight line with the spine', 'an exercise mat', 'side view at hip height'),
    'box_jump': ('Box Jump', 'at the top of the landing, both feet on the box in a quarter squat', 'a sixty-centimetre plyo box', 'side view level with the box'),
    'cable_crossover': ('Cable Crossover', 'at peak contraction with both handles met in front of the chest', 'a dual cable crossover station, high pulleys', 'front three-quarter view'),
    'cable_curl': ('Cable Curl', 'at the top of the curl, elbows pinned to the ribs', 'a low cable pulley with a straight bar', 'side view level with the elbows'),
    'cat_cow': ('Cat-Cow Stretch', 'in the rounded cat position, spine at maximum flexion', 'an exercise mat, on all fours', 'side view at hip height'),
    'child_pose': ("Child's Pose", 'settled fully into the pose, hips on the heels and arms stretched forward', 'an exercise mat', 'low side view'),
    'chin_up_negative': ('Chin-Up Negative', 'halfway through the slow lowering, elbows bent to ninety degrees', 'a pull-up bar, underhand grip', 'front view level with the chest'),
    'clap_push_up': ('Clap Push-Up', 'airborne at the top with both hands off the floor and clapped together', 'bare wooden floor, no equipment', 'low side view'),
    'cobra_stretch': ('Cobra Stretch', 'at the top of the arch, chest lifted and hips still on the mat', 'an exercise mat', 'low three-quarter view'),
    'cuban_press': ('Cuban Press', 'at the external-rotation point, elbows at shoulder height and forearms vertical', 'a pair of light dumbbells', 'front view level with the shoulders'),
    'dead_bug': ('Dead Bug', 'at full extension, one arm overhead and the opposite leg straight just above the floor', 'an exercise mat, lying supine', 'side view at floor level'),
    'dead_hang': ('Dead Hang', 'hanging at full stretch, shoulders relaxed and feet clear of the floor', 'a pull-up bar, overhand grip', 'front view level with the ribs'),
    'deadlift': ('Deadlift', 'at lockout, bar at the hips and shoulders back', 'a loaded olympic barbell on a lifting platform', 'side view level with the hips'),
    'decline_bench_press': ('Decline Bench Press', 'at the bottom, bar touching the lower chest', 'a decline bench and a loaded barbell', 'side three-quarter view'),
    'decline_crunch': ('Decline Crunch', 'at the top of the crunch, shoulder blades well off the pad', 'a decline sit-up bench', 'side view level with the torso'),
    'diamond_push_up': ('Diamond Push-Up', 'at the bottom, hands forming a diamond directly under the sternum', 'bare wooden floor, no equipment', 'low front three-quarter view'),
    'downward_dog': ('Downward Dog', 'in the full pose, hips high and heels reaching for the floor', 'an exercise mat', 'side view at hip height'),
    'dragon_flag': ('Dragon Flag', 'at the hardest point, body a straight diagonal line supported only on the upper back', 'a flat bench, hands gripping behind the head', 'side view level with the bench'),
    'dumbbell_clean': ('Dumbbell Clean', 'at the catch, dumbbells racked at the shoulders in a quarter squat', 'a pair of dumbbells', 'front three-quarter view'),
    'dumbbell_kickback': ('Dumbbell Kickback', 'at full extension, upper arm parallel to the floor and elbow locked', 'a single dumbbell, torso hinged forward', 'side view level with the elbow'),
    'dumbbell_pullover': ('Dumbbell Pullover', 'at the deepest stretch, dumbbell behind the head and ribcage expanded', 'a flat bench and a single dumbbell', 'side view level with the bench'),
    'dumbbell_row': ('Dumbbell Row', 'at the top of the row, elbow driven past the ribs', 'a flat bench, one knee and one hand supported, a dumbbell in the free hand', 'side three-quarter view'),
    'dumbbell_step_up': ('Dumbbell Step-Up', 'at the top, driving through the lead leg with the trail foot leaving the box', 'a plyo box and a pair of dumbbells', 'side view level with the box'),
    'face_pull': ('Face Pull', 'at peak contraction, rope split beside the ears and elbows high', 'a high cable pulley with a rope attachment', 'front view level with the face'),
    'farmer_carry': ('Farmer Carry', 'mid-stride under load, shoulders packed and torso upright', 'a pair of heavy dumbbells or farmer handles', 'front three-quarter view'),
    'frog_pump': ('Frog Pump', 'at the top of the bridge, soles of the feet together and hips fully extended', 'an exercise mat', 'side three-quarter view'),
    'front_squat': ('Front Squat', 'at the bottom, elbows high and thighs below parallel', 'a loaded barbell in a front rack', 'side three-quarter view'),
    'glute_bridge': ('Glute Bridge', 'at the top, hips locked out in a straight line from knee to shoulder', 'an exercise mat', 'side view at hip height'),
    'goblet_squat': ('Goblet Squat', 'at the bottom, dumbbell held at the chest and elbows inside the knees', 'a single dumbbell or kettlebell', 'front three-quarter view'),
    'half_burpee': ('Half Burpee', 'at the moment both feet land back under the hips in the plank-to-squat transition', 'bare wooden floor, no equipment', 'low side view'),
    'handstand_hold': ('Handstand Hold', 'balanced in a straight line, heels stacked over the hands', 'bare floor beside a wall', 'front view from a low angle'),
    'handstand_push_up': ('Handstand Push-Up', 'at the bottom, crown of the head just above the floor and elbows bent', 'a wall for support', 'side view from a low angle'),
    'hip_flexor_stretch': ('Hip Flexor Stretch', 'in a half-kneeling lunge with the back hip pushed forward and the torso tall', 'an exercise mat', 'side view at hip height'),
    'hip_thrust': ('Hip Thrust', 'at lockout, bar over the hips and the shin vertical', 'a flat bench and a padded loaded barbell', 'side view level with the hips'),
    'hollow_hold': ('Hollow Hold', 'in the held position, lower back pressed down with shoulders and heels off the floor', 'an exercise mat', 'side view at floor level'),
    'hyperextension': ('Hyperextension', 'at the top, torso in line with the legs and no over-arching', 'a forty-five degree back extension bench', 'side view level with the torso'),
    'incline_chest_fly': ('Incline Chest Fly', 'at the deepest stretch, arms wide with a soft elbow bend', 'an incline bench and a pair of dumbbells', 'front three-quarter view from above'),
    'incline_dumbbell_curl': ('Incline Dumbbell Curl', 'at the bottom, arms hanging fully stretched behind the torso', 'an incline bench and a pair of dumbbells', 'side view level with the chest'),
    'inverted_row': ('Inverted Row', 'at the top, chest to the bar and body in one straight line', 'a barbell in a rack at hip height', 'side view level with the bar'),
    'kettlebell_swing': ('Kettlebell Swing', 'at the top of the swing, kettlebell floating at chest height and hips locked out', 'a twenty-kilogram kettlebell', 'side view level with the hips'),
    'knee_push_up': ('Knee Push-Up', 'at the bottom, knees down and body straight from knee to head', 'an exercise mat', 'low side view'),
    'landmine_press': ('Landmine Press', 'at full extension, barbell end pressed up and forward', 'a barbell anchored in a landmine sleeve', 'side three-quarter view'),
    'lateral_shuffle': ('Lateral Shuffle', 'mid-shuffle in an athletic stance, both feet momentarily off the floor', 'bare floor, no equipment', 'front view at hip height'),
    'machine_chest_press': ('Machine Chest Press', 'at full extension, handles pressed together in front of the chest', 'a seated chest press machine', 'side three-quarter view'),
    'machine_shoulder_press': ('Machine Shoulder Press', 'at full extension, handles pressed overhead', 'a seated shoulder press machine', 'side three-quarter view'),
    'medicine_ball_russian_twist': ('Medicine Ball Russian Twist', 'at the end of a rotation, ball beside the hip and torso turned', 'a medicine ball, seated with heels raised', 'front three-quarter view'),
    'nordic_curl': ('Nordic Curl', 'halfway down, body a straight line from knee to head under hamstring control', 'a pad under the knees with the ankles anchored', 'side view level with the torso'),
    'overhead_triceps_extension': ('Overhead Triceps Extension', 'at the deepest stretch, dumbbell behind the head and elbows pointing up', 'a single dumbbell held in both hands', 'side three-quarter view'),
    'pike_push_up_close': ('Pike Push-Up', 'at the bottom, hips high and crown of the head near the floor', 'bare wooden floor, no equipment', 'side view at floor level'),
    'pike_walk': ('Pike Walk', 'mid-walk, hands walking out with the hips still high', 'bare wooden floor, no equipment', 'side view at hip height'),
    'pistol_squat': ('Pistol Squat', 'at the bottom, one leg fully bent and the other held straight out in front', 'bare floor, no equipment', 'side three-quarter view'),
    'plank_jack': ('Plank Jack', 'mid-jack with the feet apart and airborne, torso rigid in a plank', 'an exercise mat', 'low side view'),
    'preacher_curl': ('Preacher Curl', 'at the bottom, arms almost straight along the pad', 'a preacher bench and an ez-curl bar', 'side three-quarter view'),
    'prone_t_raise': ('Prone T-Raise', 'at the top, arms out to the sides forming a T with the shoulder blades pinched', 'an incline bench, chest supported', 'view from above and behind'),
    'prone_y_raise': ('Prone Y-Raise', 'at the top, arms overhead forming a Y with the thumbs up', 'an incline bench, chest supported', 'view from above and behind'),
    'pseudo_planche_push_up': ('Pseudo Planche Push-Up', 'at the bottom with the hands beside the waist and the shoulders forward of them', 'bare wooden floor, no equipment', 'low side view'),
    'rear_delt_fly': ('Rear Delt Fly', 'at peak contraction, arms wide and shoulder blades drawn together', 'a pair of light dumbbells, torso hinged forward', 'view from above and behind'),
    'reverse_crunch': ('Reverse Crunch', 'at the top, hips curled off the floor and knees over the chest', 'an exercise mat', 'side view at floor level'),
    'rope_triceps_pushdown': ('Rope Triceps Pushdown', 'at full extension, rope split apart at the thighs', 'a high cable pulley with a rope attachment', 'side view level with the elbows'),
    'scapular_pull_up': ('Scapular Pull-Up', 'at the top of the shrug, arms still straight and shoulders pulled down', 'a pull-up bar, overhand grip', 'front view level with the shoulders'),
    'scapular_wall_slide': ('Scapular Wall Slide', 'mid-slide with forearms flat to the wall and elbows at shoulder height', 'a bare wall', 'front three-quarter view'),
    'seated_cable_row': ('Seated Cable Row', 'at the top of the row, handle at the navel and chest tall', 'a seated cable row station', 'side view level with the torso'),
    'seated_calf_raise': ('Seated Calf Raise', 'at the top, up on the balls of the feet with the calves fully shortened', 'a seated calf raise machine', 'side view level with the knees'),
    'shadow_boxing': ('Shadow Boxing', 'mid-combination with one arm extended and the guard hand at the chin', 'bare floor, hand wraps, no equipment', 'front three-quarter view'),
    'side_plank': ('Side Plank', 'in the held position, hips lifted and body in one straight line', 'an exercise mat', 'front view level with the hips'),
    'single_leg_calf_raise': ('Single-Leg Calf Raise', 'at the top on one foot, heel driven high', 'a raised step, one hand lightly on a rail', 'side view level with the ankle'),
    'single_leg_glute_bridge': ('Single-Leg Glute Bridge', 'at the top, one leg extended and the hips level', 'an exercise mat', 'side view at hip height'),
    'single_leg_rdl': ('Single-Leg Romanian Deadlift', 'at the bottom, torso and rear leg forming one line parallel to the floor', 'a single dumbbell', 'side view level with the hips'),
    'squat_jump_pulse': ('Squat Jump Pulse', 'airborne at the top of the jump with the feet just off the floor', 'bare floor, no equipment', 'front view at hip height'),
    'squat_thrust': ('Squat Thrust', 'at the moment the feet snap forward under the chest from the plank', 'bare wooden floor, no equipment', 'low side view'),
    'standing_hamstring_stretch': ('Standing Hamstring Stretch', 'at the deepest point, hinged forward with a long spine', 'bare floor, no equipment', 'side view at hip height'),
    'sumo_squat': ('Sumo Squat', 'at the bottom, feet wide and toes turned out, thighs below parallel', 'a single dumbbell held between the legs', 'front view at hip height'),
    'swimmer': ('Swimmer', 'at the top, opposite arm and leg lifted clear of the floor', 'an exercise mat, lying prone', 'side view at floor level'),
    't_bar_row': ('T-Bar Row', 'at the top of the row, handles pulled into the ribs', 'a t-bar row station with plates loaded', 'side three-quarter view'),
    'thruster': ('Thruster', 'at the top, weights locked out overhead out of a front squat', 'a pair of dumbbells', 'front three-quarter view'),
    'toe_touch': ('Toe Touch', 'at the top, reaching up toward the raised feet with the shoulders off the floor', 'an exercise mat, lying supine with legs vertical', 'side view at floor level'),
    'tricep_extension_floor': ('Floor Triceps Extension', 'at the bottom, dumbbells beside the ears with the upper arms vertical', 'an exercise mat and a pair of dumbbells', 'side view at floor level'),
    'tuck_jump': ('Tuck Jump', 'at the peak of the jump with both knees tucked to the chest', 'bare floor, no equipment', 'front view at hip height'),
    'upright_row': ('Upright Row', 'at the top, elbows above the wrists at shoulder height', 'a barbell or a pair of dumbbells', 'front view level with the chest'),
    'walking_lunge_dumbbell': ('Walking Lunge', 'at the bottom of a stride, back knee just above the floor', 'a pair of dumbbells', 'side view level with the hips'),
    'wall_walk': ('Wall Walk', 'partway up, feet high on the wall and hands walked in close to it', 'a bare wall and floor', 'side view from a low angle'),
    'weighted_leg_raise': ('Weighted Leg Raise', 'at the top, legs vertical with a dumbbell held between the feet', 'an exercise mat and a light dumbbell', 'side view at floor level'),
    'weighted_sit_up': ('Weighted Sit-Up', 'at the top of the sit-up, weight held at the chest', 'an exercise mat and a dumbbell or plate', 'side view at floor level'),
    'wide_push_up': ('Wide Push-Up', 'at the bottom, hands wider than the shoulders and chest close to the floor', 'bare wooden floor, no equipment', 'low front three-quarter view'),
}

# Movements whose still frame cannot show what the exercise is. See the
# "Which categories need motion" section of the guide.
NEEDS_MOTION = {
    'bear_crawl', 'box_jump', 'clap_push_up', 'dumbbell_clean', 'half_burpee',
    'kettlebell_swing', 'lateral_shuffle', 'pike_walk', 'plank_jack',
    'shadow_boxing', 'squat_jump_pulse', 'squat_thrust', 'thruster',
    'tuck_jump', 'walking_lunge_dumbbell', 'wall_walk', 'cat_cow',
    'scapular_wall_slide', 'farmer_carry',
}

# Isometric holds — a still frame is not a compromise, it is the exercise.
HOLDS = {
    'child_pose', 'cobra_stretch', 'dead_hang', 'downward_dog',
    'handstand_hold', 'hip_flexor_stretch', 'hollow_hold', 'side_plank',
    'standing_hamstring_stretch',
}


def pascal(slug):
    return ''.join(p.capitalize() for p in slug.split('_'))


def article(word):
    """`a` / `an` by sound, not just by letter — the exercise list has
    "an archer push-up" but also "a wall walk"."""
    return 'an' if word[0].lower() in 'aeiou' else 'a'


def prompt_for(slug):
    name, moment, setup, angle = EX[slug]
    movement = name.lower()
    return (
        f'A single athlete demonstrating {article(movement)} {movement}, '
        f'captured {moment}. {setup.capitalize()}. Photographed from '
        f'{article(angle)} {angle} so the working joints are unobstructed. '
        f'{SAFETY.capitalize()}. {LOOK.capitalize()}. 3:2 landscape. '
        f'{NEGATIVE}'
    )


def load_registry_slugs():
    text = open(os.path.join(ROOT, REGISTRY), encoding='utf-8').read()
    block = text.split('_localImageSlugs = {')[1].split('};')[0]
    return set(re.findall(r"'([a-z0-9_]+)'", block))


def main():
    os.chdir(ROOT)
    files = sorted(os.path.basename(f)[:-5]
                   for f in glob.glob(f'{SRC_DIR}/*.webp'))
    registry = load_registry_slugs()
    from_files = {pascal(s) for s in registry}

    problems = []
    if set(files) != from_files:
        problems.append(f'registry/disk mismatch: '
                        f'{sorted(from_files ^ set(files))}')
    missing = [s for s in registry if s not in EX]
    if missing:
        problems.append(f'no prompt data authored for: {sorted(missing)}')
    extra = [s for s in EX if s not in registry]
    if extra:
        problems.append(f'prompt data for unknown slug: {sorted(extra)}')
    if problems:
        for p in problems:
            print(f'ERROR: {p}', file=sys.stderr)
        return 1

    rows = []
    for slug in sorted(registry, key=pascal):
        name = EX[slug][0]
        motion = ('motion' if slug in NEEDS_MOTION
                  else ('hold' if slug in HOLDS else 'static'))
        rows.append({
            'slug': slug,
            'name': name,
            'file': f'{pascal(slug)}.webp',
            'src': f'{SRC_DIR}/{pascal(slug)}.webp',
            'motion': motion,
            'prompt': prompt_for(slug),
        })

    open(os.path.join(ROOT, OUT), 'w', encoding='utf-8').write(render(rows))
    counts = {k: sum(1 for r in rows if r['motion'] == k)
              for k in ('static', 'hold', 'motion')}
    print(f'wrote {OUT} — {len(rows)} exercises '
          f'({counts["static"]} static, {counts["hold"]} hold, '
          f'{counts["motion"]} motion)')
    return 0


def render(rows):
    cards = []
    for i, r in enumerate(rows, 1):
        badge = {
            'static': ('static ok', 'ok'),
            'hold': ('isometric hold', 'ok'),
            'motion': ('needs motion', 'warn'),
        }[r['motion']]
        cards.append(f'''
    <article class="card" data-motion="{r['motion']}" data-name="{html.escape(r['name'].lower())}">
      <header>
        <span class="num">{i:02d}</span>
        <h3>{html.escape(r['name'])}</h3>
        <span class="badge {badge[1]}">{badge[0]}</span>
      </header>
      <dl>
        <dt>current file</dt><dd><code>{html.escape(r['src'])}</code></dd>
        <dt>destination folder</dt><dd><code>{SRC_DIR}/</code></dd>
        <dt>destination filename</dt><dd><code>{html.escape(r['file'])}</code></dd>
        <dt>slug</dt><dd><code>{html.escape(r['slug'])}</code></dd>
      </dl>
      <div class="promptwrap">
        <button class="copy" type="button">Copy prompt</button>
        <pre class="prompt">{html.escape(r['prompt'])}</pre>
      </div>
    </article>''')

    total = len(rows)
    motion = sum(1 for r in rows if r['motion'] == 'motion')
    hold = sum(1 for r in rows if r['motion'] == 'hold')
    static = total - motion - hold

    return TEMPLATE.format(
        total=total, motion=motion, hold=hold, static=static,
        cards=''.join(cards),
    )


TEMPLATE = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FormAI · Exercise Image Regeneration Guide</title>
<style>
  :root {{
    --bg:#000; --card:#0b0b10; --line:#ffffff17; --ink:#fff;
    --muted:#ffffff8c; --faint:#ffffff5c; --purple:#8e5bff; --lime:#b8ff33;
  }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink);
    font:15px/1.6 ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }}
  .wrap {{ max-width:1100px; margin:0 auto; padding:32px 20px 96px; }}
  h1 {{ font-size:30px; margin:0 0 6px; letter-spacing:.2px; }}
  h2 {{ font-size:20px; margin:40px 0 12px; }}
  h3 {{ font-size:16px; margin:0; flex:1 1 auto; }}
  p, li {{ color:var(--muted); }}
  code {{ font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12.5px;
    color:var(--lime); background:#ffffff0d; padding:1px 5px; border-radius:5px; }}
  a {{ color:var(--lime); }}
  .lede {{ color:var(--muted); max-width:70ch; }}
  .stats {{ display:flex; flex-wrap:wrap; gap:10px; margin:22px 0 8px; }}
  .stat {{ background:var(--card); border:1px solid var(--line); border-radius:14px;
    padding:12px 16px; min-width:120px; }}
  .stat b {{ display:block; font-size:24px; }}
  .stat span {{ color:var(--faint); font-size:12px; text-transform:uppercase;
    letter-spacing:1px; }}
  section.note {{ background:var(--card); border:1px solid var(--line);
    border-radius:16px; padding:18px 20px; margin:18px 0; }}
  section.note.flag {{ border-color:#8e5bff66; }}
  .toolbar {{ position:sticky; top:0; z-index:5; background:#000000ee;
    backdrop-filter:blur(8px); padding:14px 0; margin-bottom:10px;
    border-bottom:1px solid var(--line); display:flex; gap:10px; flex-wrap:wrap; }}
  .toolbar input {{ flex:1 1 220px; background:var(--card); color:var(--ink);
    border:1px solid var(--line); border-radius:999px; padding:10px 16px; font:inherit; }}
  .toolbar button {{ background:var(--card); color:var(--muted); border:1px solid var(--line);
    border-radius:999px; padding:10px 16px; font:inherit; cursor:pointer; }}
  .toolbar button[aria-pressed=true] {{ color:#000; background:var(--lime);
    border-color:var(--lime); font-weight:700; }}
  .card {{ background:var(--card); border:1px solid var(--line); border-radius:18px;
    padding:16px 18px; margin:14px 0; }}
  .card header {{ display:flex; align-items:center; gap:12px; margin-bottom:12px; }}
  .num {{ color:var(--faint); font-variant-numeric:tabular-nums; font-size:13px; }}
  .badge {{ font-size:11px; letter-spacing:.6px; text-transform:uppercase;
    border-radius:999px; padding:4px 10px; border:1px solid; }}
  .badge.ok {{ color:var(--lime); border-color:#b8ff3366; }}
  .badge.warn {{ color:var(--purple); border-color:#8e5bff66; }}
  dl {{ display:grid; grid-template-columns:auto 1fr; gap:4px 14px; margin:0 0 12px; }}
  dt {{ color:var(--faint); font-size:12px; text-transform:uppercase; letter-spacing:.7px; }}
  dd {{ margin:0; }}
  .promptwrap {{ position:relative; }}
  pre.prompt {{ white-space:pre-wrap; background:#ffffff08; border:1px solid var(--line);
    border-radius:12px; padding:14px 16px; margin:0; color:#e9e9ee;
    font:13px/1.65 ui-monospace,SFMono-Regular,Menlo,monospace; }}
  button.copy {{ position:absolute; top:8px; right:8px; background:var(--purple);
    color:#fff; border:0; border-radius:999px; padding:7px 14px; font:inherit;
    font-size:12.5px; font-weight:700; cursor:pointer; }}
  button.copy.done {{ background:var(--lime); color:#000; }}
  table {{ width:100%; border-collapse:collapse; margin:12px 0; }}
  th, td {{ text-align:left; padding:8px 10px; border-bottom:1px solid var(--line);
    font-size:14px; }}
  th {{ color:var(--faint); font-size:12px; text-transform:uppercase; letter-spacing:.7px; }}
  @media (max-width:600px) {{
    dl {{ grid-template-columns:1fr; }}
    button.copy {{ position:static; margin-bottom:8px; }}
  }}
</style>
</head>
<body>
<div class="wrap">

<h1>Exercise Image Regeneration Guide</h1>
<p class="lede">Every one of the {total} files in <code>photos/exercises/</code>
carries instructional text burned into the pixels. Some of it is English,
some of it is Turkish, and no translation layer can reach any of it — a
Turkish reader meets English on some exercises and an English reader meets
Turkish on others. This document is the brief for replacing all {total}.</p>

<div class="stats">
  <div class="stat"><b>{total}</b><span>images</span></div>
  <div class="stat"><b>{total}</b><span>carry text</span></div>
  <div class="stat"><b>{static}</b><span>static is right</span></div>
  <div class="stat"><b>{hold}</b><span>isometric holds</span></div>
  <div class="stat"><b>{motion}</b><span>want motion</span></div>
</div>

<h2>What is actually wrong with these files</h2>
<p>They are not photographs with a caption. They are <b>infographics</b>.
The audit found four distinct layouts:</p>
<table>
  <tr><th>layout</th><th>count</th><th>what the pixels carry</th></tr>
  <tr><td>Two-panel before/after<br><code>800&times;437</code></td><td>37</td>
      <td>A caption bar top <em>and</em> bottom. Sometimes English over
          Turkish, sometimes the same English twice.</td></tr>
  <tr><td>Step filmstrip<br><code>800&times;533</code></td><td>48</td>
      <td>A title, 3&ndash;6 numbered steps each with a Turkish instruction
          paragraph, per-frame time chips, and a
          <code>TOPLAM S&Uuml;RE</code> timeline. The isometric holds in
          this size class use a variant with one large photo and a Turkish
          sidebar &mdash; starting position, movement, breathing, cues,
          target muscles &mdash; instead of the panel strip.</td></tr>
  <tr><td>Frame grid<br><code>800&times;436</code></td><td>2</td>
      <td>A 2&times;3 contact sheet with English per-frame captions.</td></tr>
</table>

<section class="note flag">
<h3 style="margin-bottom:8px">Read this before generating anything</h3>
<p>The text in these files is not decoration — on the filmstrip layouts it
is <b>the coaching content</b>: the steps, the tempo, the breathing cues,
the muscles worked. Generating a clean photograph deletes it.</p>
<p>That is still the right move, because content burned into a pixel cannot
be translated, corrected, resized, read aloud by a screen reader, or shown
at a larger text scale. But the replacement is only complete when that
content lands somewhere the app can render it — the
<code>description</code> and <code>short_tip</code> columns the exercise
catalogue already has, or new step rows beside them. <b>The images and the
step copy are one project, not two.</b></p>
</section>

<section class="note">
<h3 style="margin-bottom:8px">Why every prompt says "centred, generous margin"</h3>
<p><code>ExerciseGuidePlayer</code> renders these with
<code>BoxFit.cover</code> inside a picture-in-picture slot and applies a
slow Ken&nbsp;Burns pan-zoom. The frame is therefore <em>cropped, and the
crop moves</em>. Anything near an edge is not reliably on screen — which is
also why a burned-in caption bar is doubly wrong here: the pan can slice it
in half.</p>
</section>

<section class="note">
<h3 style="margin-bottom:8px">Drop-in contract</h3>
<p>Keep the filename and the folder and there is <b>no code change at
all</b>. <code>ExerciseMediaRegistry.localImagePath()</code> derives the
path from the slug — <code>photos/exercises/&lt;PascalCase&gt;.webp</code> —
and <code>photos/exercises/</code> is already declared in
<code>pubspec.yaml</code>. Aspect ratio is free: <code>cover</code> crops to
the slot, so the 3:2 in these prompts changes nothing structurally.</p>
<p>Export as WebP. The current 87 total 2.7&nbsp;MB, and holding roughly
that budget keeps the APK where it is.</p>
</section>

<h2>Which categories need motion, and which do not</h2>
<p>The founder asked where a looping demonstration is required and where a
still is enough. The dividing line is not the muscle group — it is
<b>whether one frame can show what the exercise is</b>.</p>

<table>
  <tr><th>class</th><th>count</th><th>verdict</th></tr>
  <tr><td><b>Isometric holds</b><br>plank, dead hang, child's pose, stretches</td>
      <td>{hold}</td>
      <td><b>A still is not a compromise, it is the exercise.</b> There is
          nothing to animate. Never spend a video budget here.</td></tr>
  <tr><td><b>Single-plane strength</b><br>presses, rows, curls, squats, hinges</td>
      <td>{static}</td>
      <td><b>A still at the hardest position is sufficient</b>, and is
          arguably better than a loop: the position that gets corrected is
          the one the user has to be shown, and a loop shows it for a
          fraction of a second.</td></tr>
  <tr><td><b>Ballistic, locomotive and multi-position movements</b><br>
          burpees, swings, jumps, crawls, carries, shuffles, cleans,
          thrusters, wall walks</td>
      <td>{motion}</td>
      <td><b>These genuinely require a loop.</b> A still of a kettlebell
          swing and a still of a front raise are the same photograph. The
          information is the <em>path</em>, and a frame cannot carry a
          path. This is also exactly the set the current filmstrip layout
          was invented to fake.</td></tr>
</table>

<p>Each card below is tagged with its class, and the toolbar filters on it.
If the budget only covers part of the library, the {motion} tagged
<em>needs motion</em> are where a loop buys something a still cannot.</p>

<h2>Recommended media strategy</h2>
<ol>
  <li><b>Two tiers, not one.</b> A bundled WebP still for every exercise —
      it is the offline floor, it is what renders on a cold start, and it
      is what the user sees when the network is gone. A hosted loop
      <em>on top</em> for the {motion} that need one. Never ship a
      movement with only a loop.</li>
  <li><b>The loop is hosted, and today it has to be.</b>
      <code>ExerciseGuidePlayer</code> passes only <code>http</code> paths
      to the video controller and deliberately drops bundled asset paths to
      the fallback tile — a branch added because malformed-URL inputs were
      crashing. So a looping demo means a Supabase-hosted file plus the
      existing file-cache warm, not a new asset in the APK. Good outcome
      anyway: 19 loops in the binary would cost more than the entire
      current image library.</li>
  <li><b>Make the registry manifest-driven.</b>
      <code>ExerciseMediaRegistry</code> still needs a hand edit to
      <code>_localImageSlugs</code> for every file added.
      <code>WorkoutBackgroundRegistry</code> beside it already resolves
      from the asset manifest, so dropping a correctly-named file in is the
      whole procedure. Porting that pattern removes the one step in this
      pipeline a person can forget.</li>
  <li><b>Silent, muted, 3–5 s, no audio track.</b> These play in a
      picture-in-picture slot beside a live workout. An audio track would
      fight the voice coach and is dead weight in the file.</li>
  <li><b>The step copy goes to the database, not the pixels.</b> Whatever
      the filmstrips were saying belongs in the exercise catalogue next to
      <code>description</code> and <code>short_tip</code>, where it is
      translatable, screen-reader reachable and scalable with the user's
      text size. That is also what makes the next language a content task
      rather than 87 more renders.</li>
</ol>

<h2>Production pipeline</h2>
<ol>
  <li>Generate at 1536&times;1024 or larger from the prompt on the card.</li>
  <li><b>Reject any render with a letter or a digit in it.</b> Image models
      put text on gym walls, plates and clothing unprompted. This is the
      one check that cannot be skipped, because it is the entire reason the
      library is being replaced.</li>
  <li>Check the pose is the one named in the prompt. A model will happily
      return a plausible athlete in the wrong position, and a wrong
      instructional image is worse than none.</li>
  <li>Crop to 3:2, centred on the athlete, and confirm nothing important
      sits within ~8&nbsp;% of any edge — that band is what the pan-zoom
      eats.</li>
  <li>Export WebP, quality ~82, target &lt;&nbsp;40&nbsp;KB.</li>
  <li>Save over the existing file at the exact path on the card. No code
      change, no registry edit, no pubspec edit.</li>
  <li>Re-run <code>flutter build apk --release</code> and confirm the size
      has not moved materially.</li>
</ol>

<h2>The {total} images</h2>

<div class="toolbar">
  <input id="q" type="search" placeholder="Filter by exercise name…" aria-label="Filter by exercise name">
  <button data-f="all" aria-pressed="true">All</button>
  <button data-f="motion" aria-pressed="false">Needs motion</button>
  <button data-f="hold" aria-pressed="false">Holds</button>
  <button data-f="static" aria-pressed="false">Static</button>
  <button id="copyall" type="button">Copy all prompts</button>
</div>

<div id="list">{cards}
</div>

</div>
<script>
  document.querySelectorAll('button.copy').forEach(function (b) {{
    b.addEventListener('click', function () {{
      var text = b.parentElement.querySelector('pre.prompt').textContent;
      navigator.clipboard.writeText(text).then(function () {{
        b.textContent = 'Copied'; b.classList.add('done');
        setTimeout(function () {{
          b.textContent = 'Copy prompt'; b.classList.remove('done');
        }}, 1400);
      }});
    }});
  }});

  document.getElementById('copyall').addEventListener('click', function () {{
    var parts = [];
    document.querySelectorAll('#list .card').forEach(function (c) {{
      if (c.style.display === 'none') return;
      parts.push(c.querySelector('h3').textContent + ' -> ' +
        c.querySelectorAll('dd code')[2].textContent + '\n' +
        c.querySelector('pre.prompt').textContent);
    }});
    navigator.clipboard.writeText(parts.join('\n\n---\n\n'));
    this.textContent = 'Copied ' + parts.length;
    var self = this;
    setTimeout(function () {{ self.textContent = 'Copy all prompts'; }}, 1600);
  }});

  var filter = 'all';
  function apply() {{
    var q = document.getElementById('q').value.trim().toLowerCase();
    document.querySelectorAll('#list .card').forEach(function (c) {{
      var okF = filter === 'all' || c.dataset.motion === filter;
      var okQ = !q || c.dataset.name.indexOf(q) !== -1;
      c.style.display = (okF && okQ) ? '' : 'none';
    }});
  }}
  document.getElementById('q').addEventListener('input', apply);
  document.querySelectorAll('.toolbar button[data-f]').forEach(function (b) {{
    b.addEventListener('click', function () {{
      filter = b.dataset.f;
      document.querySelectorAll('.toolbar button[data-f]').forEach(function (o) {{
        o.setAttribute('aria-pressed', String(o === b));
      }});
      apply();
    }});
  }});
</script>
</body>
</html>
'''


if __name__ == '__main__':
    raise SystemExit(main())
