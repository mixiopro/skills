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
RAW_BASE_URL="https://raw.githubusercontent.com/mixiopro/skills/main"

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

# Step 2: Create ~/.mixio global directories
info "Setting up global Mixio environment ($MIXIO_DIR)..."
mkdir -p "$MIXIO_DIR"
mkdir -p "$MIXIO_SKILLS_DIR"
mkdir -p "$AGENTS_SKILLS_DIR"

# Step 3: Fetch or update Mixio Skills and AGENTS.md
info "Downloading latest Mixio skills..."
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Check if we are running from within a clone of the skills repository
SCRIPT_PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
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

# Step 4: Populate ~/.agents/skills
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

# Step 5: Register skills to all available AI agents
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
    local server_name="mixio"

    mkdir -p "$(dirname "$config_file")"

    if command -v node &>/dev/null; then
        node -e '
const fs = require("fs");
const file = process.argv[1];
let json = {};
try {
    if (fs.existsSync(file)) {
        const content = fs.readFileSync(file, "utf8").trim();
        if (content) json = JSON.parse(content);
    }
} catch (e) { json = {}; }

json.mcpServers = json.mcpServers || {};
if (!json.mcpServers["mixio"]) {
    json.mcpServers["mixio"] = {
        command: "npx",
        args: ["-y", "@mixio-pro/mcp"],
        env: {
            MIXIO_API_KEY: process.env.MIXIO_API_KEY || "YOUR_API_KEY_HERE",
            MIXIO_BASE_URL: "https://studio.mixio.pro"
        }
    };
    fs.writeFileSync(file, JSON.stringify(json, null, 2) + "\n");
}
' "$config_file" 2>/dev/null || true
    elif command -v python3 &>/dev/null; then
        python3 -c '
import sys, json, os
file = sys.argv[1]
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

if "mixio" not in data["mcpServers"]:
    data["mcpServers"]["mixio"] = {
        "command": "npx",
        "args": ["-y", "@mixio-pro/mcp"],
        "env": {
            "MIXIO_API_KEY": os.environ.get("MIXIO_API_KEY", "YOUR_API_KEY_HERE"),
            "MIXIO_BASE_URL": "https://studio.mixio.pro"
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
configure_mcp_json "$HOME/.claude/claude_desktop_config.json"
configure_mcp_json "$HOME/.claude/mcp.json"

# 2. Codex (~/.codex)
register_agent_skills "Codex" "$HOME/.codex/skills" "$HOME/.codex/AGENTS.md"

# 3. Gemini / Antigravity (~/.gemini)
register_agent_skills "Gemini / Antigravity" "$HOME/.gemini/skills" "$HOME/.gemini/GEMINI.md"
register_agent_skills "Antigravity CLI" "$HOME/.gemini/antigravity-cli/skills" ""
configure_mcp_json "$HOME/.gemini/antigravity-cli/mcp_config.json"
configure_mcp_json "$HOME/.gemini/config/mcp_config.json"

# 4. Kiro (~/.kiro)
register_agent_skills "Kiro" "$HOME/.kiro/skills" "$HOME/.kiro/steering/mixio.md"
configure_mcp_json "$HOME/.kiro/settings/mcp.json"

# 5. Cursor (~/.cursor)
register_agent_skills "Cursor" "$HOME/.cursor/skills" "$HOME/.cursor/AGENTS.md"
configure_mcp_json "$HOME/.cursor/mcp.json"

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
echo ""
echo "Next step: Configure your API Key"
echo "  1. Get your API key from ${BOLD}https://studio.mixio.pro${RESET} → Settings → API Keys"
echo "  2. Set the environment variable in your shell profile (~/.bashrc or ~/.zshrc):"
echo "     ${CYAN}export MIXIO_API_KEY=\"sk-...\"${RESET}"
echo ""
echo "To test MCP server in your agent:"
echo "  Ask: ${DIM}\"Use the studio_ping tool to check Mixio Studio MCP connection\"${RESET}"
echo ""
