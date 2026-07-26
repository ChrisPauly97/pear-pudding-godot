#!/usr/bin/env bash
# setup-dev-env.sh — Make a fresh checkout able to run the test suite.
#
# Idempotent. Safe to run repeatedly; it no-ops once both steps are satisfied.
#
#   1. Installs the pinned headless Godot build if `godot` is not on PATH.
#   2. Imports the project if `.godot/` is absent.
#
# Why step 2 matters: the repo does not commit `.godot/`, and Godot cannot
# `preload()` a .png/.tres that has never been imported. On an un-imported
# checkout roughly 30 tests fail with parse errors that look like real bugs
# but are pure environment artifacts.
#
# Usage:
#   bash scripts/setup-dev-env.sh
#
# Wired as a SessionStart hook in .claude/settings.json.
set -uo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.6-stable}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="${GODOT_INSTALL_DIR:-/usr/local/bin}"

log() { echo "[setup-dev-env] $*"; }

# ── 1. Godot binary ─────────────────────────────────────────────────────────
if command -v godot &>/dev/null; then
    log "godot already on PATH: $(godot --version 2>/dev/null | head -1)"
else
    log "godot not found — downloading ${GODOT_VERSION}..."
    ZIP_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
    URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${ZIP_NAME}.zip"

    if ! wget -q "$URL" -O /tmp/godot.zip; then
        log "WARNING: download failed (offline?). Skipping Godot install."
        exit 0
    fi

    unzip -oq /tmp/godot.zip -d /tmp/godot-extract
    if [ ! -w "$INSTALL_DIR" ]; then
        INSTALL_DIR="$HOME/.local/bin"
        mkdir -p "$INSTALL_DIR"
        log "no write access to /usr/local/bin — installing to $INSTALL_DIR"
        log "add it to PATH if it is not already there"
    fi
    cp "/tmp/godot-extract/${ZIP_NAME}" "${INSTALL_DIR}/godot"
    chmod +x "${INSTALL_DIR}/godot"
    export PATH="${INSTALL_DIR}:${PATH}"
    log "installed godot to ${INSTALL_DIR}/godot"
fi

# ── 2. Project import ───────────────────────────────────────────────────────
if [ -d "${REPO_ROOT}/.godot/imported" ]; then
    log ".godot/ present — import already done."
    exit 0
fi

if ! command -v godot &>/dev/null; then
    log "WARNING: godot still unavailable — cannot import. Tests will fail."
    exit 0
fi

log "importing project (first run takes a couple of minutes)..."
godot --headless --path "$REPO_ROOT" --editor --quit >/tmp/godot-import.log 2>&1

ERRORS=$(grep -iE "Parse Error|Compile Error|Failed to load script" /tmp/godot-import.log \
    | grep -viE "imported/|Make sure resources" || true)

if [ -n "$ERRORS" ]; then
    log "import finished WITH parse/compile errors:"
    echo "$ERRORS"
else
    log "import clean."
fi

log "ready — run tests with: godot --headless --path . -s tests/runner.gd"
