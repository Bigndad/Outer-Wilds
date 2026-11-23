#!/usr/bin/env bash
# Moves backups / history / unused files into _archive/ (same relative paths, so restoring = move back).
# Run from the config folder:  cd ~/.config/quickshell/outerwilds && bash tidy.sh
set -e
cd "$(dirname "$0")"
A=_archive
mv_keep() {  # mv_keep path : move into _archive keeping the path (git mv when tracked)
    [ -e "$1" ] || return 0
    mkdir -p "$A/$(dirname "$1")"
    if git ls-files --error-unmatch "$1" >/dev/null 2>&1 || [ -n "$(git ls-files "$1" 2>/dev/null)" ]; then
        git mv "$1" "$A/$1"
    else
        mv "$1" "$A/$1"
    fi
    echo "moved $1"
}
# 1. backups: *.bak, *.bak2, *.bak-*, *.pre-*, and the hypr-compat backup dir
while IFS= read -r f; do mv_keep "$f"; done < <(find . -path ./.git -prune -o -path "./$A" -prune -o -type f \( -name '*.bak' -o -name '*.bak[0-9]' -o -name '*.bak-*' -o -name '*.pre-*' \) -print | sed 's|^\./||' | sort)
mv_keep .hypr-compat-backup-20261113-190927
# 2. history of applied patches
for f in ow_docs.patch ow_system.patch ow_widget_system.patch ow_widgets.patch remove-roles.patch; do mv_keep "$f"; done
# 3. root duplicates nothing loads (qmldir uses data/NoctaliaBridge.qml and launcher/AppLauncher.qml)
mv_keep NoctaliaBridge.qml
mv_keep applauncher.qml
# 4. unreferenced shader / faces (no qml, qmldir or script mentions them)
mv_keep shaders/sandcolumn.frag
mv_keep shaders/sandcolumn.frag.qsb
mv_keep shaders/vignette.frag.qsb
for f in ClockFaceAnalog ClockFaceMaterialAnalog DiskFaceCircle RamFaceCircle; do mv_keep "widgets/serp/faces/$f.qml"; done
echo "done. Run: qs -c outerwilds  (if anything is missing, move it back out of $A/)"
