# Phase 99 — Video-to-Image Mapping

## Overview

87 Phase 96 exercises have no Supabase-hosted videos. Each is mapped to a
bundled `photos/exercises/<PascalCase>.webp` asset via `ExerciseMediaRegistry`.

The mapping uses `StringCase.snakeToPascal(slug)` — the same converter that
builds Supabase video URLs — so slug ↔ filename stays consistent.

## Mapping Table

| Slug | WEBP Asset | Media Type |
|---|---|---|
| archer_push_up | photos/exercises/ArcherPushUp.webp | Local image |
| bear_crawl | photos/exercises/BearCrawl.webp | Local image |
| bench_dip | photos/exercises/BenchDip.webp | Local image |
| bird_dog | photos/exercises/BirdDog.webp | Local image |
| box_jump | photos/exercises/BoxJump.webp | Local image |
| cable_crossover | photos/exercises/CableCrossover.webp | Local image |
| cable_curl | photos/exercises/CableCurl.webp | Local image |
| cat_cow | photos/exercises/CatCow.webp | Local image |
| child_pose | photos/exercises/ChildPose.webp | Local image |
| chin_up_negative | photos/exercises/ChinUpNegative.webp | Local image |
| clap_push_up | photos/exercises/ClapPushUp.webp | Local image |
| cobra_stretch | photos/exercises/CobraStretch.webp | Local image |
| cuban_press | photos/exercises/CubanPress.webp | Local image |
| dead_bug | photos/exercises/DeadBug.webp | Local image |
| dead_hang | photos/exercises/DeadHang.webp | Local image |
| deadlift | photos/exercises/Deadlift.webp | Local image |
| decline_bench_press | photos/exercises/DeclineBenchPress.webp | Local image |
| decline_crunch | photos/exercises/DeclineCrunch.webp | Local image |
| diamond_push_up | photos/exercises/DiamondPushUp.webp | Local image |
| downward_dog | photos/exercises/DownwardDog.webp | Local image |
| dragon_flag | photos/exercises/DragonFlag.webp | Local image |
| dumbbell_clean | photos/exercises/DumbbellClean.webp | Local image |
| dumbbell_kickback | photos/exercises/DumbbellKickback.webp | Local image |
| dumbbell_pullover | photos/exercises/DumbbellPullover.webp | Local image |
| dumbbell_row | photos/exercises/DumbbellRow.webp | Local image |
| dumbbell_step_up | photos/exercises/DumbbellStepUp.webp | Local image |
| face_pull | photos/exercises/FacePull.webp | Local image |
| farmer_carry | photos/exercises/FarmerCarry.webp | Local image |
| frog_pump | photos/exercises/FrogPump.webp | Local image |
| front_squat | photos/exercises/FrontSquat.webp | Local image |
| glute_bridge | photos/exercises/GluteBridge.webp | Local image |
| goblet_squat | photos/exercises/GobletSquat.webp | Local image |
| half_burpee | photos/exercises/HalfBurpee.webp | Local image |
| handstand_hold | photos/exercises/HandstandHold.webp | Local image |
| handstand_push_up | photos/exercises/HandstandPushUp.webp | Local image |
| hip_flexor_stretch | photos/exercises/HipFlexorStretch.webp | Local image |
| hip_thrust | photos/exercises/HipThrust.webp | Local image |
| hollow_hold | photos/exercises/HollowHold.webp | Local image |
| hyperextension | photos/exercises/Hyperextension.webp | Local image |
| incline_chest_fly | photos/exercises/InclineChestFly.webp | Local image |
| incline_dumbbell_curl | photos/exercises/InclineDumbbellCurl.webp | Local image |
| inverted_row | photos/exercises/InvertedRow.webp | Local image |
| kettlebell_swing | photos/exercises/KettlebellSwing.webp | Local image |
| knee_push_up | photos/exercises/KneePushUp.webp | Local image |
| landmine_press | photos/exercises/LandminePress.webp | Local image |
| lateral_shuffle | photos/exercises/LateralShuffle.webp | Local image |
| machine_chest_press | photos/exercises/MachineChestPress.webp | Local image |
| machine_shoulder_press | photos/exercises/MachineShoulderPress.webp | Local image |
| medicine_ball_russian_twist | photos/exercises/MedicineBallRussianTwist.webp | Local image |
| nordic_curl | photos/exercises/NordicCurl.webp | Local image |
| overhead_triceps_extension | photos/exercises/OverheadTricepsExtension.webp | Local image |
| pike_push_up_close | photos/exercises/PikePushUpClose.webp | Local image |
| pike_walk | photos/exercises/PikeWalk.webp | Local image |
| pistol_squat | photos/exercises/PistolSquat.webp | Local image |
| plank_jack | photos/exercises/PlankJack.webp | Local image |
| preacher_curl | photos/exercises/PreacherCurl.webp | Local image |
| prone_t_raise | photos/exercises/ProneTRaise.webp | Local image |
| prone_y_raise | photos/exercises/ProneYRaise.webp | Local image |
| pseudo_planche_push_up | photos/exercises/PseudoPlanchePushUp.webp | Local image |
| rear_delt_fly | photos/exercises/RearDeltFly.webp | Local image |
| reverse_crunch | photos/exercises/ReverseCrunch.webp | Local image |
| rope_triceps_pushdown | photos/exercises/RopeTricepsPushdown.webp | Local image |
| scapular_pull_up | photos/exercises/ScapularPullUp.webp | Local image |
| scapular_wall_slide | photos/exercises/ScapularWallSlide.webp | Local image |
| seated_cable_row | photos/exercises/SeatedCableRow.webp | Local image |
| seated_calf_raise | photos/exercises/SeatedCalfRaise.webp | Local image |
| shadow_boxing | photos/exercises/ShadowBoxing.webp | Local image |
| side_plank | photos/exercises/SidePlank.webp | Local image |
| single_leg_calf_raise | photos/exercises/SingleLegCalfRaise.webp | Local image |
| single_leg_glute_bridge | photos/exercises/SingleLegGluteBridge.webp | Local image |
| single_leg_rdl | photos/exercises/SingleLegRdl.webp | Local image |
| squat_jump_pulse | photos/exercises/SquatJumpPulse.webp | Local image |
| squat_thrust | photos/exercises/SquatThrust.webp | Local image |
| standing_hamstring_stretch | photos/exercises/StandingHamstringStretch.webp | Local image |
| sumo_squat | photos/exercises/SumoSquat.webp | Local image |
| swimmer | photos/exercises/Swimmer.webp | Local image |
| t_bar_row | photos/exercises/TBarRow.webp | Local image |
| thruster | photos/exercises/Thruster.webp | Local image |
| toe_touch | photos/exercises/ToeTouch.webp | Local image |
| tricep_extension_floor | photos/exercises/TricepExtensionFloor.webp | Local image |
| tuck_jump | photos/exercises/TuckJump.webp | Local image |
| upright_row | photos/exercises/UprightRow.webp | Local image |
| walking_lunge_dumbbell | photos/exercises/WalkingLungeDumbbell.webp | Local image |
| wall_walk | photos/exercises/WallWalk.webp | Local image |
| weighted_leg_raise | photos/exercises/WeightedLegRaise.webp | Local image |
| weighted_sit_up | photos/exercises/WeightedSitUp.webp | Local image |
| wide_push_up | photos/exercises/WidePushUp.webp | Local image |

## Original Exercises (video preserved, untouched)

The original ~51 exercises (crunch, plank, push_up, squat, pull_up, etc.) continue
to use Supabase-hosted `.mp4` videos. No change to their `videoUrl` field.

## Mapping Convention

`slug` → `StringCase.snakeToPascal(slug)` + `.webp`

Examples:
- `t_bar_row` → `TBarRow.webp`
- `prone_t_raise` → `ProneTRaise.webp`
- `single_leg_rdl` → `SingleLegRdl.webp`
- `medicine_ball_russian_twist` → `MedicineBallRussianTwist.webp`
