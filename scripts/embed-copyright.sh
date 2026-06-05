#!/usr/bin/env bash
#
# embed-copyright.sh
#
# Schreibt Urheber-/Copyright-Metadaten (EXIF, IPTC, XMP) in ALLE Bilder im
# Repository. Idempotent und beliebig wiederholbar — bei neuen Bildern einfach
# erneut ausführen; bestehende Felder werden überschrieben/aktualisiert.
#
#   Aufruf:  ./scripts/embed-copyright.sh            # alle Bilder im Repo
#            ./scripts/embed-copyright.sh -n         # Probelauf (nur anzeigen)
#            ./scripts/embed-copyright.sh pfad/...    # nur bestimmte Dateien/Ordner
#
# Voraussetzung: exiftool
#   Arch/CachyOS:  sudo pacman -S perl-image-exiftool
#   Debian/Ubuntu: sudo apt install libimage-exiftool-perl
#   macOS:         brew install exiftool

set -euo pipefail

# ----------------------------------------------------------------------------
# Konfiguration — bei Bedarf anpassen.
# ----------------------------------------------------------------------------
ARTIST="bzs42"
YEAR="$(date +%Y)"
COPYRIGHT="© ${YEAR} ${ARTIST}. Alle Rechte vorbehalten. / All rights reserved."
USAGE_TERMS="Nutzung, Vervielfältigung und Veröffentlichung nur mit ausdrücklicher vorheriger Genehmigung des Urhebers."
WEB_STATEMENT="https://bzs42.github.io/impressum.html"
CONTACT="ekleheb@gmail.com"

# Welche Endungen als Bild gelten (case-insensitive).
EXTENSIONS=(jpg jpeg png webp)

# ----------------------------------------------------------------------------
# Ab hier keine Anpassung nötig.
# ----------------------------------------------------------------------------
DRY_RUN=0
if [[ "${1:-}" == "-n" || "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if ! command -v exiftool >/dev/null 2>&1; then
    echo "Fehler: 'exiftool' ist nicht installiert." >&2
    echo "  Arch/CachyOS:  sudo pacman -S perl-image-exiftool" >&2
    echo "  Debian/Ubuntu: sudo apt install libimage-exiftool-perl" >&2
    echo "  macOS:         brew install exiftool" >&2
    exit 1
fi

# Repo-Wurzel ermitteln (relativ zum Skript-Ort, unabhängig vom Arbeitsverzeichnis).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Suchpfade: übergebene Argumente, sonst die ganze Repo-Wurzel.
SEARCH_PATHS=("$@")
if [[ ${#SEARCH_PATHS[@]} -eq 0 ]]; then
    SEARCH_PATHS=("$REPO_ROOT")
fi

# find-Ausdruck für die Endungen zusammenbauen: -iname '*.jpg' -o -iname ...
name_expr=()
for ext in "${EXTENSIONS[@]}"; do
    name_expr+=(-iname "*.${ext}" -o)
done
unset 'name_expr[${#name_expr[@]}-1]'  # letztes '-o' entfernen

# Alle Bilder sammeln (.git ausgenommen), NUL-getrennt für sichere Pfade.
mapfile -d '' -t FILES < <(
    find "${SEARCH_PATHS[@]}" \
        -type d -name .git -prune -o \
        -type f \( "${name_expr[@]}" \) -print0
)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Keine Bilder gefunden."
    exit 0
fi

echo "Gefundene Bilder: ${#FILES[@]}"
if [[ $DRY_RUN -eq 1 ]]; then
    printf '%s\n' "${FILES[@]}"
    echo "(Probelauf — es wurde nichts verändert.)"
    exit 0
fi

# Metadaten schreiben. -overwrite_original: keine *_original-Sicherungen
# (Git ist die Sicherung). Wir schreiben EXIF, IPTC und XMP parallel, damit
# möglichst viele Programme die Angaben lesen.
exiftool \
    -overwrite_original \
    -codedcharacterset=utf8 \
    -EXIF:Artist="$ARTIST" \
    -EXIF:Copyright="$COPYRIGHT" \
    -IPTC:By-line="$ARTIST" \
    -IPTC:CopyrightNotice="$COPYRIGHT" \
    -IPTC:Contact="$CONTACT" \
    -XMP-dc:Creator="$ARTIST" \
    -XMP-dc:Rights="$COPYRIGHT" \
    -XMP-xmpRights:Marked=True \
    -XMP-xmpRights:UsageTerms="$USAGE_TERMS" \
    -XMP-xmpRights:WebStatement="$WEB_STATEMENT" \
    -XMP-photoshop:Credit="$ARTIST" \
    "${FILES[@]}"

echo "Fertig. Copyright-Metadaten in ${#FILES[@]} Bild(ern) aktualisiert."
