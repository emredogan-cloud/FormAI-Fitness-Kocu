Per-exercise workout backgrounds.

Drop `<PascalCase>.webp` here — `weighted_sit_up` → `WeightedSitUp.webp` —
and the camera-free workout screen uses it on the next build. There is no
list to update: `WorkoutBackgroundRegistry` reads the asset manifest.

An exercise with no file here falls back to its category's photograph from
`photos/workouts/`, so nothing looks unfinished while this fills up.

The 51 exercises still on the fallback, with a prompt for each, are in
`WORKOUT_BACKGROUND_IMAGE_REQUESTS.md` at the repository root.

This file exists so the directory is never empty — Flutter fails the build
on an asset directory that does not exist.
