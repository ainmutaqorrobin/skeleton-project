param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$rulesRoot = Join-Path $repoRoot ".ai\\rules"

$pairs = @(
  @{ Rule = "root.md"; Path = "" },
  @{ Rule = "api.md"; Path = "apps\\api" },
  @{ Rule = "frontend.md"; Path = "apps\\frontend" },
  @{ Rule = "common.md"; Path = "apps\\common" },
  @{ Rule = "docker.md"; Path = "apps\\docker" },
  @{ Rule = "packages.md"; Path = "apps\\packages" }
)

function New-DocContent {
  param(
    [string]$Title,
    [string]$Body
  )

@"
# $Title

This file is generated from `.ai/rules`. Edit the source templates there, then run `scripts/sync-agent-docs.ps1` or `scripts/sync-agent-docs.sh`.

$Body
"@
}

foreach ($pair in $pairs) {
  $rulePath = Join-Path $rulesRoot $pair.Rule
  $rawBody = Get-Content -Path $rulePath -Raw

  foreach ($docName in @("AGENTS.md", "CLAUDE.md")) {
    $body = $rawBody.Replace("{{DOC_NAME}}", $docName)
    $outputDir = if ($pair.Path) { Join-Path $repoRoot $pair.Path } else { $repoRoot }
    $outputPath = Join-Path $outputDir $docName
    $content = New-DocContent -Title $docName -Body $body
    Set-Content -Path $outputPath -Value $content -NoNewline
  }
}

Write-Host "Synced AGENTS.md and CLAUDE.md files from .ai/rules"
