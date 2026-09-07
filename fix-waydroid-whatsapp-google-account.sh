#!/usr/bin/env bash

# ============================================================
#  Waydroid WhatsApp Google Account Visibility Fix
# ============================================================
#
# Fixes:
#   WhatsApp -> "Choose an account" -> only "Add account"
#
# even though a Google account is already configured in
# Waydroid.
#
# The actual fix:
#   Adds com.whatsapp = 1 (VISIBLE) to Android's account
#   visibility database for the detected Google account.
#
# ============================================================

set -Eeuo pipefail

WHATSAPP_PACKAGE="com.whatsapp"
ACCOUNT_TYPE="com.google"
DB="/data/system_de/0/accounts_de.db"

# ------------------------------------------------------------
# Pretty output
# ------------------------------------------------------------

BOLD="\033[1m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

info() {
    echo -e "${CYAN}➜${RESET} $*"
}

success() {
    echo -e "${GREEN}✔${RESET} $*"
}

warn() {
    echo -e "${YELLOW}⚠${RESET} $*"
}

error() {
    echo -e "${RED}✘${RESET} $*" >&2
}

die() {
    error "$*"
    exit 1
}

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

clear 2>/dev/null || true

echo
echo -e "${BOLD}============================================================${RESET}"
echo -e "${BOLD}   Waydroid WhatsApp Google Account Visibility Fix${RESET}"
echo -e "${BOLD}============================================================${RESET}"
echo
echo "Fixes the problem where WhatsApp cannot see an existing"
echo "Google account and only offers:"
echo
echo -e "    ${YELLOW}\"Add account\"${RESET}"
echo

# ------------------------------------------------------------
# Get root
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    info "Administrator access is required."
    exec sudo "$0" "$@"
fi

# ------------------------------------------------------------
# Check Waydroid
# ------------------------------------------------------------

command -v waydroid >/dev/null 2>&1 \
    || die "Waydroid is not installed or could not be found."

command -v systemctl >/dev/null 2>&1 \
    || die "systemctl could not be found."

info "Checking Waydroid container..."

if ! systemctl is-active --quiet waydroid-container; then
    warn "Waydroid container is not running."
    info "Starting Waydroid container..."

    systemctl start waydroid-container
    sleep 3
fi

success "Waydroid container is running."

# ------------------------------------------------------------
# Check account database
# ------------------------------------------------------------

echo
info "Looking for Android account database..."

if ! waydroid shell -- test -f "$DB"; then
    die "Android account database was not found:

    $DB

Your Waydroid installation may use a different location."
fi

success "Account database found:"
echo "    $DB"

# ------------------------------------------------------------
# Check SQLite
# ------------------------------------------------------------

echo
info "Checking SQLite..."

if ! waydroid shell -- command -v sqlite3 >/dev/null 2>&1; then
    die "sqlite3 is not available inside Waydroid."
fi

success "SQLite is available."

# ------------------------------------------------------------
# Detect Google account(s)
# ------------------------------------------------------------

echo
info "Searching for Google accounts..."

ACCOUNT_OUTPUT="$(
    waydroid shell -- sqlite3 "$DB" \
        "SELECT _id || '|' || name
         FROM accounts
         WHERE type='$ACCOUNT_TYPE';"
)"

if [[ -z "$ACCOUNT_OUTPUT" ]]; then
    die "No Google account was found inside Waydroid.

Add your Google account first:

    Android Settings
        -> Accounts
        -> Add account
        -> Google"
fi

ACCOUNT_COUNT="$(printf '%s\n' "$ACCOUNT_OUTPUT" | grep -c .)"

echo

if [[ "$ACCOUNT_COUNT" -eq 1 ]]; then

    ACCOUNT_ID="${ACCOUNT_OUTPUT%%|*}"
    ACCOUNT_EMAIL="${ACCOUNT_OUTPUT#*|}"

    success "Google account detected:"
    echo
    echo -e "    Account: ${BOLD}${ACCOUNT_EMAIL}${RESET}"
    echo -e "    ID:      ${BOLD}${ACCOUNT_ID}${RESET}"

else

    warn "Multiple Google accounts detected:"
    echo

    declare -a IDS=()
    declare -a EMAILS=()

    INDEX=1

    while IFS='|' read -r ID EMAIL; do
        IDS+=("$ID")
        EMAILS+=("$EMAIL")

        echo "    [$INDEX] $EMAIL"

        ((INDEX++))
    done <<< "$ACCOUNT_OUTPUT"

    echo

    while true; do

        read -rp "Choose Google account [1-${#IDS[@]}]: " CHOICE

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] &&
           (( CHOICE >= 1 && CHOICE <= ${#IDS[@]} )); then

            ACCOUNT_ID="${IDS[$((CHOICE - 1))]}"
            ACCOUNT_EMAIL="${EMAILS[$((CHOICE - 1))]}"
            break
        fi

        warn "Invalid selection."
    done
fi

# ------------------------------------------------------------
# Check WhatsApp
# ------------------------------------------------------------

echo
info "Checking WhatsApp..."

if ! waydroid shell -- pm path "$WHATSAPP_PACKAGE" >/dev/null 2>&1; then
    die "WhatsApp is not installed inside Waydroid.

Expected package:

    $WHATSAPP_PACKAGE"
fi

success "WhatsApp is installed."

# ------------------------------------------------------------
# Check current visibility
# ------------------------------------------------------------

echo
info "Checking current account visibility..."

CURRENT="$(
    waydroid shell -- sqlite3 "$DB" \
        "SELECT value
         FROM visibility
         WHERE accounts_id=$ACCOUNT_ID
         AND _package='$WHATSAPP_PACKAGE';"
)"

if [[ "$CURRENT" == "1" ]]; then

    success "WhatsApp already has visibility value 1."

    echo
    read -rp "Apply the fix again anyway? [y/N]: " ANSWER

    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
        echo
        success "No changes were necessary."
        exit 0
    fi

elif [[ -n "$CURRENT" ]]; then

    warn "WhatsApp currently has visibility value: $CURRENT"

else

    warn "WhatsApp has NO explicit Google account visibility entry."

fi

# ------------------------------------------------------------
# Backup database
# ------------------------------------------------------------

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP="${DB}.backup-whatsapp-${TIMESTAMP}"

echo
info "Creating safety backup..."

waydroid shell -- cp -p "$DB" "$BACKUP" \
    || die "Could not create database backup."

success "Backup created:"
echo
echo "    $BACKUP"

# ------------------------------------------------------------
# APPLY THE FIX
#
# THIS IS THE IMPORTANT PART.
# This is the same database change that fixed the problem.
# ------------------------------------------------------------

echo
info "Making Google account visible to WhatsApp..."

waydroid shell -- sqlite3 "$DB" "
BEGIN IMMEDIATE;

INSERT OR REPLACE INTO visibility
(
    accounts_id,
    _package,
    value
)
VALUES
(
    $ACCOUNT_ID,
    '$WHATSAPP_PACKAGE',
    1
);

COMMIT;
" || die "Failed to update account visibility."

success "Account visibility database updated."

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
info "Verifying the change..."

VERIFY="$(
    waydroid shell -- sqlite3 "$DB" \
        "SELECT accounts_id || '|' || _package || '|' || value
         FROM visibility
         WHERE accounts_id=$ACCOUNT_ID
         AND _package='$WHATSAPP_PACKAGE';"
)"

EXPECTED="${ACCOUNT_ID}|${WHATSAPP_PACKAGE}|1"

if [[ "$VERIFY" != "$EXPECTED" ]]; then

    echo
    error "VERIFICATION FAILED!"
    echo
    echo "Expected:"
    echo "    $EXPECTED"
    echo
    echo "Received:"
    echo "    $VERIFY"
    echo
    echo "Your original database backup is:"
    echo "    $BACKUP"
    echo

    exit 1
fi

success "Verification successful!"

# ------------------------------------------------------------
# Show resulting visibility table
# ------------------------------------------------------------

echo
echo -e "${BOLD}Google account visibility entries:${RESET}"
echo

waydroid shell -- sqlite3 "$DB" "
SELECT
    _package || ' = ' || value
FROM visibility
WHERE accounts_id=$ACCOUNT_ID
ORDER BY _package;
"

echo

# ------------------------------------------------------------
# Restart Waydroid
# ------------------------------------------------------------

info "Restarting Waydroid..."

# Determine the normal desktop user before restarting.
NORMAL_USER="${SUDO_USER:-}"

if [[ -n "$NORMAL_USER" ]]; then
    sudo -u "$NORMAL_USER" waydroid session stop >/dev/null 2>&1 || true
else
    waydroid session stop >/dev/null 2>&1 || true
fi

systemctl restart waydroid-container

sleep 3

success "Waydroid container restarted."

# ------------------------------------------------------------
# Finished
# ------------------------------------------------------------

echo
echo -e "${GREEN}${BOLD}============================================================${RESET}"
echo -e "${GREEN}${BOLD}                 FIX COMPLETED SUCCESSFULLY${RESET}"
echo -e "${GREEN}${BOLD}============================================================${RESET}"
echo
echo -e "Google account : ${BOLD}${ACCOUNT_EMAIL}${RESET}"
echo -e "Account ID     : ${BOLD}${ACCOUNT_ID}${RESET}"
echo -e "WhatsApp       : ${BOLD}${WHATSAPP_PACKAGE}${RESET}"
echo -e "Visibility     : ${GREEN}${BOLD}1 (VISIBLE)${RESET}"
echo
echo "Database backup:"
echo
echo "    $BACKUP"
echo
echo -e "${CYAN}${BOLD}Next step:${RESET}"
echo
echo "Start Waydroid normally:"
echo
echo "    waydroid session start"
echo
echo "Then open WhatsApp and go to the Google backup restore."
echo
echo "Your existing Google account should now appear in:"
echo
echo -e "    ${BOLD}Choose an account${RESET}"
echo
