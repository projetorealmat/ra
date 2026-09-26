#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if ! printenv PRETEXT_DIR >/dev/null 2>&1; then
  echo "Defina PRETEXT_DIR para o checkout do PreTeXt." >&2
  exit 2
fi
PRETEXT_DIR="$(printenv PRETEXT_DIR)"
if [[ ! -f "$PRETEXT_DIR/xsl/pretext-html.xsl" || ! -d "$PRETEXT_DIR/js" || ! -d "$PRETEXT_DIR/css" ]]; then
  echo "PRETEXT_DIR não contém os assets esperados do PreTeXt." >&2
  exit 2
fi

for command_name in perl xsltproc pdftocairo python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Dependência ausente: $command_name" >&2
    exit 2
  fi
done

BUILD_TMP="$(mktemp -d)"
trap 'rm -rf "$BUILD_TMP"' EXIT

cd "$ROOT_DIR"
if ! perl "$ROOT_DIR/convert-to-mbx.pl" realanal.tex >"$BUILD_TMP/converter.log" 2>&1; then
  tail -n 80 "$BUILD_TMP/converter.log" >&2
  exit 1
fi
tail -n 20 "$BUILD_TMP/converter.log"
test -s "$ROOT_DIR/realanal-out.xml"
grep -q '<pretext xml:lang="pt-BR">' "$ROOT_DIR/realanal-out.xml"
grep -q '<chapter[^>]*number="7"' "$ROOT_DIR/realanal-out.xml"
if grep -Eq '<chapter[^>]*number="8"' "$ROOT_DIR/realanal-out.xml"; then
  echo "A conversão incluiu capítulos do Volume II." >&2
  exit 1
fi
perl -0777 -i -pe 's:<rahr/>[ \r\n]*<rahr/>:<rahr/>:igs' "$ROOT_DIR/realanal-out.xml"

python3 - "$PRETEXT_DIR/xsl/pretext-html.xsl" "$ROOT_DIR/realanal-html.xsl" "$BUILD_TMP/realanal-html.xsl" <<'PY'
from pathlib import Path
import sys

pretext_html, custom_xsl, output_xsl = map(Path, sys.argv[1:])
source = custom_xsl.read_text(encoding="utf-8")
old_import = 'href="../../pretext/xsl/pretext-html.xsl"'
new_import = f'href="{pretext_html.resolve().as_uri()}"'
if source.count(old_import) != 1:
    raise SystemExit("A importação do XSL PreTeXt não corresponde ao esperado.")
output_xsl.write_text(source.replace(old_import, new_import), encoding="utf-8")
PY

rm -rf "$ROOT_DIR/html" "$ROOT_DIR/_site"
mkdir -p "$ROOT_DIR/html"
cp -a "$ROOT_DIR/figures" "$ROOT_DIR/html/figures"
find "$ROOT_DIR/html/figures" -type f \
  \( -name '.gitignore' -o -name '*.sh' -o -name 'figurerun*' -o -name '*.fig' -o -name '*.xp' -o -name '*.pdf' -o -name '*.pdf_t' \) \
  -delete
cp "$ROOT_DIR/extra.css" "$ROOT_DIR/html/extra.css"
cp "$ROOT_DIR/logo.png" "$ROOT_DIR/html/logo.png"

mkdir -p "$ROOT_DIR/html/_static/pretext"
cp -a "$PRETEXT_DIR/js" "$PRETEXT_DIR/css" "$ROOT_DIR/html/_static/pretext/"
sed 's/23241f/121212/' \
  "$PRETEXT_DIR/css/dist/theme-default-modern.css" \
  > "$ROOT_DIR/html/_static/pretext/css/theme.css"

PUBLISHER_URI="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$ROOT_DIR/realanal-publisher.xml")"
(
  cd "$ROOT_DIR/html"
  xsltproc --nonet \
    --stringparam publisher "$PUBLISHER_URI" \
    "$BUILD_TMP/realanal-html.xsl" \
    "$ROOT_DIR/realanal-out.xml"

  while IFS= read -r -d '' page; do
    perl "$ROOT_DIR/fixup-html-file.pl" < "$page" > "$page.tmp"
    mv "$page.tmp" "$page"
  done < <(find . -maxdepth 1 -type f -name '*.html' -print0)
)

mkdir -p "$ROOT_DIR/_site"
cp -a "$ROOT_DIR/html/." "$ROOT_DIR/_site/"
touch "$ROOT_DIR/_site/.nojekyll"

test -s "$ROOT_DIR/_site/index.html"
test -s "$ROOT_DIR/_site/_static/pretext/css/theme.css"
test -s "$ROOT_DIR/_site/_static/pretext/js/dist/pretext-core.js"
