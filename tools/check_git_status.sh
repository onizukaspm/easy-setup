#!/bin/bash
# check and refresh let's encrypt SSL
set -o errexit -o pipefail -o noclobber -o nounset
#set -o verbose

# echo colors
# shellcheck disable=SC2034
C_NONE="\033[0m"
# shellcheck disable=SC2034
C_BRED="\033[1;31m"
# shellcheck disable=SC2034
C_BGREEN="\033[1;32m"
# shellcheck disable=SC2034
C_BYELLOW="\033[1;33m"
# shellcheck disable=SC2034
C_BBLUE="\033[1;34m"
# shellcheck disable=SC2034
PADDING="        " # length=8

LOG() {
  echo -e "$(date +"[%F %T.%N]") ${*}"
}

exists_command() {
  command -v "$1" >/dev/null 2>&1
}

if ! exists_command git; then
  LOG "${C_BRED}git not exists! abort checking.${C_NONE}"
  exit 0
fi

# git repositories root
root_path="/d/Codes"
cd "${root_path}" || exit

ALL_CLEAN=true
repositories=$(find . -maxdepth 5 -type d -name ".git")
for repository in $repositories; do
  path="${repository%/*}"
  path="${root_path}/${path#*/}"
  cd "$path"
  # check git status
  status=$(git status)
  # parse branch
  branch=${status%Your branch*}
  branch=${branch##* }
  branch=${branch//[$'\r\n']}
  # has added changes
  staged=""
  if [[ $status == *"Changes to be committed"* ]]; then
    staged=" ${C_BGREEN}[staged]${C_NONE}"
    ALL_CLEAN=false
  fi
  # has changes
  changed=""
  if [[ $status == *"Changes not staged for commit"* ]]; then
    changed=" ${C_BRED}[changed]${C_NONE}"
    ALL_CLEAN=false
  fi
  # has changes
  untracked=""
  if [[ $status == *"Untracked files"* ]]; then
    untracked=" ${C_BRED}[untracked]${C_NONE}"
    ALL_CLEAN=false
  fi
  # ahead commits
  ahead_commits=""
  if [[ $status == *"Your branch is ahead of"* ]]; then
    ahead_commits=${status%% commit\.*}
    ahead_commits=${ahead_commits##* }
    ahead_commits=" ${C_BYELLOW}[$ahead_commits commits ahead]${C_NONE}"
    ALL_CLEAN=false
  fi

  content="${C_BYELLOW}[${branch}]${C_NONE}${PADDING:0:$((${#PADDING}-${#branch}))}${C_BBLUE}${path}${C_NONE}"
  content="$content$ahead_commits$staged$changed$untracked"

  LOG "${content}"

  cd "$root_path"
done

${ALL_CLEAN} && LOG "${C_BGREEN}ALL repositories up to date${C_NONE}"
