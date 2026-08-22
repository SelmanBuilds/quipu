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

# ---- capture: multi-schema apply_patch (FAZ 4) ----

mkvault vcodex
t; QUIPU_VAULT="$TMP/vcodex" sh "$ROOT/quipu" capture < "$FIX/codex-apply-patch.json"
assert_eq "capture: apply_patch single file logs one row" 'PostToolUse | apply_patch | alice/demo/not.md' "$(log_line "$TMP/vcodex")"

mkvault vcodexm
t; QUIPU_VAULT="$TMP/vcodexm" sh "$ROOT/quipu" capture < "$FIX/codex-apply-patch-multi.json"
MLINES=$(awk '{ i=index($0," | "); print substr($0,i+3) }' "$TMP/vcodexm/.quipu/activity.log")
assert_eq "capture: apply_patch multi logs exactly two byte-exact rows" 'PostToolUse | apply_patch | alice/demo/a.md
PostToolUse | apply_patch | alice/demo/b.md' "$MLINES"

mkvault vcodexd
t; QUIPU_VAULT="$TMP/vcodexd" sh "$ROOT/quipu" capture < "$FIX/codex-apply-patch-delete.json"
assert_eq "capture: apply_patch /dev/null logs no row" 'no' "$([ -s "$TMP/vcodexd/.quipu/activity.log" ] && printf yes || printf no)"

mkvault vcodexr
t; QUIPU_VAULT="$TMP/vcodexr" sh "$ROOT/quipu" capture < "$FIX/posttooluse.json"
assert_eq "capture: Claude Code payload unchanged (regression)" 'PostToolUse | Read | C:\Users\alice\projects\demo\taskbar_overflow.png' "$(log_line "$TMP/vcodexr")"

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
cmd_name() { # emoji|plain -> command-center folder name
  awk -F"$TAB" '$1=="command"{print $2;exit}' "$ROOT/layout/$1.txt"
}

mkvault vlay
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init

t; FAILED=$(layout_names emoji | while IFS= read -r _n; do
  if [ -d "$TMP/vlay/$_n" ] && [ -f "$TMP/vlay/$_n/.gitkeep" ]; then :; else printf '%s\n' "$_n"; fi
done)
assert_eq "init: every emoji layout folder has .gitkeep" '' "$FAILED"

mkvault vplain
QUIPU_VAULT="$TMP/vplain" sh "$ROOT/quipu" init --plain
t; MISSD=$(layout_names plain | while IFS= read -r _n; do
  [ -d "$TMP/vplain/$_n" ] || printf '%s\n' "$_n"
done)
assert_eq "init --plain: every plain layout folder exists" '' "$MISSD"
t; GOT=$(cd "$TMP/vplain" && find . -maxdepth 1 -mindepth 1 -type d ! -name .quipu ! -name .git | cut -c3- | sort)
assert_eq "init --plain: no unexpected top-level folders" "$(layout_names plain | awk -F/ '{print $1}' | sort -u)" "$GOT"
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
assert_eq "init: AGENTS.md block lists every layout folder" '' "$MISS"

t; assert_eq "init: Threads.md seeded" 'yes' "$([ -f "$TMP/vlay/Threads.md" ] && printf yes || printf no)"
TITLE=$(awk -F= -v k=threads_seed_title '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
NOTE=$(awk -F= -v k=threads_seed_note '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
CTX=$(QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" context)
t; assert_eq "context: prints threads section and seed" 'yes' "$(printf '%s\n' "$CTX" | grep -q "$TITLE" && printf '%s\n' "$CTX" | grep -q "$NOTE" && printf yes || printf no)"

printf 'user thread marker\n' >> "$TMP/vlay/Threads.md"
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "init: user Threads.md lines preserved" 'yes' "$(grep -q '^user thread marker$' "$TMP/vlay/Threads.md" && printf yes || printf no)"

DTITLE=$(awk -F= -v k=dashboard_seed_title '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
DNOTE=$(awk -F= -v k=dashboard_seed_note '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
t; assert_eq "init: Dashboard.md seeded from i18n title and note" 'yes' "$([ -f "$TMP/vlay/$(cmd_name emoji)/Dashboard.md" ] && grep -qF "$DTITLE" "$TMP/vlay/$(cmd_name emoji)/Dashboard.md" && grep -qF "$DNOTE" "$TMP/vlay/$(cmd_name emoji)/Dashboard.md" && printf yes || printf no)"

printf 'user dashboard marker\n' >> "$TMP/vlay/$(cmd_name emoji)/Dashboard.md"
QUIPU_VAULT="$TMP/vlay" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "init: user Dashboard.md lines preserved" 'yes' "$(grep -q '^user dashboard marker$' "$TMP/vlay/$(cmd_name emoji)/Dashboard.md" && printf yes || printf no)"

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

# ---- context output bound (C-16/C-17) ----

mkvault vctxb
printf 'lang=en\n' >> "$TMP/vctxb/.quipu/config"
: > "$TMP/vctxb/.quipu/index.tsv"
: > "$TMP/vctxb/.quipu/activity.log"
awk 'BEGIN { for (i=1; i<=200; i++) printf "thread line %03d padding padding padding\n", i }' > "$TMP/vctxb/Threads.md"

t; QUIPU_CTX_MAX=1000 QUIPU_VAULT="$TMP/vctxb" sh "$ROOT/quipu" context > "$TMP/vctxb.out"
SIZE=$(wc -c < "$TMP/vctxb.out" | tr -d ' ')
assert_eq "context bound: body within QUIPU_CTX_MAX" 'yes' "$([ "$SIZE" -le 1000 ] && printf yes || printf no)"
t; assert_eq "context bound: activity header present" 'yes' "$(grep -q '^recent activity$' "$TMP/vctxb.out" && printf yes || printf no)"
t; assert_eq "context bound: index header present" 'yes' "$(grep -q '^index stats$' "$TMP/vctxb.out" && printf yes || printf no)"
t; assert_eq "context bound: last threads line cut" 'no' "$(grep -q 'thread line 200' "$TMP/vctxb.out" && printf yes || printf no)"

# T-42: multibyte lines must survive the cut as valid UTF-8 (C-17).
mkvault vctxu
printf 'lang=en\n' >> "$TMP/vctxu/.quipu/config"
: > "$TMP/vctxu/.quipu/index.tsv"
: > "$TMP/vctxu/.quipu/activity.log"
awk 'BEGIN { for (i=1; i<=60; i++) printf "İstanbul ğüşiöç 🔮 日本語 — line %d\n", i }' > "$TMP/vctxu/Threads.md"

t; QUIPU_CTX_MAX=800 QUIPU_VAULT="$TMP/vctxu" sh "$ROOT/quipu" context > "$TMP/vctxu.out"
if LC_ALL=C awk '
  BEGIN { for (i = 0; i < 256; i++) ORD[sprintf("%c", i)] = i; need = 0 }
  {
    for (i = 1; i <= length($0); i++) {
      b = ORD[substr($0, i, 1)]
      if (need > 0) {
        if (b < 128 || b > 191) { bad = 1; exit 1 }
        need--
      } else if (b < 128) {
        continue
      } else if (b >= 194 && b <= 223) {
        need = 1
      } else if (b >= 224 && b <= 239) {
        need = 2
      } else if (b >= 240 && b <= 244) {
        need = 3
      } else {
        bad = 1; exit 1
      }
    }
  }
  END { if (need > 0) exit 1 }
' "$TMP/vctxu.out"; then
  VUTF=yes
else
  VUTF=no
fi
assert_eq "context bound: truncated multibyte output is valid UTF-8" 'yes' "$VUTF"

# T-43: the truncation marker appears exactly once.
CTRUNC=$(awk -F= -v k=ctx_truncated '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
t; assert_eq "context bound: truncated marker appears exactly once" '1' "$(grep -F -c "$CTRUNC" "$TMP/vctxb.out")"

# T-44: truncated --json stays valid and round-trips to the plain output.
t; CTXBJSON=$(QUIPU_CTX_MAX=1000 QUIPU_VAULT="$TMP/vctxb" sh "$ROOT/quipu" context --json SessionStart)
CTXBDEC=$(printf '%s' "$CTXBJSON" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
CTXBPLAIN=$(QUIPU_CTX_MAX=1000 QUIPU_VAULT="$TMP/vctxb" sh "$ROOT/quipu" context)
assert_eq "context bound: truncated --json round-trips to plain" "$CTXBPLAIN" "$CTXBDEC"

# ---- context nudge (C-19/C-20) ----

mkvault vnudge
QUIPU_VAULT="$TMP/vnudge" sh "$ROOT/quipu" init --plain >/dev/null 2>&1
printf 'lang=en\n' >> "$TMP/vnudge/.quipu/config"
for _n in 1 2 3; do
  printf '2026-08-20T10:0%s | PostToolUse | Read | nudge%s.md\n' "$_n" "$_n" >> "$TMP/vnudge/.quipu/activity.log"
done

CPREC=$(awk -F= -v k=ctx_precompact '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")
# shellcheck disable=SC2059
CPREC_EXPECT=$(printf "$CPREC" '700-Sessions')

t; NJ=$(QUIPU_NUDGE_AFTER=2 QUIPU_VAULT="$TMP/vnudge" sh "$ROOT/quipu" context --json UserPromptSubmit)
ND=$(printf '%s' "$NJ" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "nudge: UserPromptSubmit adds ctx_precompact" 'yes' "$(printf '%s\n' "$ND" | grep -F -q "$CPREC_EXPECT" && printf yes || printf no)"
t; assert_eq "nudge: .quipu/nudged created" 'yes' "$([ -f "$TMP/vnudge/.quipu/nudged" ] && printf yes || printf no)"
t; assert_eq "nudge: .quipu/nudged equals last log line" '2026-08-20T10:03 | PostToolUse | Read | nudge3.md' "$(cat "$TMP/vnudge/.quipu/nudged")"

t; NJ2=$(QUIPU_NUDGE_AFTER=2 QUIPU_VAULT="$TMP/vnudge" sh "$ROOT/quipu" context --json UserPromptSubmit)
ND2=$(printf '%s' "$NJ2" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "nudge: not repeated without new lines" 'no' "$(printf '%s\n' "$ND2" | grep -F -q "$CPREC_EXPECT" && printf yes || printf no)"

for _n in 4 5 6; do
  printf '2026-08-20T10:0%s | PostToolUse | Read | nudge%s.md\n' "$_n" "$_n" >> "$TMP/vnudge/.quipu/activity.log"
done
t; NJ3=$(QUIPU_NUDGE_AFTER=2 QUIPU_VAULT="$TMP/vnudge" sh "$ROOT/quipu" context --json UserPromptSubmit)
ND3=$(printf '%s' "$NJ3" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "nudge: re-triggers after threshold re-crossed" 'yes' "$(printf '%s\n' "$ND3" | grep -F -q "$CPREC_EXPECT" && printf yes || printf no)"

mkvault vnudge9
QUIPU_VAULT="$TMP/vnudge9" sh "$ROOT/quipu" init --plain >/dev/null 2>&1
printf 'lang=en\n' >> "$TMP/vnudge9/.quipu/config"
printf '2026-08-20T10:00 | PostToolUse | Read | nudge9.md\n' >> "$TMP/vnudge9/.quipu/activity.log"
t; NJ9=$(QUIPU_NUDGE_AFTER=999 QUIPU_VAULT="$TMP/vnudge9" sh "$ROOT/quipu" context --json UserPromptSubmit)
ND9=$(printf '%s' "$NJ9" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "nudge: threshold never reached -> no ctx_precompact" 'no' "$(printf '%s\n' "$ND9" | grep -F -q "$CPREC_EXPECT" && printf yes || printf no)"
t; assert_eq "nudge: .quipu/nudged not created" 'no' "$([ -f "$TMP/vnudge9/.quipu/nudged" ] && printf yes || printf no)"

# ---- remember (FAZ 3) ----

i18n() { awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt"; }
mkrem() { QUIPU_VAULT="$TMP/$1" sh "$ROOT/quipu" init --plain >/dev/null 2>&1; }
rem() { _r_v=$1; shift; QUIPU_VAULT="$TMP/$_r_v" QUIPU_LANG=en sh "$ROOT/quipu" remember "$@"; }

D=$(date +%Y-%m-%d)
REM_EMPTY=$(i18n remember_empty)
REM_GIT=$(i18n remember_git)

mkrem vr30
t; OUT=$(rem vr30); RC=$?
assert_eq "remember: empty log leaves nothing behind" 'yes' \
  "$([ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "$REM_EMPTY" && [ ! -f "$TMP/vr30/700-Sessions/$D.md" ] && [ ! -f "$TMP/vr30/Last-Session.md" ] && [ ! -f "$TMP/vr30/.quipu/remembered" ] && printf yes || printf no)"

mkrem vr31
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' '2026-08-20T10:01 | PostToolUse | Read | 300-Projects/p.md' '2026-08-20T10:02 | PostToolUse | Write | 000-Inbox/i.md' >> "$TMP/vr31/.quipu/activity.log"
t; OUT=$(rem vr31); RC=$?
assert_eq "remember: writes session file and watermark" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -s "$TMP/vr31/700-Sessions/$D.md" ] && grep -qF '## ' "$TMP/vr31/700-Sessions/$D.md" && grep -qF '500-Knowledge/not.md' "$TMP/vr31/700-Sessions/$D.md" && [ "$(cat "$TMP/vr31/.quipu/remembered")" = '2026-08-20T10:02 | PostToolUse | Write | 000-Inbox/i.md' ] && printf yes || printf no)"

printf '%s\n' '2026-08-20T10:03 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr31/.quipu/activity.log"
t; OUT=$(rem vr31); RC=$?
assert_eq "remember: appends second section same day" 'yes' \
  "$([ "$RC" -eq 0 ] && [ "$(grep -c '^## ' "$TMP/vr31/700-Sessions/$D.md")" = 2 ] && grep -qF '2026-08-20T10:00' "$TMP/vr31/700-Sessions/$D.md" && printf yes || printf no)"

t; BEFORE=$(wc -l < "$TMP/vr31/700-Sessions/$D.md" | tr -d ' ')
OUT=$(rem vr31); RC=$?
assert_eq "remember: no new lines is a no-op" 'yes' \
  "$([ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "$REM_EMPTY" && [ "$(wc -l < "$TMP/vr31/700-Sessions/$D.md" | tr -d ' ')" = "$BEFORE" ] && printf yes || printf no)"

printf '%s\n' '2026-08-20T11:00 | PostToolUse | Edit | 500-Knowledge/new.md' > "$TMP/vr31/.quipu/activity.log"
printf '%s\n' '2026-08-20T11:01 | PostToolUse | Read | 500-Knowledge/new.md' >> "$TMP/vr31/.quipu/activity.log"
t; BEFORE=$(grep -c '## ' "$TMP/vr31/700-Sessions/$D.md")
OUT=$(rem vr31); RC=$?
assert_eq "remember: rotation reprocesses whole log" 'yes' \
  "$([ "$RC" -eq 0 ] && [ "$(grep -c '## ' "$TMP/vr31/700-Sessions/$D.md")" = "$((BEFORE + 1))" ] && printf yes || printf no)"

mkrem vr35
printf 'user marker L1\n' > "$TMP/vr35/Last-Session.md"
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr35/.quipu/activity.log"
rem vr35 >/dev/null 2>&1
printf '%s\n' '2026-08-20T10:01 | PostToolUse | Read | 500-Knowledge/other.md' >> "$TMP/vr35/.quipu/activity.log"
rem vr35 >/dev/null 2>&1
t; assert_eq "remember: Last-Session keeps user line and one block" 'yes' \
  "$(grep -qF 'user marker L1' "$TMP/vr35/Last-Session.md" && [ "$(grep -c 'quipu:start' "$TMP/vr35/Last-Session.md")" = 1 ] && printf yes || printf no)"

mkrem vr36
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr36/.quipu/activity.log"
t; OUT=$(rem vr36 --dry-run); RC=$?
assert_eq "remember: dry-run prints but writes nothing" 'yes' \
  "$([ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF '## ' && printf '%s\n' "$OUT" | grep -qF 'Range: ' && [ ! -f "$TMP/vr36/700-Sessions/$D.md" ] && [ ! -f "$TMP/vr36/Last-Session.md" ] && [ ! -f "$TMP/vr36/.quipu/remembered" ] && printf yes || printf no)"

mkrem vr37
printf '%s\n' \
  '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' \
  '2026-08-20T10:01 | PostToolUse | Edit | 500-Knowledge/not.md' \
  '2026-08-20T10:02 | PostToolUse | Read | 500-Knowledge/not.md' \
  '2026-08-20T10:03 | PostToolUse | Read | 500-Knowledge/other.md' \
  >> "$TMP/vr37/.quipu/activity.log"
t; OUT=$(rem vr37); RC=$?
F37A=$(printf '  - %2d  %s' 3 '500-Knowledge/not.md')
F37B=$(printf '  - %2d  %s' 1 '500-Knowledge/other.md')
assert_eq "remember: digest counts tools and files" 'yes' \
  "$([ "$RC" -eq 0 ] && grep -qF 'Edit 2' "$TMP/vr37/700-Sessions/$D.md" && grep -qF 'Read 2' "$TMP/vr37/700-Sessions/$D.md" && grep -qF "$F37A" "$TMP/vr37/700-Sessions/$D.md" && grep -qF "$F37B" "$TMP/vr37/700-Sessions/$D.md" && printf yes || printf no)"

mkrem vr38
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/a.md' >> "$TMP/vr38/.quipu/activity.log"
printf '%s\n' '2026-08-20T10:01 | PostToolUse | Read | 500-Knowledge/b.md' >> "$TMP/vr38/.quipu/activity.log"
t; OUT=$(rem vr38 --limit 1); RC=$?
assert_eq "remember: --limit 1 lists one file" 'yes' \
  "$([ "$RC" -eq 0 ] && [ "$(grep -c '  - ' "$TMP/vr38/700-Sessions/$D.md")" = 1 ] && printf yes || printf no)"

mkrem vr39
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr39/.quipu/activity.log"
t; OUT=$(rem vr39 --git); RC=$?
assert_eq "remember: --git outside a repo is a no-op" 'yes' \
  "$([ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF 'wrote:' && [ "$(printf '%s\n' "$OUT" | grep -cF "$REM_GIT")" = 0 ] && printf yes || printf no)"

mkrem vr40
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr40/.quipu/activity.log"
git init -q "$TMP/vr40"
t; OUT=$(GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t QUIPU_VAULT="$TMP/vr40" QUIPU_LANG=en sh "$ROOT/quipu" remember --git); RC=$?
GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t QUIPU_VAULT="$TMP/vr40" QUIPU_LANG=en sh "$ROOT/quipu" remember --git >/dev/null 2>&1; RC2=$?
assert_eq "remember: --git commits once and skips empty" 'yes' \
  "$([ "$RC" -eq 0 ] && [ "$(git -C "$TMP/vr40" log --oneline | wc -l | tr -d ' ')" = 1 ] && printf '%s\n' "$OUT" | grep -qF "$REM_GIT" && [ "$RC2" -eq 0 ] && [ "$(git -C "$TMP/vr40" log --oneline | wc -l | tr -d ' ')" = 1 ] && printf yes || printf no)"

mkrem vr50
printf 'not a valid log line\n' > "$TMP/vr50/.quipu/activity.log"
t; OUT=$(rem vr50); RC=$?
assert_eq "remember: malformed log is a no-op" 'yes' \
  "$([ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "$REM_EMPTY" && [ ! -f "$TMP/vr50/700-Sessions/$D.md" ] && [ ! -f "$TMP/vr50/Last-Session.md" ] && [ ! -f "$TMP/vr50/.quipu/remembered" ] && printf yes || printf no)"

# ---- FAZ 3 E-4: claude-code adapter (data) + QUIPU_HOOK silent success ----

# T-46: adapter is pure data — no Windows shell cruft, no .sh in commands.
t; BAD=$(grep -E 'conhost|cmd\.exe' "$ROOT/adapters/claude-code.json")
assert_eq "adapter: no conhost/cmd.exe" '' "$BAD"
t; BAD=$(grep -oE '"command": "[^"]*"' "$ROOT/adapters/claude-code.json" | grep -E '\.sh')
assert_eq "adapter: no .sh in any command" '' "$BAD"

# T-47: every command is prefixed QUIPU_HOOK=1 quipu, every shell is bash,
# and "async": true appears exactly once (the PostToolUse hook).
t; CMDS=$(grep -cE '"command": "' "$ROOT/adapters/claude-code.json")
PREFIXED=$(grep -cE '"command": "QUIPU_HOOK=1 quipu ' "$ROOT/adapters/claude-code.json")
assert_eq "adapter: every command starts with QUIPU_HOOK=1 quipu" "$CMDS" "$PREFIXED"
t; SHELLS=$(grep -cE '"shell": "' "$ROOT/adapters/claude-code.json")
BASHES=$(grep -cE '"shell": "bash"' "$ROOT/adapters/claude-code.json")
assert_eq "adapter: every shell is bash" "$SHELLS" "$BASHES"
t; ASYNC=$(grep -c '"async": true' "$ROOT/adapters/claude-code.json")
assert_eq "adapter: exactly one async hook" '1' "$ASYNC"

# T-48: QUIPU_HOOK turns _q_die into a silent success — exit 0 instead of the
# error code, while the message still reaches stderr. A vault-less cwd (no
# QUIPU_VAULT override, no .quipu/config ancestor) triggers _q_die err_no_vault.
mkdir -p "$TMP/t48"
t; (cd "$TMP/t48" && QUIPU_HOOK=1 sh "$ROOT/quipu" remember) >/dev/null 2>"$TMP/t48a.err"; RC=$?
assert_eq "hook: remember no vault exits 0 with stderr" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -s "$TMP/t48a.err" ] && printf yes || printf no)"
t; (cd "$TMP/t48" && sh "$ROOT/quipu" remember) >/dev/null 2>"$TMP/t48b.err"; RC=$?
assert_eq "no-hook: remember no vault exits 1 with stderr" 'yes' \
  "$([ "$RC" -eq 1 ] && [ -s "$TMP/t48b.err" ] && printf yes || printf no)"
t; printf '%s\n' '{"hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"x.md"}}' | (cd "$TMP/t48" && QUIPU_HOOK=1 sh "$ROOT/quipu" capture) >/dev/null 2>"$TMP/t48c.err"; RC=$?
assert_eq "hook: capture no vault exits 0 with stderr" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -s "$TMP/t48c.err" ] && printf yes || printf no)"
t; printf '%s\n' '{"hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"x.md"}}' | (cd "$TMP/t48" && sh "$ROOT/quipu" capture) >/dev/null 2>"$TMP/t48d.err"; RC=$?
assert_eq "no-hook: capture no vault exits 1 with stderr" 'yes' \
  "$([ "$RC" -eq 1 ] && [ -s "$TMP/t48d.err" ] && printf yes || printf no)"

# T-49: doctor claude hooks line (C-28): settings with quipu -> installed,
# settings without quipu -> not installed. Both runs exit 0.
mkdir -p "$TMP/fakeh/.claude"
printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"quipu context --json SessionStart"}]}]}}\n' > "$TMP/fakeh/.claude/settings.json"
t; (cd "$TMP" && HOME="$TMP/fakeh" QUIPU_LANG=en sh "$ROOT/quipu" doctor) >"$TMP/fakeh1.out" 2>&1; RC=$?
assert_eq "doctor: hooks installed when settings has quipu" 'yes' \
  "$([ "$RC" -eq 0 ] && awk -F"$TAB" '$2=="claude hooks" && $3=="installed" {f=1} END {exit !f}' "$TMP/fakeh1.out" && printf yes || printf no)"
printf '{}\n' > "$TMP/fakeh/.claude/settings.json"
t; (cd "$TMP" && HOME="$TMP/fakeh" QUIPU_LANG=en sh "$ROOT/quipu" doctor) >"$TMP/fakeh2.out" 2>&1; RC=$?
assert_eq "doctor: hooks not installed when settings lacks quipu" 'yes' \
  "$([ "$RC" -eq 0 ] && awk -F"$TAB" '$2=="claude hooks" && $3=="not installed" {f=1} END {exit !f}' "$TMP/fakeh2.out" && printf yes || printf no)"

# ---- FAZ 4: codex adapter (data) + static checks (T-54..T-56) ----

# T-54: four event keys present, no PreCompact (K-11).
t; EVENTS=$(grep -cE '"(SessionStart|UserPromptSubmit|PostToolUse|SessionEnd)":' "$ROOT/adapters/codex/hooks.json")
assert_eq "codex adapter: four events present, no PreCompact" 'yes' \
  "$([ "$EVENTS" = 4 ] && ! grep -q 'PreCompact' "$ROOT/adapters/codex/hooks.json" && printf yes || printf no)"

# T-55: no "shell" field, "env" key, conhost, cmd.exe, or .sh (K-14/K-16).
t; BAD=$(grep -E '"shell"|"env"|conhost|cmd\.exe|\.sh' "$ROOT/adapters/codex/hooks.json")
assert_eq "codex adapter: no shell/env/conhost/cmd.exe/.sh" '' "$BAD"

# T-56: every command prefixed QUIPU_HOOK=1 quipu, commandWindows count matches,
# "async": true exactly once, PostToolUse matcher is apply_patch (K-12/K-13/K-15).
t; CMDS=$(grep -cE '"command":' "$ROOT/adapters/codex/hooks.json")
WINS=$(grep -cE '"commandWindows":' "$ROOT/adapters/codex/hooks.json")
PREFIXED=$(grep -cE '"command": "QUIPU_HOOK=1 quipu ' "$ROOT/adapters/codex/hooks.json")
ASYNC=$(grep -c '"async": true' "$ROOT/adapters/codex/hooks.json")
MATCHER=$(grep -c '"matcher": "apply_patch"' "$ROOT/adapters/codex/hooks.json")
assert_eq "codex adapter: prefixed commands, windows parity, one async, apply_patch matcher" 'yes' \
  "$([ "$CMDS" = 4 ] && [ "$WINS" = 4 ] && [ "$PREFIXED" = "$CMDS" ] && [ "$ASYNC" = 1 ] && [ "$MATCHER" = 1 ] && printf yes || printf no)"

# ---- capture: Windows-form path normalization (FAZ 3, live layer finding) ----

if command -v cygpath >/dev/null 2>&1; then
  mkvault vcapwin
  WINTMP=$(cygpath -w "$TMP/vcapwin")
  # The backslashes below are DATA inside single quotes (PLAN 4.11).
  t; QUIPU_VAULT="$TMP/vcapwin" sh "$ROOT/quipu" capture --event PostToolUse --tool Edit --path "$WINTMP\\500-Knowledge\\not.md"
  assert_eq "capture: Windows path becomes vault-relative" 'PostToolUse | Edit | 500-Knowledge/not.md' "$(log_line "$TMP/vcapwin")"
else
  t; skip "capture: Windows path becomes vault-relative" "cygpath not installed"
fi

# ---- FAZ 5: capture --git (T-57..T-64, T-69, T-70) + context --bridge (T-65..T-68, T-71) ----

git_commit() { # dir msg
  git -C "$TMP/$1" add -A
  GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
    git -C "$TMP/$1" commit -qm "$2"
}
mk_git_vault() { # dir -> mkvault + git init + initial commit
  mkvault "$1"
  git init -q "$TMP/$1"
  git_commit "$1" init
}

# T-57: one changed tracked .md -> one gitdiff line.
mk_git_vault vgit57
printf 'v1\n' > "$TMP/vgit57/note.md"
git_commit vgit57 add-note
printf 'v2\n' >> "$TMP/vgit57/note.md"
t; QUIPU_VAULT="$TMP/vgit57" sh "$ROOT/quipu" capture --git
assert_eq "capture --git: one changed .md -> one line" 'gitdiff | git | note.md' "$(log_line "$TMP/vgit57")"

# T-58: multi-file diff -> one line per file, exact count.
mk_git_vault vgit58
printf 'a\n' > "$TMP/vgit58/a.md"
printf 'b\n' > "$TMP/vgit58/b.md"
printf 'c\n' > "$TMP/vgit58/c.md"
git_commit vgit58 add
printf 'a2\n' >> "$TMP/vgit58/a.md"
printf 'b2\n' >> "$TMP/vgit58/b.md"
printf 'c2\n' >> "$TMP/vgit58/c.md"
t; QUIPU_VAULT="$TMP/vgit58" sh "$ROOT/quipu" capture --git
assert_eq "capture --git: multi-file diff -> 3 lines" '3' "$(awk 'END{print NR}' "$TMP/vgit58/.quipu/activity.log")"

# T-59: untracked new .md -> captured via ls-files --others.
mk_git_vault vgit59
printf 'new\n' > "$TMP/vgit59/new.md"
t; QUIPU_VAULT="$TMP/vgit59" sh "$ROOT/quipu" capture --git
assert_eq "capture --git: untracked new .md captured" 'gitdiff | git | new.md' "$(log_line "$TMP/vgit59")"

# T-60: non-.md change -> no line (H-4 filter).
mk_git_vault vgit60
printf 'd\n' > "$TMP/vgit60/data.txt"
git_commit vgit60 add-txt
printf 'd2\n' >> "$TMP/vgit60/data.txt"
t; OUT=$(QUIPU_VAULT="$TMP/vgit60" sh "$ROOT/quipu" capture --git); RC=$?
assert_eq "capture --git: non-md change -> no line" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ ! -s "$TMP/vgit60/.quipu/activity.log" ] && printf yes || printf no)"

# T-61: AGENTS.md / CLAUDE.md change -> no line (H-4).
mk_git_vault vgit61
printf '# a\n' > "$TMP/vgit61/AGENTS.md"
printf '# c\n' > "$TMP/vgit61/CLAUDE.md"
git_commit vgit61 add-bridge
printf '# a2\n' >> "$TMP/vgit61/AGENTS.md"
printf '# c2\n' >> "$TMP/vgit61/CLAUDE.md"
t; OUT=$(QUIPU_VAULT="$TMP/vgit61" sh "$ROOT/quipu" capture --git); RC=$?
assert_eq "capture --git: AGENTS.md/CLAUDE.md change -> no line" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ ! -s "$TMP/vgit61/.quipu/activity.log" ] && printf yes || printf no)"

# T-62 (DZ-8b): vault that is not a repo -> silent exit 0; "git yok" left [doğrulanmadı].
mkvault vgit62
printf 'x\n' > "$TMP/vgit62/note.md"
t; OUT=$(QUIPU_VAULT="$TMP/vgit62" sh "$ROOT/quipu" capture --git); RC=$?
assert_eq "capture --git: not a repo -> silent exit 0" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ ! -s "$TMP/vgit62/.quipu/activity.log" ] && printf yes || printf no)"

# T-63: clean tree -> exit 0, no line.
mk_git_vault vgit63
printf 'x\n' > "$TMP/vgit63/note.md"
git_commit vgit63 add
t; OUT=$(QUIPU_VAULT="$TMP/vgit63" sh "$ROOT/quipu" capture --git); RC=$?
assert_eq "capture --git: clean tree -> silent exit 0" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ ! -s "$TMP/vgit63/.quipu/activity.log" ] && printf yes || printf no)"

# T-64: deleted .md -> recorded (H-9; index `drop` handles it later).
mk_git_vault vgit64
printf 'x\n' > "$TMP/vgit64/gone.md"
git_commit vgit64 add
rm "$TMP/vgit64/gone.md"
t; QUIPU_VAULT="$TMP/vgit64" sh "$ROOT/quipu" capture --git
assert_eq "capture --git: deleted .md recorded" 'gitdiff | git | gone.md' "$(log_line "$TMP/vgit64")"

# T-69 (DZ-2): unborn HEAD + untracked .md -> no abort, line present (ls-files path).
mkvault vgit69
git init -q "$TMP/vgit69"
printf 'x\n' > "$TMP/vgit69/note.md"
t; OUT=$(QUIPU_VAULT="$TMP/vgit69" sh "$ROOT/quipu" capture --git); RC=$?
assert_eq "capture --git: unborn HEAD + untracked .md -> line present" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ "$(log_line "$TMP/vgit69")" = 'gitdiff | git | note.md' ] && printf yes || printf no)"

# T-70 (DZ-3): .md under .quipu/ -> filtered out (prefix test, not the old filter).
mk_git_vault vgit70
printf 'x\n' > "$TMP/vgit70/.quipu/secret.md"
t; OUT=$(QUIPU_VAULT="$TMP/vgit70" sh "$ROOT/quipu" capture --git); RC=$?
assert_eq "capture --git: .quipu/ .md filtered out" 'yes' \
  "$([ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ ! -s "$TMP/vgit70/.quipu/activity.log" ] && printf yes || printf no)"

# ---- context --bridge (T-65..T-68, T-71) ----

# T-65: context block + context text inside; static block and user content preserved.
mkvault vbridge
printf 'user line 1\nuser line 2\n' > "$TMP/vbridge/AGENTS.md"
printf 'static body\n' | awk -f "$LIB/block.awk" "$TMP/vbridge/AGENTS.md" > "$TMP/vbridge/.quipu/t.tmp" && mv "$TMP/vbridge/.quipu/t.tmp" "$TMP/vbridge/AGENTS.md"
printf '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md\n' >> "$TMP/vbridge/.quipu/activity.log"
t; QUIPU_LANG=en QUIPU_VAULT="$TMP/vbridge" sh "$ROOT/quipu" context --bridge >/dev/null 2>&1
assert_eq "context --bridge: context block + user content + static block preserved" 'yes' \
  "$(grep -q '^<!-- quipu:context:start -->$' "$TMP/vbridge/AGENTS.md" \
     && grep -q '^<!-- quipu:context:end -->$' "$TMP/vbridge/AGENTS.md" \
     && grep -q '^<!-- quipu:start -->$' "$TMP/vbridge/AGENTS.md" \
     && grep -q '^user line 1$' "$TMP/vbridge/AGENTS.md" \
     && grep -q '^user line 2$' "$TMP/vbridge/AGENTS.md" \
     && grep -q '500-Knowledge/not.md' "$TMP/vbridge/AGENTS.md" && printf yes || printf no)"

# T-66: idempotent — second run does not duplicate the block.
t; QUIPU_LANG=en QUIPU_VAULT="$TMP/vbridge" sh "$ROOT/quipu" context --bridge >/dev/null 2>&1
assert_eq "context --bridge: idempotent (single context block)" '1' "$(grep -c 'quipu:context:start' "$TMP/vbridge/AGENTS.md")"

# T-67: stdout carries only the confirmation, not the raw context (i18n, QUIPU_LANG=en).
t; OUT=$(QUIPU_LANG=en QUIPU_VAULT="$TMP/vbridge" sh "$ROOT/quipu" context --bridge); RC=$?
BRIDGE_OK=$(i18n bridge_updated)
assert_eq "context --bridge: stdout only confirmation" "$BRIDGE_OK" "$OUT"

# T-68 (DZ-5): -v override targets the context markers (conditional BEGIN).
: > "$TMP/t68.md"
printf 'ctx body\n' | awk -v start='<!-- quipu:context:start -->' -v end='<!-- quipu:context:end -->' -f "$LIB/block.awk" "$TMP/t68.md" > "$TMP/t68.out"
t; assert_eq "block.awk: -v override replaces default markers" 'yes' \
  "$(grep -q '^<!-- quipu:context:start -->$' "$TMP/t68.out" && grep -q '^ctx body$' "$TMP/t68.out" && ! grep -q '^<!-- quipu:start -->$' "$TMP/t68.out" && printf yes || printf no)"

# T-71 (DZ-5): without -v the exact default markers are preserved (literal lock).
: > "$TMP/t71.md"
printf 'default body\n' | awk -f "$LIB/block.awk" "$TMP/t71.md" > "$TMP/t71.out"
t; assert_eq "block.awk: default markers exact text" 'yes' \
  "$(grep -q '^<!-- quipu:start -->$' "$TMP/t71.out" && grep -q '^<!-- quipu:end -->$' "$TMP/t71.out" && grep -q '^default body$' "$TMP/t71.out" && printf yes || printf no)"

# ---- FAZ 6: e2e chain scenarios (T-72..T-73) ----

# T-72 (I-2): the whole chain in one vault — init -> flag-mode capture -> index
# -> search. Each step's exit code is asserted on its own (SPEC 3, T-72), so a
# regression is pinned to one link instead of surfacing only at the last hop.
# `init` now pins fold=tr itself (V1-DUZELTME R-1), so no manual config patch
# is needed (P-6). QUIPU_LANG is deliberately NOT set on this init call: it
# would outrank the just-written config lang=tr in the _q_lang chain and pin
# fold=default instead (`init --lang tr` alone is enough; only the message
# text of the LATER commands needs QUIPU_LANG=en for ASCII stability).
t; QUIPU_VAULT="$TMP/vchain" sh "$ROOT/quipu" init --lang tr >/dev/null 2>&1; RC=$?
assert_eq "chain: init exits 0" '0' "$RC"
printf '# Notlar\n\nAlpha zincir notu.\n' > "$TMP/vchain/note.md"

# Flag-mode capture needs no JSON fixture (G-4) — the chain stays hermetic.
t; QUIPU_VAULT="$TMP/vchain" QUIPU_LANG=en sh "$ROOT/quipu" capture --event PostToolUse --tool Write --path note.md; RC=$?
assert_eq "chain: capture exits 0" '0' "$RC"
t; assert_eq "chain: capture appends the flag-mode line" 'PostToolUse | Write | note.md' "$(log_line "$TMP/vchain")"

t; QUIPU_VAULT="$TMP/vchain" QUIPU_LANG=en sh "$ROOT/quipu" index >/dev/null 2>&1; RC=$?
assert_eq "chain: index exits 0" '0' "$RC"

t; CHAIN_HIT=$(QUIPU_VAULT="$TMP/vchain" QUIPU_LANG=en sh "$ROOT/quipu" search alpha | awk -F"$TAB" 'NR==1{print $2}')
assert_eq "chain: search returns the captured note" 'note.md' "$CHAIN_HIT"

# T-73 (I-3): the Turkish form of the same chain. The note says "İstanbul ışık";
# indexing folds it, so the lowercase query hits, and the dotted-capital query
# must return the byte-identical result set — index folding == query folding all
# the way along the chain (SPEC 4.2 in chain form). `init` pins fold=tr itself
# (R-1); QUIPU_LANG is withheld on this call for the same reason as T-72 (P-6).
QUIPU_VAULT="$TMP/vchaintr" sh "$ROOT/quipu" init --lang tr >/dev/null 2>&1
printf '# Işık\n\nİstanbul ışık deneyleri burada.\n' > "$TMP/vchaintr/istanbul.md"
QUIPU_VAULT="$TMP/vchaintr" QUIPU_LANG=en sh "$ROOT/quipu" capture --event PostToolUse --tool Write --path istanbul.md >/dev/null 2>&1
QUIPU_VAULT="$TMP/vchaintr" QUIPU_LANG=en sh "$ROOT/quipu" index >/dev/null 2>&1

t; CHAIN_TR_LOWER=$(QUIPU_VAULT="$TMP/vchaintr" QUIPU_LANG=en sh "$ROOT/quipu" search istanbul | awk -F"$TAB" '{print $2}')
assert_eq "chain tr: lowercase query returns the folded note" 'istanbul.md' "$CHAIN_TR_LOWER"

# Dotted capital İ (U+0130): same path list, or the folding broke mid-chain.
t; CHAIN_TR_UPPER=$(QUIPU_VAULT="$TMP/vchaintr" QUIPU_LANG=en sh "$ROOT/quipu" search İstanbul | awk -F"$TAB" '{print $2}')
assert_eq "chain tr: dotted-capital query matches lowercase run" "$CHAIN_TR_LOWER" "$CHAIN_TR_UPPER"

# ---- FAZ 6: index summary shape + git chain + doctor (T-74..T-77) ----

# T-74 (I-4): first index run. The exact line is locked against the i18n
# template under QUIPU_LANG=en, then the same counts are re-read through
# language-independent field extraction so a translation change cannot mask a
# counting bug.
mk_index_vault vidx74
(cd "$TMP/vidx74" && QUIPU_LANG=en "$ROOT/quipu" index) >"$TMP/vidx74.out" 2>&1
# idx_summary is the controlled i18n template (not user data); args are integers.
# shellcheck disable=SC2059
EXP74=$(printf "$(awk -F= -v k=idx_summary '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ROOT/i18n/en.txt")" 3 0 3 0)
t; assert_eq "index: first run summary is the exact idx_summary line" "$EXP74" "$(cat "$TMP/vidx74.out")"
t; assert_eq "index: first run fields are 3 0 3 0" '3 0 3 0' "$(idx_nums "$TMP/vidx74.out")"

# T-75 (I-4): an unchanged second run reuses every row; touching one file makes
# exactly that row stale and leaves the other two reused.
(cd "$TMP/vidx74" && QUIPU_LANG=en "$ROOT/quipu" index) >"$TMP/vidx74.out" 2>&1
t; assert_eq "index: unchanged second run reuses 3, stale 0" '3 3 0 0' "$(idx_nums "$TMP/vidx74.out")"
sleep 1
touch "$TMP/vidx74/heading.md"
(cd "$TMP/vidx74" && QUIPU_LANG=en "$ROOT/quipu" index) >"$TMP/vidx74.out" 2>&1
t; assert_eq "index: one touched file leaves stale 1, reused 2" '3 2 1 0' "$(idx_nums "$TMP/vidx74.out")"

# T-76 (I-5): the git chain in one vault — init --git -> commit -> note.md ->
# capture --git -> index -> search hit -> remember --git (which commits by
# itself) -> commit leftovers -> capture --git again. The core claim is the last
# one: the commit consumed the diff, so no second gitdiff line appears (H-9
# honesty proven end to end). `init` pins fold=tr itself (R-1); QUIPU_LANG is
# withheld on this call for the same reason as T-72/T-73 (P-6). gitdiff lines
# are counted with awk index() rather than grep, keeping the pattern policy
# uniform (PLAN 4.3).
mkdir -p "$TMP/vgitchain"
QUIPU_VAULT="$TMP/vgitchain" sh "$ROOT/quipu" init --git --lang tr >/dev/null 2>&1
git_commit vgitchain init
printf 'Alpha git zinciri notu.\n' > "$TMP/vgitchain/note.md"

t; QUIPU_VAULT="$TMP/vgitchain" sh "$ROOT/quipu" capture --git
assert_eq "git chain: first capture --git logs one gitdiff line" '1' \
  "$(awk 'index($0, "gitdiff") > 0 {c++} END{print c+0}' "$TMP/vgitchain/.quipu/activity.log")"

t; (cd "$TMP/vgitchain" && QUIPU_LANG=en "$ROOT/quipu" index) >"$TMP/vgitchain.idx" 2>&1; RC=$?
assert_eq "git chain: index after capture exits 0" '0' "$RC"

t; assert_eq "git chain: search alpha returns note.md" 'note.md' \
  "$(QUIPU_VAULT="$TMP/vgitchain" QUIPU_LANG=en sh "$ROOT/quipu" search alpha | awk 'NR==1{print $2}')"

GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
  QUIPU_VAULT="$TMP/vgitchain" QUIPU_LANG=en sh "$ROOT/quipu" remember --git >/dev/null 2>&1
# remember --git already committed; this only drains anything it left behind and
# must not fail the run when the tree is clean.
git_commit vgitchain after-remember >/dev/null 2>&1 || true

t; QUIPU_VAULT="$TMP/vgitchain" sh "$ROOT/quipu" capture --git
assert_eq "git chain: capture --git after the commit adds no gitdiff line" '1' \
  "$(awk 'index($0, "gitdiff") > 0 {c++} END{print c+0}' "$TMP/vgitchain/.quipu/activity.log")"

# T-77 (I-6): doctor over the full chain vault. The summary wording and the ok /
# warn counts are free to move (claude hooks are not installed here), so only the
# trailing number — the failure count — is asserted, language-independently.
t; (cd "$TMP/vgitchain" && QUIPU_LANG=en "$ROOT/quipu" doctor) >"$TMP/vgitchain.doc" 2>&1; RC=$?
assert_eq "doctor: chain vault exits 0" '0' "$RC"
t; assert_eq "doctor: chain vault summary reports 0 fail" '0' \
  "$(awk 'END{ gsub(/[^0-9]/, " "); n = split($0, f, " "); print f[n] }' "$TMP/vgitchain.doc")"

# ---- FAZ 7: DZ-4 unknown flag diagnosis (T-78..T-81) ----

# DZ-4: an unrecognized flag must name itself and exit 2 on every command that
# parses flags, while the legacy "missing required argument" diagnosis stays
# byte-identical. err_unknown_flag is the controlled i18n template; the only
# argument is the flag itself.
# shellcheck disable=SC2059
FLAG_MSG=$(printf "$(i18n err_unknown_flag)\n" --bogus)

# T-78: capture.
mkvault vflag78
t; QUIPU_VAULT="$TMP/vflag78" QUIPU_LANG=en sh "$ROOT/quipu" capture --bogus \
  </dev/null >/dev/null 2>"$TMP/vflag78-capture.err"; RC=$?
assert_eq "capture --bogus exits 2" '2' "$RC"
t; assert_eq "capture --bogus names the flag" "$FLAG_MSG" "$(cat "$TMP/vflag78-capture.err")"

# T-79: same diagnosis from init / context / remember.
for _c in init context remember; do
  t; QUIPU_VAULT="$TMP/vflag78" QUIPU_LANG=en sh "$ROOT/quipu" "$_c" --bogus \
    </dev/null >/dev/null 2>"$TMP/vflag78-$_c.err"; RC=$?
  assert_eq "$_c --bogus exits 2" '2' "$RC"
  t; assert_eq "$_c --bogus names the flag" "$FLAG_MSG" "$(cat "$TMP/vflag78-$_c.err")"
done

# T-80: search must diagnose the flag instead of swallowing it as a query word.
# The vault is fully indexed, so nothing but the flag can fail the run.
mk_search_vault vflag80
QUIPU_VAULT="$TMP/vflag80" sh "$ROOT/quipu" index >/dev/null 2>&1
t; QUIPU_VAULT="$TMP/vflag80" QUIPU_LANG=en sh "$ROOT/quipu" search --bogus \
  >"$TMP/vflag80.out" 2>"$TMP/vflag80.err"; RC=$?
assert_eq "search --bogus exits 2" '2' "$RC"
t; assert_eq "search --bogus names the flag" "$FLAG_MSG" "$(cat "$TMP/vflag80.err")"
t; assert_eq "search --bogus prints no results" '' "$(cat "$TMP/vflag80.out")"

# T-81 regression: `_q_die key code` callers are untouched — a known flag
# starved of its value still gets the old message, with no flag interpolation.
t; QUIPU_VAULT="$TMP/vflag78" QUIPU_LANG=en sh "$ROOT/quipu" capture --event \
  </dev/null >/dev/null 2>"$TMP/vflag78-event.err"; RC=$?
assert_eq "capture --event without value exits 2" '2' "$RC"
t; assert_eq "capture --event without value keeps err_missing_arg" \
  "$(i18n err_missing_arg)" "$(cat "$TMP/vflag78-event.err")"
t; assert_eq "capture --event without value mentions no flag" 'no' \
  "$(grep -qE 'unknown|--bogus' "$TMP/vflag78-event.err" && printf yes || printf no)"

# ---- FAZ 7: search --brief (T-82..T-84) ----

# The search fixture plus one document whose folded field is far longer than
# the 120-byte snippet window, so the cut path is actually exercised.
mk_search_vault vbrief
awk 'BEGIN{ s = "alpha"; for (i = 1; i <= 48; i++) s = s " wordnumber" i; print "# longdoc"; print ""; print s }' > "$TMP/vbrief/long-doc.md"
QUIPU_VAULT="$TMP/vbrief" sh "$ROOT/quipu" index >/dev/null 2>&1

# T-82 (J-5): --brief adds a 5th TAB field, never wider than 120 bytes, and a
# folded field that already fits is carried through uncut.
#
# Byte vs character: gawk counts length()/substr() in CHARACTERS, mawk in
# BYTES. The claim below is a byte claim, so it only holds while every row
# matching `alpha` is pure ASCII — which it is: the fixture pins fold=tr, and
# the three matching documents (title-doc / body-doc / long-doc) are ASCII to
# begin with (measured: 194 bytes == 194 awk chars for the whole column).
# Do NOT add a matching document with non-ASCII folded text without switching
# this assertion to a real byte count.
BRIEF=$(QUIPU_VAULT="$TMP/vbrief" QUIPU_LANG=en sh "$ROOT/quipu" search alpha --brief)
t; assert_eq "search --brief: every row has 5 fields" 'yes' "$(printf '%s\n' "$BRIEF" | awk -F"$TAB" '{if (NF != 5) bad++} END{print (bad ? "no" : "yes")}')"
t; assert_eq "search --brief: snippet is at most 120 bytes" 'yes' "$(printf '%s\n' "$BRIEF" | awk -F"$TAB" '{if (length($5) > 120) bad++} END{print (bad ? "no" : "yes")}')"
t; SHORT_FULL=$(awk -F"$TAB" '$1 == "body-doc.md" { print $5 }' "$TMP/vbrief/.quipu/index.tsv")
assert_eq "search --brief: short field is emitted whole" "$SHORT_FULL" "$(printf '%s\n' "$BRIEF" | awk -F"$TAB" '$2 == "body-doc.md" { print $5 }')"

# T-83 (J-5): the long document's snippet stops on a word boundary. Proof: it
# does not end with a space, and in the full folded field the byte right after
# the snippet IS a space, so no word was split. The snippet and the full field
# reach awk as file arguments (never `awk -v`, which would mangle raw data).
QUIPU_VAULT="$TMP/vbrief" QUIPU_LANG=en sh "$ROOT/quipu" search alpha --brief \
  | awk -F"$TAB" '$2 == "long-doc.md" { print $5 }' > "$TMP/vbrief-brief.txt"
awk -F"$TAB" '$1 == "long-doc.md" { print $5 }' "$TMP/vbrief/.quipu/index.tsv" > "$TMP/vbrief-full.txt"
t; assert_eq "search --brief: snippet has no trailing space" 'yes' "$(awk 'NR == 1 { print (substr($0, length($0), 1) == " " ? "no" : "yes") }' "$TMP/vbrief-brief.txt")"
t; assert_eq "search --brief: cut lands on a word boundary" 'yes' "$(awk 'FNR == 1 && NR == 1 { b = $0; next } FNR == 1 { print (substr($0, 1, length(b)) == b && substr($0, length(b) + 1, 1) == " " ? "yes" : "no") }' "$TMP/vbrief-brief.txt" "$TMP/vbrief-full.txt")"

# T-84 (J-6): --brief and --paths are mutually exclusive.
t; QUIPU_VAULT="$TMP/vbrief" QUIPU_LANG=en sh "$ROOT/quipu" search alpha --brief --paths >"$TMP/vbrief-conf.out" 2>"$TMP/vbrief-conf.err"; RC=$?
assert_eq "search --brief --paths exits 2" '2' "$RC"
t; assert_eq "search --brief --paths reports the conflict" "$(i18n err_conflict)" "$(cat "$TMP/vbrief-conf.err")"

# ---- V1-DUZELTME: CRLF-authored tag stays CR-free (--brief row safety) ----
#
# CI run 32576726590 (commit d955757, ubuntu-latest + macos-latest only;
# windows-latest passed) failed "scale: --brief rows have 5 fields" and
# "scale: --brief honours --limit 50 at scale" (expected 50, got 52). The
# SAME run's non-brief "scale: search returns all 5000 hits" (T-86) passed at
# an exact 5000/5000, which rules out a matching/count bug in path/title/tags
# and isolates the failure to the brief-only path (the extra snippet
# column). A later run (32578854473, commit fdf1218) reproduced the identical
# split ubuntu+macos fail / windows pass, confirming it tracks the AWK
# implementation (mawk on ubuntu, BWK awk on macOS; gawk ships with Git Bash
# on windows-latest), not the OS by itself.
#
# Investigation found a real, implementation-sensitive gap upstream of
# search.awk: lib/index.awk's trim_() strips CR from a title (gsub(CR, "",
# s)), but collect_tags() — used for BOTH frontmatter "tags:" values and body
# "#hashtag" scanning — never did. A CRLF-authored note hands collect_tags a
# $0 with a trailing \r still attached (only \n is a record separator to
# awk); when that \r lands on a line's LAST token (e.g. a trailing "#tag"),
# whether it survives split(s, parts, " ") depends on whether that specific
# awk's whitespace-splitting treats \r as blank. gawk does, which quietly
# masked the gap here (verified locally: this exact CRLF fixture round-trips
# clean under gawk even without the fix below) — nothing guarantees mawk or
# BWK awk do too. lib/index.awk's collect_tags() now strips CR itself
# (gsub(CR, "", s) before squish_brackets/split), independent of whichever
# awk's split(" ") happens to treat as whitespace. lib/search.awk additionally
# gained a scrub() choke point (title/tags/snippet all pass through it before
# printf) as defense in depth: whatever the exact byte-level mechanism behind
# the ubuntu/macos --brief split turns out to be, no field reaching that
# printf can carry a raw TAB/CR/LF into the emitted row.
#
# NOT independently reproduced at 5000-doc scale here: real `quipu index`
# costs ~6 subprocess spawns per stale file, and this environment measured
# ~3.7s/file (vs. 27s TOTAL for all 5000 files on ubuntu-latest CI) — a real
# 5000-doc index would run for hours, not the ~40 minutes the scale test
# already costs on a normal Linux runner, so it was not attempted here. This
# fixture instead pins the ONE gap identified by static+dynamic (gawk)
# investigation: it would have failed before the collect_tags() fix (an
# unfixed run leaves the \r on the tag, so index.tsv's tags column and its
# length() both come out dirty) and passes after it, on the only awk (gawk)
# available in this environment.
mkdir -p "$TMP/vcrlf/.quipu"
printf 'fold=default\nlang=en\n' > "$TMP/vcrlf/.quipu/config"
CRB=$(printf '\r')
printf '# crlf note%s\n%s\nortakterim body #tag1 #tag2%s\n' "$CRB" "$CRB" "$CRB" > "$TMP/vcrlf/crlf-doc.md"
QUIPU_VAULT="$TMP/vcrlf" sh "$ROOT/quipu" index >/dev/null 2>&1
t; assert_eq "index: CRLF-authored tag has no embedded CR" '9' \
  "$(awk -F"$TAB" '$1 == "crlf-doc.md" { print length($3) }' "$TMP/vcrlf/.quipu/index.tsv")"
t; assert_eq "index: CRLF-authored tag value is exactly tag1,tag2" 'tag1,tag2' \
  "$(awk -F"$TAB" '$1 == "crlf-doc.md" { print $3 }' "$TMP/vcrlf/.quipu/index.tsv")"
BRIEFCRLF=$(QUIPU_VAULT="$TMP/vcrlf" QUIPU_LANG=en sh "$ROOT/quipu" search ortakterim --brief)
t; assert_eq "search --brief: CRLF-doc row is one line with 5 fields" 'yes' \
  "$(printf '%s\n' "$BRIEFCRLF" | awk -F"$TAB" '{n++; if (NF != 5) bad=1} END{print (n == 1 && bad != 1) ? "yes" : "no"}')"

# ---- FAZ 7: scale, 5000 docs (T-85..T-87) ----

# J-7 turns the "5000 notes" claim into a measurement instead of a sentence in
# prose, on Linux, macOS and Windows alike. The corpus is generated here by one
# loop and never committed: ~100 bytes per note, a term every document shares
# (`ortakterim`) plus a per-file unique term. Note 1 additionally carries a long
# ASCII word run, so the 120-byte --brief cut is exercised at scale too.
printf '# info: scale vault: generating 5000 docs\n'
mkvault vscale
printf 'fold=tr\nlang=en\n' > "$TMP/vscale/.quipu/config"
i=1
while [ "$i" -le 5000 ]; do
  printf '# not %s\n\nortakterim tekil%s satir govdesi burada duruyor ve kisa kaliyor.\n' "$i" "$i" > "$TMP/vscale/n$i.md"
  i=$((i + 1))
done
awk 'BEGIN{ s = "ortakterim tekil1"; for (i = 1; i <= 48; i++) s = s " wordnumber" i; print "# not 1"; print ""; print s }' > "$TMP/vscale/n1.md"

# T-85 (J-7): a cold index over 5000 documents completes and indexes every one
# of them. On Windows/msys each stale file costs ~6 process spawns, which is the
# cost J-7 exists to expose, so the number that matters is the printed one.
printf '# info: scale vault: indexing 5000 docs (this takes minutes on Windows)\n'
START=$(date +%s)
QUIPU_VAULT="$TMP/vscale" QUIPU_LANG=en sh "$ROOT/quipu" index > "$TMP/vscale.out" 2>&1
END=$(date +%s)
t; assert_eq "scale: index of a clean 5000-doc vault counts 5000" '5000 0 5000 0' "$(idx_nums "$TMP/vscale.out")"
t; assert_eq "scale: index.tsv has 5000 rows" '5000' "$(awk 'END{print NR}' "$TMP/vscale/.quipu/index.tsv")"
printf '# info: index 5000 docs: %s s\n' "$((END - START))"
# 3600s is a hang/regression ceiling, not a performance claim; the real number is
# printed above (measured 2150-2367 s for 5000 docs on Windows msys across two runs —
# ~0.43-0.47 s/doc, dominated by ~6 process spawns per file; Linux and macOS are far faster).
t; assert_eq "scale: index 5000 docs within bound" 'yes' "$([ $((END - START)) -lt 3600 ] && printf yes || printf no)"

# T-86 (J-7): search over the 5000-row index stays interactive. `ortakterim` is
# in every document, so --limit 5000 must return all 5000 rows.
START=$(date +%s)
QUIPU_VAULT="$TMP/vscale" QUIPU_LANG=en sh "$ROOT/quipu" search ortakterim --limit 5000 > "$TMP/vscale-search.out" 2>&1
END=$(date +%s)
t; assert_eq "scale: search returns all 5000 hits" '5000' "$(awk 'END{print NR}' "$TMP/vscale-search.out")"
printf '# info: search 5000-doc index: %s s\n' "$((END - START))"
t; assert_eq "scale: search on a 5000-doc index within bound" 'yes' "$([ $((END - START)) -lt 30 ] && printf yes || printf no)"

# T-87 (J-7): the --brief contract (5 TAB fields, snippet capped at 120 bytes)
# and --limit hold at scale, not just on the six-document fixture.
QUIPU_VAULT="$TMP/vscale" QUIPU_LANG=en sh "$ROOT/quipu" search ortakterim --limit 50 --brief > "$TMP/vscale-brief.out" 2>&1
t; assert_eq "scale: --brief rows have 5 fields" 'yes' "$(awk -F"$TAB" '{if (NF != 5) bad++} END{print (bad ? "no" : "yes")}' "$TMP/vscale-brief.out")"
t; assert_eq "scale: --brief snippet is at most 120 bytes" 'yes' "$(awk -F"$TAB" '{if (length($5) > 120) bad++} END{print (bad ? "no" : "yes")}' "$TMP/vscale-brief.out")"
t; assert_eq "scale: --brief honours --limit 50 at scale" '50' "$(awk 'END{print NR}' "$TMP/vscale-brief.out")"

# ---- V1-DUZELTME: fold profile pinning + index self-refresh (T-88..T-95) ----

# T-88 (R-1): `init --lang tr` pins fold=tr; `init` with no --lang flag under
# LC_ALL=C pins fold=default. QUIPU_LANG must stay unset on these calls — see
# the P-6 note on T-72 above: it would outrank the config lang= just written
# and corrupt the derivation.
t; QUIPU_VAULT="$TMP/vt88tr" sh "$ROOT/quipu" init --lang tr >/dev/null 2>&1; RC=$?
assert_eq "T-88: init --lang tr exits 0" '0' "$RC"
t; assert_eq "T-88: init --lang tr pins fold=tr" 'tr' \
  "$(awk -F= -v k=fold '$1==k{sub(/^[^=]*=/,"");print;exit}' "$TMP/vt88tr/.quipu/config")"

t; QUIPU_VAULT="$TMP/vt88def" LC_ALL=C sh "$ROOT/quipu" init >/dev/null 2>&1; RC=$?
assert_eq "T-88: init without --lang exits 0" '0' "$RC"
t; assert_eq "T-88: init without --lang under LC_ALL=C pins fold=default" 'default' \
  "$(awk -F= -v k=fold '$1==k{sub(/^[^=]*=/,"");print;exit}' "$TMP/vt88def/.quipu/config")"

# T-89 (R-2): a second `init --lang en` updates lang= but never touches an
# already-pinned fold=.
t; QUIPU_VAULT="$TMP/vt89" sh "$ROOT/quipu" init --lang tr >/dev/null 2>&1; RC=$?
assert_eq "T-89: first init --lang tr exits 0" '0' "$RC"
t; QUIPU_VAULT="$TMP/vt89" sh "$ROOT/quipu" init --lang en >/dev/null 2>&1; RC=$?
assert_eq "T-89: second init --lang en exits 0" '0' "$RC"
t; assert_eq "T-89: second init updates lang=en" 'en' \
  "$(awk -F= -v k=lang '$1==k{sub(/^[^=]*=/,"");print;exit}' "$TMP/vt89/.quipu/config")"
t; assert_eq "T-89: fold=tr survives the second init" 'tr' \
  "$(awk -F= -v k=fold '$1==k{sub(/^[^=]*=/,"");print;exit}' "$TMP/vt89/.quipu/config")"

# T-90 (R-2): a hand-written fold= is never overwritten by `init`, known or
# unknown profile alike.
mkdir -p "$TMP/vt90/.quipu"
printf 'fold=latin\n' > "$TMP/vt90/.quipu/config"
t; QUIPU_VAULT="$TMP/vt90" sh "$ROOT/quipu" init --lang tr >/dev/null 2>&1; RC=$?
assert_eq "T-90: init over a hand-written fold= exits 0" '0' "$RC"
t; assert_eq "T-90: init never overwrites a hand-written fold=" 'latin' \
  "$(awk -F= -v k=fold '$1==k{sub(/^[^=]*=/,"");print;exit}' "$TMP/vt90/.quipu/config")"

# T-91 (P-3 regression): the exact live scenario from V1-DUZELTME-BULGULAR.md.
# init --lang tr -> note -> index -> a SECOND note added and indexed under
# QUIPU_LANG=en. Before R-1/R-4 the second note's folded field kept its raw
# Turkish diacritics (a different profile than the first note) and was
# unreachable by any query; now both rows fold with the SAME pinned profile.
t; QUIPU_VAULT="$TMP/vt91" sh "$ROOT/quipu" init --lang tr >/dev/null 2>&1; RC=$?
assert_eq "T-91: init --lang tr exits 0" '0' "$RC"
printf '# dpi\n\nİkinci monitörde taşbar taşması.\n' > "$TMP/vt91/dpi.md"
t; QUIPU_VAULT="$TMP/vt91" QUIPU_LANG=en sh "$ROOT/quipu" index >/dev/null 2>&1; RC=$?
assert_eq "T-91: first index exits 0" '0' "$RC"

printf '# dpi2\n\nÜçüncü monitörde ölçek sorunu.\n' > "$TMP/vt91/dpi2.md"
t; QUIPU_VAULT="$TMP/vt91" QUIPU_LANG=en sh "$ROOT/quipu" index >/dev/null 2>&1; RC=$?
assert_eq "T-91: second index (QUIPU_LANG=en) exits 0" '0' "$RC"

t; assert_eq "T-91: no raw Turkish letter survives in any folded column" 'yes' \
  "$(awk -F"$TAB" '{if ($5 ~ /[ışİÜüÖö]/) bad++} END{print (bad ? "no" : "yes")}' "$TMP/vt91/.quipu/index.tsv")"
t; assert_eq "T-91: QUIPU_LANG=en search monitor finds both notes" '2' \
  "$(QUIPU_VAULT="$TMP/vt91" QUIPU_LANG=en sh "$ROOT/quipu" search monitor | awk 'END{print NR}')"

# T-92 (R-3): doctor's fold check — absent fold= warns (exit stays 0), an
# unknown profile fails (exit 1). doc_summary's last number is read back
# language-independently, same technique as idx_nums above.
mkdir -p "$TMP/vt92a/.quipu"
printf 'layout=emoji\nlang=en\n' > "$TMP/vt92a/.quipu/config"
t; QUIPU_VAULT="$TMP/vt92a" QUIPU_LANG=en sh "$ROOT/quipu" doctor >"$TMP/vt92a.out" 2>&1; RC=$?
assert_eq "T-92: doctor with no fold= exits 0" '0' "$RC"
t; assert_eq "T-92: doctor with no fold= warns" 'yes' \
  "$(awk -F"$TAB" '$2=="fold profile" && $1=="warn" {f=1} END{exit !f}' "$TMP/vt92a.out" && printf yes || printf no)"

mkdir -p "$TMP/vt92b/.quipu"
printf 'layout=emoji\nlang=en\nfold=yokboyleprofil\n' > "$TMP/vt92b/.quipu/config"
t; QUIPU_VAULT="$TMP/vt92b" QUIPU_LANG=en sh "$ROOT/quipu" doctor >"$TMP/vt92b.out" 2>&1; RC=$?
assert_eq "T-92: doctor with unknown fold= exits 1" '1' "$RC"
t; assert_eq "T-92: doc_summary's last field (fail count) is 1" '1' \
  "$(awk '/^summary:/{ gsub(/[^0-9]/," "); s=""; for (i=1;i<=NF;i++) if ($i!="") s=s (s==""?"":" ") $i; n=split(s,a," "); print a[n] }' "$TMP/vt92b.out")"

# T-93 (R-4): `_q_fold_prof` is the single source for both index and search —
# a profile-specific fold (fold=latin: Straße -> strasse) shows up identically
# in index.tsv column 5 and in the search hit.
mkdir -p "$TMP/vt93/.quipu"
printf 'fold=latin\nlang=en\n' > "$TMP/vt93/.quipu/config"
printf '# strasse\n\nStraße Notizen hier.\n' > "$TMP/vt93/strasse.md"
t; QUIPU_VAULT="$TMP/vt93" QUIPU_LANG=en sh "$ROOT/quipu" index >/dev/null 2>&1; RC=$?
assert_eq "T-93: index under fold=latin exits 0" '0' "$RC"
t; assert_eq "T-93: index.tsv column 5 folds Straße to strasse" '# strasse  strasse notizen hier.' \
  "$(awk -F"$TAB" '$1=="strasse.md"{print $5}' "$TMP/vt93/.quipu/index.tsv")"
t; assert_eq "T-93: search strasse hits the same latin-folded document" 'strasse.md' \
  "$(QUIPU_VAULT="$TMP/vt93" QUIPU_LANG=en sh "$ROOT/quipu" search strasse | awk -F"$TAB" 'NR==1{print $2}')"

# T-94 (R-5): adapter data, static check (T-54..T-56 pattern) — SessionEnd
# runs `index` after `remember` in both adapters, commandWindows included.
t; assert_eq "claude-code adapter: SessionEnd command runs index" 'yes' \
  "$(awk '/"SessionEnd"/,/\]/' "$ROOT/adapters/claude-code.json" | grep -q '"command":.*quipu index' && printf yes || printf no)"
t; assert_eq "codex adapter: SessionEnd command runs index" 'yes' \
  "$(awk '/"SessionEnd"/,/\]/' "$ROOT/adapters/codex/hooks.json" | grep -q '"command":.*quipu index' && printf yes || printf no)"
t; assert_eq "codex adapter: SessionEnd commandWindows runs index" 'yes' \
  "$(awk '/"SessionEnd"/,/\]/' "$ROOT/adapters/codex/hooks.json" | grep -q '"commandWindows":.*quipu index' && printf yes || printf no)"

# T-95 (R-6): the hook path stays silent on `index`, the same H-7 rule as the
# other commands; the index is still written.
mk_index_vault vt95
t; OUT=$(QUIPU_VAULT="$TMP/vt95" QUIPU_HOOK=1 sh "$ROOT/quipu" index 2>"$TMP/vt95.err"); RC=$?
assert_eq "T-95: QUIPU_HOOK=1 index exits 0" '0' "$RC"
t; assert_eq "T-95: QUIPU_HOOK=1 index prints nothing to stdout" '' "$OUT"
t; assert_eq "T-95: QUIPU_HOOK=1 index prints nothing to stderr" '' "$(cat "$TMP/vt95.err")"
t; assert_eq "T-95: index.tsv is still written" '3' "$(awk 'END{print NR}' "$TMP/vt95/.quipu/index.tsv")"

# ---- FAZ 8: reflection block + missed-reflection catcher (T-96..T-108) ----

# T-96: the first `remember` appends a reflection block; the three headings
# come from i18n (QUIPU_LANG=en).
mkrem vr96
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr96/.quipu/activity.log"
t; rem vr96 >/dev/null 2>&1
assert_eq "reflect: first remember appends a block with three i18n headings" 'yes' \
  "$(grep -q '^<!-- quipu:reflect:start -->$' "$TMP/vr96/700-Sessions/$D.md" \
     && grep -q '^<!-- quipu:reflect:end -->$' "$TMP/vr96/700-Sessions/$D.md" \
     && grep -qF "### $(i18n reflect_head_what)" "$TMP/vr96/700-Sessions/$D.md" \
     && grep -qF "### $(i18n reflect_head_where)" "$TMP/vr96/700-Sessions/$D.md" \
     && grep -qF "### $(i18n reflect_head_threads)" "$TMP/vr96/700-Sessions/$D.md" \
     && printf yes || printf no)"

# T-97: a model line inside the block survives a same-day second `remember`;
# no second block is added. The block sits at EOF after the first remember, so
# the end marker is re-appended around the model line (sed '$d' drops it).
sed '$d' "$TMP/vr96/700-Sessions/$D.md" > "$TMP/vr96/.tmp"
printf '%s\n' 'Model wrote this reflection line.' >> "$TMP/vr96/.tmp"
printf '%s\n' '<!-- quipu:reflect:end -->' >> "$TMP/vr96/.tmp"
mv "$TMP/vr96/.tmp" "$TMP/vr96/700-Sessions/$D.md"
printf '%s\n' '2026-08-20T10:01 | PostToolUse | Read | 500-Knowledge/other.md' >> "$TMP/vr96/.quipu/activity.log"
t; rem vr96 >/dev/null 2>&1
assert_eq "reflect: same-day second remember keeps the model line, one block" 'yes' \
  "$(grep -qF 'Model wrote this reflection line.' "$TMP/vr96/700-Sessions/$D.md" \
     && [ "$(grep -c 'quipu:reflect:start' "$TMP/vr96/700-Sessions/$D.md")" = 1 ] \
     && printf yes || printf no)"

# T-98: user text written OUTSIDE the block survives further remembers
# (append-only regression; the reflection block is never rewritten).
printf '%s\n' 'User note outside the reflection block.' >> "$TMP/vr96/700-Sessions/$D.md"
printf '%s\n' '2026-08-20T10:02 | PostToolUse | Write | 000-Inbox/i.md' >> "$TMP/vr96/.quipu/activity.log"
t; rem vr96 >/dev/null 2>&1
assert_eq "reflect: user text outside the block preserved" 'yes' \
  "$(grep -qF 'User note outside the reflection block.' "$TMP/vr96/700-Sessions/$D.md" \
     && [ "$(grep -c 'quipu:reflect:start' "$TMP/vr96/700-Sessions/$D.md")" = 1 ] \
     && printf yes || printf no)"

# T-99: a block holding only markers + headings + blank lines is EMPTY, so the
# SessionStart ask appears. (ctx_reflect_ask is the controlled i18n template;
# its two %s are the path and the marker name — SC2059 pattern.)
mkrem vr99
{
  printf '%s\n' '<!-- quipu:reflect:start -->'
  printf '### %s\n' "$(i18n reflect_head_what)"
  printf '%s\n' ''
  printf '### %s\n' "$(i18n reflect_head_where)"
  printf '%s\n' ''
  printf '### %s\n' "$(i18n reflect_head_threads)"
  printf '%s\n' ''
  printf '%s\n' '<!-- quipu:reflect:end -->'
} > "$TMP/vr99/700-Sessions/$D.md"
t; A99=$(QUIPU_VAULT="$TMP/vr99" QUIPU_LANG=en sh "$ROOT/quipu" context --json SessionStart)
A99D=$(printf '%s' "$A99" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
# shellcheck disable=SC2059
A99_EXPECT=$(printf "$(i18n ctx_reflect_ask)" "700-Sessions/$D.md" 'quipu:reflect')
assert_eq "reflect: headings and blanks do not count as content" 'yes' \
  "$(printf '%s\n' "$A99D" | grep -qF "$A99_EXPECT" && printf yes || printf no)"

# T-100: one content line makes the block filled: no ask.
mkrem vr100
{
  printf '%s\n' '<!-- quipu:reflect:start -->'
  printf '### %s\n' "$(i18n reflect_head_what)"
  printf '%s\n' ''
  printf '%s\n' 'a single reflection line'
  printf '%s\n' '<!-- quipu:reflect:end -->'
} > "$TMP/vr100/700-Sessions/$D.md"
t; A100=$(QUIPU_VAULT="$TMP/vr100" QUIPU_LANG=en sh "$ROOT/quipu" context --json SessionStart)
A100D=$(printf '%s' "$A100" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
# shellcheck disable=SC2059
A100_EXPECT=$(printf "$(i18n ctx_reflect_ask)" "700-Sessions/$D.md" 'quipu:reflect')
assert_eq "reflect: one content line -> block filled, no ask" 'no' \
  "$(printf '%s\n' "$A100D" | grep -qF "$A100_EXPECT" && printf yes || printf no)"

# T-101: an empty-block PREVIOUS day + remember -> needs_reflection written as
# "day count", the count parsed from the digest Range line ((3 events)); the
# "(top 10)" files header must NOT be counted.
mkrem vr101
{
  printf '%s\n' '## 09:00'
  printf '%s\n' 'Range: 08:00 → 09:00 (3 events)'
  printf '%s\n' 'Tools: Read 3'
  printf '%s\n' 'Touched files (top 10):'
  printf '%s\n' '  -  3  prev.md'
  printf '%s\n' '<!-- quipu:reflect:start -->'
  printf '### %s\n' "$(i18n reflect_head_what)"
  printf '%s\n' ''
  printf '%s\n' '<!-- quipu:reflect:end -->'
} > "$TMP/vr101/700-Sessions/2020-01-01.md"
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr101/.quipu/activity.log"
t; rem vr101 >/dev/null 2>&1
assert_eq "reflect: empty previous block -> needs_reflection written" '2020-01-01 3' "$(cat "$TMP/vr101/.quipu/needs_reflection")"

# T-102: SessionStart puts the missed notice in the context and deletes the
# flag (single shot).
t; M102=$(QUIPU_VAULT="$TMP/vr101" QUIPU_LANG=en sh "$ROOT/quipu" context --json SessionStart)
M102D=$(printf '%s' "$M102" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
# shellcheck disable=SC2059
M102_EXPECT=$(printf "$(i18n ctx_reflect_missed)" '2020-01-01' '3')
assert_eq "reflect: SessionStart shows missed notice and deletes the flag" 'yes' \
  "$(printf '%s\n' "$M102D" | grep -qF "$M102_EXPECT" \
     && [ ! -f "$TMP/vr101/.quipu/needs_reflection" ] && printf yes || printf no)"

# T-103: a second SessionStart carries no missed notice.
t; M103=$(QUIPU_VAULT="$TMP/vr101" QUIPU_LANG=en sh "$ROOT/quipu" context --json SessionStart)
M103D=$(printf '%s' "$M103" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "reflect: second SessionStart has no missed notice" 'no' \
  "$(printf '%s\n' "$M103D" | grep -qF "$M102_EXPECT" && printf yes || printf no)"

# T-104: a filled previous-day block -> no needs_reflection at all.
mkrem vr104
{
  printf '%s\n' '## 09:00'
  printf '%s\n' 'Range: 08:00 → 09:00 (3 events)'
  printf '%s\n' '<!-- quipu:reflect:start -->'
  printf '### %s\n' "$(i18n reflect_head_what)"
  printf '%s\n' 'filled content line'
  printf '%s\n' '<!-- quipu:reflect:end -->'
} > "$TMP/vr104/700-Sessions/2020-01-01.md"
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Edit | 500-Knowledge/not.md' >> "$TMP/vr104/.quipu/activity.log"
t; rem vr104 >/dev/null 2>&1
assert_eq "reflect: filled previous block -> no needs_reflection" 'no' \
  "$([ -f "$TMP/vr104/.quipu/needs_reflection" ] && printf yes || printf no)"

# T-105: today's empty block -> the SessionStart ask names the session path
# and the quipu:reflect marker.
mkrem vr105
{
  printf '%s\n' '<!-- quipu:reflect:start -->'
  printf '### %s\n' "$(i18n reflect_head_what)"
  printf '%s\n' ''
  printf '%s\n' '<!-- quipu:reflect:end -->'
} > "$TMP/vr105/700-Sessions/$D.md"
t; A105=$(QUIPU_VAULT="$TMP/vr105" QUIPU_LANG=en sh "$ROOT/quipu" context --json SessionStart)
A105D=$(printf '%s' "$A105" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "reflect: ask names the path and the marker" 'yes' \
  "$(printf '%s\n' "$A105D" | grep -qF "700-Sessions/$D.md" \
     && printf '%s\n' "$A105D" | grep -qF 'quipu:reflect' && printf yes || printf no)"

# T-106: the updated ctx_precompact text points at the reflection block.
mkrem vr106
printf 'lang=en\n' >> "$TMP/vr106/.quipu/config"
printf '%s\n' '2026-08-20T10:00 | PostToolUse | Read | x.md' >> "$TMP/vr106/.quipu/activity.log"
# ctx_precompact is the controlled i18n template; the argument is a folder name.
# shellcheck disable=SC2059
CP106=$(printf "$(i18n ctx_precompact)" '700-Sessions')
t; NJ106=$(QUIPU_NUDGE_AFTER=0 QUIPU_VAULT="$TMP/vr106" QUIPU_LANG=en sh "$ROOT/quipu" context --json UserPromptSubmit)
NJ106D=$(printf '%s' "$NJ106" | awk -f "$LIB/jsonfield.awk" -f "$DRV/hookctx.awk" -)
assert_eq "reflect: ctx_precompact points at the reflection block" 'yes' \
  "$(printf '%s\n' "$NJ106D" | grep -qF "$CP106" \
     && printf '%s\n' "$NJ106D" | grep -qF 'reflection block' && printf yes || printf no)"

# T-107: the AGENTS.md bridge body carries the memory protocol paragraph from
# i18n; raw reflect_/ctx_reflect_ keys never appear (a missing key would leak
# its name through _q_msg's fallback).
mkrem vr107
QUIPU_VAULT="$TMP/vr107" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "reflect: bridge protocol paragraph, no raw keys" 'yes' \
  "$(grep -qF "$(i18n bridge_reflect)" "$TMP/vr107/AGENTS.md" \
     && ! grep -qE 'reflect_head_|ctx_reflect_' "$TMP/vr107/AGENTS.md" && printf yes || printf no)"

# T-108: static honesty gates (S-5 is not repeated). python3 appears nowhere
# in quipu; the "stat " line count stays pinned at its FAZ 7 value (6: the
# mtime() wrapper plus the doctor dialect probe) — FAZ 8 adds no stat usage.
t; assert_eq "reflect: no python3, stat count pinned" '6 0' \
  "$(grep -c 'stat ' "$ROOT/quipu") $(grep -c 'python3' "$ROOT/quipu")"

# ---- FAZ 9: identity + personalized seed + runbook gates (T-110..T-120) ----

# T-110 (V-2): init --user Ada --companion Kuz -> config user=/companion=.
# --plain rides along on this SAME call so it is the vault's first-ever init:
# an unnamed init first (e.g. via mkrem, as this used to do) would seed
# companion.md with neutral defaults, and the only-if-missing guard
# (quipu:679) then skips personalization on the named init that follows,
# starving T-112 of the names it checks for. --plain also pins layout=plain
# in one shot, which CN110=$(comp_name plain) below depends on.
QUIPU_VAULT="$TMP/v110" QUIPU_LANG=en sh "$ROOT/quipu" init --plain --user Ada --companion Kuz >/dev/null 2>&1
t; assert_eq "identity: config has user and companion lines" 'yes' \
  "$(grep -q '^user=Ada$' "$TMP/v110/.quipu/config" \
     && grep -q '^companion=Kuz$' "$TMP/v110/.quipu/config" && printf yes || printf no)"

# T-111 (V-2): a second init --user Baska must never overwrite user=Ada.
QUIPU_VAULT="$TMP/v110" QUIPU_LANG=en sh "$ROOT/quipu" init --user Baska >/dev/null 2>&1
t; assert_eq "identity: second init keeps user=Ada" 'yes' \
  "$(grep -q '^user=Ada$' "$TMP/v110/.quipu/config" \
     && ! grep -q '^user=Baska$' "$TMP/v110/.quipu/config" && printf yes || printf no)"

# T-112 (V-3): the seed carries both names; no raw %s survives.
CN110=$(comp_name plain)
t; assert_eq "identity: companion.md personalized, no raw %s" 'yes' \
  "$(grep -qF 'Kuz' "$TMP/v110/$CN110/companion.md" \
     && grep -qF 'Ada' "$TMP/v110/$CN110/companion.md" \
     && ! grep -qF '%s' "$TMP/v110/$CN110/companion.md" && printf yes || printf no)"

# T-113 (V-3): unnamed init -> neutral i18n defaults, still no raw %s.
mkrem v113
t; assert_eq "identity: unnamed init uses neutral defaults, no raw %s" 'yes' \
  "$(grep -qF "$(i18n persona_default_companion)" "$TMP/v113/$(comp_name plain)/companion.md" \
     && grep -qF "$(i18n persona_default_user)" "$TMP/v113/$(comp_name plain)/companion.md" \
     && ! grep -qF '%s' "$TMP/v113/$(comp_name plain)/companion.md" && printf yes || printf no)"

# T-114 (V-3): a user-edited companion.md survives a second init (regression of
# the only-if-missing guarantee).
printf '%s\n' 'My custom persona line' >> "$TMP/v113/$(comp_name plain)/companion.md"
QUIPU_VAULT="$TMP/v113" sh "$ROOT/quipu" init >/dev/null 2>&1
t; assert_eq "identity: second init preserves edited companion.md" 'yes' \
  "$(grep -qF 'My custom persona line' "$TMP/v113/$(comp_name plain)/companion.md" \
     && ! grep -qF '%s' "$TMP/v113/$(comp_name plain)/companion.md" && printf yes || printf no)"

# T-115 (V-4): the AGENTS.md bridge body names the companion; the raw
# bridge_companion key never leaks (a missing key would print its name).
t; assert_eq "identity: bridge names companion, no raw key" 'yes' \
  "$(grep -qF 'Kuz' "$TMP/v110/AGENTS.md" \
     && ! grep -qF 'bridge_companion' "$TMP/v110/AGENTS.md" && printf yes || printf no)"

# T-116 (V-5): doctor warns when user=/companion= is absent and still exits 0.
# The identity row is extracted by its message content (both languages carry
# "user=" and "companion=" in doc_identity_missing), not by a translation.
mkvault v116
QUIPU_VAULT="$TMP/v116" QUIPU_LANG=en sh "$ROOT/quipu" init --plain >/dev/null 2>&1
t; (cd "$TMP/v116" && QUIPU_LANG=en "$ROOT/quipu" doctor) >"$TMP/v116.doc" 2>&1; RC=$?
assert_eq "identity: doctor with no identity warns, exit 0" '0' "$RC"
t; assert_eq "identity: warn row extracted language-independently" 'yes' \
  "$(awk -F"$TAB" '$3 ~ /user=/ && $3 ~ /companion=/ {found=1} END{print (found ? "yes" : "no")}' "$TMP/v116.doc")"
t; assert_eq "identity: warn row is a warn, not a fail" \
  "$(i18n doc_warn)" "$(awk -F"$TAB" '$3 ~ /user=/ {print $1; exit}' "$TMP/v116.doc")"
# With identity present the row turns ok (same extraction path).
QUIPU_VAULT="$TMP/v116" QUIPU_LANG=en sh "$ROOT/quipu" init --user Ada --companion Kuz >/dev/null 2>&1
t; (cd "$TMP/v116" && QUIPU_LANG=en "$ROOT/quipu" doctor) >"$TMP/v116b.doc" 2>&1; RC=$?
assert_eq "identity: doctor with identity ok, exit 0" '0' "$RC"
t; assert_eq "identity: ok row shows both names" 'yes' \
  "$(awk -F"$TAB" '$2=="identity" && $3=="Ada/Kuz" {found=1} END{print (found ? "yes" : "no")}' "$TMP/v116b.doc")"

# T-117 (V-2 + FAZ 7 -*) regression: --user starved of its value keeps the old
# err_missing_arg; --companion followed by a flag diagnoses that flag instead
# of swallowing it as a name.
mkvault v117
t; QUIPU_VAULT="$TMP/v117" QUIPU_LANG=en sh "$ROOT/quipu" init --user \
  >/dev/null 2>"$TMP/v117-user.err"; RC=$?
assert_eq "identity: init --user without value exits 2" '2' "$RC"
t; assert_eq "identity: init --user without value keeps err_missing_arg" \
  "$(i18n err_missing_arg)" "$(cat "$TMP/v117-user.err")"
t; QUIPU_VAULT="$TMP/v117" QUIPU_LANG=en sh "$ROOT/quipu" init --companion --bogus \
  >/dev/null 2>"$TMP/v117-comp.err"; RC=$?
assert_eq "identity: init --companion --bogus exits 2" '2' "$RC"
t; # shellcheck disable=SC2059
assert_eq "identity: init --companion --bogus names the flag" \
  "$(printf "$(i18n err_unknown_flag)\n" --bogus)" "$(cat "$TMP/v117-comp.err")"

# T-118: the four new keys exist in both languages and the key sets stay equal.
t; IDKEYS=$(for _k in persona_default_companion persona_default_user doc_identity doc_identity_missing; do
  for _f in en tr; do
    grep -q "^$_k=" "$ROOT/i18n/$_f.txt" || printf '%s:%s\n' "$_k" "$_f"
  done
done)
assert_eq "identity: FAZ 9 keys present in both languages" '' "$IDKEYS"
t; KTR9=$(awk -F= 'NF >= 1 && $1 !~ /^#/ {print $1}' "$ROOT/i18n/tr.txt" | sort)
KEN9=$(awk -F= 'NF >= 1 && $1 !~ /^#/ {print $1}' "$ROOT/i18n/en.txt" | sort)
assert_eq "identity: i18n tr/en key sets identical" "$KEN9" "$KTR9"

# T-119: static runbook gate — the platform-specific tool strings never appear
# in docs/KURULUM.md (ASCII grep; the doc is written without them).
t; BAD119=$(grep -nE 'brew|python3|osacompile|swift|apt-get|winget' "$ROOT/docs/KURULUM.md" || true)
assert_eq "runbook: no platform-specific tool strings" '' "$BAD119"

# T-120: every phase heading is present and every command the runbook calls is
# within the setup whitelist {doctor, init, index, search, context, remember} —
# compared against the usage list so no invented command can slip in.
t; MISS120=$(for _n in 0 1 2 3 4 5; do
  grep -q "^## Faz $_n " "$ROOT/docs/KURULUM.md" || printf '%s\n' "$_n"
done)
assert_eq "runbook: every phase heading present (Faz 0..5)" '' "$MISS120"
t; CMDS120=$(grep -oE 'quipu [a-z-]+' "$ROOT/docs/KURULUM.md" | awk '{print $2}' | sort -u | tr '\n' ' ' | sed 's/ $//')
assert_eq "runbook: only whitelisted commands called" 'context doctor index init remember search' "$CMDS120"
t; USAGE120=$(awk -F= '/^usage_/ {sub(/^usage_/,""); print $1}' "$ROOT/i18n/en.txt" | sort | tr '\n' ' ')
BAD120=$(for _c in $CMDS120; do
  case " $USAGE120 " in
    *" $_c "*) : ;;
    *) printf '%s\n' "$_c" ;;
  esac
done)
assert_eq "runbook: every called command exists in the usage list" '' "$BAD120"
t; assert_eq "runbook: capture command not mentioned" 'no' \
  "$(grep -qw capture "$ROOT/docs/KURULUM.md" && printf yes || printf no)"

# ---- summary ----

printf '# pass %d, fail %d, skip %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
