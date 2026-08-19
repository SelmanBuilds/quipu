#!/bin/sh
# quipu — test suite for the FAZ 1 Adim 1 primitives.
# Zero external framework (PLAN FAZ 1). Run: sh tests/run.sh
# CI executes this on ubuntu / macos / windows (PLAN Adim 2).
#
# Backslash policy: PLAN 4.11 forbids escape-sequence-based CODE in the
# shipped sources (lib/*.awk, fold/*.sed). In this file backslashes appear
# only as DATA inside single-quoted expected values; single quotes preserve
# them verbatim through every shell layer.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LIB="$ROOT/lib"
FOLD="$ROOT/fold"
FIX="$ROOT/tests/fixtures"
DRV="$ROOT/tests/drivers"

PASS=0
FAIL=0
SKIP=0
NUM=0
TMP=${TMPDIR:-/tmp}/quipu-tests-$$
mkdir -p "$TMP" || exit 1
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

ok()     { PASS=$((PASS + 1)); printf 'ok %d - %s\n' "$NUM" "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf 'not ok %d - %s\n' "$NUM" "$1"; }
skip()   { SKIP=$((SKIP + 1)); printf 'ok %d - %s # SKIP %s\n' "$NUM" "$1" "$2"; }
t()      { NUM=$((NUM + 1)); }

assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then
    ok "$1"
  else
    not_ok "$1"
    printf '#    expected: [%s]\n#    got:      [%s]\n' "$2" "$3"
  fi
}

field() { # driver.awk file
  awk -f "$LIB/jsonfield.awk" -f "$DRV/$1" "$2"
}
scoped()   { field filepath_scoped.awk "$1"; }
unscoped() { field filepath_unscoped.awk "$1"; }
toolname() { field toolname.awk "$1"; }

fold_p() { # profile-name
  sed -f "$FOLD/$1.sed" | tr 'A-Z' 'a-z'
}

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# ---- jsonfield: escapes, control bytes, UTF-8, missing field (PLAN 4.8) ----

t; assert_eq "jsonfield decodes escaped quote and backslashes" 'a"b' "$(toolname "$FIX/escapes.json")"
t; assert_eq "scoped file_path keeps Windows path" 'C:\Users\x\not.md' "$(scoped "$FIX/escapes.json")"
t; assert_eq "unscoped agrees when the real field comes first" 'C:\Users\x\not.md' "$(unscoped "$FIX/escapes.json")"

CTL=$(awk 'BEGIN{printf "li%cne%ctab%cret",10,9,13}')
t; assert_eq "jsonfield decodes newline tab carriage-return" "$CTL" "$(toolname "$FIX/controls.json")"

t; assert_eq "jsonfield preserves UTF-8" 'İstanbul çğöü 日本語 🔮' "$(toolname "$FIX/utf8.json")"
t; assert_eq "missing field returns empty string" '' "$(scoped "$FIX/missing.json")"

# ---- scoping: trap in tool_response (PLAN 4.8 sinir 1) ----

t; assert_eq "real captured schema: scoped file_path correct" 'C:\Users\alice\projects\demo\taskbar_overflow.png' "$(scoped "$FIX/posttooluse.json")"
t; assert_eq "real captured schema: unscoped agrees" 'C:\Users\alice\projects\demo\taskbar_overflow.png' "$(unscoped "$FIX/posttooluse.json")"
t; assert_eq "trap before tool_input: scoped wins" 'dogru.md' "$(scoped "$FIX/trap-before.json")"
printf '# info: unscoped on trap-before.json returns [%s] (documented failure mode)\n' "$(unscoped "$FIX/trap-before.json")"

# ---- jsonemit -> jsonfield round-trip ----

roundtrip() { # fixture expected
  t
  emit=$(awk -f "$LIB/jsonfield.awk" -f "$LIB/jsonemit.awk" -f "$DRV/roundtrip.awk" "$1")
  back=$(printf '{"x":%s}' "$emit" | awk -f "$LIB/jsonfield.awk" -f "$DRV/value.awk" -)
  assert_eq "round-trip: $(basename "$1")" "$2" "$back"
}

roundtrip "$FIX/roundtrip-path.json" 'C:\Users\x\not.md "quoted"'
MULTI=$(awk 'BEGIN{printf "line1%cline2%ctabbed",10,9}')
roundtrip "$FIX/roundtrip-multi.json" "$MULTI"
roundtrip "$FIX/roundtrip-utf8.json" 'İstanbul çğöü 日本語 🔮'
roundtrip "$FIX/roundtrip-ctl.json" 'a?b'   # uXXXX placeholder is documented in lib

# ---- big payload: scoped reads, bounded time (PLAN 4.12, 4.8 sinir 2) ----

printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"big/target.md"},"tool_response":"base64:' > "$TMP/big.json"
awk 'BEGIN{for(i=0;i<7000;i++) printf "0000000000000000000000000000000000000000000000000000000000000000"}' >> "$TMP/big.json"
printf '%s' '"}' >> "$TMP/big.json"

t; START=$(date +%s)
FULL=$(field filepath_scoped.awk "$TMP/big.json")
END=$(date +%s)
assert_eq "448 KB payload: full read returns scoped path" 'big/target.md' "$FULL"
t; assert_eq "448 KB payload: bounded time" 'yes' "$([ $((END - START)) -lt 30 ] && printf yes || printf no)"

t; PREFIX=$(head -c 65536 "$TMP/big.json" | awk -f "$LIB/jsonfield.awk" -f "$DRV/filepath_scoped.awk" -)
assert_eq "448 KB payload: 64 KB prefix returns same path" 'big/target.md' "$PREFIX"

# ---- folding profiles (PLAN 4.1-4.3) ----

t; assert_eq "latin: PLAN 4.1 canonical" 'uber munchen cafe naive senor strasse joao' "$(printf '%s\n' 'Über MÜNCHEN Café NAÏVE Señor Straße João' | fold_p latin)"
t; assert_eq "latin: german" 'arger ol ubung strasse' "$(printf '%s\n' 'Ärger Öl Übung Straße' | fold_p latin)"
t; assert_eq "latin: french" 'cafe naive coeur creme deja-vu' "$(printf '%s\n' 'Café NAÏVE cœur Crème déjà-vu' | fold_p latin)"
t; assert_eq "latin: spanish" 'senor espana camion pinguino' "$(printf '%s\n' 'Señor España CAMIÓN pingüino' | fold_p latin)"
t; assert_eq "latin: CJK Cyrillic emoji untouched" '日本語 中文 Привет 🔮' "$(printf '%s\n' '日本語 中文 Привет 🔮' | fold_p latin)"
t; assert_eq "tr: I goes through dotless i to i" 'istanbul isik calisma guzel' "$(printf '%s\n' 'İstanbul IŞIK çalışma ĞÜZEL' | fold_p tr)"
t; assert_eq "tr: latin base included" 'uber munchen cafe naive' "$(printf '%s\n' 'Über MÜNCHEN Café NAÏVE' | fold_p tr)"
t; assert_eq "tr: PLAN 4.3 order passthrough" 'uber 日本語 Привет 🔮 cafe' "$(printf '%s\n' 'Über 日本語 Привет 🔮 Cafe' | fold_p tr)"
t; assert_eq "default: folds nothing, tr lowercases ASCII" 'café naÏve mÜnchen' "$(printf '%s\n' 'Café NAÏVE MÜNCHEN' | fold_p default)"

# ---- source hygiene (PLAN 4.1, 4.11) ----

t; BAD=$(awk 'index($0, sprintf("%c", 92)) != 0 { print FILENAME ":" NR }' "$LIB"/*.awk "$FOLD"/*.sed)
assert_eq "no literal backslash in shipped sources" '' "$BAD"

t; BAD=$(grep -Fl '[' "$FOLD"/*.sed)
assert_eq "no character classes in fold profiles" '' "$BAD"

# ---- mtime portability (PLAN 4.4) ----

: > "$TMP/mtime.txt"
t; EXPECTED=$(stat -c %Y "$TMP/mtime.txt" 2>/dev/null || stat -f %m "$TMP/mtime.txt" 2>/dev/null || echo 0)
assert_eq "mtime returns the platform stat value" "$EXPECTED" "$(mtime "$TMP/mtime.txt")"
t; assert_eq "mtime of missing file falls back to 0" '0' "$(mtime "$TMP/does-not-exist.txt")"

# ---- POSIX compliance (PLAN 3) ----

if command -v shellcheck >/dev/null 2>&1; then
  t
  if shellcheck -s sh "$ROOT/tests/run.sh" >/dev/null 2>&1; then
    ok "shellcheck POSIX clean"
  else
    not_ok "shellcheck POSIX clean"
    shellcheck -s sh "$ROOT/tests/run.sh" || true
  fi
else
  t; skip "shellcheck POSIX clean" "shellcheck not installed (CI installs it)"
fi

# ---- summary ----

printf '# pass %d, fail %d, skip %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
