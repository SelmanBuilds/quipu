# quipu — capture layer: extract one tool-use event from a single JSON line.
# Loaded alongside jsonfield.awk (awk -f lib/jsonfield.awk -f lib/capture.awk).
# No literal backslash anywhere in this file (PLAN 4.11): control bytes come
# from code points via the jsonfield helpers (q_, bs_, tab_, cr_, nl_).
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
  }
  if (ev != "" && tool != "" && p != "") {
    print ev, tool, p
  }
  exit
}
