#!/usr/bin/env bash
# install.sh - Toasty installer for Windows (Git Bash / WSL)
# Usage: curl -fsSL https://raw.githubusercontent.com/shanselman/toasty/main/install.sh | bash
# Or with a specific version: TOASTY_VERSION=v0.6 bash install.sh

set -euo pipefail

REPO="shanselman/toasty"
INSTALL_DIR="${USERPROFILE:-$HOME}/.toasty"
EXE_NAME="toasty.exe"
EXE_PATH="$INSTALL_DIR/$EXE_NAME"
VERSION="${TOASTY_VERSION:-latest}"

# ── colors ───────────────────────────────────────────────────────────────────

reset="\033[0m"; cyan="\033[36m"; green="\033[32m"; red="\033[31m"; gray="\033[90m"
step()  { echo -e "  ${gray}$*${reset}"; }
ok()    { echo -e "  ${green}$*${reset}"; }
fail()  { echo -e "  ${red}$*${reset}"; }

# ── detect architecture ───────────────────────────────────────────────────────

detect_arch() {
    local machine
    machine="$(uname -m 2>/dev/null || echo x86_64)"
    case "$machine" in
        aarch64|arm64) echo "arm64" ;;
        *)             echo "x64"   ;;
    esac
}

ARCH="$(detect_arch)"

echo ""
echo -e "${cyan}Toasty Installer${reset}"
echo "────────────────────────────────────────"
step "Architecture : $ARCH"
step "Install dir  : $INSTALL_DIR"
echo ""

# ── detect runtime ────────────────────────────────────────────────────────────

# Confirm we're running on Windows (Git Bash or WSL) — toasty is Windows-only.
if ! command -v cmd.exe &>/dev/null && [[ "$(uname -s)" != MINGW* ]] && [[ "$(uname -s)" != CYGWIN* ]]; then
    fail "toasty is a Windows application."
    fail "Please run this script in Git Bash, WSL, or use install.ps1 in PowerShell."
    exit 1
fi

# ── require curl ─────────────────────────────────────────────────────────────

if ! command -v curl &>/dev/null; then
    fail "curl is required but not found. Please install curl and try again."
    exit 1
fi

# ── fetch release info ────────────────────────────────────────────────────────

if [[ "$VERSION" == "latest" ]]; then
    RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
else
    RELEASE_URL="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
fi

step "Fetching release info ..."
release_json="$(curl -fsSL -H "User-Agent: toasty-installer" "$RELEASE_URL")"

tag="$(echo "$release_json" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)"
asset_name="toasty-${ARCH}.exe"
download_url="$(echo "$release_json" | grep -o "\"browser_download_url\":\"[^\"]*${asset_name}\"" | head -1 | cut -d'"' -f4)"

if [[ -z "$download_url" ]]; then
    fail "Could not find $asset_name in release $tag."
    exit 1
fi

# ── check for existing install ────────────────────────────────────────────────

if [[ -f "$EXE_PATH" ]]; then
    installed_tag="$("$EXE_PATH" --version 2>/dev/null | grep -o 'v[0-9][^ ]*' | head -1 || true)"
    if [[ "$installed_tag" == "$tag" ]]; then
        ok "toasty $tag is already installed and up to date."
        echo ""
        exit 0
    fi
    if [[ -n "$installed_tag" ]]; then
        step "Upgrading $installed_tag → $tag ..."
    else
        step "Installing $tag ..."
    fi
else
    step "Installing $tag ..."
fi

# ── download ──────────────────────────────────────────────────────────────────

tmp_file="${TMPDIR:-/tmp}/toasty_$$.exe"
trap 'rm -f "$tmp_file"' EXIT

step "Downloading $asset_name ..."
if ! curl -fsSL --progress-bar "$download_url" -o "$tmp_file"; then
    fail "Download failed."
    exit 1
fi

# ── install ───────────────────────────────────────────────────────────────────

mkdir -p "$INSTALL_DIR"
cp "$tmp_file" "$EXE_PATH"
chmod +x "$EXE_PATH"

# ── update PATH (shell profile) ───────────────────────────────────────────────

path_line="export PATH=\"\$PATH:$INSTALL_DIR\""

for profile in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [[ -f "$profile" ]]; then
        if ! grep -qF "$INSTALL_DIR" "$profile" 2>/dev/null; then
            printf '\n# Toasty - toast notification CLI\n%s\n' "$path_line" >> "$profile"
            step "Added $INSTALL_DIR to PATH in $profile"
        fi
        break
    fi
done

# If no profile file exists yet, create ~/.bashrc
if [[ ! -f "$HOME/.bashrc" && ! -f "$HOME/.bash_profile" && ! -f "$HOME/.profile" ]]; then
    printf '# Toasty - toast notification CLI\n%s\n' "$path_line" > "$HOME/.bashrc"
    step "Created $HOME/.bashrc with PATH entry"
fi

# ── update PATH (current session) ────────────────────────────────────────────

export PATH="$PATH:$INSTALL_DIR"

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
ok "toasty $tag installed successfully!"
echo "  Location : $EXE_PATH"
echo ""
echo "Try it (reload your shell or run: source ~/.bashrc):"
echo -e "  ${cyan}toasty \"Hello from toasty!\"${reset}"
echo ""
echo "Install hooks for your AI agent:"
echo -e "  ${cyan}toasty --install${reset}"
echo ""
