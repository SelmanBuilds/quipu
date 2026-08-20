# quipu — capture layer: turn one tool-use event (single JSON line) into
# zero or more EVENT<TAB>TOOL<TAB>PATH rows for activity.log.
# Loaded alongside jsonfield.awk (awk -f lib/jsonfield.awk -f lib/capture.awk).
#
# Dispatch is payload-shaped, not tool-name-shaped (FAZ 4, K-1):
#   * tool_input.file_path present  -> one row, unchanged (Claude Code schema)
#   * no file_path, tool_name = apply_patch -> one row per "+++ b/" target in
#     tool_input.command (unified diff); "/dev/null" targets are dropped.
#   * otherwise -> no rows.
#
# No literal backslash anywhere in this file (PLAN 4.11): control bytes come
# from code points via the jsonfield helpers (q_, bs_, tab_, cr_, nl_).
# No regex: the diff scan uses substr only (PLAN 4.8).
BEGIN { OFS = sprintf("%c", 9) }
{
  ev = jsonfield($0, "hook_event_name")
  tool = jsonfield($0, "tool_name")
  p = jsonfield_scoped($0, "tool_input", "file_path")
  if (p != "") {
    # Contract 8: no TAB/CR/LF may reach the log.
    gsub(tab_(), "", p)
    gsub(cr_(), "", p)
    gsub(nl_(), "", p)
    if (ev != "" && tool != "" && p != "") {
      print ev, tool, p
    }
    exit
  }
  # file_path absent: apply_patch carries its target paths inside the
  # unified-diff command text. Only "+++ b/" (target) headers are read;
  # "--- a/" (source) headers are never captured.
  if (tool == "apply_patch") {
    cmd = jsonfield_scoped($0, "tool_input", "command")
    if (cmd != "") {
      n = split(cmd, lines, nl_())
      for (i = 1; i <= n; i++) {
        line = lines[i]
        if (substr(line, 1, 6) == "+++ b/") {
          path = substr(line, 7)
          if (path == "/dev/null") continue
          gsub(tab_(), "", path)
          gsub(cr_(), "", path)
          gsub(nl_(), "", path)
          if (path == "") continue
          print ev, "apply_patch", path
        }
      }
    }
  }
  exit
}
