## nicystar — a starship-look prompt built on nicy's API.
##
## Line 1: bold cyan ~/cwd, bold purple  branch, red [status] bracket
## (starship symbols: ✘ conflicted, ! modified, + staged, ? untracked,
## $ stashed, ⇡n ahead, ⇣n behind).
## Line 2: ❯ — bold green on success, bold red on failure.
##
## Usage: nicystar [exit_status]   (PROMPT_COMMAND passes $? in)

import
  nicypkg/functions,
  os,
  strformat,
  strutils

when isMainModule:
  let
    failed = paramCount() > 0 and paramStr(1) != "0"
    cwd = color(tilde(getCwd()), cyan, b = true)
    gs = newGitStats()

  var branch: string
  if gs.branchName.len > 0:
    branch = color(" " & gs.branchName, magenta, b = true)

  var st: string
  if gs.conflicted > 0: st.add "✘"
  if gs.changed > 0: st.add "!"
  if gs.staged > 0: st.add "+"
  if gs.untracked > 0: st.add "?"
  if gs.stash > 0: st.add "$"
  if gs.ahead > 0: st.add fmt"⇡{gs.ahead}"
  if gs.behind > 0: st.add fmt"⇣{gs.behind}"
  let statusPart = if st.len > 0: color(fmt" [{st}]", red) else: ""

  let promptChar =
    if failed: color("❯ ", red, b = true)
    else: color("❯ ", green, b = true)

  echo fmt"{cwd}{branch}{statusPart}{'\n'}{promptChar}"
