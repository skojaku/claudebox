#!/usr/bin/env bash
# ==============================================================================
#  ClaudeBox installer
#
#  Downloads and installs ClaudeBox from skojaku/claudebox on GitHub.
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/skojaku/claudebox/main/install.sh | bash
#
#  Environment variables:
#    CLAUDEBOX_BRANCH  Branch or tag to install (default: main)
# ==============================================================================

set -e

REPO="skojaku/claudebox"
BRANCH="${CLAUDEBOX_BRANCH:-main}"
INSTALL_DIR="$HOME/.claudebox"
SOURCE_DIR="$INSTALL_DIR/source"
TMP_ARCHIVE="$INSTALL_DIR/install-archive.tar.gz"

# ------------------------------------------------------------------ helpers --

# Terminal colors (fall back gracefully if not supported)
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
    GREEN="\033[0;32m"
    CYAN="\033[0;36m"
    YELLOW="\033[1;33m"
    RED="\033[0;31m"
    NC="\033[0m"
else
    GREEN="" CYAN="" YELLOW="" RED="" NC=""
fi

info()  { printf "${CYAN}==>${NC} %s\n"    "$*"; }
ok()    { printf "${GREEN}✓${NC}  %s\n"   "$*"; }
warn()  { printf "${YELLOW}!${NC}  %s\n"  "$*"; }
die()   { printf "${RED}✗${NC}  %s\n" "$*" >&2; exit 1; }

# ---------------------------------------------------------- check prerequisites --

check_prereqs() {
    local missing=()

    command -v bash >/dev/null 2>&1   || missing+=("bash")
    command -v docker >/dev/null 2>&1 || warn "Docker not found — ClaudeBox will attempt to install it on first run."

    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        missing+=("curl or wget")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        die "Missing required tools: ${missing[*]}"
    fi
}

download() {
    local url="$1"
    local dest="$2"
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -fsSL "$url" -o "$dest"
    else
        wget -qO "$dest" "$url"
    fi
}

# --------------------------------------------------------------- install logic --

do_install() {
    local tarball_url="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
    local is_update=false

    [ -f "$INSTALL_DIR/.installed" ] && is_update=true

    if $is_update; then
        info "Updating ClaudeBox (branch: ${BRANCH})..."
    else
        info "Installing ClaudeBox (branch: ${BRANCH})..."
    fi

    # Create install directory
    mkdir -p "$SOURCE_DIR"

    # Download source tarball
    info "Downloading source from GitHub..."
    download "$tarball_url" "$TMP_ARCHIVE" \
        || die "Failed to download from ${tarball_url}\nCheck your internet connection and that the branch '${BRANCH}' exists."

    # Extract (strip top-level directory from the GitHub tarball)
    info "Extracting..."
    tar -xz -f "$TMP_ARCHIVE" -C "$SOURCE_DIR" --strip-components=1 \
        || die "Failed to extract archive."

    rm -f "$TMP_ARCHIVE"

    # Make main script executable
    chmod +x "$SOURCE_DIR/main.sh"

    # Run main.sh in installer mode — this updates the ~/.local/bin symlink
    # and prints the first-run welcome or update confirmation
    CLAUDEBOX_INSTALLER_RUN="true" bash "$SOURCE_DIR/main.sh"
}

# -------------------------------------------------------------------- main --

main() {
    check_prereqs
    do_install

    # Remind the user to add ~/.local/bin to PATH if needed
    local bin_dir="$HOME/.local/bin"
    case ":${PATH}:" in
        *":${bin_dir}:"*) ;;   # already on PATH
        *)
            printf "\n"
            warn "${bin_dir} is not on your PATH."
            warn "Add the following to your ~/.bashrc or ~/.zshrc and restart your shell:"
            printf "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}\n\n"
            ;;
    esac
}

main "$@"
