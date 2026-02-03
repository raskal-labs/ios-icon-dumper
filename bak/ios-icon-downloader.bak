#!/bin/sh
# ios-icon-downloader.sh
# Version: v2.0.0 (Unified)
# Source: Apple App Store API
# Compatibility: Linux, macOS, iOS

set -u

VERSION="v2.0.0"

# --- DEFAULTS ---
# If dumper.conf is missing, use these relative paths:
OUTPUT_ROOT="./artifacts"
META_DIR="./_meta"
ID_LIST_FILE="${META_DIR}/id_list.txt"

# --- LOAD CONFIG ---
if [ -f "dumper.conf" ]; then
    . ./dumper.conf
fi

# MERGED LOGIC: Always create a subfolder for this specific tool's output
OUT_DIR="$OUTPUT_ROOT/downloaded"

# --- FUNCTIONS ---

check_dependencies() {
    for cmd in curl grep cut tr; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "[!] Error: Missing required command: $cmd"
            exit 1
        fi
    done
}

run_init() {
    if [ ! -f "$ID_LIST_FILE" ]; then
        echo "[*] Initializing environment..."
        mkdir -p "$META_DIR"
        mkdir -p "$OUT_DIR"
        
        echo "# Add Bundle IDs here (one per line)" > "$ID_LIST_FILE"
        echo "com.spotify.client" >> "$ID_LIST_FILE"
        
        echo "[+] Created structure."
        echo "[+] Created list at: $ID_LIST_FILE"
        echo "[!] ACTION REQUIRED: Edit the list, then run 'run'."
    else
        echo "[i] Environment already initialized."
    fi
}

run_doctor() {
    echo "--- Downloader Doctor ---"
    echo "OS: $(uname -s)"
    echo "Config: $([ -f "dumper.conf" ] && echo "Loaded" || echo "Default")"
    echo "Output: $OUT_DIR"
    echo "Input:  $ID_LIST_FILE"
    
    echo -n "Checking API... "
    curl -s -m 5 --head "https://itunes.apple.com" >/dev/null && echo "OK" || echo "FAIL"
    
    echo -n "Checking Write Access... "
    mkdir -p "$OUT_DIR" && touch "$OUT_DIR/.test" && rm "$OUT_DIR/.test" && echo "OK" || echo "FAIL"
}

run_downloader() {
    check_dependencies
    [ ! -f "$ID_LIST_FILE" ] && run_init && exit 0

    mkdir -p "$OUT_DIR"
    echo "[i] Reading: $ID_LIST_FILE"
    echo "[i] Saving to: $OUT_DIR"
    echo "-----------------------------------------------------"

    COUNT=0
    while read -r BUNDLE_ID; do
        [ -z "$BUNDLE_ID" ] && continue
        case "$BUNDLE_ID" in \#*) continue ;; esac
        
        CLEAN_ID=$(echo "$BUNDLE_ID" | tr -d '\r')
        echo -n " -> $CLEAN_ID... "

        JSON=$(curl -s -m 5 "https://itunes.apple.com/lookup?bundleId=$CLEAN_ID&country=US")
        ICON_URL=$(echo "$JSON" | grep -o '"artworkUrl512":"[^"]*"' | cut -d'"' -f4)

        if [ -n "$ICON_URL" ]; then
            curl -s -m 10 "$ICON_URL" -o "$OUT_DIR/$CLEAN_ID.png"
            echo "OK"
            COUNT=$((COUNT+1))
        else
            echo "FAILED (Not in US Store)"
        fi
    done < "$ID_LIST_FILE"
    
    echo "-----------------------------------------------------"
    echo "[v] Done. $COUNT icons saved."
}

# --- MAIN ---
CMD="${1:-run}"
case "$CMD" in
    run)    run_downloader ;;
    init)   run_init ;;
    doctor) run_doctor ;;
    *)      echo "Usage: $0 {run|init|doctor}" ;;
esac
