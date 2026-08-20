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
  # SC2018/SC2019 suggest [:upper:]/[:lower:], but PLAN 4.3 forbids them here:
  # BSD tr is byte-based and multibyte classes can corrupt UTF-8. ASCII
  # ranges after folding are safe on every platform (verified on macOS CI).
  # shellcheck disable=SC2018,SC2019
  sed -f "$FOLD/$1.sed" | tr 'A-Z' 'a-z'
}

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
TAB=$(printf '\t')

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
  t
  if shellcheck -s sh "$ROOT/quipu" >/dev/null 2>&1; then
    ok "shellcheck POSIX clean (quipu)"
  else
    not_ok "shellcheck POSIX clean (quipu)"
    shellcheck -s sh "$ROOT/quipu" || true
  fi
else
  t; skip "shellcheck POSIX clean" "shellcheck not installed (CI installs it)"
  t; skip "shellcheck POSIX clean (quipu)" "shellcheck not installed (CI installs it)"
fi

# ---- cli skeleton ----

t; VERSION=$(sh "$ROOT/quipu" --version)
assert_eq "quipu --version prints quipu 0.1.0" 'quipu 0.1.0' "$VERSION"

mkdir -p "$TMP/empty"
t; (cd "$TMP/empty" && "$ROOT/quipu" doctor) >"$TMP/empty.out" 2>&1; RC=$?
assert_eq "doctor in empty dir exits 0" '0' "$RC"
t
if grep -q 'quipu doctor' "$TMP/empty.out"; then
  ok "doctor output mentions quipu doctor"
else
  not_ok "doctor output mentions quipu doctor"
fi

mkdir -p "$TMP/vault/.quipu"
: > "$TMP/vault/.quipu/config"
t; (cd "$TMP/vault" && "$ROOT/quipu" doctor) >"$TMP/vault.out" 2>&1; RC=$?
assert_eq "doctor with vault exits 0" '0' "$RC"

t; (cd "$TMP/empty" && QUIPU_LANG=zz "$ROOT/quipu" doctor) >"$TMP/zz.out" 2>&1; RC=$?
assert_eq "doctor with QUIPU_LANG=zz exits 0" '0' "$RC"


# ---- capture (PLAN FAZ 1) ----

mkvault() { mkdir -p "$TMP/$1/.quipu"; : > "$TMP/$1/.quipu/config"; }
log_line() { awk 'END{i=index($0," | "); print substr($0,i+3)}' "$1/.quipu/activity.log"; }

mkvault vcap

t; QUIPU_VAULT="$TMP/vcap" sh "$ROOT/quipu" capture < "$FIX/posttooluse.json"
assert_eq "capture: posttooluse appends one line" 'PostToolUse | Read | C:\Users\alice\projects\demo\taskbar_overflow.png' "$(log_line "$TMP/vcap")"

t; printf '%s\n' '{"hook_event_name":"PostToolUse","tool_name":"Read","tool_response":{"file_path":"TUZAK.md"},"tool_input":{"file_path":"dogru.md"}}' | QUIPU_VAULT="$TMP/vcap" sh "$ROOT/quipu" capture
assert_eq "capture: scoped path beats tool_response trap" 'PostToolUse | Read | dogru.md' "$(log_line "$TMP/vcap")"

# 448 KB payload (big.json pattern) plus a trap file_path past the 64 KB bound.
printf '%s' '{"hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"big/target.md"},"tool_response":"base64:' > "$TMP/bigcap.json"
awk 'BEGIN{for(i=0;i<7000;i++) printf "0000000000000000000000000000000000000000000000000000000000000000"}' >> "$TMP/bigcap.json"
printf '%s' '","trap":{"file_path":"C:\Users\x\trap.md"}}' >> "$TMP/bigcap.json"
t; START=$(date +%s)
QUIPU_VAULT="$TMP/vcap" sh "$ROOT/quipu" capture < "$TMP/bigcap.json"
END=$(date +%s)
assert_eq "capture: 448 KB payload returns first scoped path" 'PostToolUse | Read | big/target.md' "$(log_line "$TMP/vcap")"
t; assert_eq "capture: 448 KB payload bounded time" 'yes' "$([ $((END - START)) -lt 30 ] && printf yes || printf no)"

mkvault vcapctl
t; printf '%s\n' '{"hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"a\nb\tc\rd"}}' | QUIPU_VAULT="$TMP/vcapctl" sh "$ROOT/quipu" capture
assert_eq "capture: control bytes in path stay on one line" '1' "$(awk 'END{print NR}' "$TMP/vcapctl/.quipu/activity.log")"
t; assert_eq "capture: control bytes stripped from path" 'PostToolUse | Read | abcd' "$(log_line "$TMP/vcapctl")"

t; QUIPU_VAULT="$TMP/vcap" sh "$ROOT/quipu" capture --event PostToolUse --tool Edit --path 500-Knowledge/not.md
assert_eq "capture: flag mode appends line" 'PostToolUse | Edit | 500-Knowledge/not.md' "$(log_line "$TMP/vcap")"

t
# literal $HOME in the single-quoted JSON is the test payload (test data, not expansion).
# shellcheck disable=SC2016
printf '%s\n' '{"hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"C:\\Users\\x$HOME\\not.md"}}' | QUIPU_VAULT="$TMP/vcap" sh "$ROOT/quipu" capture
# literal $HOME in the expected value is part of the same test.
# shellcheck disable=SC2016
assert_eq "capture: dollar in path preserved literally" 'PostToolUse | Read | C:\Users\x$HOME\not.md' "$(log_line "$TMP/vcap")"

mkvault vcaprot
t; LONGPATH=$(awk 'BEGIN{for(i=0;i<200;i++) printf "x"}')
QUIPU_VAULT="$TMP/vcaprot" QUIPU_LOG_MAX=100 sh "$ROOT/quipu" capture --event PostToolUse --tool Edit --path "$LONGPATH"
QUIPU_VAULT="$TMP/vcaprot" QUIPU_LOG_MAX=100 sh "$ROOT/quipu" capture --event PostToolUse --tool Edit --path two.md
assert_eq "capture: rotation creates activity.log.1" 'yes' "$([ -f "$TMP/vcaprot/.quipu/activity.log.1" ] && printf yes || printf no)"
t; assert_eq "capture: rotated log keeps one line" '1' "$(awk 'END{print NR}' "$TMP/vcaprot/.quipu/activity.log")"
t; assert_eq "capture: rotated log has latest entry" 'PostToolUse | Edit | two.md' "$(log_line "$TMP/vcaprot")"
# ---- init + context ----

t; QUIPU_VAULT="$TMP/vinit" sh "$ROOT/quipu" init --lang tr
for _f in config index.tsv activity.log; do
  t; assert_eq "init: creates .quipu/$_f" 'yes' "$([ -f "$TMP/vinit/.quipu/$_f" ] && printf yes || printf no)"
done
t; assert_eq "init: config records lang=tr" 'yes' "$(grep -q '^lang=tr$' "$TMP/vinit/.quipu/config" && printf yes || printf no)"
t; (cd "$TMP/vinit" && "$ROOT/quipu" doctor) >"$TMP/vinit-doctor.out" 2>&1; RC=$?
assert_eq "init: doctor exits 0 in the vault" '0' "$RC"

# Second init must not duplicate the bridge block nor disturb user text.
printf '# My notes\nkeep this line\n' >> "$TMP/vinit/AGENTS.md"
t; QUIPU_VAULT="$TMP/vinit" sh "$ROOT/quipu" init
assert_eq "init: second run preserves user text" 'yes' "$(grep -q '^keep this line$' "$TMP/vinit/AGENTS.md" && printf yes || printf no)"
t; CNT=$(grep -c 'quipu:start' "$TMP/vinit/AGENTS.md")
assert_eq "init: second run does not duplicate bridge block" '1' "$CNT"
t;
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Read | C:\Users\alice\demo\taskbar.png' >> "$TMP/vinit/.quipu/activity.log"

# context --json round-trips back to the plain output.
printf '2026-08-20T10:00 | PostToolUse | Read | not.md\n' >> "$TMP/vinit/.quipu/activity.log"
t; PLAIN=$(QUIPU_VAULT="$TMP/vinit" sh "$ROOT/quipu" context)
JSON=$(QUIPU_VAULT="$TMP/vinit" sh "$ROOT/quipu" context --json SessionStart)
DECODED=$(printf '%s' "$JSON" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "context: --json round-trips to plain output" "$PLAIN" "$DECODED"

# Empty vault: context exits 0 without crashing.
mkdir -p "$TMP/vempty/.quipu"
: > "$TMP/vempty/.quipu/config"
t; (cd "$TMP/vempty" && "$ROOT/quipu" context) >"$TMP/vempty.out" 2>&1; RC=$?
assert_eq "context: empty vault exits 0" '0' "$RC"

# init without an AGENTS.md creates it with the bridge heading.
t; QUIPU_VAULT="$TMP/vagents" sh "$ROOT/quipu" init
assert_eq "init: creates AGENTS.md when absent" 'yes' "$([ -f "$TMP/vagents/AGENTS.md" ] && printf yes || printf no)"
t; assert_eq "init: AGENTS.md contains bridge heading" 'yes' "$(grep -q '^## quipu$' "$TMP/vagents/AGENTS.md" && printf yes || printf no)"
# ---- FAZ 2: layout + identity ----

t; BAD=$(awk 'index($0, sprintf("%c", 92)) != 0 { print FILENAME ":" NR }' "$ROOT/layout"/*.txt "$ROOT/persona"/*.md)
assert_eq "no literal backslash in layout and persona data" '' "$BAD"

SL1=$(awk -F"$TAB" '$0 !~ /^#/ && NF >= 2 {print $1}' "$ROOT/layout/emoji.txt")
SL2=$(awk -F"$TAB" '$0 !~ /^#/ && NF >= 2 {print $1}' "$ROOT/layout/plain.txt")
t; assert_eq "layout files share identical slug columns" "$SL1" "$SL2"

KTR=$(awk -F= 'NF >= 1 && $1 !~ /^#/ {print $1}' "$ROOT/i18n/tr.txt" | sort)
KEN=$(awk -F= 'NF >= 1 && $1 !~ /^#/ {print $1}' "$ROOT/i18n/en.txt" | sort)
t; assert_eq "i18n tr/en key sets identical" "$KEN" "$KTR"

mkvault vexcl
: > "$TMP/vexcl/CLAUDE.md"
printf '# Not\n' > "$TMP/vexcl/not.md"
t; (cd "$TMP/vexcl" && "$ROOT/quipu" index) >/dev/null 2>&1
assert_eq "index: CLAUDE.md excluded, not.md indexed" '1' "$(awk 'END{print NR}' "$TMP/vexcl/.quipu/index.tsv")"
t; assert_eq "index: CLAUDE.md has no row" '' "$(awk -F"$TAB" 'index($1, "CLAUDE.md") {print $1}' "$TMP/vexcl/.quipu/index.tsv")"
layout_names() { # emoji|plain -> one folder name per line
  awk -F"$TAB" '$0 !~ /^#/ && NF >= 2 {print $2}' "$ROOT/layout/$1.txt"
}
comp_name() { # emoji|plain -> companion folder name
  awk -F"$TAB" '$1=="companion"{print $2;exit}' "$ROOT/layout/$1.txt"
}

mkvault vlay
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init

t; FAILED=$(layout_names emoji | while IFS= read -r _n; do
  if [ -d "$TMP/vlay/$_n" ] && [ -f "$TMP/vlay/$_n/.gitkeep" ]; then :; else printf '%s\n' "$_n"; fi
done)
assert_eq "init: five emoji folders each with .gitkeep" '' "$FAILED"

mkvault vplain
QUIPU_VAULT="$TMP/vplain" sh "$ROOT/quipu" init --plain
t; GOT=$(cd "$TMP/vplain" && find . -maxdepth 1 -mindepth 1 -type d ! -name .quipu ! -name .git | cut -c3- | sort)
assert_eq "init --plain: folder names match layout/plain.txt" "$(layout_names plain | sort)" "$GOT"
t; BAD=$( (cd "$TMP/vplain" && find . -maxdepth 1 -mindepth 1 -type d ! -name .quipu ! -name .git) | LC_ALL=C grep '[^ -~]' || true)
assert_eq "init --plain: folder names contain no non-ASCII bytes" '' "$BAD"

t; assert_eq "init: config records layout=emoji" 'yes' "$(grep -q '^layout=emoji$' "$TMP/vlay/.quipu/config" && printf yes || printf no)"
t; assert_eq "init --plain: config records layout=plain" 'yes' "$(grep -q '^layout=plain$' "$TMP/vplain/.quipu/config" && printf yes || printf no)"

D0=$(find "$TMP/vlay" -type d | wc -l | tr -d ' ')
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init --plain >"$TMP/vlay-conflict.out" 2>&1; RC=$?
t; assert_eq "init --plain on emoji vault exits 2" '2' "$RC"
t; assert_eq "init --plain conflict changes no folders" "$D0" "$(find "$TMP/vlay" -type d | wc -l | tr -d ' ')"

D0=$(find "$TMP/vlay" -type d | wc -l | tr -d ' ')
K0=$(find "$TMP/vlay" -name .gitkeep | wc -l | tr -d ' ')
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "init: second run keeps folder count" "$D0" "$(find "$TMP/vlay" -type d | wc -l | tr -d ' ')"
t; assert_eq "init: second run keeps .gitkeep count" "$K0" "$(find "$TMP/vlay" -name .gitkeep | wc -l | tr -d ' ')"

t; assert_eq "init: companion.md created and non-empty" 'yes' "$([ -s "$TMP/vlay/$(comp_name emoji)/companion.md" ] && printf yes || printf no)"

printf 'user marker 7\n' >> "$TMP/vlay/$(comp_name emoji)/companion.md"
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "init: user companion.md edits preserved" 'yes' "$(grep -q '^user marker 7$' "$TMP/vlay/$(comp_name emoji)/companion.md" && printf yes || printf no)"

mkvault vlaytr
QUIPU_VAULT="$TMP/vlaytr" sh "$ROOT/quipu" init --lang tr >/dev/null 2>&1
t; assert_eq "init --lang tr: companion.md from Turkish persona" 'yes' "$(grep -q 'Üslup' "$TMP/vlaytr/$(comp_name emoji)/companion.md" && printf yes || printf no)"

t; assert_eq "init: CLAUDE.md created with block pointing at AGENTS.md" 'yes' "$([ -f "$TMP/vlay/CLAUDE.md" ] && grep -q 'quipu:start' "$TMP/vlay/CLAUDE.md" && grep -q 'AGENTS.md' "$TMP/vlay/CLAUDE.md" && printf yes || printf no)"

mkvault vclau
printf 'user claude text\nkeep this too\n' > "$TMP/vclau/CLAUDE.md"
QUIPU_VAULT="$TMP/vclau" sh "$ROOT/quipu" init >/dev/null 2>&1
QUIPU_VAULT="$TMP/vclau" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "init: pre-existing CLAUDE.md text preserved" 'yes' "$(grep -q '^keep this too$' "$TMP/vclau/CLAUDE.md" && printf yes || printf no)"
t; assert_eq "init: CLAUDE.md block not duplicated" '1' "$(grep -c 'quipu:start' "$TMP/vclau/CLAUDE.md")"

t; MISS=$(layout_names emoji | while IFS= read -r _n; do
  awk -v s="$_n" 'index($0, s) {found=1} END {exit !found}' "$TMP/vlay/AGENTS.md" || printf '%s\n' "$_n"
done)
assert_eq "init: AGENTS.md block lists all five folders" '' "$MISS"

t; assert_eq "init: Threads.md seeded" 'yes' "$([ -f "$TMP/vlay/Threads.md" ] && printf yes || printf no)"
TITLE=$(awk -F= -v k=threads_seed_title '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
NOTE=$(awk -F= -v k=threads_seed_note '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
CTX=$(QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" context)
t; assert_eq "context: prints threads section and seed" 'yes' "$(printf '%s\n' "$CTX" | grep -q "$TITLE" && printf '%s\n' "$CTX" | grep -q "$NOTE" && printf yes || printf no)"

printf 'user thread marker\n' >> "$TMP/vlay/Threads.md"
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "init: user Threads.md lines preserved" 'yes' "$(grep -q '^user thread marker$' "$TMP/vlay/Threads.md" && printf yes || printf no)"

QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" index >/dev/null 2>&1
t; assert_eq "index: companion.md has a row" 'yes' "$(awk -F"$TAB" 'index($1, "companion.md") {print "yes"; exit}' "$TMP/vlay/.quipu/index.tsv")"
t; assert_eq "index: companion.md path uses emoji folder" 'yes' "$(awk -F"$TAB" -v n="$(comp_name emoji)" 'index($1, "companion.md") && index($1, n) {print "yes"; exit}' "$TMP/vlay/.quipu/index.tsv")"

P=$(QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" search Boundaries --paths)
t; assert_eq "search: finds companion.md content" 'yes' "$(printf '%s\n' "$P" | grep -q 'companion.md' && printf yes || printf no)"
t; assert_eq "search --paths: prints emoji folder path" 'yes' "$(printf '%s\n' "$P" | awk -v s="$(comp_name emoji)" 'index($0, s) {found=1} END {exit !found}' && printf yes || printf no)"

TARGET="$(comp_name emoji)/not.md"
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" capture --event PostToolUse --tool Edit --path "$TARGET"
t; assert_eq "capture: emoji-folder path logged intact" 'yes' "$(awk -v s="$TARGET" 'index($0, s) {found=1} END {exit !found}' "$TMP/vlay/.quipu/activity.log" && printf yes || printf no)"
CTX=$(QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" context)
t; assert_eq "context: prints emoji-folder capture path" 'yes' "$(printf '%s\n' "$CTX" | awk -v s="$TARGET" 'index($0, s) {found=1} END {exit !found}' && printf yes || printf no)"

mkvault vfresh
QUIPU_VAULT="$TMP/vfresh" sh "$ROOT/quipu" init >/dev/null 2>&1
t; (cd "$TMP/vfresh" && QUIPU_LANG=en "$ROOT/quipu" doctor) >"$TMP/vfresh.out" 2>&1; RC=$?
assert_eq "doctor: fresh emoji vault exits 0" '0' "$RC"

mkvault vfreshp
QUIPU_VAULT="$TMP/vfreshp" sh "$ROOT/quipu" init --plain >/dev/null 2>&1
t; (cd "$TMP/vfreshp" && QUIPU_LANG=en "$ROOT/quipu" doctor) >"$TMP/vfreshp.out" 2>&1; RC=$?
assert_eq "doctor: fresh --plain vault exits 0" '0' "$RC"

t; assert_eq "doctor: layout line shows emoji" 'yes' "$(awk -F"$TAB" '$2=="layout" && $3=="emoji" {print "yes"; exit}' "$TMP/vfresh.out")"
t; assert_eq "doctor: layout line shows plain" 'yes' "$(awk -F"$TAB" '$2=="layout" && $3=="plain" {print "yes"; exit}' "$TMP/vfreshp.out")"
# doctor: the OneDrive install-path warning must not depend on a vault existing.
ODH="$TMP/OneDrive-home"
mkdir -p "$ODH"
cp "$ROOT/quipu" "$ODH/"
cp -r "$ROOT/lib" "$ROOT/i18n" "$ROOT/fold" "$ROOT/layout" "$ROOT/persona" "$ODH/"
mkdir -p "$TMP/odwork"
t; OUT=$( (cd "$TMP/odwork" && sh "$ODH/quipu" doctor) 2>&1 )
assert_eq "doctor: OneDrive install path warns with no vault" 'yes' \
  "$(printf '%s\n' "$OUT" | grep -q OneDrive && printf yes || printf no)"
t; OUT=$( (cd "$TMP/vfreshp" && sh "$ODH/quipu" doctor) 2>&1 )
assert_eq "doctor: plain layout suppresses the OneDrive warning" 'no' \
  "$(printf '%s\n' "$OUT" | grep -q OneDrive && printf yes || printf no)"

# ---- index ----

mk_index_vault() { # dir
  mkdir -p "$TMP/$1/.quipu"
  cat > "$TMP/$1/.quipu/config" <<'EOF'
fold=tr
lang=en
EOF
  cat > "$TMP/$1/fm.md" <<'EOF'
---
title: Frontmatter Başlık
tags: alpha beta
---
# Frontmatter Başlık
Frontmatter body.
EOF
  cat > "$TMP/$1/heading.md" <<'EOF'
# Başlık
Heading body.
EOF
  cat > "$TMP/$1/turkce.md" <<'EOF'
İstanbul çalışma üzerine.
EOF
}

idx_nums() { # summary-file -> "N R S D"
  awk '{ gsub(/[^0-9]/," "); s=""; for (i=1;i<=NF;i++) if ($i!="") s=s (s==""?"":" ") $i; print s }' "$1"
}

mk_index_vault idx1

t; (cd "$TMP/idx1" && "$ROOT/quipu" index) >"$TMP/idx1.out" 2>&1; RC=$?
assert_eq "index: first run exits 0" '0' "$RC"
t; assert_eq "index: first run writes 3 rows" '3' "$(awk 'END{print NR}' "$TMP/idx1/.quipu/index.tsv")"
t; assert_eq "index: every row has 5 columns" 'yes' "$(awk -F'\t' '{if (NF != 5) bad++} END{print (bad ? "no" : "yes")}' "$TMP/idx1/.quipu/index.tsv")"
t; assert_eq "index: first run counts" '3 0 3 0' "$(idx_nums "$TMP/idx1.out")"

sleep 1
touch "$TMP/idx1/heading.md"
t; (cd "$TMP/idx1" && "$ROOT/quipu" index) >"$TMP/idx1.out" 2>&1
assert_eq "index: touch one file reuses 2, stale 1" '3 2 1 0' "$(idx_nums "$TMP/idx1.out")"

rm "$TMP/idx1/fm.md"
t; (cd "$TMP/idx1" && "$ROOT/quipu" index) >"$TMP/idx1.out" 2>&1
assert_eq "index: delete one file leaves 2 rows" '2' "$(awk 'END{print NR}' "$TMP/idx1/.quipu/index.tsv")"
t; assert_eq "index: delete one file drops 1" '2 2 0 1' "$(idx_nums "$TMP/idx1.out")"

t; assert_eq "index: folded field contains calisma" 'yes' "$(awk -F'\t' '$1=="turkce.md" {print (index($5,"calisma")>0) ? "yes" : "no"}' "$TMP/idx1/.quipu/index.tsv")"
t; assert_eq "index: folded field drops raw çalışma" 'no' "$(awk -F'\t' '$1=="turkce.md" {print (index($5,"çalışma")>0) ? "yes" : "no"}' "$TMP/idx1/.quipu/index.tsv")"

mk_index_vault idxfull
t; (cd "$TMP/idxfull" && "$ROOT/quipu" index) >/dev/null 2>&1
(cd "$TMP/idxfull" && "$ROOT/quipu" index --full) >"$TMP/idxfull.out" 2>&1
assert_eq "index: --full regenerates all rows" '3 0 3 0' "$(idx_nums "$TMP/idxfull.out")"

mkdir -p "$TMP/idxemoji/.quipu"
: > "$TMP/idxemoji/.quipu/config"
mkdir -p "$TMP/idxemoji/🔮 notlar"
cat > "$TMP/idxemoji/🔮 notlar/d.md" <<'EOF'
# Not
emoji folder.
EOF
t; (cd "$TMP/idxemoji" && "$ROOT/quipu" index) >"$TMP/idxemoji.out" 2>&1; RC=$?
assert_eq "index: emoji folder doc indexed (exits 0)" '0' "$RC"
t; assert_eq "index: emoji folder path preserved" '🔮 notlar/d.md' "$(awk -F'\t' 'NR==1 {print $1}' "$TMP/idxemoji/.quipu/index.tsv")"

mk_index_vault idxlang
t; (cd "$TMP/idxlang" && QUIPU_LANG=en "$ROOT/quipu" index) >"$TMP/idxlang.out" 2>&1
# idx_summary is the controlled i18n template (not user data); args are integers.
# shellcheck disable=SC2059
EXPECT=$(printf "$(awk -F= -v k=idx_summary '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")" 3 0 3 0)
assert_eq "index: summary uses i18n idx_summary template" "$EXPECT" "$(cat "$TMP/idxlang.out")"

mkdir -p "$TMP/idxempty/.quipu"
: > "$TMP/idxempty/.quipu/config"
t; (cd "$TMP/idxempty" && "$ROOT/quipu" index) >"$TMP/idxempty.out" 2>&1; RC=$?
assert_eq "index: empty vault exits 0" '0' "$RC"
t; assert_eq "index: empty vault counts" '0 0 0 0' "$(idx_nums "$TMP/idxempty.out")"

# ---- search ----

mk_search_vault() { # dir
  mkdir -p "$TMP/$1/.quipu"
  cat > "$TMP/$1/.quipu/config" <<'EOF'
fold=tr
lang=en
EOF
  printf '# notlar\n\nİstanbul üzerine notlar. Işık deneyleri burada.\n' > "$TMP/$1/istanbul-a.md"
  printf 'İstanbul ve ışık bu dosyada anlatılıyor.\n' > "$TMP/$1/istanbul-b.md"
  printf 'Çalışma notları ve günlük plan.\n' > "$TMP/$1/calisma-a.md"
  printf 'Bu dosyada çalışma düzeni var.\n' > "$TMP/$1/calisma-b.md"
  printf '# alpha\nalpha appears in the body too.\n' > "$TMP/$1/title-doc.md"
  printf '# beta\nalpha appears in the body as well.\n' > "$TMP/$1/body-doc.md"
}

mk_search_vault searchv
QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" index >/dev/null 2>&1

# §4.2 live check. A raw `grep -i` over these docs returns 1/2, 1/2, 0/2 for
# İstanbul / IŞIK / çalışma (the Turkish folding gap); folded search is 2/2.
t; assert_eq "search İstanbul returns 2/2" '2' "$(QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search İstanbul | awk 'END{print NR}')"
t; assert_eq "search IŞIK returns 2/2" '2' "$(QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search IŞIK | awk 'END{print NR}')"
t; assert_eq "search çalışma returns 2/2" '2' "$(QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search çalışma | awk 'END{print NR}')"

# A title match ranks ahead of a body-only match.
t; FIRST=$(QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search alpha | awk 'NR==1{print $2}')
assert_eq "search ranks title match first" 'title-doc.md' "$FIRST"

# --limit and --paths shapes.
t; assert_eq "search --limit 1 returns one line" '1' "$(QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search çalışma --limit 1 | awk 'END{print NR}')"
t; PATHS=$(QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search çalışma --paths | sort)
assert_eq "search --paths prints only the two paths" 'calisma-a.md
calisma-b.md' "$PATHS"
t; assert_eq "search --paths lines have no TAB" '' "$(printf '%s\n' "$PATHS" | awk 'index($0, sprintf("%c", 9)) != 0 { print NR }')"

# Empty query is a usage error; an unmatched query is empty but successful.
t; QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search >"$TMP/search-empty.out" 2>&1; RC=$?
assert_eq "search empty query exits 2" '2' "$RC"
t; OUT=$(QUIPU_VAULT="$TMP/searchv" sh "$ROOT/quipu" search xyzzy); RC=$?
assert_eq "search no-match exits 0" '0' "$RC"
t; assert_eq "search no-match empty output" '' "$OUT"

# ---- summary ----

printf '# pass %d, fail %d, skip %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
