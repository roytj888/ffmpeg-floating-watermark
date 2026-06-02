# ffmpeg-floating-watermark

[English](README.md) | **简体中文**

**一条命令,把你的 logo 盖到一整个文件夹的视频上,别人偷不走。**

你只给它两样东西:一个视频文件夹 + 你的 logo 图片。它会给每个视频盖上一个**缓慢飘动、微微发光的徽标**——不是死贴在角落的角标,而是会动会发光的标记,搬运的人很难裁掉。处理完丢给你一个装满成品的 `watermarked/` 文件夹。就这么简单。

专为要发大量短视频(短剧 / Shorts / Reels / TikTok)、又不想一条一条手动加水印的人做的:

- **极其简单**——两个参数,一条命令。不用打开剪辑软件,不用拉时间线,不用一条条调。
- **整批一次搞定**——把 50 集丢进一个文件夹,跑一次,走开就行。中途断了?再跑一次,自动从没做完的地方接着来。
- **开箱即用**——自动识别每个视频的尺寸(竖屏横屏都行),自动避开字幕区;第一次用如果没装 FFmpeg,还会帮你自动装好。
- **不动原片**——成品输出到单独的文件夹,原视频原封不动。

## 功能特点

- **一条命令,整个文件夹**——批量处理目录里所有视频;已经做好的会自动跳过(支持断点续传)。
- **飘动 + 发光**——平滑飘动轨迹 + Screen 叠加的霓虹发光质感(想要普通半透明就用 `-Blend normal`)。
- **自动适配分辨率**——探测每个视频,按画面比例缩放水印大小和飘动范围;竖屏横屏都支持。
- **避开字幕**——自动让水印躲开底部字幕区域(`-SubtitleMargin` 可调)。
- **任意 logo**——JPG 或 PNG 都行;就算是纯底色图标也 OK(自动加圆角透明)。
- **Windows 自动装 FFmpeg**——没装的话用 winget 自动安装(`Gyan.FFmpeg`)。

## 环境要求

- Windows + PowerShell 5.1 及以上(脚本已处理 UTF-8 / 中文路径)。
- `PATH` 里有 [FFmpeg](https://ffmpeg.org)——或者首次运行时让脚本用 winget 自动装。

## 使用方法

最简单的两参数用法(输入可以是单个视频文件,也可以是整个文件夹):

```powershell
.\scripts\add_watermark.ps1 `
  -InputPath "E:\某短剧\压制视频" `
  -Logo "E:\某短剧\logo.png"
```

成品默认输出到 `<InputPath>\watermarked\`,原视频绝不改动。

调参示例(更淡、更大、飘得更慢):

```powershell
.\scripts\add_watermark.ps1 `
  -InputPath "E:\某短剧\压制视频" -Logo "E:\某短剧\logo.png" `
  -Opacity 0.75 -SizePct 0.11 -Speed 0.7
```

### 参数说明

| 参数 | 默认值 | 说明 |
|---|---|---|
| `-InputPath` | *(必填)* | 单个视频文件,或装着一批视频的文件夹 |
| `-Logo` | *(必填)* | logo 图片(JPG/PNG;会自动加圆角透明) |
| `-OutputDir` | `<InputPath>\watermarked` | 输出目录 |
| `-Opacity` | `0.9` | 水印强度,0–1(太亮就调到 0.7 左右) |
| `-SizePct` | `0.09` | 水印宽度占画面宽度的比例(0.09 = 9%) |
| `-SubtitleMargin` | `0.25` | 底部留给字幕、不让水印进入的高度比例 |
| `-Speed` | `1.0` | 飘动速度倍率(0.6 更慢更稳,1.5 更活泼) |
| `-Blend` | `screen` | `screen` = 发光感(默认推荐);`normal` = 普通半透明 |
| `-Crf` | `20` | 画质,越小越清晰、文件越大(18–23 合理) |
| `-Preset` | `veryfast` | libx264 编码速度/体积权衡 |

## 工作原理

对每个视频,脚本会:

1. 把 logo 转成 512×512 的圆角透明 PNG。
2. 探测分辨率和帧率,按比例缩放水印大小和飘动范围。
3. 用多个正弦波叠加驱动 `x`、`y` 坐标,做出平滑的游走轨迹。
4. 在 RGB 空间用 **Screen 叠加** 做出发光感,再用 libx264 重新编码。

## 作为 Claude Code 技能使用

这个仓库同时也是一个 [Claude Code](https://claude.com/claude-code) 技能。把整个文件夹放进 `~/.claude/skills/`(即 `~/.claude/skills/ffmpeg-floating-watermark/SKILL.md`),之后你只要让 Claude "给这些视频加飘动水印",它就会自动调用。详见 [`SKILL.md`](SKILL.md)。

## 注意事项 / 踩过的坑

这些是踩坑后固化下来的,改脚本时别破坏:

- **Screen 叠加必须在 RGB 空间做**,不能在 YUV 里做——否则黑色底(U/V=128)会把整个画面染成紫色。脚本里先 `format=gbrp` 再 blend,最后 `format=yuv420p`。
- **中文路径**:PowerShell 5.1 在中国区默认 GBK,脚本开头强制切到 UTF-8(`chcp 65001`),保证中文路径传给 `ffmpeg.exe` 不乱码。
- **小数分隔符**:飘动表达式里的小数用 InvariantCulture 强制为 `.`(中国区 locale 默认会输出 `,`,会破坏滤镜解析)。

## 许可证

[MIT](LICENSE)
