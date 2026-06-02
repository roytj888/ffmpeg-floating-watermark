<#
.SYNOPSIS
  Batch-add a floating, glowing (Screen-blend) watermark to short-drama videos.

.DESCRIPTION
  - Auto-detects FFmpeg; if missing on Windows, installs it via winget (Gyan.FFmpeg).
  - Turns any logo (jpg/png) into a rounded-corner transparent PNG.
  - Probes each video and scales the watermark size & motion bounds to the
    resolution, so portrait and landscape both work.
  - Uses Screen blend for a neon-glow look, with a smooth pseudo-random drift
    that stays clear of the bottom subtitle band.
  - Batch over a folder, resumes (skips finished outputs), prints progress.

.EXAMPLE
  .\add_watermark.ps1 -InputPath "E:\drama\ep" -Logo "E:\drama\logo.jpg"

.EXAMPLE
  .\add_watermark.ps1 -InputPath "E:\drama\ep" -Logo "E:\logo.png" -Opacity 0.75 -SizePct 0.11
#>
param(
  [Parameter(Mandatory = $true)] [string]$InputPath,      # video file OR folder
  [Parameter(Mandatory = $true)] [string]$Logo,           # logo image (jpg/png)
  [string]$OutputDir = "",                                # default: <InputPath>\watermarked
  [double]$Opacity = 0.9,                                 # 0..1 watermark strength
  [double]$SizePct = 0.09,                                # watermark width / frame width
  [double]$SubtitleMargin = 0.25,                         # bottom fraction kept clear of WM
  [double]$Speed = 1.0,                                   # drift speed multiplier
  [ValidateSet('screen', 'normal')] [string]$Blend = 'screen',
  [int]$Crf = 20,
  [string]$Preset = 'veryfast'
)

$ErrorActionPreference = 'Stop'
# Make the console + native-arg encoding UTF-8 so Chinese file paths survive
# being passed to ffmpeg.exe (Windows-China locale is GBK by default).
try { chcp 65001 > $null } catch {}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ci = [System.Globalization.CultureInfo]::InvariantCulture

# Run a native exe (ffmpeg/ffprobe) discarding its stderr WITHOUT tripping
# PowerShell 5.1's "Stop" preference. In PS5.1, `nativeexe 2>$null` wraps each
# stderr line in a NativeCommandError ErrorRecord; under $ErrorActionPreference
# = 'Stop' that becomes terminating even when the exe exits 0. We lower the
# preference only around the call and return real stdout, so callers can still
# rely on $LASTEXITCODE for genuine failures.
function Invoke-Native {
  # NB: don't name the param $Args — it collides with PowerShell's automatic
  # $Args variable and the splat silently passes nothing to the exe.
  param([string]$Exe, [string[]]$ArgList)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & $Exe @ArgList 2>$null
  } finally {
    $ErrorActionPreference = $prev
  }
  return $out
}

function Find-Tool {
  param([string]$name)  # 'ffmpeg' or 'ffprobe'
  $c = Get-Command "$name.exe" -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if (Test-Path $pkgRoot) {
    $hit = Get-ChildItem -Path $pkgRoot -Recurse -Filter "$name.exe" -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  return $null
}

function Ensure-FFmpeg {
  if (Find-Tool 'ffmpeg') { return }
  Write-Host "FFmpeg not found. Installing via winget (Gyan.FFmpeg)..." -ForegroundColor Yellow
  winget install Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
  if (-not (Find-Tool 'ffmpeg')) {
    throw "FFmpeg install failed. Install FFmpeg manually (https://ffmpeg.org) and re-run."
  }
}

Ensure-FFmpeg
$FFMPEG = Find-Tool 'ffmpeg'
$FFPROBE = Find-Tool 'ffprobe'
Write-Host "ffmpeg : $FFMPEG"
Write-Host "ffprobe: $FFPROBE"

# --- Resolve inputs / outputs --------------------------------------------------
$InputPath = (Resolve-Path -LiteralPath $InputPath).Path
$Logo = (Resolve-Path -LiteralPath $Logo).Path
$isFolder = Test-Path -LiteralPath $InputPath -PathType Container
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $base = if ($isFolder) { $InputPath } else { Split-Path $InputPath -Parent }
  $OutputDir = Join-Path $base 'watermarked'
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$workDir = Join-Path $OutputDir '_wm_tmp'
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

# --- Build rounded-corner transparent logo (512x512, corner radius 80) ---------
# geq params are single-quoted so their commas aren't read as filter separators;
# commas inside the alpha expression are escaped with \, to be safe.
$roundLogo = Join-Path $workDir 'logo_round.png'
$logoFilter = "scale=512:512,format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='255*(1-(lt(X\,80)*lt(Y\,80)*gt(pow(X-80\,2)+pow(Y-80\,2)\,6400))-(gt(X\,432)*lt(Y\,80)*gt(pow(X-432\,2)+pow(Y-80\,2)\,6400))-(lt(X\,80)*gt(Y\,432)*gt(pow(X-80\,2)+pow(Y-432\,2)\,6400))-(gt(X\,432)*gt(Y\,432)*gt(pow(X-432\,2)+pow(Y-432\,2)\,6400)))'"
# -update 1 -frames:v 1: ffmpeg 8.x's image2 muxer refuses to write a single
# still to a non-pattern filename (no %d) and exits non-zero without these.
Invoke-Native $FFMPEG @('-y', '-i', $Logo, '-frames:v', '1', '-update', '1', '-vf', $logoFilter, $roundLogo) | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $roundLogo)) {
  throw "Failed to process the logo. Is '$Logo' a valid image?"
}
Write-Host "Rounded logo ready: $roundLogo"

# --- Collect videos ------------------------------------------------------------
if ($isFolder) {
  $videos = Get-ChildItem -LiteralPath $InputPath -File |
    Where-Object { $_.Extension -match '^\.(mp4|mov|mkv|avi|m4v|flv|webm)$' } |
    Sort-Object Name
} else {
  $videos = @(Get-Item -LiteralPath $InputPath)
}
$total = ($videos | Measure-Object).Count
if ($total -eq 0) { throw "No video files found at: $InputPath" }
Write-Host "Found $total video(s). Output -> $OutputDir`n"

# --- Process -------------------------------------------------------------------
$ok = 0; $skip = 0; $fail = 0; $idx = 0
foreach ($v in $videos) {
  $idx++
  $out = Join-Path $OutputDir $v.Name
  if (Test-Path -LiteralPath $out) {
    Write-Host "[$idx/$total] SKIP (exists): $($v.Name)"
    $skip++; continue
  }

  # Probe resolution + frame rate
  $info = Invoke-Native $FFPROBE @('-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,r_frame_rate', '-of', 'csv=p=0', $v.FullName)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($info)) {
    Write-Host "  FAILED to probe: $($v.Name)" -ForegroundColor Red; $fail++; continue
  }
  $p = $info.Trim() -split ','
  $W = [int]$p[0]; $H = [int]$p[1]
  $fr = $p[2] -split '/'
  $fps = if ($fr.Count -eq 2 -and [double]$fr[1] -ne 0) { [math]::Round([double]$fr[0] / [double]$fr[1]) } else { 30 }

  # Resolution-adaptive watermark size + motion bounds
  $wm = [int][math]::Round($W * $SizePct); if ($wm -lt 24) { $wm = 24 }
  $xc = ($W - $wm) / 2.0; $xa = $xc * 0.88; $xa1 = $xa * 0.7; $xa2 = $xa * 0.3
  $ytop = $H * 0.06
  $ybot = $H * (1 - $SubtitleMargin) - $wm; if ($ybot -le $ytop) { $ybot = $ytop + 1 }
  $yc = ($ytop + $ybot) / 2.0; $ya = ($ybot - $ytop) / 2.0 * 0.95; $ya1 = $ya * 0.69; $ya2 = $ya * 0.31
  $w1 = 0.21 * $Speed; $w2 = 0.13 * $Speed; $w3 = 0.17 * $Speed; $w4 = 0.11 * $Speed

  # Build drift expressions with InvariantCulture so decimals use '.', never ','
  $F = { param($n) ([double]$n).ToString($ci) }
  $xExpr = "$(&$F $xc)+$(&$F $xa1)*sin($(&$F $w1)*t)+$(&$F $xa2)*sin($(&$F $w2)*t+1.3)"
  $yExpr = "$(&$F $yc)+$(&$F $ya1)*sin($(&$F $w3)*t+0.7)+$(&$F $ya2)*sin($(&$F $w4)*t+2.1)"
  $aa = (&$F $Opacity)

  if ($Blend -eq 'screen') {
    $fc = "[1:v]scale=${wm}:${wm},colorchannelmixer=aa=${aa}[wm];[2:v][wm]overlay=x='$xExpr':y='$yExpr',format=gbrp[layer];[0:v]format=gbrp[base];[base][layer]blend=all_mode=screen,format=yuv420p[out]"
    $ffArgs = @('-y', '-i', $v.FullName, '-i', $roundLogo,
      '-f', 'lavfi', '-i', "color=black:s=${W}x${H}:r=${fps}",
      '-filter_complex', $fc, '-map', '[out]', '-map', '0:a?',
      '-c:v', 'libx264', '-crf', "$Crf", '-preset', $Preset, '-c:a', 'copy', '-shortest', $out)
  } else {
    $fc = "[1:v]scale=${wm}:${wm},format=rgba,colorchannelmixer=aa=${aa}[wm];[0:v][wm]overlay=x='$xExpr':y='$yExpr'[out]"
    $ffArgs = @('-y', '-i', $v.FullName, '-i', $roundLogo,
      '-filter_complex', $fc, '-map', '[out]', '-map', '0:a?',
      '-c:v', 'libx264', '-crf', "$Crf", '-preset', $Preset, '-c:a', 'copy', $out)
  }

  Write-Host "[$idx/$total] ${W}x${H} @${fps}fps  wm=${wm}px  -> $($v.Name)"
  Invoke-Native $FFMPEG $ffArgs | Out-Null
  if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $out)) {
    $ok++
  } else {
    Write-Host "  FAILED to render: $($v.Name)" -ForegroundColor Red; $fail++
  }
}

Write-Host "`nDONE.  ok=$ok  skip=$skip  fail=$fail"
Write-Host "Output folder: $OutputDir"
