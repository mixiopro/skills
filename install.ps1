# Mixio Skills & Agents Universal Installer for Windows PowerShell
# Usage:
#   irm https://raw.githubusercontent.com/mixiopro/skills/main/install.ps1 | iex
#   or:
#   powershell -ExecutionPolicy ByPass -c "irm https://raw.githubusercontent.com/mixiopro/skills/main/install.ps1 | iex"

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-MixioHeader {
    Write-Host ""
    Write-Host "  __  __ _      _         ____  _     _ _ _      " -ForegroundColor Cyan
    Write-Host " |  \/  (_)_  _(_) ___   / ___|| | __(_) | |___  " -ForegroundColor Cyan
    Write-Host " | |\/| | \ \/ / |/ _ \  \___ \| |/ /| | | / __| " -ForegroundColor Cyan
    Write-Host " | |  | | |>  <| | (_) |  ___) |   < | | | \__ \ " -ForegroundColor Cyan
    Write-Host " |_|  |_|_/_/\_\_|\___/  |____/|_|\_\|_|_|_|___/ " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Mixio Skills & Agent System Installer for Windows" -ForegroundColor White
    Write-Host "https://mixio.pro — AI Agent Skills & Workflows" -ForegroundColor Gray
    Write-Host ""
}

function Write-Info($msg) {
    Write-Host "==> " -ForegroundColor Cyan -NoNewline
    Write-Host $msg -ForegroundColor White
}

function Write-Success($msg) {
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $msg -ForegroundColor White
}

function Write-WarnMsg($msg) {
    Write-Host "[!] " -ForegroundColor Yellow -NoNewline
    Write-Host $msg -ForegroundColor Yellow
}

function Write-ErrMsg($msg) {
    Write-Host "[ERR] " -ForegroundColor Red -NoNewline
    Write-Host $msg -ForegroundColor Red
}

Write-MixioHeader

# Paths
$UserHome = $HOME
if (-not $UserHome) {
    $UserHome = $env:USERPROFILE
}

$MixioDir = Join-Path $UserHome ".mixio"
$MixioSkillsDir = Join-Path $MixioDir "skills"
$AgentsDir = Join-Path $UserHome ".agents"
$AgentsSkillsDir = Join-Path $AgentsDir "skills"
$AgentsMdPath = Join-Path $AgentsDir "AGENTS.md"

$RepoZipUrl = "https://github.com/mixiopro/skills/archive/refs/heads/main.zip"
$RepoGitUrl = "https://github.com/mixiopro/skills.git"

# Step 1: Pre-flight checks
Write-Info "Checking prerequisites..."

$hasGit = $false
try {
    $gitVer = git --version 2>$null
    if ($gitVer) {
        $hasGit = $true
        Write-Success "Found git: $gitVer"
    }
} catch {}

$hasNode = $false
try {
    $nodeVer = node -v 2>$null
    if ($nodeVer) {
        $hasNode = $true
        Write-Success "Found node: $nodeVer"
    }
} catch {}

if (-not $hasNode) {
    Write-WarnMsg "Node.js not found. Node.js 22+ is recommended for running Mixio MCP server (@mixio-pro/mcp)."
}

# Step 2: Interactive API Key resolution & Browser open
$apiKey = if ($env:MIXIO_API_KEY) { $env:MIXIO_API_KEY } else { "" }

if (-not $apiKey) {
    Write-Host ""
    Write-Info "Mixio API Key Configuration"
    Write-Host "  Get your API key at: https://studio.mixio.pro/settings/api-keys" -ForegroundColor White
    
    $openBrowser = Read-Host "  Open API keys page in browser now? [Y/n]"
    if (-not $openBrowser -or $openBrowser -match "^[Yy]$") {
        Write-Info "Opening https://studio.mixio.pro/settings/api-keys in browser..."
        try {
            Start-Process "https://studio.mixio.pro/settings/api-keys"
        } catch {}
    }

    Write-Host ""
    $inputKey = Read-Host "  Paste your Mixio API Key (sk-...) [press Enter to skip]"
    if ($inputKey) {
        $apiKey = $inputKey.Trim()
    }
}

if ($apiKey) {
    $maskedKey = if ($apiKey.Length -gt 11) { $apiKey.Substring(0, 7) + "..." + $apiKey.Substring($apiKey.Length - 4) } else { "sk-***" }
    Write-Success "API Key provided: $maskedKey"
    try {
        [System.Environment]::SetEnvironmentVariable('MIXIO_API_KEY', $apiKey, 'User')
        [System.Environment]::SetEnvironmentVariable('MIXIO_BASE_URL', 'https://studio.mixio.pro', 'User')
        $env:MIXIO_API_KEY = $apiKey
        $env:MIXIO_BASE_URL = 'https://studio.mixio.pro'
        Write-Success "Persisted MIXIO_API_KEY in Windows User environment variables."
    } catch {}
} else {
    Write-WarnMsg "No API key provided. You can set MIXIO_API_KEY later in Windows environment variables or MCP config."
}

# Step 3: Create directories
Write-Info "Setting up global Mixio directories ($MixioDir)..."
New-Item -ItemType Directory -Force -Path $MixioDir | Out-Null
New-Item -ItemType Directory -Force -Path $MixioSkillsDir | Out-Null
New-Item -ItemType Directory -Force -Path $AgentsSkillsDir | Out-Null

# Step 4: Fetch repo skills and AGENTS.md
Write-Info "Downloading latest Mixio skills..."
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("mixio_install_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$downloadSuccess = $false

# Check if running from local repo
$localScriptDir = if (Test-Path variable:PSScriptRoot) { $PSScriptRoot } else { "" }
if ($localScriptDir -and (Test-Path (Join-Path $localScriptDir "skills")) -and (Test-Path (Join-Path $localScriptDir "AGENTS.md"))) {
    Get-ChildItem -Path $MixioSkillsDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $localScriptDir "skills\*") -Destination $MixioSkillsDir -Recurse -Force
    Copy-Item -Path (Join-Path $localScriptDir "AGENTS.md") -Destination (Join-Path $MixioDir "AGENTS.md") -Force
    Copy-Item -Path (Join-Path $localScriptDir "AGENTS.md") -Destination $AgentsMdPath -Force
    $downloadSuccess = $true
} else {
    if ($hasGit) {
        try {
            git clone --depth 1 $RepoGitUrl (Join-Path $tempDir "repo") 2>$null | Out-Null
            if (Test-Path (Join-Path $tempDir "repo\skills")) {
                $sourceSkillsDir = Join-Path $tempDir "repo\skills"
                $sourceAgentsMd = Join-Path $tempDir "repo\AGENTS.md"
                Get-ChildItem -Path $MixioSkillsDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Copy-Item -Path "$sourceSkillsDir\*" -Destination $MixioSkillsDir -Recurse -Force
                if (Test-Path $sourceAgentsMd) {
                    Copy-Item -Path $sourceAgentsMd -Destination (Join-Path $MixioDir "AGENTS.md") -Force
                    Copy-Item -Path $sourceAgentsMd -Destination $AgentsMdPath -Force
                }
                $downloadSuccess = $true
            }
        } catch {}
    }

    if (-not $downloadSuccess) {
        try {
            $zipFile = Join-Path $tempDir "skills.zip"
            Write-Info "Downloading archive from GitHub..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $RepoZipUrl -OutFile $zipFile -UseBasicParsing
            Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
            
            $extractedSkillsDir = Join-Path $tempDir "skills-main\skills"
            $extractedAgentsMd = Join-Path $tempDir "skills-main\AGENTS.md"
            if (Test-Path $extractedSkillsDir) {
                Get-ChildItem -Path $MixioSkillsDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Copy-Item -Path "$extractedSkillsDir\*" -Destination $MixioSkillsDir -Recurse -Force
                if (Test-Path $extractedAgentsMd) {
                    Copy-Item -Path $extractedAgentsMd -Destination (Join-Path $MixioDir "AGENTS.md") -Force
                    Copy-Item -Path $extractedAgentsMd -Destination $AgentsMdPath -Force
                }
                $downloadSuccess = $true
            }
        } catch {
            Write-ErrMsg "Failed to download skills archive: $_"
        }
    }
}

# Cleanup temp files
try {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
} catch {}

# Step 5: Populate ~/.agents/skills
Write-Info "Populating skills into $AgentsSkillsDir..."

# Clean stale mixio-* skills from ~/.agents/skills
Get-ChildItem -Path $AgentsSkillsDir -Directory -Filter "mixio-*" | ForEach-Object {
    $curName = $_.Name
    if (-not (Test-Path (Join-Path $MixioSkillsDir $curName))) {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Get-ChildItem -Path $MixioSkillsDir -Directory | ForEach-Object {
    $skillName = $_.Name
    $dest = Join-Path $AgentsSkillsDir $skillName
    if (Test-Path $dest) {
        Remove-Item -Path $dest -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path "$($_.FullName)\*" -Destination $dest -Recurse -Force
}

$skillDirs = Get-ChildItem -Path $AgentsSkillsDir -Directory | Where-Object { $_.Name -like "mixio-*" }
Write-Success "Installed $($skillDirs.Count) Mixio skills in $AgentsSkillsDir"

# Step 6: Register skills with AI agents
Write-Info "Registering Mixio skills and docs to AI agent profiles..."

function Link-Or-Copy-Skills {
    param(
        [string]$AgentName,
        [string]$TargetSkillsDir,
        [string]$TargetAgentsDoc
    )

    try {
        New-Item -ItemType Directory -Force -Path $TargetSkillsDir | Out-Null
        
        # Clean obsolete mixio-* skills from target agent directory
        Get-ChildItem -Path $TargetSkillsDir -Filter "mixio-*" | ForEach-Object {
            $curName = $_.Name
            if (-not (Test-Path (Join-Path $MixioSkillsDir $curName))) {
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        $installed = 0
        Get-ChildItem -Path $AgentsSkillsDir -Directory -Filter "mixio-*" | ForEach-Object {
            $dest = Join-Path $TargetSkillsDir $_.Name
            # On Windows, try SymbolicLink / Junction or copy
            try {
                if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force -ErrorAction SilentlyContinue }
                New-Item -ItemType SymbolicLink -Path $dest -Target $_.FullName -ErrorAction Stop | Out-Null
                $installed++
            } catch {
                try {
                    if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force -ErrorAction SilentlyContinue }
                    New-Item -ItemType Junction -Path $dest -Target $_.FullName -ErrorAction Stop | Out-Null
                    $installed++
                } catch {
                    Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
                    $installed++
                }
            }
        }

        if ($TargetAgentsDoc -and (Test-Path (Join-Path $MixioDir "AGENTS.md"))) {
            $docParent = Split-Path -Path $TargetAgentsDoc -Parent
            New-Item -ItemType Directory -Force -Path $docParent | Out-Null
            Copy-Item -Path (Join-Path $MixioDir "AGENTS.md") -Destination $TargetAgentsDoc -Force
        }

        Write-Success "Configured $AgentName ($installed skills linked)"
    } catch {
        Write-WarnMsg "Could not configure $AgentName`: $_"
    }
}

function Configure-Mcp-Json {
    param(
        [string]$JsonFilePath,
        [string]$PassedApiKey
    )
    try {
        $parent = Split-Path -Path $JsonFilePath -Parent
        New-Item -ItemType Directory -Force -Path $parent | Out-Null

        $data = @{}
        if (Test-Path $JsonFilePath) {
            $raw = Get-Content -Path $JsonFilePath -Raw
            if ($raw.Trim().Length -gt 0) {
                $data = $raw | ConvertFrom-Json -AsHashtable
            }
        }

        if (-not $data.ContainsKey("mcpServers")) {
            $data["mcpServers"] = @{}
        }

        $mcpServers = $data["mcpServers"]
        $existingMixio = if ($mcpServers.ContainsKey("mixio")) { $mcpServers["mixio"] } else { @{} }
        $existingEnv = if ($existingMixio.ContainsKey("env")) { $existingMixio["env"] } else { @{} }

        $finalApiKey = if ($PassedApiKey) {
            $PassedApiKey
        } elseif ($existingEnv.ContainsKey("MIXIO_API_KEY") -and $existingEnv["MIXIO_API_KEY"] -ne "YOUR_API_KEY_HERE") {
            $existingEnv["MIXIO_API_KEY"]
        } elseif ($env:MIXIO_API_KEY) {
            $env:MIXIO_API_KEY
        } else {
            "YOUR_API_KEY_HERE"
        }

        $mcpServers["mixio"] = @{
            command = "npx"
            args = @("-y", "@mixio-pro/mcp")
            env = @{
                MIXIO_API_KEY = $finalApiKey
                MIXIO_BASE_URL = "https://studio.mixio.pro"
            }
        }
        $data | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonFilePath -Encoding utf8
    } catch {}
}

# 1. Claude Code
Link-Or-Copy-Skills -AgentName "Claude Code" -TargetSkillsDir (Join-Path $UserHome ".claude\skills") -TargetAgentsDoc (Join-Path $UserHome ".claude\CLAUDE.md")
Configure-Mcp-Json -JsonFilePath (Join-Path $UserHome ".claude\claude_desktop_config.json") -PassedApiKey $apiKey
Configure-Mcp-Json -JsonFilePath (Join-Path $UserHome ".claude\mcp.json") -PassedApiKey $apiKey
if ($env:APPDATA) {
    Configure-Mcp-Json -JsonFilePath (Join-Path $env:APPDATA "Claude\claude_desktop_config.json") -PassedApiKey $apiKey
}

# 2. Codex
Link-Or-Copy-Skills -AgentName "Codex" -TargetSkillsDir (Join-Path $UserHome ".codex\skills") -TargetAgentsDoc (Join-Path $UserHome ".codex\AGENTS.md")

# 3. Gemini / Antigravity
Link-Or-Copy-Skills -AgentName "Gemini / Antigravity" -TargetSkillsDir (Join-Path $UserHome ".gemini\skills") -TargetAgentsDoc (Join-Path $UserHome ".gemini\GEMINI.md")
Link-Or-Copy-Skills -AgentName "Antigravity CLI" -TargetSkillsDir (Join-Path $UserHome ".gemini\antigravity-cli\skills") -TargetAgentsDoc ""
Configure-Mcp-Json -JsonFilePath (Join-Path $UserHome ".gemini\antigravity-cli\mcp_config.json") -PassedApiKey $apiKey
Configure-Mcp-Json -JsonFilePath (Join-Path $UserHome ".gemini\config\mcp_config.json") -PassedApiKey $apiKey

# 4. Kiro
Link-Or-Copy-Skills -AgentName "Kiro" -TargetSkillsDir (Join-Path $UserHome ".kiro\skills") -TargetAgentsDoc (Join-Path $UserHome ".kiro\steering\mixio.md")
Configure-Mcp-Json -JsonFilePath (Join-Path $UserHome ".kiro\settings\mcp.json") -PassedApiKey $apiKey

# 5. Cursor
Link-Or-Copy-Skills -AgentName "Cursor" -TargetSkillsDir (Join-Path $UserHome ".cursor\skills") -TargetAgentsDoc (Join-Path $UserHome ".cursor\AGENTS.md")
Configure-Mcp-Json -JsonFilePath (Join-Path $UserHome ".cursor\mcp.json") -PassedApiKey $apiKey

# 6. OpenCode
Link-Or-Copy-Skills -AgentName "OpenCode" -TargetSkillsDir (Join-Path $UserHome ".opencode\skills") -TargetAgentsDoc (Join-Path $UserHome ".opencode\AGENTS.md")

# 7. GitHub Copilot
Link-Or-Copy-Skills -AgentName "GitHub Copilot" -TargetSkillsDir (Join-Path $UserHome ".copilot\skills") -TargetAgentsDoc (Join-Path $UserHome ".copilot\AGENTS.md")

# 8. Generic Agent (.agent)
Link-Or-Copy-Skills -AgentName "Generic Agent (.agent)" -TargetSkillsDir (Join-Path $UserHome ".agent\skills") -TargetAgentsDoc (Join-Path $UserHome ".agent\AGENTS.md")

# 9. Hermes Agent (.hermes)
if (Test-Path (Join-Path $UserHome ".hermes")) {
    Link-Or-Copy-Skills -AgentName "Hermes Agent" -TargetSkillsDir (Join-Path $UserHome ".hermes\skills\mixio") -TargetAgentsDoc (Join-Path $UserHome ".hermes\AGENTS.md")
}

# Also sync with npx skills standard package if npx is available
try {
    $npxVer = npx --version 2>$null
    if ($npxVer) {
        Write-Info "Syncing with npx skills standard registry..."
        npx skills add mixiopro/skills -g -y 2>$null | Out-Null
    }
} catch {}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  Mixio Skills & Agent Setup Completed Successfully!  " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary of locations:" -ForegroundColor White
Write-Host "  • Mixio Home Directory : $MixioDir" -ForegroundColor Gray
Write-Host "  • Global Skills Store  : $MixioSkillsDir" -ForegroundColor Gray
Write-Host "  • Global Agents Store  : $AgentsDir (AGENTS.md + skills)" -ForegroundColor Gray
Write-Host "  • Registered Agents    : Claude Code, Codex, Gemini/Antigravity, Kiro, Cursor, Copilot, OpenCode, Hermes" -ForegroundColor Gray
if ($apiKey) {
    Write-Host "  • Mixio API Key        : Configured in MCP configs & User environment" -ForegroundColor Green
} else {
    Write-Host "  • Mixio API Key        : Not set (Get from https://studio.mixio.pro/settings/api-keys)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "To test MCP server in your agent:" -ForegroundColor White
Write-Host "  Ask: ""Use the studio_ping tool to check Mixio Studio MCP connection""" -ForegroundColor Gray
Write-Host ""
