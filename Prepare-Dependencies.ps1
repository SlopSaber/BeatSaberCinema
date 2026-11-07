[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ArtifactDirectory)

$ErrorActionPreference = 'Stop'
$destination = Join-Path ([IO.Path]::GetFullPath($ArtifactDirectory)) 'Mods/Libraries'
$cache = Join-Path $PSScriptRoot 'BeatSaberCinema/obj/CinemaDownloads'
[IO.Directory]::CreateDirectory($destination) | Out-Null
[IO.Directory]::CreateDirectory($cache) | Out-Null
$headers = @{ 'User-Agent' = 'BeatSaberCinema-Build' }
$records = @()

function Get-ReleaseAsset($Release, [string]$Name) {
    $asset = $Release.assets | Where-Object name -eq $Name | Select-Object -First 1
    if (-not $asset) { throw "Release asset is missing: $Name" }
    $file = Join-Path $cache ($Release.tag_name + '-' + $Name)
    if (-not (Test-Path -LiteralPath $file)) {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file -Headers $headers
    }
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    if ($asset.digest -and $asset.digest -ne ('sha256:' + $hash.ToLowerInvariant())) {
        throw "Release asset checksum mismatch: $Name"
    }
    return $file
}

function Copy-ZipEntry([string]$Archive, [string]$Suffix, [string]$Target) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $entry = @($zip.Entries | Where-Object { $_.FullName.EndsWith($Suffix, [StringComparison]::OrdinalIgnoreCase) })
        if ($entry.Count -ne 1) { throw "Expected one archive entry ending with $Suffix" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0], (Join-Path $destination $Target), $true)
    }
    finally { $zip.Dispose() }
}

$yt = Invoke-RestMethod 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest' -Headers $headers
$ytFile = Get-ReleaseAsset $yt 'yt-dlp.exe'
$sums = Get-ReleaseAsset $yt 'SHA2-256SUMS'
$expected = (Get-Content -LiteralPath $sums | Where-Object { $_ -match '\s+yt-dlp\.exe$' }) -split '\s+'
if ($expected[0] -ne (Get-FileHash -LiteralPath $ytFile).Hash) { throw 'yt-dlp checksum mismatch.' }
Copy-Item -LiteralPath $ytFile -Destination (Join-Path $destination 'yt-dlp.exe')
Invoke-WebRequest "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$($yt.tag_name)/LICENSE" -OutFile (Join-Path $destination 'yt-dlp-LICENSE.txt')
$records += @{ name = 'yt-dlp'; version = $yt.tag_name; source = $yt.html_url }

$ff = Invoke-RestMethod 'https://api.github.com/repos/GyanD/codexffmpeg/releases/latest' -Headers $headers
$ffAsset = $ff.assets | Where-Object name -match '-essentials_build\.zip$' | Select-Object -First 1
if (-not $ffAsset) { throw 'FFmpeg essentials archive is missing.' }
$ffArchive = Get-ReleaseAsset $ff $ffAsset.name
Copy-ZipEntry $ffArchive '/bin/ffmpeg.exe' 'ffmpeg.exe'
Copy-ZipEntry $ffArchive '/LICENSE' 'ffmpeg-LICENSE.txt'
$records += @{ name = 'FFmpeg'; version = $ff.tag_name; source = $ff.html_url; sourceCode = 'https://www.gyan.dev/ffmpeg/builds/#source-code' }

$deno = Invoke-RestMethod 'https://api.github.com/repos/denoland/deno/releases/latest' -Headers $headers
$denoArchive = Get-ReleaseAsset $deno 'deno-x86_64-pc-windows-msvc.zip'
$denoSums = Get-ReleaseAsset $deno 'deno-x86_64-pc-windows-msvc.zip.sha256sum'
$expected = [regex]::Match((Get-Content -LiteralPath $denoSums -Raw), '(?i)\b[0-9a-f]{64}\b').Value
if ($expected -ne (Get-FileHash -LiteralPath $denoArchive).Hash) { throw 'Deno checksum mismatch.' }
Copy-ZipEntry $denoArchive 'deno.exe' 'deno.exe'
Invoke-WebRequest "https://raw.githubusercontent.com/denoland/deno/$($deno.tag_name)/LICENSE.md" -OutFile (Join-Path $destination 'deno-LICENSE.txt')
$records += @{ name = 'Deno'; version = $deno.tag_name; source = $deno.html_url }

@{ tools = $records; files = @(Get-ChildItem -LiteralPath $destination -Filter '*.exe' | ForEach-Object {
    @{ name = $_.Name; sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash }
}) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'tools.json')
$records | ForEach-Object { Write-Output "$($_.name) $($_.version)" }
