# quipu — index builder helpers.
#
# Contract (PLAN 4.11): this file contains NO literal backslash. Every control
# character comes from its code point, so no quoting layer can corrupt it.
# No regex is used where a plain index()/substr() scan will do.
#
# Modes (-v mode=...):
#   plan   args: <old-index> <current-list> <all-list>
#          vars: oldfile=<old-index path>  allfile=<all-list path>
#          old-index rows:   path TAB title TAB tags TAB mtime TAB folded
#          current-list rows: path TAB mtime
#          all-list rows:     path
#          emits:
#            "reuse" TAB <whole old row>   (in current-list, mtime unchanged)
#            "stale" TAB path TAB mtime    (in current-list, changed / new)
#            "carry" TAB <whole old row>   (unchanged, path still exists)
#            "drop"  TAB path              (old row whose path is gone)
#   meta   args: <file.md>        emits: title TAB tags
#   flat   stdin: folded text     emits: one squeezed line, at most `max` chars

BEGIN {
  TAB = sprintf("%c", 9)
  CR  = sprintf("%c", 13)
  FS  = TAB
  OFS = TAB
  if (max + 0 == 0) max = 2000
  buf = ""
  title = ""
  tags = ""
  ntag = 0
  nold = 0
  fm = 0
}

# ---- mode: plan -------------------------------------------------------------

mode == "plan" && FILENAME == allfile {
  if ($1 != "") exists[$1] = 1
  next
}

mode == "plan" && FILENAME == oldfile {
  oldrow[$1] = $0
  oldmt[$1] = $4
  paths[++nold] = $1
  next
}

mode == "plan" {
  if ($1 == "") next
  seen[$1] = 1
  if (($1 in oldmt) && oldmt[$1] == $2) print "reuse", oldrow[$1]
  else                                  print "stale", $1, $2
  next
}

# ---- mode: meta -------------------------------------------------------------

mode == "meta" && FNR == 1 && $0 == "---" { fm = 1; next }

mode == "meta" && fm == 1 {
  if ($0 == "---" || $0 == "...") { fm = 2; next }
  if (substr($0, 1, 6) == "title:") { if (title == "") title = trim_(substr($0, 7)) }
  if (substr($0, 1, 5) == "tags:")  { collect_tags(substr($0, 6)) }
  next
}

mode == "meta" {
  if (title == "" && substr($0, 1, 2) == "# ") title = trim_(substr($0, 3))
  collect_tags($0)
  next
}

# ---- mode: flat -------------------------------------------------------------

mode == "flat" {
  if (length(buf) >= max) next
  line = $0
  gsub(TAB, " ", line)
  gsub(CR, " ", line)
  gsub(/  */, " ", line)
  buf = buf " " line
  next
}

# ---- helpers ----------------------------------------------------------------

function trim_(s) {
  sub(/^[ ]+/, "", s)
  sub(/[ ]+$/, "", s)
  gsub(TAB, " ", s)
  gsub(CR, "", s)
  return s
}

# Replace ',' '[' ']' with spaces; character loop, no regex (PLAN 4.11).
function squish_brackets(s,   i, c, out) {
  out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "," || c == "[" || c == "]") c = " "
    out = out c
  }
  return out
}

# Collect "#word" tags and bare comma/space separated frontmatter values.
#
# CRLF note (V1-DUZELTME): trim_() strips CR for titles, but a tag scanned
# here never went through trim_ — squish_brackets()/strip_punct() only touch
# ',' '[' ']' and end-of-word punctuation, never CR. A CRLF-authored note
# hands $0 to collect_tags with a trailing \r still attached (only \n is a
# record separator to awk), and if that \r lands on the LAST token of the
# line (e.g. a trailing "#tag"), it rides along past split(" ") on any awk
# whose whitespace-splitting doesn't treat \r as blank, straight into the
# stored tag value and from there into index.tsv and search output. gawk's
# split(" ") happens to also drop \r as whitespace, which quietly masks the
# gap there but not on every awk. Strip it explicitly so the tag is clean
# regardless of implementation.
function collect_tags(s,   n, i, w, parts) {
  gsub(CR, "", s)
  s = squish_brackets(s)
  n = split(s, parts, " ")
  for (i = 1; i <= n; i++) {
    w = parts[i]
    if (substr(w, 1, 1) == "#") {
      if (w !~ /^#[0-9A-Za-z_-]/) continue
      w = substr(w, 2)
    }
    else if (fm != 1) continue     # bare words are tags only inside frontmatter
    w = strip_punct(w)
    if (w == "") continue
    if (w in seen) continue
    seen[w] = 1
    ntag++
    tags = (tags == "") ? w : tags "," w
  }
}

function strip_punct(w,   c) {
  while (length(w) > 0) {
    c = substr(w, length(w), 1)
    if (c == "." || c == "," || c == ";" || c == ":" || c == "!" || c == "?" || c == ")" || c == "'" || c == sprintf("%c", 34)) w = substr(w, 1, length(w) - 1)
    else break
  }
  return w
}

END {
  if (mode == "meta") print title, tags
  if (mode == "flat") { sub(/^[ ]+/, "", buf); print substr(buf, 1, max) }
  if (mode == "plan") {
    for (i = 1; i <= nold; i++) {
      p = paths[i]
      if (!(p in exists)) print "drop", p
      else if (!(p in seen)) print "carry", oldrow[p]
    }
  }
}
