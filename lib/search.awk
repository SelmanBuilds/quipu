# quipu — search.awk: lexical BM25 ranker over .quipu/index.tsv (Katman 3).
#
# Input  : index.tsv rows (stdin or file arg), 5 TAB-separated fields:
#          yol  başlık  etiketler  mtime  katlanmış-alan
#          (columns 2/3 are RAW as written by quipu index; column 5 is the
#           folded, single-space-squeezed search field.)
# Invoke : awk -v mode=bm25 -v terms="..." -f lib/search.awk index.tsv
#          `terms` is the query, already folded to ASCII and lowercased by
#          the caller (same fold profile + tr 'A-Z' 'a-z' as the index).
#          Add -v brief=1 -v snip=120 to request the snippet column (J-5).
# Output : skor<TAB>yol<TAB>başlık<TAB>etiketler   (skor %.3f). Documents that
#          match no query term are suppressed.
#          With brief=1 a 5th TAB-separated column is appended: the leading
#          `snip` units (default 120) of the folded field, trimmed back to
#          the last word boundary inside that window so no word is split.
#          A field no longer than `snip` is emitted whole. The snippet
#          carries no marker and no ellipsis, and the cut uses only
#          substr()/length()/index() — no regex, no gsub — so the PLAN 4.11
#          no-literal-backslash contract still holds. Without brief the
#          4-column row is emitted byte-for-byte as before.
#
#          `snip` unit caveat: length()/substr() count CHARACTERS in gawk but
#          BYTES in mawk/BWK awk, so `snip` is a byte budget only where the
#          folded field is ASCII — which is what the tr fold profile produces.
#          Under fold=default the field keeps its multi-byte characters, so a
#          window with no space in it can be cut mid-character on byte-based
#          awks. Accepted limitation (FAZ 7 L-5), not a correctness bug: the
#          snippet is a display hint, never a key or a matching input.
#
# Contract (PLAN 4.11): no literal backslash; no regex beyond split()/index()
# (both take plain string separators). Word matching pads each field with
# spaces and searches " terim " via index(), so "ac" never matches "acik".
# Title/tag boosts compare the folded term against the RAW title/tag fields,
# so they fire only when those fields already equal the folded form (e.g.
# plain-ASCII words). Documented limitation of FAZ 1 lexical search.
#
# Fallback: if no query term word-matches ANY document (e.g. the user typed a
# prefix such as "istan"), matching degrades to a substring scan via
# index(katlanmış, terim); tf becomes the substring occurrence count and the
# title/tag boosts become substring checks too. This keeps prefix queries
# usable at the cost of precision (PLAN Dilim 3).

BEGIN {
  TAB = sprintf("%c", 9)
  FS  = TAB
  OFS = TAB
  k1 = 1.2
  b  = 0.75
  n = 0
  qc = split(terms, qw, " ")
  fallback = 0
  if (snip + 0 <= 0) snip = 120
}

{
  n++
  path[n]   = $1
  title[n]  = $2
  tags[n]   = $3
  folded[n] = $5
}

END {
  if (n == 0 || qc == 0) exit 0

  # ---- pass 1: document frequency, doc word counts, average length --------
  sumlen = 0
  total  = 0
  for (t = 1; t <= qc; t++) df[qw[t]] = 0
  for (d = 1; d <= n; d++) {
    dl[d] = split(folded[d], w, " ")
    sumlen += dl[d]
    pad = " " folded[d] " "
    for (t = 1; t <= qc; t++) {
      term = qw[t]
      if (term == "") continue
      if (index(pad, " " term " ") > 0) {
        df[term]++
        total++
      }
    }
  }
  avgdl = (n > 0 && sumlen > 0) ? (sumlen / n) : 1

  # Substring fallback when no term word-matched any document.
  if (total == 0) {
    fallback = 1
    for (t = 1; t <= qc; t++) df[qw[t]] = 0
    for (d = 1; d <= n; d++) {
      for (t = 1; t <= qc; t++) {
        term = qw[t]
        if (term == "") continue
        if (index(folded[d], term) > 0) df[term]++
      }
    }
  }

  # ---- pass 2: BM25 score and emit -----------------------------------------
  for (d = 1; d <= n; d++) {
    score = 0
    matched = 0
    pad = " " folded[d] " "
    ptitle = " " title[d] " "
    ntag = split(tags[d], ta, ",")
    for (t = 1; t <= qc; t++) {
      term = qw[t]
      if (term == "") continue
      if (fallback) {
        tf = count_occ(folded[d], term)
      } else {
        tf = count_occ(pad, " " term " ")
      }
      if (tf == 0) continue
      matched = 1
      idf = log((n - df[term] + 0.5) / (df[term] + 0.5))
      contrib = idf * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (dl[d] / avgdl)))
      if (fallback) {
        if (index(title[d], term) > 0) contrib *= 2
        if (index(tags[d], term) > 0) contrib *= 1.5
      } else {
        if (index(ptitle, " " term " ") > 0) contrib *= 2
        for (j = 1; j <= ntag; j++) {
          if (ta[j] == term) { contrib *= 1.5; break }
        }
      }
      score += contrib
    }
    if (matched) {
      if (brief + 0) {
        printf "%.3f%c%s%c%s%c%s%c%s%c", score, 9, path[d], 9, title[d], 9, tags[d], 9, snippet(folded[d], snip), 10
      } else {
        printf "%.3f%c%s%c%s%c%s%c", score, 9, path[d], 9, title[d], 9, tags[d], 10
      }
    }
  }
}

function count_occ(s, needle,   pos, cnt, len, rest) {
  cnt = 0
  len = length(needle)
  rest = s
  pos = index(rest, needle)
  while (pos > 0) {
    cnt++
    rest = substr(rest, pos + len)
    pos = index(rest, needle)
  }
  return cnt
}

# First `max` bytes of s, trimmed back to the last space inside the window so
# the snippet never ends mid-word. substr/length only (PLAN 4.11).
function snippet(s, max,   cut, i) {
  if (length(s) <= max) return s
  cut = substr(s, 1, max)
  for (i = length(cut); i >= 1; i--) {
    if (substr(cut, i, 1) == " ") return substr(cut, 1, i - 1)
  }
  return cut
}
