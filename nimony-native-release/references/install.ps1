# Installs the <app> binary from GitHub Releases on Windows.
#
#   irm https://github.com/<owner>/<repo>/releases/latest/download/install.ps1 | iex
#
# $env:<APP>_VERSION      release tag to install (default: the latest release)
# $env:<APP>_INSTALL_DIR  where to put <app>.exe (default: %LOCALAPPDATA%\Programs\<app>)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = '<owner>/<repo>'
$version = if ($env:<APP>_VERSION) { $env:<APP>_VERSION } else { 'latest' }
$dir = if ($env:<APP>_INSTALL_DIR) { $env:<APP>_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\<app>' }

$arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($arch) {
  'AMD64' { }
  'ARM64' { Write-Warning 'No Windows ARM64 build is published; installing the x64 build, which needs x64 emulation.' }
  default { throw "<app> install: unsupported architecture: $arch" }
}

$base = "https://github.com/$repo/releases/download/$version"
if ($version -eq 'latest') { $base = "https://github.com/$repo/releases/latest/download" }
$asset = '<app>-windows-amd64.zip'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("<app>-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Write-Host "Downloading $asset ($version)"
  Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile (Join-Path $tmp $asset)
  Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile (Join-Path $tmp 'SHA256SUMS')

  $expected = $null
  foreach ($line in Get-Content (Join-Path $tmp 'SHA256SUMS')) {
    $parts = $line -split '\s+', 2
    if ($parts.Count -eq 2 -and $parts[1].TrimStart('*') -eq $asset) { $expected = $parts[0] }
  }
  if (-not $expected) { throw "<app> install: $asset is not listed in SHA256SUMS" }
  $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $tmp $asset)).Hash
  if ($actual -ne $expected) { throw "<app> install: checksum mismatch for $asset" }

  Expand-Archive -Path (Join-Path $tmp $asset) -DestinationPath $tmp -Force
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $exe = Join-Path $dir '<app>.exe'
  Copy-Item -Force (Join-Path $tmp '<app>.exe') $exe
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

& $exe -h | Out-Null
if ($LASTEXITCODE -ne 0) { throw "<app> install: installed $exe but it does not run" }
Write-Host "Installed <app> to $exe"

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (($userPath -split ';') -contains $dir)) {
  $newPath = if ($userPath) { "$userPath;$dir" } else { $dir }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  $env:Path = "$env:Path;$dir"
  Write-Host "Added $dir to your user PATH; open a new terminal to use <app>."
}
