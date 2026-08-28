#!/usr/bin/env bash
# Mixio Skills & Agents Universal Installer for Linux & macOS
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mixiopro/skills/main/install.sh | bash
#   or:
#   wget -qO- https://raw.githubusercontent.com/mixiopro/skills/main/install.sh | bash

set -euo pipefail

# Text styling
BOLD="$(tput bold 2>/dev/null || echo '')"
RESET="$(tput sgr0 2>/dev/null || echo '')"
GREEN="$(tput setaf 2 2>/dev/null || echo '')"
CYAN="$(tput setaf 6 2>/dev/null || echo '')"
YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
RED="$(tput setaf 1 2>/dev/null || echo '')"
DIM="$(tput dim 2>/dev/null || echo '')"

info() { echo "${CYAN}==>${RESET} ${BOLD}$*${RESET}"; }
success() { echo "${GREEN}✓${RESET} $*"; }
warn() { echo "${YELLOW}⚠${RESET} $*"; }
error() { echo "${RED}✗${RESET} $*" >&2; }

echo ""
echo "${BOLD}${CYAN}  __  __ _      _         ____  _     _ _ _      ${RESET}"
echo "${BOLD}${CYAN} |  \/  (_)_  _(_) ___   / ___|| | __(_) | |___  ${RESET}"
echo "${BOLD}${CYAN} | |\/| | \ \/ / |/ _ \  \___ \| |/ /| | | / __| ${RESET}"
echo "${BOLD}${CYAN} | |  | | |>  <| | (_) |  ___) |   < | | | \__ \ ${RESET}"
echo "${BOLD}${CYAN} |_|  |_|_/_/\_\_|\___/  |____/|_|\_\|_|_|_|___/ ${RESET}"
echo ""
echo "${BOLD}Mixio Skills & Agent System Installer${RESET}"
echo "${DIM}https://mixio.pro — AI Agent Skills & Workflows${RESET}"
echo ""

# Configuration paths
MIXIO_DIR="${MIXIO_DIR:-$HOME/.mixio}"
MIXIO_SKILLS_DIR="$MIXIO_DIR/skills"
AGENTS_DIR="$HOME/.agents"
AGENTS_SKILLS_DIR="$AGENTS_DIR/skills"
AGENTS_MD_PATH="$AGENTS_DIR/AGENTS.md"

REPO_URL="https://github.com/mixiopro/skills.git"

# Step 1: Pre-flight checks
info "Checking environment and prerequisites..."

HAS_GIT=0
if command -v git &>/dev/null; then
    HAS_GIT=1
    success "Found git: $(git --version)"
fi

HAS_NODE=0
if command -v node &>/dev/null; then
    HAS_NODE=1
    NODE_V=$(node -v)
    success "Found node: $NODE_V"
else
    warn "Node.js not detected. Node 22+ is recommended for running Mixio MCP server (@mixio-pro/mcp)."
fi

# Step 2: Interactive API Key resolution & Browser open
API_KEY="${MIXIO_API_KEY:-}"

open_url_in_browser() {
    local url="$1"
    if command -v open &>/dev/null; then
        open "$url" 2>/dev/null || true
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" 2>/dev/null || true
    elif command -v python3 &>/dev/null; then
        python3 -m webbrowser "$url" 2>/dev/null || true
    fi
}

# If no API Key passed in environment, ask interactively (reading from /dev/tty so curl | bash works)
if [ -z "$API_KEY" ]; then
    echo ""
    info "Mixio API Key Configuration"
    echo "  Get your API key at: ${BOLD}https://studio.mixio.pro/dashboard/api-keys${RESET}"
    
    # Try opening browser on user behalf if terminal is available
    if [ -t 0 ] || [ -e /dev/tty ]; then
        echo -n "  Open API keys page in browser now? [Y/n]: "
        read -r open_browser < /dev/tty || open_browser="y"
        if [[ "$open_browser" =~ ^[Yy]?$ ]]; then
            info "Opening https://studio.mixio.pro/dashboard/api-keys in browser..."
            open_url_in_browser "https://studio.mixio.pro/dashboard/api-keys"
        fi

        echo ""
        echo -n "  Paste your Mixio API Key (sk-...) [press Enter to skip]: "
        read -r input_key < /dev/tty || input_key=""
        API_KEY="$(echo "$input_key" | tr -d '[:space:]')"
    fi
fi

if [ -n "$API_KEY" ]; then
    success "API Key provided: ${API_KEY:0:7}...${API_KEY: -4}"
    
    # Automatically add to shell configuration if not already present
    USER_SHELL="$(basename "${SHELL:-bash}")"
    PROFILE_FILE=""
    if [ "$USER_SHELL" = "zsh" ]; then
        PROFILE_FILE="$HOME/.zshrc"
    elif [ "$USER_SHELL" = "bash" ]; then
        if [ -f "$HOME/.bash_profile" ]; then
            PROFILE_FILE="$HOME/.bash_profile"
        else
            PROFILE_FILE="$HOME/.bashrc"
        fi
    fi

    if [ -n "$PROFILE_FILE" ]; then
        if ! grep -q "MIXIO_API_KEY" "$PROFILE_FILE" 2>/dev/null; then
            echo "" >> "$PROFILE_FILE"
            echo "# Mixio API Key" >> "$PROFILE_FILE"
            echo "export MIXIO_API_KEY=\"$API_KEY\"" >> "$PROFILE_FILE"
            echo "export MIXIO_BASE_URL=\"https://studio.mixio.pro\"" >> "$PROFILE_FILE"
            success "Saved MIXIO_API_KEY to $PROFILE_FILE"
        fi
    fi
else
    warn "No API Key provided. You can set MIXIO_API_KEY later in your shell or MCP config."
fi

# Step 3: Create ~/.mixio global directories
info "Setting up global Mixio environment ($MIXIO_DIR)..."
mkdir -p "$MIXIO_DIR"
mkdir -p "$MIXIO_SKILLS_DIR"
mkdir -p "$AGENTS_SKILLS_DIR"

# Step 4: Fetch or update Mixio Skills and AGENTS.md
info "Downloading latest Mixio skills..."
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Safely check if running from within a clone of repo (handling unbound variable)
SCRIPT_PARENT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
fi

if [ -n "$SCRIPT_PARENT_DIR" ] && [ -d "$SCRIPT_PARENT_DIR/skills" ] && [ -f "$SCRIPT_PARENT_DIR/AGENTS.md" ]; then
    cp -R "$SCRIPT_PARENT_DIR/skills/." "$MIXIO_SKILLS_DIR/"
    cp "$SCRIPT_PARENT_DIR/AGENTS.md" "$MIXIO_DIR/AGENTS.md"
    cp "$SCRIPT_PARENT_DIR/AGENTS.md" "$AGENTS_MD_PATH"
else
    if [ "$HAS_GIT" -eq 1 ]; then
        git clone --depth 1 "$REPO_URL" "$TMP_DIR/repo" 2>/dev/null || {
            warn "git clone failed, falling back to archive download..."
        }
    fi

    if [ -d "$TMP_DIR/repo/skills" ]; then
        # Clean existing skills in ~/.mixio/skills to remove obsolete skills
        rm -rf "$MIXIO_SKILLS_DIR"/* 2>/dev/null || true
        cp -R "$TMP_DIR/repo/skills/." "$MIXIO_SKILLS_DIR/"
        [ -f "$TMP_DIR/repo/AGENTS.md" ] && cp "$TMP_DIR/repo/AGENTS.md" "$MIXIO_DIR/AGENTS.md"
        [ -f "$TMP_DIR/repo/AGENTS.md" ] && cp "$TMP_DIR/repo/AGENTS.md" "$AGENTS_MD_PATH"
    else
        # Fallback to tarball or curl
        info "Fetching release bundle from GitHub..."
        if command -v curl &>/dev/null; then
            curl -fsSL "https://github.com/mixiopro/skills/archive/refs/heads/main.tar.gz" -o "$TMP_DIR/main.tar.gz" || true
        elif command -v wget &>/dev/null; then
            wget -qO "$TMP_DIR/main.tar.gz" "https://github.com/mixiopro/skills/archive/refs/heads/main.tar.gz" || true
        fi

        if [ -f "$TMP_DIR/main.tar.gz" ]; then
            tar -xzf "$TMP_DIR/main.tar.gz" -C "$TMP_DIR"
            EXTRACTED_DIR="$TMP_DIR/skills-main"
            if [ -d "$EXTRACTED_DIR/skills" ]; then
                rm -rf "$MIXIO_SKILLS_DIR"/* 2>/dev/null || true
                cp -R "$EXTRACTED_DIR/skills/." "$MIXIO_SKILLS_DIR/"
                [ -f "$EXTRACTED_DIR/AGENTS.md" ] && cp "$EXTRACTED_DIR/AGENTS.md" "$MIXIO_DIR/AGENTS.md"
                [ -f "$EXTRACTED_DIR/AGENTS.md" ] && cp "$EXTRACTED_DIR/AGENTS.md" "$AGENTS_MD_PATH"
            fi
        fi
    fi
fi

# Step 5: Populate ~/.agents/skills
info "Registering skills into ~/.agents/skills..."
# Clean stale mixio-* skills from ~/.agents/skills
for existing_mixio in "$AGENTS_SKILLS_DIR"/mixio-*; do
    if [ -e "$existing_mixio" ]; then
        skill_sub="$(basename "$existing_mixio")"
        if [ ! -d "$MIXIO_SKILLS_DIR/$skill_sub" ]; then
            rm -rf "$existing_mixio"
        fi
    fi
done

for skill_dir in "$MIXIO_SKILLS_DIR"/*; do
    if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
        skill_name="$(basename "$skill_dir")"
        target_dir="$AGENTS_SKILLS_DIR/$skill_name"
        rm -rf "$target_dir"
        mkdir -p "$target_dir"
        cp -R "$skill_dir/." "$target_dir/"
    fi
done

SKILL_COUNT=$(find "$AGENTS_SKILLS_DIR" -maxdepth 2 -name "SKILL.md" | grep -c "mixio-" || echo "0")
success "Installed $SKILL_COUNT Mixio skills in $AGENTS_SKILLS_DIR and $MIXIO_SKILLS_DIR"

# Step 6: Register skills to all available AI agents
info "Detecting installed AI agents and registering Mixio skills..."

# Function to link or copy skills to an agent directory
register_agent_skills() {
    local agent_label="$1"
    local agent_skills_dir="$2"
    local agents_doc_path="$3"

    mkdir -p "$agent_skills_dir"
    local count=0

    # Clean obsolete mixio-* skills from agent dir
    for existing in "$agent_skills_dir"/mixio-*; do
        if [ -e "$existing" ] || [ -L "$existing" ]; then
            local existing_name="$(basename "$existing")"
            if [ ! -d "$MIXIO_SKILLS_DIR/$existing_name" ]; then
                rm -rf "$existing"
            fi
        fi
    done

    for skill_path in "$MIXIO_SKILLS_DIR"/mixio-*; do
        if [ -d "$skill_path" ] && [ -f "$skill_path/SKILL.md" ]; then
            local skill_name
            skill_name="$(basename "$skill_path")"
            local agent_target="$AGENTS_SKILLS_DIR/$skill_name"
            local dest="$agent_skills_dir/$skill_name"

            # Create symlink pointing to ~/.agents/skills/<skill> if supported, otherwise copy
            rm -rf "$dest"
            if ln -s "$agent_target" "$dest" 2>/dev/null; then
                ((count++)) || true
            else
                cp -R "$agent_target" "$dest"
                ((count++)) || true
            fi
        fi
    done

    # Place AGENTS.md if target path provided
    if [ -n "$agents_doc_path" ] && [ -f "$MIXIO_DIR/AGENTS.md" ]; then
        mkdir -p "$(dirname "$agents_doc_path")"
        cp "$MIXIO_DIR/AGENTS.md" "$agents_doc_path" 2>/dev/null || true
    fi

    success "Configured $agent_label ($count skills linked)"
}

# Helper function to merge MCP config into JSON file safely using python/node
configure_mcp_json() {
    local config_file="$1"
    local key_val="${2:-}"

    mkdir -p "$(dirname "$config_file")"

    if command -v node &>/dev/null; then
        MIXIO_KEY="$key_val" node -e '
const fs = require("fs");
const file = process.argv[1];
const keyVal = process.env.MIXIO_KEY || "";
let json = {};
try {
    if (fs.existsSync(file)) {
        const content = fs.readFileSync(file, "utf8").trim();
        if (content) json = JSON.parse(content);
    }
} catch (e) { json = {}; }

json.mcpServers = json.mcpServers || {};
const existingServer = json.mcpServers["mixio"] || {};
const existingEnv = existingServer.env || {};
const finalKey = keyVal || existingEnv.MIXIO_API_KEY || process.env.MIXIO_API_KEY || "YOUR_API_KEY_HERE";

json.mcpServers["mixio"] = {
    command: "npx",
    args: ["-y", "@mixio-pro/mcp"],
    env: {
        MIXIO_API_KEY: finalKey,
        MIXIO_BASE_URL: existingEnv.MIXIO_BASE_URL || "https://studio.mixio.pro"
    }
};
fs.writeFileSync(file, JSON.stringify(json, null, 2) + "\n");
' "$config_file" 2>/dev/null || true
    elif command -v python3 &>/dev/null; then
        MIXIO_KEY="$key_val" python3 -c '
import sys, json, os
file = sys.argv[1]
key_val = os.environ.get("MIXIO_KEY", "")
data = {}
try:
    if os.path.exists(file):
        with open(file, "r", encoding="utf-8") as f:
            content = f.read().strip()
            if content:
                data = json.loads(content)
except Exception:
    data = {}

if "mcpServers" not in data or not isinstance(data["mcpServers"], dict):
    data["mcpServers"] = {}

existing_server = data["mcpServers"].get("mixio", {})
existing_env = existing_server.get("env", {}) if isinstance(existing_server, dict) else {}
final_key = key_val or existing_env.get("MIXIO_API_KEY") or os.environ.get("MIXIO_API_KEY", "YOUR_API_KEY_HERE")

data["mcpServers"]["mixio"] = {
    "command": "npx",
    "args": ["-y", "@mixio-pro/mcp"],
    "env": {
        "MIXIO_API_KEY": final_key,
        "MIXIO_BASE_URL": existing_env.get("MIXIO_BASE_URL", "https://studio.mixio.pro")
    }
}
with open(file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
' "$config_file" 2>/dev/null || true
    fi
}

# 1. Claude Code (~/.claude)
register_agent_skills "Claude Code" "$HOME/.claude/skills" "$HOME/.claude/CLAUDE.md"
configure_mcp_json "$HOME/.claude/claude_desktop_config.json" "$API_KEY"
configure_mcp_json "$HOME/.claude/mcp.json" "$API_KEY"

# 2. Codex (~/.codex)
register_agent_skills "Codex" "$HOME/.codex/skills" "$HOME/.codex/AGENTS.md"

# 3. Gemini / Antigravity (~/.gemini)
register_agent_skills "Gemini / Antigravity" "$HOME/.gemini/skills" "$HOME/.gemini/GEMINI.md"
register_agent_skills "Antigravity CLI" "$HOME/.gemini/antigravity-cli/skills" ""
configure_mcp_json "$HOME/.gemini/antigravity-cli/mcp_config.json" "$API_KEY"
configure_mcp_json "$HOME/.gemini/config/mcp_config.json" "$API_KEY"

# 4. Kiro (~/.kiro)
register_agent_skills "Kiro" "$HOME/.kiro/skills" "$HOME/.kiro/steering/mixio.md"
configure_mcp_json "$HOME/.kiro/settings/mcp.json" "$API_KEY"

# 5. Cursor (~/.cursor)
register_agent_skills "Cursor" "$HOME/.cursor/skills" "$HOME/.cursor/AGENTS.md"
configure_mcp_json "$HOME/.cursor/mcp.json" "$API_KEY"

# 6. OpenCode (~/.opencode)
register_agent_skills "OpenCode" "$HOME/.opencode/skills" "$HOME/.opencode/AGENTS.md"

# 7. GitHub Copilot (~/.copilot)
register_agent_skills "GitHub Copilot" "$HOME/.copilot/skills" "$HOME/.copilot/AGENTS.md"

# 8. Generic Agent directory (~/.agent)
register_agent_skills "Generic Agent (.agent)" "$HOME/.agent/skills" "$HOME/.agent/AGENTS.md"

# 9. Hermes Agent (~/.hermes)
if [ -d "$HOME/.hermes" ]; then
    register_agent_skills "Hermes Agent" "$HOME/.hermes/skills/mixio" "$HOME/.hermes/AGENTS.md"
fi

# Also ensure npx skills registers if available
if command -v npx &>/dev/null; then
    info "Syncing with npx skills standard registry..."
    npx skills add mixiopro/skills -g -y 2>/dev/null || true
fi

echo ""
echo "${GREEN}${BOLD}======================================================${RESET}"
echo "${GREEN}${BOLD}  Mixio Skills & Agent Setup Completed Successfully!  ${RESET}"
echo "${GREEN}${BOLD}======================================================${RESET}"
echo ""
echo "Summary of locations:"
echo "  • Mixio Home Directory : $MIXIO_DIR"
echo "  • Global Skills Store  : $MIXIO_SKILLS_DIR"
echo "  • Global Agents Store  : $AGENTS_DIR (AGENTS.md + skills)"
echo "  • Registered Agents    : Claude Code, Codex, Gemini/Antigravity, Kiro, Cursor, Copilot, OpenCode, Hermes"
if [ -n "$API_KEY" ]; then
    echo "  • Mixio API Key        : ${GREEN}Configured in MCP configs & shell profile${RESET}"
else
    echo "  • Mixio API Key        : ${YELLOW}Not set (Get from https://studio.mixio.pro/dashboard/api-keys)${RESET}"
fi
echo ""
echo "To test MCP server in your agent:"
echo "  Ask: ${DIM}\"Use the studio_ping tool to check Mixio Studio MCP connection\"${RESET}"
echo ""
