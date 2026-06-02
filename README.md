# ffmpeg-floating-watermark

**English** | [简体中文](README.zh-CN.md)

**Stamp your logo onto a whole folder of videos so nobody can steal them — with one command.**

You give it two things: a folder of videos and your logo image. It puts your logo on every video as a softly **glowing badge that drifts slowly around the screen** — not a dead corner stamp, but a moving, glowing mark that's much harder for re-uploaders to crop off. Then it hands you a `watermarked/` folder with all the finished videos. That's it.

Made for people posting lots of short videos (短剧 / Shorts / Reels / TikTok) who are tired of doing it one clip at a time:

- **Dead simple** — two arguments, one command. No video-editing app, no timeline, no per-clip fiddling.
- **Does the whole batch** — drop 50 episodes in a folder, run it once, walk away. Stops halfway? Just run it again, it picks up where it left off.
- **Just works** — figures out each video's size on its own (vertical or horizontal), keeps the watermark out of the subtitle area, and even installs FFmpeg for you on first run if you don't have it.
- **Your originals stay untouched** — results go into a separate folder.

## Features

- **One command, whole folder** — batch every video in a directory; already-finished outputs are skipped (resume after interruption).
- **Floating + glowing** — smooth drifting motion + Screen-blend glow for a neon feel (`-Blend normal` for plain semi-transparent instead).
- **Resolution-adaptive** — probes each video and scales watermark size & motion bounds to the frame; portrait and landscape both work.
- **Subtitle-safe** — keeps the watermark out of the bottom band where subtitles live (`-SubtitleMargin`).
- **Any logo** — JPG or PNG; even a solid-background icon works (auto rounded-corner transparency).
- **Self-bootstrapping on Windows** — if FFmpeg is missing, installs it via winget (`Gyan.FFmpeg`).

## Requirements

- Windows with PowerShell 5.1+ (the script handles UTF-8 / Chinese paths).
- [FFmpeg](https://ffmpeg.org) on `PATH` — or let the script install it via winget on first run.

## Usage

Simplest two-argument form (input can be a single video **or** a whole folder):

```powershell
.\scripts\add_watermark.ps1 `
  -InputPath "E:\drama\episodes" `
  -Logo "E:\drama\logo.png"
```

Output is written to `<InputPath>\watermarked\` by default. The originals are never modified.

Tuning example (softer, larger, slower drift):

```powershell
.\scripts\add_watermark.ps1 `
  -InputPath "E:\drama\episodes" -Logo "E:\drama\logo.png" `
  -Opacity 0.75 -SizePct 0.11 -Speed 0.7
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-InputPath` | *(required)* | A single video file, or a folder of videos |
| `-Logo` | *(required)* | Logo image (JPG/PNG; gets auto rounded-corner transparency) |
| `-OutputDir` | `<InputPath>\watermarked` | Output directory |
| `-Opacity` | `0.9` | Watermark strength, 0–1 (try ~0.7 if too bright) |
| `-SizePct` | `0.09` | Watermark width as a fraction of frame width (0.09 = 9%) |
| `-SubtitleMargin` | `0.25` | Bottom fraction kept clear of the watermark (subtitle zone) |
| `-Speed` | `1.0` | Drift-speed multiplier (0.6 = calmer, 1.5 = livelier) |
| `-Blend` | `screen` | `screen` = glow (default); `normal` = plain semi-transparent |
| `-Crf` | `20` | Quality; lower = sharper/larger (18–23 is reasonable) |
| `-Preset` | `veryfast` | libx264 speed/size trade-off |

## How it works

For each video the script:

1. Converts the logo into a 512×512 rounded-corner transparent PNG.
2. Probes resolution + frame rate, then scales the watermark and its motion bounds.
3. Drives the position with summed sine waves (`x`, `y`) for a smooth wandering path.
4. Composites with a **Screen blend** in RGB space for the glow, then re-encodes with libx264.

## Use as a Claude Code skill

This repo is also a [Claude Code](https://claude.com/claude-code) skill. Drop the folder into `~/.claude/skills/` (so you have `~/.claude/skills/ffmpeg-floating-watermark/SKILL.md`) and Claude will invoke it automatically when you ask to "add a floating watermark to these videos." See [`SKILL.md`](SKILL.md).

## Notes / gotchas

These are hard-won and baked into the script — don't undo them when editing:

- **Screen blend must run in RGB**, not YUV — otherwise the black canvas (U/V=128) tints the whole frame purple. The script does `format=gbrp` → blend → `format=yuv420p`.
- **Chinese paths**: PowerShell 5.1 defaults to GBK in the China region; the script forces UTF-8 (`chcp 65001`) so paths survive being passed to `ffmpeg.exe`.
- **Decimal separators** in motion expressions are forced to `.` via InvariantCulture (a `,` locale would break the filter parsing).

## License

[MIT](LICENSE)

---

中文使用说明见 **[README.zh-CN.md](README.zh-CN.md)**。
