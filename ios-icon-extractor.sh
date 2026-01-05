#!/bin/sh
# ios-icon-extractor.sh
# Version: v2.0.0 (Unified)
# Source: Local Device (via plutil)
# Compatibility: iOS 15+ (Rootless/Rootful)

set -eu

# --- DEFAULTS ---
HOME_DIR="$HOME"
DEFAULT_OUT="./artifacts"
DEFAULT_META="./_meta"

# --- LOAD CONFIG ---
if [ -f "dumper.conf" ]; then
    . ./dumper.conf
fi

OUT_BASE="${OUTPUT_ROOT:-$DEFAULT_OUT}"
META_DIR="${META_DIR:-$DEFAULT_META}"

# MERGED LOGIC: Subfolder for extraction results
OUT_DIR="$OUT_BASE/extracted"

# --- PATHS ---
SYSTEM_DIR="$OUT_DIR/system"
APPSTORE_DIR="$OUT_DIR/appstore"
MANIFEST_DIR="$META_DIR/manifests"
APP_NAMES_TSV="$META_DIR/app-names.tsv"
SKIPPED_TSV="$META_DIR/skipped.tsv"

# Search paths (Rootless + User + System)
SEARCH_PATHS="/Applications /var/jb/Applications /var/containers/Bundle/Application"

CMD="${1:-run}"
DRY_RUN="${DRY_RUN:-0}"

# --- HELPERS ---
ensure_dir() { [ "$DRY_RUN" = "0" ] && mkdir -p "$1"; }
read_plist() { [ -f "$1" ] && (plutil -convert xml1 -o - "$1" 2>/dev/null || cat "$1"); }

# --- COMMANDS ---

do_doctor() {
    echo "--- Extractor Doctor ---"
    echo "Role: Local Extractor"
    echo "Output: $OUT_DIR"
    echo "Meta:   $META_DIR"
    
    echo -n "Checking Tools (plutil)... "
    command -v plutil >/dev/null && echo "OK" || echo "FAIL (Install file-cmds)"
    
    echo -n "Checking Search Paths... "
    FOUND=0
    for p in $SEARCH_PATHS; do
        if [ -d "$p" ]; then FOUND=1; fi
    done
    [ "$FOUND" = "1" ] && echo "OK" || echo "FAIL (Are you on iOS?)"
}

do_discover() {
    ensure_dir "$MANIFEST_DIR"
    TS="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
    MANIFEST="$MANIFEST_DIR/manifest_$TS.txt"
    
    echo "[*] Discovering apps..."
    : > "$MANIFEST"

    # shellcheck disable=SC2086
    find $SEARCH_PATHS -maxdepth 2 -name "*.app" 2>/dev/null | while read -r app; do
        INFO="$app/Info.plist"
        [ -f "$INFO" ] || continue
        
        BID=$(read_plist "$INFO" | grep -a -m1 -A1 CFBundleIdentifier | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        case "$BID" in *[!A-Za-z0-9._-]*|"") continue ;; esac
        echo "$BID" >> "$MANIFEST"
    done
    
    COUNT=$(wc -l < "$MANIFEST")
    echo "[*] Found $COUNT apps."
    
    # AUTO-SYNC: Update the master list for the downloader
    cp "$MANIFEST" "$META_DIR/id_list.txt"
    echo "[+] Updated master list: $META_DIR/id_list.txt"
}

do_extract() {
    ensure_dir "$OUT_DIR" "$SYSTEM_DIR" "$APPSTORE_DIR" "$META_DIR"
    
    # Get latest manifest
    MANIFEST=$(ls -t "$MANIFEST_DIR"/manifest_*.txt 2>/dev/null | head -1 || true)
    [ -z "$MANIFEST" ] && echo "[!] No manifest found. Run 'discover' first." && exit 1
    
    echo "[*] Extracting icons from manifest..."
    while read -r BID; do
        case "$BID" in com.apple.*) BASE="$SYSTEM_DIR";; *) BASE="$APPSTORE_DIR";; esac
        
        # Locate App
        # shellcheck disable=SC2086
        APP_PATH=$(find $SEARCH_PATHS -maxdepth 2 -name "*.app" 2>/dev/null | while read -r C; do
            [ -f "$C/Info.plist" ] || continue
            CID=$(read_plist "$C/Info.plist" | grep -a -m1 -A1 CFBundleIdentifier | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
            [ "$CID" = "$BID" ] && echo "$C" && break
        done)
        
        if [ -z "$APP_PATH" ]; then
            echo "$BID	not_found" >> "$SKIPPED_TSV"
            continue
        fi
        
        DEST="$BASE/$BID"
        ensure_dir "$DEST"
        
        # Copy highest res icon
        echo " -> $BID"
        find "$APP_PATH" -type f -name "*.png" -exec cp {} "$DEST" \; 2>/dev/null
        
        # Identify main glyph
        GLYPH=$(find "$DEST" -name "AppIcon60x60@2x.png" -o -name "AppIcon*@3x.png" | head -1)
        [ -z "$GLYPH" ] && GLYPH=$(ls -S "$DEST"/*.png 2>/dev/null | head -1)
        [ -n "$GLYPH" ] && cp "$GLYPH" "$DEST/glyph-source.png"
        
    done < "$MANIFEST"
    echo "[v] Done."
}

# --- MAIN ---
case "$CMD" in
    run)        do_extract ;;
    discover)   do_discover ;;
    doctor)     do_doctor ;;
    *)          echo "Usage: $0 {run|discover|doctor}" ;;
esac
