# quipu - idempotent marker-block injector (AGENTS.md bridge, PLAN Dilim 4).
# Reads the replacement body from stdin, one line per record, and joins the
# lines with sprintf("%c",10) so this file contains no literal backslash
# (PLAN 4.11, test 29).
#
# For every file argument:
#   * the span from "<!-- quipu:start -->" through "<!-- quipu:end -->"
#     inclusive is replaced by the marker pair with the new body between them;
#   * when no marker is present, the block is appended at end of file;
#   * every other line passes through verbatim (user content is preserved).

BEGIN {
  start = "<!-- quipu:start -->"
  end   = "<!-- quipu:end -->"
  body  = ""
  while ((getline line < "-") > 0) {
    if (body == "") body = line
    else body = body sprintf("%c", 10) line
  }
  close("-")
}

FNR == 1 {
  if (NR > 1 && !seen) {
    print start
    if (body != "") print body
    print end
  }
  inblk = 0
  seen  = 0
}

inblk {
  if ($0 == end) inblk = 0
  next
}

$0 == start {
  print start
  if (body != "") print body
  print end
  seen  = 1
  inblk = 1
  next
}

{
  print
}

END {
  if (!seen) {
    print start
    if (body != "") print body
    print end
  }
}
