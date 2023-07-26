#!/bin/bash

# exit on any error:
set -eE

# top level function:
mf_subrepo() {
  local command=$1
  local RES=

  local subrepo_repo=
  local subrepo_repo_confirmed=false
  local subrepo_repo_dir=
  local subrepo_name=
  local subrepo_dir=
  local subrepo_version=
  local subrepo_versions=
  local subrepo_latest_version=
  local subrepo_ahead_local=0
  local subrepo_ahead_pushed=0
  local subrepo_behind=0
  local subrepo_v=
  local subrepo_local=true
  local subrepo_branch="main"
  local subrepo_branch_type="release"
  local subrepo_on_updates_branch=false
  
  local git_main_branch=
  local git_temp_branch=
  local git_stashed="n"

  # match repository URLs:
  local repourl_regex="^(https?|git)(:\/\/|@)([^\/:]+)[\/:]([^\/]+)\/([^\/]+)(\.git)?$"

  # envsubst or perl equivalent:
  local replace_cmd=$(which envsubst)
  if [ -z "$replace_cmd" ]; then
    replace_cmd='perl -pe '"'"'s/\$\{([^\}]+)\}/$ENV{$1}/g'"'"
  fi

  if [ ! -d "$ROOT_DIR/.git" ]; then
    mframe_utils_error "Not inside a GIT repository."
  fi

  # execute desired command:
  "mf_subrepo_$command"
}

#
# ------------------------------------------------------------------------------
#

# `make subrepo name=...` command:
mf_subrepo_create() {
  mf_subrepo_set_current "$SUBREPO_NAME"

  if [ -d "$subrepo_dir" ]; then
    mframe_utils_error "Subrepo \"$subrepo_name\" already exists."
  fi

  # ask for subrepo repository, unless already confirmed:
  if ! $subrepo_repo_confirmed; then
    mframe_utils_input "Subrepo GIT repository:" "$subrepo_repo" true; subrepo_repo="$RES"
  fi

  # ask for subrepo template:
  local empty_hint=
  if [ ! -z "$MFRAME_TPL" ] && [ "$MFRAME_TPL" != 'empty' ]; then
    empty_hint=" (use 'empty' for an empty subrepo)"
  fi
  mframe_utils_input "Subrepo template$empty_hint:" "$MFRAME_TPL"; local tpl="$RES"

  # do the work on a temp branch for easy error recovery:
  mframe_utils_git_create_temp_branch

  # in case of any errors remove temp branch and restore initial state:
  trap 'mframe_utils_git_remove_temp_branch' ERR INT

  RUN mkdir -p $MFRAME_DIR

  if [ -z "$tpl" ] || [ "$tpl" == 'empty' ]; then
    RUN cp -r $MFRAME_ROOT_DIR/subrepo-skel $subrepo_dir
    RUN mkdir -p $subrepo_dir/.github/workflows
    RUN cp $MFRAME_ROOT_DIR/.github/workflows/auto-pr.yml $subrepo_dir/.github/workflows/
    RUN cp $MFRAME_ROOT_DIR/.github/workflows/release.yml $subrepo_dir/.github/workflows/
  else
    if [[ "$tpl" =~ $repourl_regex ]]; then
      RUN git clone -q $tpl $subrepo_dir
      RUN rm -rf $subrepo_dir/.git
    elif [ -d "$MFRAME_DIR/.$tpl" ]; then
      RUN cp -r $MFRAME_DIR/.$tpl $subrepo_dir
    else
      mframe_utils_error "Can't find subrepo template \"$tpl\"."
    fi
  fi

  # substitute placeholders:
  RUN find $subrepo_dir -type f -exec sh -c \
    "REPO=$subrepo_repo NAME=$subrepo_name $replace_cmd < {} > {}.tmp && mv {}.tmp {}" \;

  # commit the new subrepo and make it a subrepo:
  RUN git add $subrepo_dir
  RUN git commit -q -m "chore(mframe): Created subrepo \"$subrepo_name\"" $subrepo_dir
  RUN git subrepo init $subrepo_dir -q -r $subrepo_repo -b main

  # merge changes made on the temp branch and discard it:
  mframe_utils_git_merge_temp_branch

  echo "Subrepo \"$subrepo_name\" created in \"$subrepo_dir\"."

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-created-hook repo=$subrepo_repo name=$subrepo_name
  fi
}

# `make subrepo-clone name=... [v=latest]` command:
mf_subrepo_clone() {
  mf_subrepo_set_current "$SUBREPO_NAME"

  # do the work on a temp branch for easy error recovery:
  mframe_utils_git_create_temp_branch

  # in case of any errors remove temp branch and restore initial state:
  trap 'mframe_utils_git_remove_temp_branch' ERR INT

  local v="$SUBREPO_V"
  if [ -z "$v" -o "$v" == "latest" ]; then
    mf_subrepo_get_versions
    v="$subrepo_latest_version"
  fi

  RUN git subrepo clone $subrepo_repo $subrepo_dir -q -b v$v $([ -d "$subrepo_dir" ] && echo "-f")

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-hook-cloned _subrepo-cfgadd repo=$subrepo_repo name=$subrepo_name
  fi

  if ! git diff --quiet; then
    RUN git commit -a -q --amend --no-edit --no-verify
  fi

  # merge changes made on the temp branch and discard it:
  mframe_utils_git_merge_temp_branch

  echo "Subrepo \"$subrepo_name\" (v$v) cloned in \"$subrepo_dir\"."

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-cloned-hook repo=$subrepo_repo name=$subrepo_name
  fi
}

# `make subrepo-pull name=...` command:
mf_subrepo_pull() {
  mf_subrepo_set_current "$SUBREPO_NAME"

  if [ ! -d "$subrepo_dir" ]; then
    mframe_utils_error "No subrepo found at \"$subrepo_dir\"."
  fi

  if $subrepo_local; then
    echo "Subrepo \"$subrepo_name\" is local, there's no upstream to pull from."
    return 0
  else
    mf_subrepo_upstream_diff

    if [ $((subrepo_ahead_local + subrepo_ahead_pushed)) -gt 0 ]; then
      echo
      echo "WARNING:"
      echo "Subrepo \"$subrepo_name\" contains changes that are not yet merged upstream"
      echo "and will be lost if you continue."
      echo

      if ! mframe_utils_confirm "Are you sure you want to continue?"; then
        return 0
      fi

      echo
    fi
  fi

  # do the work on a temp branch for easy error recovery:
  mframe_utils_git_create_temp_branch

  # in case of any errors remove temp branch and restore initial state:
  trap 'mframe_utils_git_remove_temp_branch' ERR INT

  local b=$(mf_subrepo_release_branch)
  RUN git subrepo pull $subrepo_dir -q -f -b $b

  # remove nonce for this subrepo:
  if $subrepo_on_updates_branch; then
    RUN rm -f $MFRAME_TMP_DIR/.nonces/$subrepo_name

    if [ $subrepo_ahead_pushed -eq 0 ]; then
      RUN git push -q $subrepo_repo :$subrepo_branch
    fi
  fi

  # merge changes made on the temp branch and discard it:
  mframe_utils_git_merge_temp_branch

  echo "Upstream changes to subrepo \"$subrepo_name\" pulled from branch \"$b\"."

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-pulled-hook repo=$subrepo_repo name=$subrepo_name
  fi
}

# `make subrepo-pull-all` command:
mf_subrepo_pull_all() {
  for subrepo in $(mf_subrepo_get_live); do
    SUBREPO_NAME=$(basename $subrepo) mf_subrepo_pull
  done

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-pulled-all-hook
  fi
}

# `make subrepo-push name=...` command:
mf_subrepo_push() {
  mf_subrepo_set_current "$SUBREPO_NAME"

  if [ ! -d "$subrepo_dir" ]; then
    mframe_utils_error "No subrepo found at \"$subrepo_dir\"."
  fi

  mf_confirm_repo

  if $subrepo_local; then
    echo
    echo "Subrepo \"$subrepo_name\" is now pushed for the first time, please make"
    echo "sure its upstream repository is created before continuing."
    echo
    echo "The upstream repository for this subrepo should be:"
    echo $subrepo_repo
    echo
    
    if ! mframe_utils_confirm "Continue?" "y"; then
      return 0
    fi

    echo
  else
    mf_subrepo_upstream_diff

    if [ $subrepo_ahead_local -eq 0 ]; then
      echo "Subrepo \"$subrepo_name\" has no local changes."
      return 0
    fi
  fi

  # do the work on a temp branch for easy error recovery:
  mframe_utils_git_create_temp_branch

  # in case of any errors remove temp branch and restore initial state:
  trap 'mframe_utils_git_remove_temp_branch' ERR INT

  local b=$(mf_subrepo_updates_branch)

  if [ ! -f "$subrepo_dir/.gitrepo" ]; then
    RUN git subrepo init $subrepo_dir -q -r $subrepo_repo -b $b
  fi

  RUN git subrepo push $subrepo_dir -q -b $b

  mframe_utils_git_merge_temp_branch
  echo "Local changes to subrepo \"$subrepo_name\" pushed on branch \"$b\"."

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-pushed-hook repo=$subrepo_repo name=$subrepo_name
  fi
}

# `make subrepo-push-all` command:
mf_subrepo_push_all() {
  for subrepo in $(mf_subrepo_get_live); do
    SUBREPO_NAME=$(basename $subrepo) mf_subrepo_push
  done

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-pushed-all-hook
  fi
}

# `make subrepo-remove name=...` command:
mf_subrepo_remove() {
  mf_subrepo_set_current "$SUBREPO_NAME"

  if [ ! -d "$subrepo_dir" ]; then
    mframe_utils_error "No subrepo found at \"$subrepo_dir\"."
  fi

  if ! git diff --quiet $subrepo_dir || ! git diff --cached --quiet $subrepo_dir; then
    mframe_utils_error "Subrepo has uncommitted changes, so it can't be deleted."
  fi

  # do the work on a temp branch for easy error recovery:
  mframe_utils_git_create_temp_branch

  # in case of any errors remove temp branch and restore initial state:
  trap 'mframe_utils_git_remove_temp_branch' ERR INT

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-hook-remove repo=$subrepo_repo name=$subrepo_name
    RUN make _subrepo-cfgrem repo=$subrepo_repo name=$subrepo_name
  fi

  if [ -f "$subrepo_dir/.gitrepo" ]; then
    RUN git subrepo clean $subrepo_dir -q -f
  fi

  RUN rm -rf $subrepo_dir
  RUN git add $subrepo_dir
  RUN git commit -q -m "chore(mframe): Removed subrepo \"$subrepo_name\"" $subrepo_dir/*

  if ! git diff --quiet; then
    RUN git commit -a -q --amend --no-edit
  fi

  # merge changes made on the temp branch and discard it:
  mframe_utils_git_merge_temp_branch

  echo "Subrepo \"$subrepo_name\" removed."

  if [ "$HOOKS" != "false" ]; then
    RUN make _subrepo-removed-hook repo=$subrepo_repo name=$subrepo_name
  fi
}

# `make subrepo-status [name=...]` command:
mf_subrepo_status() {
  # a list of subrepos that have uncommitted changes:
  local wip_subrepos="$(mf_subrepo_list_uncommitted)"

  mframe_utils_git_stash_push
  trap 'mframe_utils_git_stash_pop' ERR INT

  if [ ! -z "$SUBREPO_NAME" ]; then
    mf_subrepo_set_current "$SUBREPO_NAME"

    if [ ! -d "$subrepo_dir" ]; then
      mframe_utils_error "No subrepo found at \"$subrepo_dir\"."
    fi
  fi

  local subdir=$subrepo_dir

  local uncommitted=
  local first=true
  for subrepo in $(mf_subrepo_get $subdir); do
    if $first; then
      echo "Ahead / Behind     Subrepo"
      first=false
    fi

    mf_subrepo_set_current $(basename $subrepo)
    mf_subrepo_upstream_diff

    local upgrade=
    local unreleased=

    if ! $subrepo_local; then
      mf_subrepo_get_versions
      if [ -z "$subrepo_latest_version" ]; then
        unreleased=" - unreleased"
      elif [ "$subrepo_version" != "$subrepo_latest_version" ]; then
        upgrade=" [v$subrepo_latest_version available]"
      fi
    fi

    if echo "$wip_subrepos" | grep -Eq "([^[:alnum:]_.-]|^)$subrepo([^[:alnum:]_.-]|$)"; then
      uncommitted=" ** has uncommitted changes **"
    else
      uncommitted=
    fi

    printf %5s $((subrepo_ahead_local + subrepo_ahead_pushed))
    printf " / "
    printf %-11s $subrepo_behind
    echo "$subrepo_name ($subrepo_v$unreleased)$upgrade$uncommitted"
  done

  mframe_utils_git_stash_pop
}

# `make subrepo-info [name=...]` command:
mf_subrepo_info() {
  # a list of subrepos that have uncommitted changes:
  local wip_subrepos="$(mf_subrepo_list_uncommitted)"

  mframe_utils_git_stash_push
  trap 'mframe_utils_git_stash_pop' ERR INT

  if [ ! -z "$SUBREPO_NAME" ]; then
    mf_subrepo_set_current "$SUBREPO_NAME"

    if [ ! -d "$subrepo_dir" ]; then
      mframe_utils_error "No subrepo found at \"$subrepo_dir\"."
    fi
  fi

  local subdir=$subrepo_dir

  local pad="-17"

  local uncommitted=
  for subrepo in $(mf_subrepo_get $subdir); do
    mf_subrepo_set_current $(basename $subrepo)
    mf_subrepo_upstream_diff

    if ! $subrepo_local; then
      mf_subrepo_get_versions
    fi

    if echo "$wip_subrepos" | grep -Eq "([^[:alnum:]_.-]|^)$subrepo([^[:alnum:]_.-]|$)"; then
      uncommitted=" ** has uncommitted changes **"
    else
      uncommitted=
    fi

    echo "Subrepo \"$subrepo_name\":"
    printf %${pad}s "  Repo URL:"
    echo $subrepo_repo
    printf %${pad}s "  Versions:"
    if $subrepo_local; then
      echo
    elif [ -z "$subrepo_latest_version" ]; then
      echo "[1 - unreleased]"
    else
      echo $subrepo_versions | sed -E "s/(^|[[:space:]])$subrepo_version([[:space:]]|$)/\1[$subrepo_version]\2/g"
    fi
    printf %${pad}s "  Diff Status:"
    if $subrepo_local; then
      echo "local subrepo $uncommitted"
    else
      echo "$subrepo_ahead_local + $subrepo_ahead_pushed ahead, $subrepo_behind behind $uncommitted"
    fi

    if [ $subrepo_ahead_local -gt 0 ]; then
      echo; echo "  Commits ahead (local):"
      git log --pretty='format:[%h] %s' subrepo/$subrepo_dir/fetch..subrepo/$subrepo_dir | awk '{print "    "$0}'
    fi

    if [ $subrepo_ahead_pushed -gt 0 ]; then
      echo; echo "  Commits ahead (pushed, but not yet released):"
      git log --pretty='format:[%h] %s' subrepo/$subrepo_dir/release..subrepo/$subrepo_dir/fetch | awk '{print "    "$0}'
    fi

    if [ $subrepo_behind -gt 0 ]; then
      echo; echo "  Commits behind latest $subrepo_v release:"
      git log --pretty='format:[%h] %s' subrepo/$subrepo_dir..subrepo/$subrepo_dir/release | awk '{print "    "$0}'
    fi

    echo; echo
  done

  mframe_utils_git_stash_pop
}

# `make subrepo-gitrepo-reset [name=...]` command:
mf_subrepo_gitrepo_reset() {
  local head=$(git rev-parse HEAD)

  # do the work on a temp branch for easy error recovery:
  mframe_utils_git_create_temp_branch

  # in case of any errors remove temp branch and restore initial state:
  trap 'mframe_utils_git_remove_temp_branch' ERR INT

  if [ ! -z "$SUBREPO_NAME" ]; then
    mf_subrepo_set_current "$SUBREPO_NAME"
  fi

  local subdir=$subrepo_dir

  for subrepo in $(mf_subrepo_get_live $subdir); do
    mf_subrepo_set_current $(basename $subrepo)

    RUN git config --file=$subrepo_dir/.gitrepo subrepo.parent $head
  done

  if ! git diff --quiet; then
    RUN git commit -a -q -m "chore(mframe): .gitrepo reset"
  fi

  # merge changes made on the temp branch and discard it:
  mframe_utils_git_merge_temp_branch
}

#
# ------------------------------------------------------------------------------
#

mf_subrepo_state() {
  echo
  echo "Internal state:"
  echo subrepo_repo = $subrepo_repo
  echo subrepo_repo_confirmed = $subrepo_repo_confirmed
  echo subrepo_name = $subrepo_name
  echo subrepo_dir = $subrepo_dir
  echo subrepo_version = $subrepo_version
  echo subrepo_versions = $subrepo_versions
  echo subrepo_latest_version = $subrepo_latest_version
  echo subrepo_ahead_local = $subrepo_ahead_local
  echo subrepo_ahead_pushed = $subrepo_ahead_pushed
  echo subrepo_behind = $subrepo_behind
  echo subrepo_v = $subrepo_v
  echo subrepo_local = $subrepo_local
  echo subrepo_branch = $subrepo_branch
  echo subrepo_branch_type = $subrepo_branch_type
  echo subrepo_on_updates_branch = $subrepo_on_updates_branch
  echo
}

# set current  subrepo, given its name:
# $1 - subrepo name
mf_subrepo_set_current() {
  subrepo_repo=
  subrepo_repo_confirmed=false
  subrepo_repo_dir=
  subrepo_name=
  subrepo_dir=
  subrepo_version=1
  subrepo_versions=
  subrepo_latest_version=
  subrepo_ahead_local=0
  subrepo_ahead_pushed=0
  subrepo_behind=0
  subrepo_v="local subrepo"
  subrepo_local=true
  subrepo_branch=main
  subrepo_branch_type=release
  subrepo_on_updates_branch=false

  local name="$1"

  if [ -z "$name" ]; then
    mframe_utils_input "Subrepo name:" "" true; name="$RES"
  fi

  if [[ "$name" =~ $repourl_regex ]]; then
    # user input is a repository URL from which we can infer the subrepo's name
    # and its local directory
    subrepo_repo="$name"
    subrepo_repo_confirmed=true
  else
    subrepo_name="$name"

    # in case a .gitrepo file is available, extract the repository URL:
    if [ -f "$MFRAME_DIR/$subrepo_name/.gitrepo" ]; then
      subrepo_repo=$(cat $MFRAME_DIR/$subrepo_name/.gitrepo | grep remote | awk '{print $3}')
      subrepo_repo_confirmed=true
    else
      subrepo_repo_dir="$name"

      if [ ! -z "$MFRAME_GIT" ]; then
        subrepo_repo="$MFRAME_GIT/$subrepo_repo_dir"
      fi
    fi
  fi

  if $subrepo_repo_confirmed; then
    if [ -z "$subrepo_repo_dir" ]; then
      subrepo_repo_dir=$(basename "$subrepo_repo" .git)
    fi
  fi

  subrepo_dir="$MFRAME_DIR/$subrepo_name"

  if [ -f "$subrepo_dir/.gitrepo" ]; then
    local commit=$(git config --file=$subrepo_dir/.gitrepo subrepo.commit)

    if [ ! -z "$commit" ]; then
      subrepo_local=false

      subrepo_branch=$(git config --file=$subrepo_dir/.gitrepo subrepo.branch)
      if [[ "$subrepo_branch" =~ ^(updates/)?v([0-9]+)(/|$) ]]; then
        if [ ! -z "${BASH_REMATCH[1]}" ]; then
          subrepo_branch_type="updates"
          subrepo_on_updates_branch=true
        fi
        subrepo_version=${BASH_REMATCH[2]}
      fi

      subrepo_v="v$subrepo_version"
    fi
  fi

  if [ "$DEBUG" == "true" ]; then
    mf_subrepo_state
  fi
}

# get all versions for the current subrepo:
mf_subrepo_get_versions() {
  if [ ! -z "$subrepo_versions" ]; then
    return 0
  fi

  subrepo_versions=$(git ls-remote --refs --tags $subrepo_repo \
    | grep -E 'refs\/tags\/v[[:digit:]]+$' \
    | awk '{print $2}' \
    | sed -e 's;refs/tags/v;;' \
    | sort -rV)

  subrepo_latest_version=$(echo "$subrepo_versions" | head -1)
}

# check if current subrepo has the specified version released:
# $1 - version
mf_subrepo_has_version() {
  mf_subrepo_get_versions

  local v=
  for v in $subrepo_versions; do
    if [ "$v" == "$1" ]; then
      return 0
    fi
  done

  return 1
}

# check if the current subrepo has the specified branch:
# $1 - branch
mf_subrepo_has_branch() {
  RUN git ls-remote --exit-code --heads $subrepo_repo refs/heads/$1 &> /dev/null
}

# output the "updates" branch for the current subrepo:
mf_subrepo_updates_branch() {
  if $subrepo_local; then
    echo "main"
  else
    if [ ! -s "$MFRAME_TMP_DIR/.nonces/$subrepo_name" ]; then
      mkdir -p $MFRAME_TMP_DIR/.nonces
      cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1 > $MFRAME_TMP_DIR/.nonces/$subrepo_name
    fi

    echo "updates/$subrepo_v/$MFRAME_PROJECT_NAME#$(cat $MFRAME_TMP_DIR/.nonces/$subrepo_name)"
  fi
}

# output the "release" branch for the current subrepo:
mf_subrepo_release_branch() {
  if mf_subrepo_has_version $subrepo_version; then
    echo "v$subrepo_version"
  else
    echo "main"
  fi
}

# fetch the release head for the current subrepo:
mf_subrepo_fetch_release() {
  local b=$(mf_subrepo_release_branch)

  RUN git fetch --no-tags --quiet $subrepo_repo $b
  RUN git update-ref refs/subrepo/$subrepo_dir/release FETCH_HEAD^0
}

# determine subrepo diff (commits ahead/behind) against its upstream:
mf_subrepo_upstream_diff() {
  if $subrepo_local; then
    return 0
  fi

  RUN git subrepo branch $subrepo_dir -q -f --fetch

  if $subrepo_on_updates_branch; then
    RUN git update-ref refs/subrepo/$subrepo_dir/updates refs/subrepo/$subrepo_dir/fetch
    mf_subrepo_fetch_release
  else
    RUN git update-ref refs/subrepo/$subrepo_dir/release refs/subrepo/$subrepo_dir/fetch
  fi

  subrepo_ahead_local=$(git rev-list --count subrepo/$subrepo_dir/fetch..subrepo/$subrepo_dir)

  if $subrepo_on_updates_branch; then
    subrepo_ahead_pushed=$(git rev-list --count subrepo/$subrepo_dir/release..subrepo/$subrepo_dir/fetch)
  fi

  subrepo_behind=$(git rev-list --count subrepo/$subrepo_dir..subrepo/$subrepo_dir/release)
}

# list all subrepos with uncommitted changes:
mf_subrepo_list_uncommitted() {
  local mod=

  for mod in $(find $MFRAME_DIR -type d -depth 1); do
    if [ ! -f "$mod/.gitrepo" ]; then
      continue
    fi

    if ! git diff --quiet $mod || ! git diff --cached --quiet $mod; then
      echo $mod
    fi
  done
}

# get the list of subrepos:
mf_subrepo_get() {
  local filter=${1:-.}
  find $MFRAME_DIR -type d -depth 1 -not -path '*/.*' | grep "$filter" | sort
}

# get the list of subrepos that have a .gitrepo file:
mf_subrepo_get_live() {
  local filter=${1:-.}
  find $MFRAME_DIR -name .gitrepo -depth 2 -exec dirname {} \; | grep "$filter" | sort
}

# confirm repo name:
mf_confirm_repo() {
  # ask for subrepo repository, unless already confirmed:
  if ! $subrepo_repo_confirmed; then
    mframe_utils_input "Subrepo GIT repository:" "$subrepo_repo" true; subrepo_repo="$RES"
  fi
}

#
# ------------------------------------------------------------------------------
#

# get user input:
# $1 - prompt message
# $2 - default value
# $3 - required flag (true/false, default false)
mframe_utils_input() {
  local REPLY=

  while
    read -p "$1$(if [ ! -z "$2" ]; then echo " [$2]"; fi) "

    if [ ! -z "$REPLY" ]; then
      REPLY=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< $REPLY)
    else
      if [ ! -z "$2" ]; then
        REPLY="$2"
      fi
    fi

    [ -z "$REPLY" ] && [ "$3" == "true" ]
  do
    continue
  done

  RES="$REPLY"
}

# get user confirmation:
# $1 - message/question to display
# $2 - default option (y/n or empty for no default)
mframe_utils_confirm() {
  local res_regex="^([yY]([eE][sS])?|[nN][oO]?)$"
  local res=

  if [ "$AUTOCONFIRM" == "yn" ]; then
    res="$2"
  else
    res="$AUTOCONFIRM"
  fi

  local default=
  if [ "$2" == "y" ]; then
    default=" (Y/n)"
  elif [ "$2" == "n" ]; then
    default=" (y/N)"
  else
    default=" (y/n)"
  fi

  while ! [[ "$res" =~ $res_regex ]]; do
    read -p "$1$default " res

    if [ -z "$res" -a ! -z "$2" ]; then
      res="$2"
    fi
  done

  if [[ "$res" =~ ^[yY]([eE][sS])?$ ]]; then
    return 0
  else
    return 1
  fi
}

# show an error message and exit:
# $1 - error message
mframe_utils_error() {
  echo "ERROR: $1"
  exit 1
}

# stash/unstash changes in a GIT working directory:
mframe_utils_git_stash_push() {
  if [ "$git_stashed" == "y" ]; then
    return 1
  fi

  mframe_utils_ensure_root_dir

  if ! git diff --quiet || ! git diff --cached --quiet; then
    RUN git stash -q
    git_stashed="y"
  fi
}

mframe_utils_git_stash_pop() {
  if [ "$git_stashed" == "n" ]; then
    return 0
  fi

  mframe_utils_ensure_root_dir

  RUN git stash pop --index -q
  git_stashed="n"
}

# create/merge/remove a temp GIT branch:
mframe_utils_git_create_temp_branch() {
  mframe_utils_ensure_root_dir

  git_temp_branch=temp_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
  git_main_branch=$(git rev-parse --abbrev-ref HEAD)

  mframe_utils_git_stash_push
  RUN git checkout -q -b $git_temp_branch
}

mframe_utils_git_merge_temp_branch() {
  mframe_utils_ensure_root_dir

  RUN git checkout -q $git_main_branch
  RUN git merge -q $git_temp_branch

  mframe_utils_git_remove_temp_branch
}

mframe_utils_git_remove_temp_branch() {
  mframe_utils_ensure_root_dir

  RUN git checkout -q $git_main_branch
  RUN git branch -q -D $git_temp_branch
  mframe_utils_git_stash_pop

  git_temp_branch=
  git_main_branch=
}

# ensure we are in the ROOT_DIR directory:
mframe_utils_ensure_root_dir() {
  if [ "$(pwd)" != "$ROOT_DIR" ]; then
    RUN cd $ROOT_DIR
  fi
}

#
# ------------------------------------------------------------------------------
#

RUN() {
  say "$*"
  "$@"
}

say() {
  [ "$DEBUG" == "true" ] && echo '>>>' "$@"
  return 0
}
