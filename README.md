# ffmpeg-floating-watermark

Batch-add a **floating, glowing watermark** to short-form / vertical videos with a single command. Built on FFmpeg. Designed for short-drama (短剧) social-media operations: point it at a folder of dozens of episodes and one logo, and it processes them all — portrait or landscape, auto-scaled, resumable.

> The logo drifts slowly along a smooth pseudo-random path with a soft neon **Screen-blend** glow, and automatically stays clear of the bottom subtitle band — so it looks intentional, not like a static stamp, and is harder to crop out.

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

## 中文说明

一条命令给一整个文件夹的竖屏/短剧视频批量加 **飘动发光水印**。基于 FFmpeg,专为短剧社媒运营设计:给一个文件夹(几十集)和一张 logo,全部自动处理,竖屏横屏都行,支持断点续传。

水印会沿平滑的伪随机轨迹缓慢飘动,带 **Screen 叠加** 的霓虹发光质感,并自动避开底部字幕区——看起来是设计过的,而不是死贴一个角标,也更难被裁掉。

### 快速开始

```powershell
.\scripts\add_watermark.ps1 -InputPath "E:\某短剧\压制视频" -Logo "E:\某短剧\logo.png"
```

成品默认输出到 `<InputPath>\watermarked\`,原视频不动。参数说明见上方英文表格。第一次在没装 FFmpeg 的电脑上跑,脚本会用 winget 自动安装(`Gyan.FFmpeg`),多花一两分钟正常。
