#Requires -Version 5.1
<#
.SYNOPSIS
    MP4 dosyasındaki sese duyarlı (audio-reactive) zoom efekti uygular.
    Parçalı render + profesyonel envelope follower + yüzdelik normalizasyon.

.DESCRIPTION
    FFmpeg + FFprobe kullanarak bir videonun ses enerjisine göre kademeli
    yatay/dikey zoom efekti üretir. Bellek dostu "parçalı render" mimarisi
    kullanır; çok uzun videolarda dahi güvenle çalışır.

    Ayrıntılı bilgi için README.md dosyasına bakın.

.PARAMETER InputFile
    Girdi video dosyası (mp4, mkv, mov...). Zorunlu, konumsal 0.

.PARAMETER OutputFile
    Çıktı dosyası. Belirtilmezse <input>_zoomed.mp4 üretilir.

.PARAMETER MaxZoomPixels
    Her kenardan en fazla kaç piksel kırpılacak. 0 = piksel modu kapalı.
    Varsayılan: 50.

.PARAMETER PixelReference
    Piksel → çarpan referans kenarı: Shorter, Longer, Width, Height.

.PARAMETER MinZoom
    Zoom aralığının alt sınırı. Varsayılan: 1.00.

.PARAMETER MaxZoom
    Zoom aralığının üst sınırı (yalnız MaxZoomPixels=0 iken kullanılır).

.PARAMETER EnergyMode
    Enerji ölçüm modu: Loudness (varsayılan), RMS, Peak.

.PARAMETER AttackMs
    Zarf yükselme süresi (ms). Varsayılan: 15.

.PARAMETER ReleaseMs
    Zarf düşme süresi (ms). Varsayılan: 250.

.PARAMETER PercentileLow
    Normalizasyonda alt referans yüzdelik. Varsayılan: 5.

.PARAMETER PercentileHigh
    Normalizasyonda üst referans yüzdelik. Varsayılan: 95.

.PARAMETER Gamma
    Normalize edilmiş değere uygulanan eğri. Varsayılan: 0.8.

.PARAMETER UpdateHz
    Zoom güncelleme frekansı. Varsayılan: 15.

.PARAMETER ChunkSeconds
    Render parçası uzunluğu (saniye). Varsayılan: 30.

.PARAMETER DeltaThreshold
    Kümülatif toplamda atlanacak minimum delta. Varsayılan: 0.0005.

.PARAMETER Crf
    x264 kalite faktörü. Varsayılan: 20.

.PARAMETER KeepTemp
    Geçici dosyaları koru (hata ayıklama).

.EXAMPLE
    .\AudioZoom.ps1 "song.mp4"

.EXAMPLE
    .\AudioZoom.ps1 "song.mp4" -MaxZoomPixels 60 -UpdateHz 12 `
        -ChunkSeconds 5 -AttackMs 25 -ReleaseMs 400 -Gamma 0.7
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$InputFile,

    [Parameter(Position=1)]
    [string]$OutputFile,

    [int]   $MaxZoomPixels  = 50,
    [ValidateSet('Shorter','Longer','Width','Height')]
    [string]$PixelReference = 'Shorter',

    [double]$MinZoom        = 1.00,
    [double]$MaxZoom        = 1.12,

    [ValidateSet('Loudness','RMS','Peak')]
    [string]$EnergyMode     = 'Loudness',

    [int]   $AttackMs       = 15,
    [int]   $ReleaseMs      = 250,
    [double]$PercentileLow  = 5.0,
    [double]$PercentileHigh = 95.0,
    [double]$Gamma          = 0.8,

    [int]   $UpdateHz       = 15,
    [int]   $ChunkSeconds   = 30,
    [double]$DeltaThreshold = 0.0005,
    [int]   $Crf            = 20,
    [switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'
$Inv = [System.Globalization.CultureInfo]::InvariantCulture

# ==================================================================
# 0. Ön kontroller
# ==================================================================
if (-not (Test-Path -LiteralPath $InputFile)) { throw "Girdi bulunamadı: $InputFile" }
foreach ($tool in 'ffmpeg','ffprobe') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool PATH üzerinde yok. FFmpeg kurulu ve PATH'e ekli olmalı."
    }
}
if ($MaxZoomPixels -lt 0)                  { throw "MaxZoomPixels negatif olamaz." }
if ($UpdateHz -lt 1)                       { throw "UpdateHz >= 1 olmalı." }
if ($ChunkSeconds -lt 2)                   { throw "ChunkSeconds en az 2 olmalı." }
if ($AttackMs -lt 1)                       { throw "AttackMs >= 1 olmalı." }
if ($ReleaseMs -lt 1)                      { throw "ReleaseMs >= 1 olmalı." }
if ($PercentileLow -lt 0 -or $PercentileLow -ge 50) {
    throw "PercentileLow 0-50 arasında olmalı."
}
if ($PercentileHigh -le 50 -or $PercentileHigh -gt 100) {
    throw "PercentileHigh 50-100 arasında olmalı."
}
if ($PercentileHigh -le $PercentileLow)    { throw "PercentileHigh > PercentileLow olmalı." }
if ($Gamma -le 0)                          { throw "Gamma > 0 olmalı." }

# ==================================================================
# FFmpeg sürüm tespiti
# ==================================================================
$ffVerLine = (& ffmpeg -version 2>&1 | Select-Object -First 1) -join ''
$ffMajor   = 6
if ($ffVerLine -match 'ffmpeg version (\d+)\.') { $ffMajor = [int]$matches[1] }
$filterOpt = if ($ffMajor -ge 9) { '-/filter_complex' } else { '-filter_complex_script' }
Write-Host ("▶ FFmpeg major sürüm: {0} → filtre seçeneği: {1}" -f $ffMajor, $filterOpt) -ForegroundColor DarkGray

$InputFile = (Resolve-Path -LiteralPath $InputFile).Path
if (-not $OutputFile) {
    $dir  = Split-Path -Parent $InputFile
    $base = [IO.Path]::GetFileNameWithoutExtension($InputFile)
    $OutputFile = Join-Path $dir ("{0}_zoomed.mp4" -f $base)
}
$OutputFile = [IO.Path]::GetFullPath($OutputFile)

Write-Host "▶ Girdi  : $InputFile"  -ForegroundColor Cyan
Write-Host "▶ Çıktı  : $OutputFile" -ForegroundColor Cyan

# ==================================================================
# 1. Metadata
# ==================================================================
$probe = (& ffprobe -v quiet -print_format json -show_streams -show_format -- $InputFile) | ConvertFrom-Json
$v = $probe.streams | Where-Object codec_type -eq 'video' | Select-Object -First 1
$a = $probe.streams | Where-Object codec_type -eq 'audio' | Select-Object -First 1
if (-not $v) { throw "Video akışı yok." }
if (-not $a) { throw "Ses akışı yok (bu efekt ses olmadan çalışmaz)." }

function ConvertTo-Fps([string]$r) {
    if ($r -match '^(\d+)/(\d+)$') {
        $d = [double]$matches[2]
        if ($d -eq 0) { return 30.0 }
        return [double]$matches[1] / $d
    }
    return 30.0
}

$fps      = ConvertTo-Fps $v.r_frame_rate
$width    = [int]$v.width
$height   = [int]$v.height
$duration = [double]$probe.format.duration
if ($duration -le 0) { throw "Süre okunamadı." }

$fpsStr = [string]::Format($Inv, '{0:0.######}', $fps)
Write-Host ("   {0}x{1} @ {2} fps, {3} sn" -f `
    $width, $height, $fpsStr, `
    [string]::Format($Inv, '{0:F2}', $duration)) -ForegroundColor DarkGray

# ==================================================================
# 1b. Piksel → çarpan
# ==================================================================
if ($MaxZoomPixels -gt 0) {
    $refDim = switch ($PixelReference) {
        'Width'   { $width }
        'Height'  { $height }
        'Shorter' { [Math]::Min($width, $height) }
        'Longer'  { [Math]::Max($width, $height) }
    }
    $half = 2.0 * $MaxZoomPixels
    if ($half -ge $refDim) {
        throw "MaxZoomPixels ($MaxZoomPixels) referans boyutun ($refDim) yarısından küçük olmalı."
    }
    $MaxZoom = $refDim / ($refDim - $half)
    Write-Host ("   Piksel modu: her kenardan max {0} px ({1}) → MaxZoom = {2}" `
        -f $MaxZoomPixels, $PixelReference, `
           [string]::Format($Inv, '{0:F4}', $MaxZoom)) -ForegroundColor DarkGray
} else {
    Write-Host ("   Çarpan modu: MinZoom={0}, MaxZoom={1}" `
        -f [string]::Format($Inv, '{0:F3}', $MinZoom), `
           [string]::Format($Inv, '{0:F3}', $MaxZoom)) -ForegroundColor DarkGray
}
if ($MaxZoom -lt $MinZoom) { throw "Hesaplanan MaxZoom ($MaxZoom) < MinZoom ($MinZoom)." }

# ==================================================================
# 2. PCM çıkar
# ==================================================================
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("az_" + [IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$pcmFile     = Join-Path $tmpRoot "audio.raw"
$filterFile  = Join-Path $tmpRoot "filter.txt"
$concatList  = Join-Path $tmpRoot "concat.txt"
$mergedVideo = Join-Path $tmpRoot "merged_video.mp4"
$chunkFiles  = @()

try {
    $sampleRate = 8000
    & ffmpeg -y -v error -i $InputFile -vn -ac 1 -ar $sampleRate `
        -f s16le -acodec pcm_s16le -- $pcmFile
    if ($LASTEXITCODE -ne 0) { throw "Ses çıkarma başarısız." }

    $bytes = [IO.File]::ReadAllBytes($pcmFile)
    if ($bytes.Length -lt 2) { throw "Ses verisi boş." }
    $sampleCount = [int]($bytes.Length / 2)
    $samples     = [int16[]]::new($sampleCount)
    [Buffer]::BlockCopy($bytes, 0, $samples, 0, $bytes.Length)

    Write-Host ("   {0} örnek okundu ({1} sn)." -f `
        [string]::Format($Inv, '{0:N0}', $sampleCount), `
        [string]::Format($Inv, '{0:F1}', ($sampleCount / $sampleRate))) -ForegroundColor DarkGray

    # ==============================================================
    # 3. Kare başına ham enerji
    # ==============================================================
    $samplesPerFrame = $sampleRate / $fps
    $totalFrames     = [int][Math]::Floor($duration * $fps)
    $rawEnergy       = [double[]]::new($totalFrames)

    for ($f = 0; $f -lt $totalFrames; $f++) {
        $start = [int][Math]::Floor($f * $samplesPerFrame)
        $end   = [int][Math]::Min($sampleCount, [Math]::Floor(($f + 1) * $samplesPerFrame))
        $sumSq = 0.0
        $peak  = 0.0
        for ($i = $start; $i -lt $end; $i++) {
            $s = $samples[$i] / 32768.0
            $sumSq += $s * $s
            $a = [Math]::Abs($s)
            if ($a -gt $peak) { $peak = $a }
        }
        $n = [Math]::Max(1, $end - $start)
        $rms = [Math]::Sqrt($sumSq / $n)

        $rawEnergy[$f] = switch ($EnergyMode) {
            'RMS'      { $rms }
            'Peak'     { $peak }
            'Loudness' {
                if ($rms -lt 1e-6) { -120.0 }
                else { 20.0 * [Math]::Log10($rms) }
            }
        }
    }

    # ==============================================================
    # 4. Asimetrik envelope follower
    # ==============================================================
    $attackCoef  = [Math]::Exp(-1.0 / ($AttackMs  / 1000.0 * $fps))
    $releaseCoef = [Math]::Exp(-1.0 / ($ReleaseMs / 1000.0 * $fps))

    $envelope = [double[]]::new($totalFrames)
    $prev     = $rawEnergy[0]
    for ($i = 0; $i -lt $totalFrames; $i++) {
        $x    = $rawEnergy[$i]
        $coef = if ($x -gt $prev) { $attackCoef } else { $releaseCoef }
        $prev = $coef * $prev + (1.0 - $coef) * $x
        $envelope[$i] = $prev
    }

    # ==============================================================
    # 5. Yüzdelik normalizasyon + gamma
    # ==============================================================
    $sortedEnv = [double[]]$envelope.Clone()
    [Array]::Sort($sortedEnv)

    $iLow  = [int][Math]::Floor($totalFrames * $PercentileLow  / 100.0)
    $iHigh = [int][Math]::Min($totalFrames - 1,
              [int][Math]::Floor($totalFrames * $PercentileHigh / 100.0))
    $pLow  = $sortedEnv[$iLow]
    $pHigh = $sortedEnv[$iHigh]
    $pRange = [Math]::Max(1e-9, $pHigh - $pLow)

    Write-Host ("   Envelope: %{0} = {1}, %{2} = {3}, aralık = {4}" `
        -f $PercentileLow, `
           [string]::Format($Inv, '{0:F4}', $pLow), `
           $PercentileHigh, `
           [string]::Format($Inv, '{0:F4}', $pHigh), `
           [string]::Format($Inv, '{0:F4}', $pRange)) -ForegroundColor DarkGray

    $norm = [double[]]::new($totalFrames)
    for ($i = 0; $i -lt $totalFrames; $i++) {
        $n = ($envelope[$i] - $pLow) / $pRange
        if ($n -lt 0) { $n = 0 } elseif ($n -gt 1) { $n = 1 }
        $norm[$i] = [Math]::Pow($n, $Gamma)
    }

    # ==============================================================
    # 6. Segmentasyon + peak-hold
    # ==============================================================
    $frameStep = [Math]::Max(1, [int][Math]::Floor($fps / $UpdateHz))
    $numSeg    = [int][Math]::Ceiling($totalFrames / $frameStep)
    $segDur    = $frameStep / $fps
    $effHz     = $fps / $frameStep

    Write-Host ("   Global segment: {0} adet (~{1} Hz, seg süresi {2} sn)." `
        -f $numSeg, `
           [string]::Format($Inv, '{0:F2}', $effHz), `
           [string]::Format($Inv, '{0:F4}', $segDur)) -ForegroundColor DarkGray

    $zoomValues = [double[]]::new($numSeg)
    $span       = $MaxZoom - $MinZoom
    for ($s = 0; $s -lt $numSeg; $s++) {
        $sf = $s * $frameStep
        $ef = [Math]::Min($totalFrames, $sf + $frameStep)
        $mx = 0.0
        for ($i = $sf; $i -lt $ef; $i++) {
            if ($norm[$i] -gt $mx) { $mx = $norm[$i] }
        }
        $zoomValues[$s] = $MinZoom + $span * $mx
    }

    # ==============================================================
    # 7. Parçalara böl + güvenlik denetimi
    # ==============================================================
    # FFmpeg zoompan expression parser'ı ~400 terim sonrası -12 veriyor.
    # Güvenli sınır: parça başına <= 200 segment.
    $MaxSegPerChunk = 200
    $maxChunkDur    = $MaxSegPerChunk / $UpdateHz
    $effectiveChunkSeconds = [Math]::Min($ChunkSeconds, $maxChunkDur)

    if ($effectiveChunkSeconds -lt $ChunkSeconds) {
        Write-Host ("   ⚠ ChunkSeconds {0} sn → {1} sn'ye düşürüldü " `
            -f $ChunkSeconds, `
               [string]::Format($Inv, '{0:F1}', $effectiveChunkSeconds)) -ForegroundColor Yellow
        Write-Host ("     (UpdateHz={0} için parça başına segment ≤ {1})." `
            -f $UpdateHz, $MaxSegPerChunk) -ForegroundColor Yellow
    }

    $chunkFrames   = [int][Math]::Max(1, [Math]::Round($effectiveChunkSeconds * $fps))
    $chunkDuration = $chunkFrames / $fps
    $totalChunks   = [int][Math]::Ceiling($duration / $chunkDuration)

    Write-Host ("   {0} sn'lik {1} parçaya bölünecek ({2} kare/parça)." `
        -f [string]::Format($Inv, '{0:F1}', $chunkDuration), `
           $totalChunks, $chunkFrames) -ForegroundColor DarkGray

    $termsWarned = $false
    for ($c = 0; $c -lt $totalChunks; $c++) {
        $chunkStartTime = $c * $chunkDuration
        $chunkEndTime   = [Math]::Min($duration, ($c + 1) * $chunkDuration)
        $thisChunkDur   = $chunkEndTime - $chunkStartTime
        if ($thisChunkDur -le 0.001) { continue }

        $chunkFile = Join-Path $tmpRoot ("chunk_{0:D4}.mp4" -f $c)

        $firstSeg = [int][Math]::Floor($chunkStartTime / $segDur)
        $lastSeg  = [int][Math]::Min(
            $numSeg - 1,
            [int][Math]::Ceiling($chunkEndTime / $segDur) - 1
        )
        if ($firstSeg -gt $lastSeg) { continue }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendFormat($Inv, '{0:F5}', $zoomValues[$firstSeg])

        $localTerms = 0
        for ($s = $firstSeg; $s -lt $lastSeg; $s++) {
            $delta = $zoomValues[$s + 1] - $zoomValues[$s]
            if ([Math]::Abs($delta) -lt $DeltaThreshold) { continue }
            $tGlobal = ($s + 1) * $segDur
            $tLocal  = $tGlobal - $chunkStartTime
            if ($tLocal -le 0.0001) { continue }
            if ($delta -gt 0) {
                [void]$sb.AppendFormat($Inv, '+{0:F5}*gte(in_time,{1:F4})', $delta, $tLocal)
            } else {
                [void]$sb.AppendFormat($Inv, '-{0:F5}*gte(in_time,{1:F4})', -$delta, $tLocal)
            }
            $localTerms++
        }
        $localExpr = $sb.ToString()

        if ($localExpr.Length -gt 20000 -and -not $termsWarned) {
            Write-Host ("   ⚠ Bir parçanın ifadesi {0} karakter. UpdateHz veya " `
                -f $localExpr.Length) -ForegroundColor Yellow
            Write-Host ("     ChunkSeconds değerini düşürmeyi düşünün." `
                ) -ForegroundColor Yellow
            $termsWarned = $true
        }

        $filter = "[0:v]setpts=PTS-STARTPTS,zoompan=z='$localExpr':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${width}x${height}:fps=$fpsStr[v]"
        [IO.File]::WriteAllText($filterFile, $filter, [Text.Encoding]::ASCII)

        Write-Host ("   [{0}/{1}] {2} - {3} sn | {4} segment, {5} terim, {6} karakter" `
            -f ($c + 1), $totalChunks, `
               [string]::Format($Inv, '{0:F2}', $chunkStartTime), `
               [string]::Format($Inv, '{0:F2}', $chunkEndTime), `
               ($lastSeg - $firstSeg + 1), $localTerms, $localExpr.Length) `
            -ForegroundColor DarkGray

        $chunkArgs = @(
            '-y', '-hide_banner', '-loglevel', 'error',
            '-ss', ([string]::Format($Inv, '{0:F6}', $chunkStartTime)),
            '-t',  ([string]::Format($Inv, '{0:F6}', $thisChunkDur)),
            '-i', $InputFile,
            $filterOpt, $filterFile,
            '-map', '[v]',
            '-an',
            '-c:v', 'libx264', '-preset', 'medium', '-crf', "$Crf",
            '-pix_fmt', 'yuv420p',
            '-video_track_timescale', '90000',
            '-avoid_negative_ts', 'make_zero',
            $chunkFile
        )
        & ffmpeg @chunkArgs
        if ($LASTEXITCODE -ne 0) { throw "Parça $c render başarısız (kod $LASTEXITCODE)." }

        $chunkFiles += $chunkFile
    }

    # ==============================================================
    # 8. Parçaları birleştir
    # ==============================================================
    Write-Host "⏳ Parçalar birleştiriliyor..." -ForegroundColor Cyan

    $concatContent = ($chunkFiles | ForEach-Object {
        $p = $_ -replace '\\', '/'
        "file '$p'"
    }) -join "`n"
    # BOM'suz ASCII: FFmpeg concat demuxer BOM kabul etmez.
    [IO.File]::WriteAllText($concatList, $concatContent, [Text.Encoding]::ASCII)

    & ffmpeg -y -hide_banner -loglevel error `
        -f concat -safe 0 -i $concatList `
        -c copy -- $mergedVideo
    if ($LASTEXITCODE -ne 0) { throw "Concat başarısız (kod $LASTEXITCODE)." }

    # ==============================================================
    # 9. Orijinal sesi mux et
    # ==============================================================
    Write-Host "⏳ Ses mux ediliyor..." -ForegroundColor Cyan

    & ffmpeg -y -hide_banner -loglevel error `
        -i $mergedVideo -i $InputFile `
        -map 0:v:0 -map 1:a:0? `
        -c:v copy -c:a copy `
        -movflags +faststart -shortest `
        -- $OutputFile
    if ($LASTEXITCODE -ne 0) { throw "Ses mux başarısız (kod $LASTEXITCODE)." }

    $outSize = (Get-Item -LiteralPath $OutputFile).Length
    Write-Host ("✔ Tamamlandı: {0} ({1} MB)" -f $OutputFile, `
        [string]::Format($Inv, '{0:F1}', ($outSize / 1MB))) -ForegroundColor Green
}
finally {
    if ($KeepTemp) {
        Write-Host "ℹ Geçici dosyalar korundu: $tmpRoot" -ForegroundColor Yellow
    } else {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
