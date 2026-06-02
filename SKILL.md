---
name: drama-watermark
description: 给短剧视频批量加"飘动发光水印"（logo 浮动 + Screen 荧光叠加）。当用户提到给短剧/视频加水印、批量加 logo、防搬运水印、浮动水印、发光水印、watermark，或想把某个 logo 图片叠加到一批视频上时，务必使用本技能。支持竖屏/横屏自动适配、整文件夹批量、断点续传，Windows 上自动安装 FFmpeg，开箱即用。
---

# 短剧飘动发光水印（drama-watermark）

给短剧视频批量叠加一个**缓慢飘动、带荧光发光感**的 logo 水印。专为社媒短剧运营场景设计：一个文件夹几十集，一条命令全部处理完，竖屏横屏都能自动适配。

核心是 `scripts/add_watermark.ps1`（Windows PowerShell）。它做这几件事：
- 自动找 FFmpeg，找不到就用 winget 装（`Gyan.FFmpeg`）。
- 把任意 logo（jpg/png）转成 512×512 圆角透明 PNG。
- 用 ffprobe 探测每个视频的分辨率/帧率，按比例缩放水印大小和飘动范围。
- 用 **Screen 叠加**做出微微发光的霓虹质感，水印沿伪随机轨迹缓慢飘动，并自动避开底部字幕区。
- 整文件夹批量处理，已生成的输出会跳过（断点续传）。

## 什么时候用

只要用户想把一个 logo 盖到短剧/视频上——尤其是要"飘来飘去、有点发光、防止别人搬运"的效果——就用这个技能。常见说法："加水印""批量加 logo""防搬运""浮动水印""发光水印"。

## 怎么运行

最简单的两参数用法（输入可以是单个视频，也可以是整个文件夹）：

```powershell
& "$HOME\.claude\skills\drama-watermark\scripts\add_watermark.ps1" `
  -InputPath "E:\某短剧\压制视频" `
  -Logo "E:\某短剧\水印logo.jpg"
```

输出默认写到 `<InputPath>\watermarked\`（输入是文件时写到该文件所在目录的 `watermarked\`）。

### 参数

| 参数 | 默认 | 说明 |
|------|------|------|
| `-InputPath` | 必填 | 单个视频文件，或装着一批视频的文件夹 |
| `-Logo` | 必填 | logo 图片（jpg/png 都行；红底图标也 OK，会自动加圆角） |
| `-OutputDir` | `<InputPath>\watermarked` | 输出目录 |
| `-Opacity` | `0.9` | 水印强度 0–1，嫌太亮就调到 0.7 左右 |
| `-SizePct` | `0.09` | 水印宽度占画面宽度的比例（0.09 = 9%） |
| `-SubtitleMargin` | `0.25` | 底部留给字幕、不让水印进入的高度比例 |
| `-Speed` | `1.0` | 飘动速度倍率，想更慢就 0.6，更活泼就 1.5 |
| `-Blend` | `screen` | `screen`=发光感（默认推荐）；`normal`=普通半透明 |
| `-Crf` | `20` | 画质，数字越小越清晰、文件越大（18–23 合理） |
| `-Preset` | `veryfast` | 编码速度/体积权衡 |

调参示例：

```powershell
& "$HOME\.claude\skills\drama-watermark\scripts\add_watermark.ps1" `
  -InputPath "E:\drama\ep" -Logo "E:\drama\logo.png" `
  -Opacity 0.75 -SizePct 0.11 -Speed 0.7
```

## 给用户的话术（非技术用户）

- 默认就是"飘动 + 发光"的效果，一般不用改参数，直接给输入文件夹和 logo 就行。
- 第一次在新电脑上跑，如果没装 FFmpeg，脚本会自动装，会多花一两分钟，属正常。
- 处理是有损重新编码，原视频不会被改动，成品在 `watermarked` 文件夹里。
- 中途断了重跑没关系，已经做好的那几集会自动跳过。

## 技术要点（维护时看）

这些是踩过坑后固化下来的，改脚本时注意别破坏：

1. **Screen 叠加必须在 RGB 空间做。** 直接在 YUV 里 `blend=all_mode=screen` 会让黑色底（U/V=128 而非 0）把整画面染成紫色。脚本里先 `format=gbrp` 再 blend，最后 `format=yuv420p`。
2. **中文路径编码。** PowerShell 5.1 在中国区默认 GBK，传中文路径给 ffmpeg.exe 会乱码。脚本开头 `chcp 65001` + UTF-8 控制台编码解决；已用葡语短剧（路径含中文括号）实测通过。
3. **PS5.1 把原生 stderr 当错误。** `$ErrorActionPreference='Stop'` 下，`ffmpeg.exe 2>$null` 会把 ffmpeg 正常的 stderr 横幅包成 NativeCommandError 终止脚本。脚本用 `Invoke-Native` 辅助函数在调用期间临时降为 `Continue`，靠 `$LASTEXITCODE` 判断真失败。
4. **ffmpeg 8.x 写单张图要 `-update 1 -frames:v 1`。** 否则 image2 muxer 认为文件名缺少 `%d` 序列模式而非零退出。
5. **不要把辅助函数参数命名为 `$Args`。** 那是 PowerShell 自动变量，splat `@Args` 会静默传空。脚本里用的是 `$ArgList`。
6. **小数分隔符用 InvariantCulture。** 飘动表达式里的小数必须是 `.`，中国区 locale 默认会输出 `,`，会被 ffmpeg 当成滤镜参数分隔符。
