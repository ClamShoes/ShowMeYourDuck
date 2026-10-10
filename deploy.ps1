<#
.SYNOPSIS
Deploys main to showmeyourduck.paff.me: tests, web export (committed as "Web build: ..."), push,
server update. With -Apk it also exports the Android debug APK and publishes it at /download/.

.EXAMPLE
.\deploy.ps1          # web + server
.\deploy.ps1 -Apk     # web + server + new APK on the download page
#>
param([switch]$Apk)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$Godot = Join-Path $PSScriptRoot 'Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$Key = Join-Path $PSScriptRoot 'ShowMeYourDuck.ppk'
$HostName = 'ec2-user@13.239.116.120'
$Site = 'https://showmeyourduck.paff.me'
$ApkPath = Join-Path $PSScriptRoot 'export\android\ShowMeYourDuck.apk'
$RemoteDownload = '/var/www/duck/download'

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "`nDEPLOY FAILED: $msg" -ForegroundColor Red; exit 1 }
# Native tools report failure through the exit code only; stderr is left on the console.
function Run($what, [scriptblock]$block) {
	& $block
	if ($LASTEXITCODE -ne 0) { Fail "$what (exit $LASTEXITCODE)" }
}
function Remote($command) { Run "server: $command" { plink -batch -i $Key $HostName $command } }

foreach ($f in @($Godot, $Key)) { if (-not (Test-Path $f)) { Fail "missing $f" } }
foreach ($t in @('git', 'plink', 'pscp')) { if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { Fail "$t not on PATH" } }

Step 'Checks'
$branch = git branch --show-current
if ($branch -ne 'main') { Fail "on branch '$branch'; switch to main first" }
# Content diffs, not `git status`: Godot rewrites .import files with identical content, which status
# (with autocrlf) reports as modified.
$dirty = @(git diff --name-only HEAD) + @(git ls-files --others --exclude-standard) | Where-Object { $_ -and $_ -notmatch '^web/' }
if ($dirty) { Fail "uncommitted changes (commit or stash them first):`n$($dirty -join "`n")" }
Run 'git pull' { git pull --ff-only }

Step 'Tests'
Run 'tests failed' { & $Godot --headless --path . -s res://tests/run_tests.gd }

Step 'Web export'
Run 'web export' { & $Godot --headless --path . --export-release Web web/index.html }
Run 'git add web' { git add web }
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
	$subject = git log -1 --format=%s
	Run 'git commit' { git commit -q -m "Web build: $subject" }
	Write-Host "Committed: Web build: $subject"
} else {
	Write-Host 'Web build unchanged.'
}

Step 'Push'
Run 'git push' { git push origin main }

Step 'Server update'
Remote '~/update-duck.sh'

if ($Apk) {
	Step 'Android APK'
	New-Item -ItemType Directory -Force (Split-Path $ApkPath) | Out-Null
	Run 'APK export' { & $Godot --headless --path . --export-debug Android $ApkPath }
	$protocol = (Select-String -Path scripts\net\net.gd -Pattern 'PROTOCOL_VERSION := (\d+)').Matches[0].Groups[1].Value
	$build = '{0}, commit {1}, protocol {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), (git rev-parse --short HEAD), $protocol
	$page = Join-Path $env:TEMP 'duck-download-index.html'
	$html = (Get-Content -Raw -Encoding UTF8 deploy\download\index.html).Replace('{{BUILD}}', $build)
	[IO.File]::WriteAllText($page, $html, (New-Object Text.UTF8Encoding $false))
	Remote "mkdir -p $RemoteDownload"
	# Upload under a temporary name and rename, so testers never download a half-written APK.
	Run 'APK upload' { pscp -batch -q -i $Key $ApkPath "${HostName}:$RemoteDownload/ShowMeYourDuck.apk.part" }
	Run 'page upload' { pscp -batch -q -i $Key $page "${HostName}:$RemoteDownload/index.html" }
	Remote "mv $RemoteDownload/ShowMeYourDuck.apk.part $RemoteDownload/ShowMeYourDuck.apk"
	Write-Host "Published APK ($build)"
}

Step 'Verify'
$local = git rev-parse HEAD
$remote = plink -batch -i $Key $HostName 'git -C /opt/duck rev-parse HEAD'
if ($remote -ne $local) { Fail "server is on $remote, expected $local" }
Write-Host "Server on $(git rev-parse --short HEAD)"
$status = (Invoke-WebRequest -UseBasicParsing -Method Head $Site).StatusCode
if ($status -ne 200) { Fail "$Site returned $status" }
Write-Host "$Site -> $status"
try {
	$r = Invoke-WebRequest -UseBasicParsing -Method Head "$Site/download/ShowMeYourDuck.apk"
	$size = [long]$r.Headers['Content-Length']
	if ($Apk -and $size -ne (Get-Item $ApkPath).Length) { Fail "served APK is $size bytes, expected $((Get-Item $ApkPath).Length)" }
	Write-Host "$Site/download/ -> APK $([math]::Round($size / 1MB, 1)) MB"
} catch {
	if ($Apk) { Fail "APK not reachable: $_" }
	Write-Host 'No APK published yet (run with -Apk).'
}

Write-Host "`nDeploy done." -ForegroundColor Green
