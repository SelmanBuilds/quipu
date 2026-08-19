# quipu — JSON string field reader.
# Contract (see PLAN 4.8, 4.11, 4.12):
#   * No regex. Manual character scan only.
#   * No literal backslash anywhere in this file. Backslash is produced with
#     sprintf("%c", 92) so no quoting layer (heredoc, shell, editor) can corrupt it.
#   * Never scans tool_response: callers use jsonfield_from() with a scope anchor.
#   * Missing field returns "" instead of failing.

function q_(   ) { return sprintf("%c", 34) }   # "
function bs_(  ) { return sprintf("%c", 92) }   # backslash
function nl_(  ) { return sprintf("%c", 10) }
function tab_( ) { return sprintf("%c",  9) }
function cr_(  ) { return sprintf("%c", 13) }

# Position just past the closing quote of "key". 0 if absent.
function jf_keyend(s, key, start,   k, i) {
  if (start < 1) start = 1
  k = q_() key q_()
  i = index(substr(s, start), k)
  if (i == 0) return 0
  return start + i - 1 + length(k)
}

# Read the string value that follows position p (expects optional ws, ':', ws, '"').
function jf_read(s, p,   n, c, out, esc) {
  n = length(s)
  while (p <= n) {
    c = substr(s, p, 1)
    if (c == ":" || c == " " || c == tab_() || c == nl_() || c == cr_()) p++
    else break
  }
  if (substr(s, p, 1) != q_()) return ""   # not a string value (number/object/null)
  p++
  out = ""; esc = 0
  while (p <= n) {
    c = substr(s, p, 1)
    if (esc) {
      if      (c == "n") out = out nl_()
      else if (c == "t") out = out tab_()
      else if (c == "r") out = out cr_()
      else if (c == "b" || c == "f") { }        # dropped on purpose
      else if (c == "u") { out = out "?"; p += 4 }   # uXXXX escape -> placeholder
      else out = out c                          # covers escaped quote, backslash, slash
      esc = 0
    }
    else if (c == bs_()) esc = 1
    else if (c == q_()) return out
    else out = out c
    p++
  }
  return out
}

# Whole-string lookup. Convenience only; prefer jsonfield_from for nested keys.
function jsonfield(s, key,   e) {
  e = jf_keyend(s, key, 1)
  if (e == 0) return ""
  return jf_read(s, e)
}

# Scoped lookup: find "key" only at/after position `start`.
function jsonfield_from(s, key, start,   e) {
  e = jf_keyend(s, key, start)
  if (e == 0) return ""
  return jf_read(s, e)
}

# Position of an anchor key, for scoping. e.g. jf_anchor(s, "tool_input")
function jf_anchor(s, key) { return jf_keyend(s, key, 1) }

# The one the capture layer actually wants: tool_input.file_path, never
# matching a literal "file_path" that happens to sit inside tool_response.
function jsonfield_scoped(s, anchor, key,   a) {
  a = jf_anchor(s, anchor)
  if (a == 0) return ""
  return jsonfield_from(s, key, a)
}
