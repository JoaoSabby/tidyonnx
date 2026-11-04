# The Windows host resolves metadata and launches Docker without running package tests.
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $repo
try {
  if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker is required; no host test fallback is permitted.'
  }
  $engine = & docker info --format '{{.OSType}}'
  if ($LASTEXITCODE -ne 0 -or $engine -ne 'linux') {
    throw 'A running Docker Linux-container engine is required.'
  }
  $releases = Invoke-RestMethod -Uri 'https://fedoraproject.org/releases.json'
  $versions = @($releases | Where-Object { [string]$_.version -match '^[0-9]+$' } |
    ForEach-Object { [int]$_.version })
  if (!$versions.Count) { throw 'Official Fedora metadata has no stable release.' }
  $latestFedora = ($versions | Measure-Object -Maximum).Maximum
  $fedoraImage = 'registry.fedoraproject.org/fedora:' + $latestFedora
  $runId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + $PID
  $evidence = Join-Path $repo ('validation-results/fedora/' + $runId)
  New-Item -ItemType Directory -Path $evidence -Force | Out-Null
  $fedoraImage | Out-File (Join-Path $evidence 'selected-fedora-image.txt') -Encoding utf8
  & docker version | Out-File (Join-Path $evidence 'docker-version.txt') -Encoding utf8
  $buildArguments = @('build', '--pull', '--no-cache', '--file', 'tools/docker/Dockerfile',
    '--build-arg', ('FEDORA_IMAGE=' + $fedoraImage), '--iidfile',
    (Join-Path $evidence 'image-id.txt'), '--tag', 'tidyonnx-fedora-tests', '.')
  & docker @buildArguments 2>&1 |
    Tee-Object -FilePath (Join-Path $evidence 'image-build.log')
  if ($LASTEXITCODE -ne 0) { throw 'Fedora test image build failed.' }
  $imageId = (Get-Content -LiteralPath (Join-Path $evidence 'image-id.txt') -Raw).Trim()
  & docker image inspect $imageId |
    Out-File (Join-Path $evidence 'image-inspect.json') -Encoding utf8
  & docker image inspect $fedoraImage |
    Out-File (Join-Path $evidence 'base-image-inspect.json') -Encoding utf8
  & git rev-parse HEAD | Out-File (Join-Path $evidence 'git-head.txt') -Encoding utf8
  & git diff --binary | Out-File (Join-Path $evidence 'worktree.patch') -Encoding utf8
  $containerId = (& docker create $imageId).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Cannot create the Fedora validation container.' }
  try {
    & docker start --attach $containerId
    $startStatus = $LASTEXITCODE
    $state = & docker inspect --format '{{.State.Status}}' $containerId
    $runStatus = & docker inspect --format '{{.State.ExitCode}}' $containerId
    & docker logs $containerId 2>&1 |
      Out-File (Join-Path $evidence 'container.log') -Encoding utf8
    & docker inspect $containerId |
      Out-File (Join-Path $evidence 'container-inspect.json') -Encoding utf8
    & docker cp ($containerId + ':/evidence/.') $evidence
    $copyStatus = $LASTEXITCODE
  } finally {
    & docker rm $containerId | Out-Null
  }
  if ($startStatus -ne 0 -or $copyStatus -ne 0 -or $state -ne 'exited' -or $runStatus -ne '0') {
    throw 'Fedora validation failed; inspect the retained logs.'
  }
} finally {
  Pop-Location
}
