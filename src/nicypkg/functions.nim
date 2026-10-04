import
  libgit2,
  os,
  osproc,
  posix,
  strformat,
  strutils,
  terminal

type
  Color* = enum
    none = -1
    black = 0
    red = 1
    green = 2
    yellow = 3
    blue = 4
    magenta = 5
    cyan = 6
    white = 7

  GitStats* = object
    branchName*: string
    detached*: bool
    localRef*: string
    remoteRef*: string
    ahead*: int
    behind*: int
    untracked*: int
    conflicted*: int
    changed*: int
    staged*: int
    stash*: int

proc parentComm(): string =
  ## Name of the parent process' executable, e.g. "bash" or "zsh".
  ## Uses /proc when available (no subprocess), ps otherwise.
  when defined(linux):
    try:
      return readFile("/proc/" & $getppid() & "/comm").strip()
    except OSError, IOError:
      discard
  let (o, err) = execCmdEx("ps -p " & $getppid() & " -o comm=")
  if err == 0:
    return o.strip()
  ""

when defined(bash): # shell switch during compilation using "-d:bash"
  proc detectShell(): string =
    "bash"
elif defined(zsh): # or "-d:zsh"
  proc detectShell(): string =
    "zsh"
else: # or detect shell automatically
  proc detectShell(): string =
    # Match the executable name only, not its arguments: shells are often
    # launched as "bash -i" (tmux, terminal emulators, pty wrappers), which
    # the old args-based check missed, defaulting to zsh escapes.
    let name = parentComm()
    if name == "bash" or name.endsWith("/bash"):
      "bash"
    elif name == "zsh" or name.endsWith("/zsh"):
      "zsh"
    else:
      ""    # unknown: emit no zero-width wrappers at all

let
  shellName* = # make sure the shell detection runs once only
    detectShell()

proc zeroWidth*(s: string): string =
  ## Wrap `s` in the shell's zero-width escape so invisible sequences
  ## don't confuse the shell's prompt cursor math.
  case shellName
  of "bash":
    fmt"\[{s}\]"
  of "zsh":
    fmt"%{{{s}%}}"
  else:
    s

proc foreground*(s: string, color: Color): string =
  let c = "\x1b[" & $(ord(color)+30) & "m"
  result = fmt"{zeroWidth($c)}{s}"

proc background*(s: string, color: Color): string =
  let c = "\x1b[" & $(ord(color)+40) & "m"
  result = fmt"{zeroWidth($c)}{s}"

proc bold*(s: string): string =
  const b = "\x1b[1m"
  result = fmt"{zeroWidth(b)}{s}"

proc underline*(s: string): string =
  const u = "\x1b[4m"
  result = fmt"{zeroWidth(u)}{s}"

proc italics*(s: string): string =
  const i = "\x1b[3m"
  result = fmt"{zeroWidth(i)}{s}"

proc reverse*(s: string): string =
  const rev = "\x1b[7m"
  result = fmt"{zeroWidth(rev)}{s}"

proc reset*(s: string): string =
  const res = "\x1b[0m"
  result = fmt"{s}{zeroWidth(res)}"

proc color*(s: string, fg, bg = Color.none, b, u, r = false): string =
  if s.len == 0:
    return
  result = s
  if fg != Color.none:
    result = foreground(result, fg)
  if bg != Color.none:
    result = background(result, bg)
  if b:
    result = bold(result)
  if u:
    result = underline(result)
  if r:
    result = reverse(result)
  result = reset(result)

proc horizontalRule*(c = '-'): string =
  for _ in 1 .. terminalWidth():
    result &= c
  result &= zeroWidth("\n")

proc tilde*(path: string): string =
  # donated by @misterbianco
  let home = getHomeDir()
  if path.startsWith(home):
    result = "~/" & path.split(home)[1]
  else:
    result = path

proc getCwd*(): string =
  result = try:
    getCurrentDir() & " "
  except OSError:
    "[not found]"

proc virtualenv*(): string =
  let env = getEnv("VIRTUAL_ENV")
  result = extractFilename(env) & " "
  if env.len == 0:
    result = ""

proc openRepo(): ptr git_repository =
  ## The repository containing the current directory, or nil.
  result = nil
  var buf: git_buf
  if git_repository_discover(addr buf, ".", 0, nil) != 0:
    return
  defer: git_buf_dispose(addr buf)
  if buf.data != nil:
    discard git_repository_open(addr result, buf.data)

proc getGitDetachedBranch(repo: ptr git_repository): string =
  ## Equivalent of `git describe --tags --always` for a detached HEAD.
  var opts: git_describe_options
  discard git_describe_options_init(addr opts, 1)
  opts.describe_strategy = gitDescribeTags
  opts.show_commit_oid_as_fallback = 1
  var res: ptr git_describe_result = nil
  if git_describe_workdir(addr res, repo, addr opts) != 0:
    return
  defer: git_describe_result_free(res)
  var fmtOpts: git_describe_format_options
  discard git_describe_format_options_init(addr fmtOpts, 1)
  var buf: git_buf
  if git_describe_format(addr buf, res, addr fmtOpts) != 0:
    return
  defer: git_buf_dispose(addr buf)
  if buf.data != nil:
    result = $buf.data

proc gitBranch*(): string =
  ## Name of the current branch (or the describe of a detached HEAD),
  ## with a trailing space; empty outside a repository.
  let repo = openRepo()
  if repo == nil:
    return
  defer: git_repository_free(repo)
  var head: ptr git_reference = nil
  if git_repository_head(addr head, repo) != 0:
    return
  defer: git_reference_free(head)
  if git_repository_head_detached(repo) == 1:
    result = getGitDetachedBranch(repo) & " "
  else:
    result = $git_reference_shorthand(head) & " "

proc gitStatus*(dirty, clean: string): string =
  ## `dirty` if the worktree has any changes (including untracked files),
  ## else `clean`; empty outside a repository.
  let repo = openRepo()
  if repo == nil:
    return
  defer: git_repository_free(repo)
  var opts: git_status_options
  discard git_status_options_init(addr opts, 1)
  opts.flags = statusOptIncludeUntracked   # match `git status --porcelain`
  var list: ptr git_status_list = nil
  if git_status_list_new(addr list, repo, addr opts) != 0:
    return
  defer: git_status_list_free(list)
  result = if git_status_list_entrycount(list) > 0: dirty else: clean

proc endsWithDescribeSuffix(s: string): bool =
  ## True for describe output like "v1.0-3-gabc1234" (tag-depth-commit),
  ## false for an exact tag name like "v1.0" or "v1.0-beta".
  var i = s.len - 1
  while i >= 0 and s[i] in {'0'..'9', 'a'..'f'}: dec i
  if i < 0 or s[i] != 'g' or i == s.len - 1: return false
  dec i
  i >= 0 and s[i] == '-'

proc gitTag*(): string =
  ## The tag pointing exactly at HEAD; empty when HEAD is not on a tag
  ## or outside a repository.
  let repo = openRepo()
  if repo == nil:
    return
  defer: git_repository_free(repo)
  var opts: git_describe_options
  discard git_describe_options_init(addr opts, 1)
  opts.describe_strategy = gitDescribeTags
  var res: ptr git_describe_result = nil
  if git_describe_workdir(addr res, repo, addr opts) != 0:
    return          # no tag reachable from HEAD
  defer: git_describe_result_free(res)
  var fmtOpts: git_describe_format_options
  discard git_describe_format_options_init(addr fmtOpts, 1)
  var buf: git_buf
  if git_describe_format(addr buf, res, addr fmtOpts) != 0:
    return
  defer: git_buf_dispose(addr buf)
  if buf.data != nil and not endsWithDescribeSuffix($buf.data):
    result = $buf.data

proc user*(): string =
  result = $getpwuid(getuid()).pw_name

proc host*(): string =
  const size = 64
  result = newString(size)
  discard gethostname(cstring(result), size)

proc uidsymbol*(root, user: string): string =
  result = if getuid() == 0: root else: user

proc returnCondition*(ok: string, ng: string, delimiter = "."): string =
  result = fmt"%(?{delimiter}{ok}{delimiter}{ng})"

proc returnCondition*(ok: proc(): string, ng: proc(): string,
    delimiter = "."): string =
  result = returnCondition(ok(), ng(), delimiter)

proc getStashCount(repo: ptr git_repository): int =
  ## Number of stashes: one reflog entry per stash on refs/stash, which is
  ## exactly what `git stash list` reads.
  var log: ptr git_reflog = nil
  if git_reflog_read(addr log, repo, "refs/stash") == 0:
    defer: git_reflog_free(log)
    result = git_reflog_entrycount(log).int

proc newGitStats*(): GitStats =
  ## All git stats for the prompt in a single pass, without spawning `git`.
  let repo = openRepo()
  if repo == nil:
    return
  defer: git_repository_free(repo)

  var head: ptr git_reference = nil
  if git_repository_head(addr head, repo) == 0:
    defer: git_reference_free(head)
    if git_repository_head_detached(repo) == 1:
      result.branchName = getGitDetachedBranch(repo)
      if result.branchName.len > 0:
        result.detached = true
      else:
        result.branchName = "Big Bang"
    else:
      result.branchName = $git_reference_shorthand(head)
      result.localRef = result.branchName
      var up: ptr git_reference = nil
      if git_branch_upstream(addr up, head) == 0:
        defer: git_reference_free(up)
        result.remoteRef = $git_reference_shorthand(up)
        let localOid = git_reference_target(head)
        let upOid = git_reference_target(up)
        if localOid != nil and upOid != nil:
          var ahead, behind: csize_t = 0
          if git_graph_ahead_behind(addr ahead, addr behind, repo,
              localOid, upOid) == 0:
            result.ahead = ahead.int
            result.behind = behind.int
  else:
    result.branchName = "Big Bang"   # unborn HEAD

  var opts: git_status_options
  discard git_status_options_init(addr opts, 1)
  opts.flags = statusOptIncludeUntracked   # match `git status --porcelain`
  var list: ptr git_status_list = nil
  if git_status_list_new(addr list, repo, addr opts) == 0:
    defer: git_status_list_free(list)
    for i in 0 ..< git_status_list_entrycount(list).int:
      let entry = git_status_byindex(list, i.csize_t)
      if entry == nil:
        continue
      let st = entry.status
      if (st and statusConflicted) != 0:
        inc result.conflicted
        continue
      # WT_NEW means untracked, counted separately below
      if (st and (statusWtModified or statusWtDeleted or
                 statusWtTypechange or statusWtRenamed)) != 0:
        inc result.changed
      if (st and (statusIndexNew or statusIndexModified or statusIndexDeleted or
                 statusIndexRenamed or statusIndexTypechange)) != 0:
        inc result.staged
      if (st and statusWtNew) != 0:
        inc result.untracked
  result.stash = getStashCount(repo)

proc dirty*(gs: GitStats): bool =
  (gs.untracked + gs.changed + gs.staged + gs.conflicted) > 1

proc branch*(gs: GitStats, detachedPrefix = "", postfix = " "): string =
  if gs.branchName.len > 0:
    result = gs.branchName & postfix
  if gs.detached and detachedPrefix.len > 0:
    result = detachedPrefix & result

proc status*(gs: GitStats, ahead, behind, untracked, changed, staged,
    conflicted, stash: string, separator, postfix = " "): string =
  var parts = newSeq[string]()

  template add(gs: GitStats, field: untyped, value: string, ss: seq[string]) =
    if gs.`field` > 0:
      if gs.`field` > 1:
        ss.add($gs.`field` & value)
      else:
        ss.add(value)

  if gs.branchName.len > 0:
    add(gs, ahead, ahead, parts)
    add(gs, behind, behind, parts)
    add(gs, untracked, untracked, parts)
    add(gs, changed, changed, parts)
    add(gs, staged, staged, parts)
    add(gs, conflicted, conflicted, parts)
    add(gs, stash, stash, parts)
    result = parts.join(separator)
    if result.len > 0 and postfix.len > 0:
      result &= postfix
