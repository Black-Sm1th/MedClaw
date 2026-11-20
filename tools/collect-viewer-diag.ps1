# MedClaw 阅片台（QtWebEngine）现场诊断收集脚本
# 用法：双击 collect-viewer-diag.cmd；结果写到桌面 medclaw-viewer-diag-*.txt
# 只读取文件，不做任何修改。

$ErrorActionPreference = 'Continue'
$outPath = Join-Path ([Environment]::GetFolderPath('Desktop')) ('medclaw-viewer-diag-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$sb = New-Object System.Text.StringBuilder
function W([string]$line) { [void]$sb.AppendLine($line) }

W ("== MedClaw 阅片台诊断 " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " ==")
W ""

W "-- 1. 系统 --"
$os = Get-CimInstance Win32_OperatingSystem
W ("{0}  build {1}  {2}" -f $os.Caption, $os.BuildNumber, $os.OSArchitecture)
W ""

W "-- 2. 显卡 --"
Get-CimInstance Win32_VideoController | ForEach-Object {
    W ("{0} | 驱动 {1} | {2}" -f $_.Name, $_.DriverVersion, $_.DriverDate)
}
W ""

W "-- 3. 进程 --"
$procs = Get-Process AetherStudy -ErrorAction SilentlyContinue
if ($procs) {
    $procs | ForEach-Object {
        W ("pid {0} | {1} | 启动 {2} | exe 修改 {3}" -f $_.Id, $_.Path, $_.StartTime, (Get-Item $_.Path).LastWriteTime)
    }
} else {
    W "没有正在运行的 AetherStudy 进程（先打开客户端、打开影像，再跑本脚本）"
}
W ""

W "-- 4. 安装目录里的查看器资产 --"
$bases = @()
if ($procs) { $procs | ForEach-Object { if ($_.Path) { $bases += (Split-Path $_.Path -Parent) } } }
$bases += 'D:\workspace\AetherStudy\client'
$bases = @($bases | Where-Object { $_ } | Select-Object -Unique)
$indexFound = @()
foreach ($d in $bases) {
    W ("目录: " + $d)
    $qt = Join-Path $d 'Qt6Core.dll'
    if (Test-Path $qt) { W ("  Qt6Core.dll: " + (Get-Item $qt).VersionInfo.FileVersion) }
    $candidates = @(
        (Join-Path $d 'viewer-web\cornerstone3d'),
        (Join-Path $d 'viewer-web\dist\cornerstone3d'),
        (Join-Path $d '..\release\viewer-web\cornerstone3d'),
        (Join-Path $d '..\release\viewer-web\dist\cornerstone3d')
    )
    $hit = $false
    foreach ($c in $candidates) {
        $idx = Join-Path $c 'index.html'
        if (Test-Path $idx) {
            $hit = $true
            $indexFound += $idx
            $h = (Get-FileHash $idx -Algorithm SHA1).Hash.Substring(0, 12)
            $txt = Get-Content $idx -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $mark = if ($txt -match '渲染诊断') { 'YES(最新诊断版)' } elseif ($txt -match 'MedViewer') { '仅旧诊断版' } else { 'NO(原始版)' }
            W ("  index.html: " + $idx)
            W ("    sha1 " + $h + " | 诊断补丁: " + $mark + " | 修改 " + (Get-Item $idx).LastWriteTime)
            $bundle = Join-Path $c 'bundle.stripdel01.js'
            if (Test-Path $bundle) { W ("    bundle: " + (Get-Item $bundle).Length + " bytes | " + (Get-Item $bundle).LastWriteTime) }
        }
    }
    if (-not $hit) { W "  没有找到 viewer-web/cornerstone3d/index.html" }
}
W ""

W "-- 5. 相关环境变量（进程级 > 用户级）--"
foreach ($n in @('QTWEBENGINE_CHROMIUM_FLAGS','MEDCLAW_WEBENGINE_ANGLE','MEDCLAW_SOFTWARE_OPENGL','QT_OPENGL','QSG_RHI_BACKEND')) {
    $v = [Environment]::GetEnvironmentVariable($n, 'Process')
    if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, 'User') }
    W ("{0} = {1}" -f $n, ($(if ($v) { $v } else { '(未设置)' })))
}
W ""

$logDir = Join-Path $env:LOCALAPPDATA 'AetherStudy\logs'
$logs = @()
if (Test-Path $logDir) {
    $logs = @(Get-ChildItem $logDir -Filter 'client-*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 4)
}

W "-- 6. 关键诊断行（最新 4 个日志文件）--"
if ($logs.Count -eq 0) {
    W ("日志目录不存在或为空: " + $logDir)
} else {
    $all = @()
    foreach ($f in $logs) {
        $hits = Select-String -Path $f.FullName -Pattern '\[MedViewer\]|\[WebEngine\]|GPU 渲染档位|2D 工具组|2D MPR render backend|Cornerstone3D 四视图|OpenGL|WebGL' -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($hits) { $hits | ForEach-Object { $all += $_.Line } }
    }
    if ($all.Count -eq 0) {
        W "（最近日志里没有查看器相关行：可能还没打开过影像，或日志已滚走）"
    } else {
        $all | Select-Object -Last 200 | ForEach-Object { W $_ }
    }
}

W ""
W "-- 7. 最近启动 / 加载影像的记录 --"
$loadHits = @()
foreach ($f in $logs) {
    $hits = Select-String -Path $f.FullName -Pattern '\[OpenFile\]|\[MedicalOpen\]|\[MedicalView\]|\[ViewerWeb\] loading|\[ViewerHost\]' -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($hits) { $hits | ForEach-Object { $loadHits += $_.Line } }
}
if ($loadHits.Count -eq 0) { W "（没有命中）" } else { $loadHits | Select-Object -Last 60 | ForEach-Object { W $_ } }

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Host ""
Write-Host "诊断文件已生成：" -ForegroundColor Green
Write-Host $outPath -ForegroundColor Yellow
Write-Host ""
Write-Host "把这个 txt 发回来即可（只有版本号、显卡、日志片段，不含影像数据）。"
