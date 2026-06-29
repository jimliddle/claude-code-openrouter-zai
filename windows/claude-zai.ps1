param(
  [string]$Model,
  [string]$OpenRouterModel,
  [switch]$ListModels,
  [string]$SearchModels,
  [string]$OpenRouterUrl,
  [string]$EnvFile,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ClaudeArgs
)

$ErrorActionPreference = "Stop"

$SelectedModel = if ($OpenRouterModel) {
  $OpenRouterModel
} elseif ($Model) {
  $Model
} elseif ($env:CLAUDE_ZAI_MODEL) {
  $env:CLAUDE_ZAI_MODEL
} else {
  "z-ai/glm-5.2"
}

$BaseUrl = if ($OpenRouterUrl) {
  $OpenRouterUrl
} elseif ($env:OPENROUTER_BASE_URL) {
  $env:OPENROUTER_BASE_URL
} elseif ($env:CLAUDE_ZAI_BASE_URL) {
  $env:CLAUDE_ZAI_BASE_URL
} else {
  "https://openrouter.ai/api"
}
$BaseUrl = $BaseUrl.TrimEnd("/")

if (-not $EnvFile) {
  $EnvFile = if ($env:CLAUDE_ZAI_ENV_FILE) { $env:CLAUDE_ZAI_ENV_FILE } else { Join-Path $HOME ".claude-zai.env.ps1" }
}

function Resolve-OpenRouterModel {
  param([string]$Name)
  switch -Regex ($Name) {
    "^(glm|glm-5\.2|glm5\.2|zai|z-ai|default)$" { "z-ai/glm-5.2"; return }
    "^(glm-5|glm5)$" { "z-ai/glm-5"; return }
    "^(glm-5-turbo|glm5-turbo)$" { "z-ai/glm-5-turbo"; return }
    "^(glm-4\.7|glm4\.7)$" { "z-ai/glm-4.7"; return }
    "^(glm-4\.6|glm4\.6)$" { "z-ai/glm-4.6"; return }
    "^(sonnet|claude-sonnet)$" { "anthropic/claude-sonnet-4.6"; return }
    "^(opus|claude-opus)$" { "anthropic/claude-opus-4.8"; return }
    "^(haiku|claude-haiku)$" { "anthropic/claude-haiku-4.5"; return }
    "^(gpt|gpt-5|gpt5)$" { "openai/gpt-5.5"; return }
    "^(gpt-codex|codex)$" { "openai/gpt-5.3-codex"; return }
    "^(qwen-coder|qwen3-coder)$" { "qwen/qwen3-coder"; return }
    default { $Name; return }
  }
}

function Show-OpenRouterModels {
  param([string]$Filter)
  $Url = "$BaseUrl/v1/models"
  $Payload = Invoke-RestMethod -Uri $Url -Method Get
  $Rows = @($Payload.data)
  if ($Filter) {
    $Needle = $Filter.ToLowerInvariant()
    $Rows = $Rows | Where-Object {
      (($_.id, $_.name, $_.description, $_.architecture.modality, $_.architecture.tokenizer) -join " ").ToLowerInvariant().Contains($Needle)
    }
  }
  $Rows |
    Sort-Object id |
    ForEach-Object {
      $Context = if ($_.context_length) { "$($_.context_length) ctx" } else { "ctx ?" }
      $Input = if ($_.pricing.prompt) { $_.pricing.prompt } else { "?" }
      $Output = if ($_.pricing.completion) { $_.pricing.completion } else { "?" }
      "$($_.id)`t$Context`tinput $Input`toutput $Output`t$($_.name)"
    }
}

if ($ListModels) {
  Show-OpenRouterModels
  exit 0
}

if ($SearchModels) {
  Show-OpenRouterModels -Filter $SearchModels
  exit 0
}

if ($EnvFile -and (Test-Path $EnvFile)) {
  . $EnvFile
}

if (-not $env:OPENROUTER_API_KEY -and -not $env:ANTHROPIC_AUTH_TOKEN) {
  throw "OPENROUTER_API_KEY is not set. Add `$env:OPENROUTER_API_KEY = `"sk-or-...`" to $EnvFile."
}

$SelectedModel = Resolve-OpenRouterModel $SelectedModel

$env:ANTHROPIC_BASE_URL = $BaseUrl
Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
if (-not $env:ANTHROPIC_AUTH_TOKEN) {
  $env:ANTHROPIC_AUTH_TOKEN = $env:OPENROUTER_API_KEY
}
$env:ANTHROPIC_MODEL = $SelectedModel
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $SelectedModel
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $SelectedModel
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $SelectedModel
$env:CLAUDE_CODE_SUBAGENT_MODEL = $SelectedModel
if (-not $env:CLAUDE_CODE_DISABLE_LEGACY_MODEL_REMAP) {
  $env:CLAUDE_CODE_DISABLE_LEGACY_MODEL_REMAP = "1"
}
if (-not $env:CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY) {
  $env:CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"
}
if (-not $env:API_TIMEOUT_MS) {
  $env:API_TIMEOUT_MS = "3000000"
}

if ($env:OPENROUTER_SITE_URL -or $env:OPENROUTER_APP_NAME) {
  $Headers = @()
  if ($env:OPENROUTER_SITE_URL) {
    $Headers += "HTTP-Referer: $($env:OPENROUTER_SITE_URL)"
  }
  if ($env:OPENROUTER_APP_NAME) {
    $Headers += "X-Title: $($env:OPENROUTER_APP_NAME)"
  }
  $env:ANTHROPIC_CUSTOM_HEADERS = $Headers -join ","
}

$ArgsList = @("--model", $SelectedModel)
if ($ClaudeArgs) {
  $ArgsList += $ClaudeArgs
}

& claude @ArgsList
exit $LASTEXITCODE
