## Minimal libgit2 FFI — only the API surface nicy needs, linked against
## the system libgit2. Replaces shelling out to the `git` binary for every
## prompt (see icyphox/nicy#11) without pulling in a heavy wrapper package.

{.passL: "-lgit2".}

type
  git_repository* {.importc: "git_repository", header: "<git2.h>".} = object
  git_reference* {.importc: "git_reference", header: "<git2.h>".} = object
  git_status_list* {.importc: "git_status_list", header: "<git2.h>".} = object
  git_reflog* {.importc: "git_reflog", header: "<git2.h>".} = object
  git_describe_result* {.importc: "git_describe_result", header: "<git2.h>".} = object
  git_oid* {.importc: "git_oid", header: "<git2.h>".} = object
  git_tree* {.importc: "git_tree", header: "<git2.h>".} = object
  git_diff_delta* {.importc: "git_diff_delta", header: "<git2.h>".} = object

  git_buf* {.importc: "git_buf", header: "<git2.h>".} = object
    data* {.importc: "ptr".}: cstring
    reserved* {.importc: "reserved".}: csize_t
    size* {.importc: "size".}: csize_t

  git_strarray* {.importc: "git_strarray", header: "<git2.h>".} = object
    strings* {.importc: "strings".}: ptr cstring
    count* {.importc: "count".}: csize_t

  git_status_options* {.importc: "git_status_options", header: "<git2.h>".} = object
    version* {.importc: "version".}: cuint
    show* {.importc: "show".}: cint
    flags* {.importc: "flags".}: cuint
    pathspec* {.importc: "pathspec".}: git_strarray
    baseline* {.importc: "baseline".}: ptr git_tree
    rename_threshold* {.importc: "rename_threshold".}: uint16

  git_describe_options* {.importc: "git_describe_options", header: "<git2.h>".} = object
    version* {.importc: "version".}: cuint
    max_candidates_tags* {.importc: "max_candidates_tags".}: cuint
    describe_strategy* {.importc: "describe_strategy".}: cint
    pattern* {.importc: "pattern".}: cstring
    only_follow_first_parent* {.importc: "only_follow_first_parent".}: cint
    show_commit_oid_as_fallback* {.importc: "show_commit_oid_as_fallback".}: cint

  git_describe_format_options* {.importc: "git_describe_format_options", header: "<git2.h>".} = object
    version* {.importc: "version".}: cuint
    abbreviated_size* {.importc: "abbreviated_size".}: cuint
    always_use_long_format* {.importc: "always_use_long_format".}: cint
    dirty_suffix* {.importc: "dirty_suffix".}: cstring

  git_status_entry* {.importc: "git_status_entry", header: "<git2.h>".} = object
    status* {.importc: "status".}: cuint
    head_to_index* {.importc: "head_to_index".}: ptr git_diff_delta
    index_to_workdir* {.importc: "index_to_workdir".}: ptr git_diff_delta

const
  gitDescribeTags* = 1          # GIT_DESCRIBE_TAGS: match `git describe --tags`

  statusOptIncludeUntracked* = 1'u32 shl 0
  statusIndexNew* = 1'u32 shl 0
  statusIndexModified* = 1'u32 shl 1
  statusIndexDeleted* = 1'u32 shl 2
  statusIndexRenamed* = 1'u32 shl 3
  statusIndexTypechange* = 1'u32 shl 4
  statusWtNew* = 1'u32 shl 7
  statusWtModified* = 1'u32 shl 8
  statusWtDeleted* = 1'u32 shl 9
  statusWtTypechange* = 1'u32 shl 10
  statusWtRenamed* = 1'u32 shl 11
  statusConflicted* = 1'u32 shl 15

proc git_libgit2_init*(): cint {.importc, header: "<git2.h>".}
proc git_repository_discover*(a1: ptr git_buf, start_path: cstring,
    across_fs: cint, ceiling_dirs: cstring): cint {.importc, header: "<git2.h>".}
proc git_repository_open*(a1: ptr ptr git_repository, path: cstring): cint {.
  importc, header: "<git2.h>".}
proc git_repository_head*(a1: ptr ptr git_reference,
    repo: ptr git_repository): cint {.importc, header: "<git2.h>".}
proc git_repository_head_detached*(repo: ptr git_repository): cint {.
  importc, header: "<git2.h>".}
proc git_repository_free*(repo: ptr git_repository) {.importc, header: "<git2.h>".}
proc git_reference_is_branch*(a1: ptr git_reference): cint {.
  importc, header: "<git2.h>".}
proc git_branch_upstream*(a1: ptr ptr git_reference,
    branch: ptr git_reference): cint {.importc, header: "<git2.h>".}
proc git_reference_target*(a1: ptr git_reference): ptr git_oid {.
  importc, header: "<git2.h>".}
proc git_reference_shorthand*(a1: ptr git_reference): cstring {.
  importc, header: "<git2.h>".}
proc git_reference_free*(a1: ptr git_reference) {.importc, header: "<git2.h>".}
proc git_graph_ahead_behind*(ahead: ptr csize_t, behind: ptr csize_t,
    repo: ptr git_repository, local, upstream: ptr git_oid): cint {.
  importc, header: "<git2.h>".}
proc git_status_options_init*(opts: ptr git_status_options,
    version: cuint): cint {.importc, header: "<git2.h>".}
proc git_status_list_new*(a1: ptr ptr git_status_list,
    repo: ptr git_repository, opts: ptr git_status_options): cint {.
  importc, header: "<git2.h>".}
proc git_status_list_entrycount*(a1: ptr git_status_list): csize_t {.
  importc, header: "<git2.h>".}
proc git_status_byindex*(a1: ptr git_status_list, idx: csize_t): ptr git_status_entry {.
  importc, header: "<git2.h>".}
proc git_status_list_free*(a1: ptr git_status_list) {.importc, header: "<git2.h>".}
proc git_reflog_read*(a1: ptr ptr git_reflog, repo: ptr git_repository,
    name: cstring): cint {.importc, header: "<git2.h>".}
proc git_reflog_entrycount*(a1: ptr git_reflog): csize_t {.
  importc, header: "<git2.h>".}
proc git_reflog_free*(a1: ptr git_reflog) {.importc, header: "<git2.h>".}
proc git_describe_options_init*(opts: ptr git_describe_options,
    version: cuint): cint {.importc, header: "<git2.h>".}
proc git_describe_workdir*(a1: ptr ptr git_describe_result,
    repo: ptr git_repository, opts: ptr git_describe_options): cint {.
  importc, header: "<git2.h>".}
proc git_describe_format_options_init*(opts: ptr git_describe_format_options,
    version: cuint): cint {.importc, header: "<git2.h>".}
proc git_describe_format*(a1: ptr git_buf, a2: ptr git_describe_result,
    opts: ptr git_describe_format_options): cint {.importc, header: "<git2.h>".}
proc git_describe_result_free*(a1: ptr git_describe_result) {.
  importc, header: "<git2.h>".}
proc git_buf_dispose*(a1: ptr git_buf) {.importc, header: "<git2.h>".}

discard git_libgit2_init()
