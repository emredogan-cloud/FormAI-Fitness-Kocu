# Exercise guide videos

Drop short looping demo clips here named by exercise id:

- `crunch_demo.mp4`
- `plank_demo.mp4`
- `leg_raise_demo.mp4`

`ExerciseGuidePlayer` loads these via `VideoPlayerController.asset(path)`
and shows a neon fallback tile when a file is missing, so checking in a
path before the asset exists is safe.

Keep clips short (2–4 s), muted-friendly, and ≤1 MB where possible since
they ship inside the APK / IPA bundle.
