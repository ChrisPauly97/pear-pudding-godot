#!/usr/bin/env bash
# install-hooks.sh — Set up dev tooling for Pear Pudding TCG
#
# What this does:
#   1. Installs gdtoolkit (provides gdlint + gdformat) if not already present
#   2. Installs the pre-commit hook that runs gdlint on every staged .gd file
#
# Usage:
#   bash scripts/install-hooks.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
HOOK_FILE="$HOOKS_DIR/pre-commit"

# ── 1. Install gdtoolkit ────────────────────────────────────────────────────
echo "Checking for gdtoolkit..."
if ! command -v gdlint &>/dev/null; then
    echo "  gdlint not found — installing gdtoolkit via pip..."
    if command -v pip3 &>/dev/null; then
        pip3 install --user gdtoolkit
    elif command -v pip &>/dev/null; then
        pip install --user gdtoolkit
    else
        echo "  ERROR: pip / pip3 not found. Install Python 3 and pip, then re-run."
        exit 1
    fi
    echo "  gdtoolkit installed."
else
    echo "  gdlint already available: $(gdlint --version)"
fi

# ── 2. Install pre-commit hook ──────────────────────────────────────────────
echo "Installing pre-commit hook..."
mkdir -p "$HOOKS_DIR"

cat > "$HOOK_FILE" << 'HOOK_SCRIPT'
#!/usr/bin/env bash
# pre-commit hook — lint all staged GDScript files with gdlint
set -euo pipefail

if ! command -v gdlint &>/dev/null; then
    echo "[pre-commit] gdlint not found. Run: bash scripts/install-hooks.sh"
    exit 1
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$' || true)

if [ -z "$STAGED" ]; then
    exit 0
fi

echo "[pre-commit] Running gdlint on staged files..."

FAILED=0
for FILE in $STAGED; do
    if ! gdlint "$FILE" 2>&1; then
        FAILED=1
    fi
done

if [ "$FAILED" -ne 0 ]; then
    echo ""
    echo "[pre-commit] Linting failed. Fix the issues above and re-stage the files."
    echo "             To skip (not recommended): git commit --no-verify"
    exit 1
fi

echo "[pre-commit] All staged .gd files passed gdlint."
HOOK_SCRIPT

chmod +x "$HOOK_FILE"
echo "  Hook installed at $HOOK_FILE"

echo ""
echo "Done! The pre-commit hook will now lint all staged .gd files before each commit."
echo ""
echo "To run tests manually:"
echo "  godot --headless --path . -s tests/runner.gd"
