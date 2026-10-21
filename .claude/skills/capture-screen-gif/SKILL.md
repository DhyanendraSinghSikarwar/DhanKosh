---
name: capture-screen-gif
description: Use when a screen needs a reference GIF (Pending in assets_reference/_screens_index.md), or a screen's UI changed. Records with adb screenrecord and converts with ffmpeg, using dummy data only.
---

# Capture a screen GIF

Settings: width 480px, 12 fps, at most 5 MB, dummy data only.

1. Pick the screen row in `assets_reference/_screens_index.md` and note its GIF path (`assets_reference/<NN_feature>/<screen>.gif`) and feature file.
2. Preconditions: `adb devices` shows one device/emulator; the app is loaded with DUMMY data only (fake names, accounts, amounts, SMS). Never record real financial data; if any real data is visible, discard the recording.
3. Navigate to the screen, then record (max 180 s; keep it 5-15 s):
   `adb shell screenrecord --time-limit 12 /sdcard/cap.mp4`
4. Pull and clean up: `adb pull /sdcard/cap.mp4 cap.mp4` then `adb shell rm /sdcard/cap.mp4`.
5. Convert with a palette for quality:
   `ffmpeg -i cap.mp4 -vf "fps=12,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" -loop 0 <gif path>`
6. Check size <= 5 MB. If larger, shorten the clip, lower fps to 10, or reduce palette (`palettegen=max_colors=96`). Delete `cap.mp4`.
7. Update `assets_reference/_screens_index.md`: set that row's Status from `Pending` to `Captured` (add a note if needed).
8. Update section 7 of the feature memory file: embed `![screen](../assets_reference/<NN_feature>/<screen>.gif)` and add a Change Log row.
9. Do not commit raw mp4 files.
