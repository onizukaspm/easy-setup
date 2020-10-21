#!/bin/bash
# check and refresh let's encrypt SSL
set -o errexit -o pipefail -o noclobber -o nounset
#set -o verbose
declare -A API_KEYS
declare -A API_SECRETS
# *.example.com
API_KEYS["example.com"]="dns api key"
API_SECRETS["example.com"]="dns api secrets"

# echo colors
# shellcheck disable=SC2034
C_NONE="\033[0m"
# Regular
# shellcheck disable=SC2034
C_BLACK="\033[0;30m"
# shellcheck disable=SC2034
C_RED="\033[0;31m"
# shellcheck disable=SC2034
C_GREEN="\033[0;32m"
# shellcheck disable=SC2034
C_YELLOW="\033[0;33m"
# shellcheck disable=SC2034
C_BLUE="\033[0;34m"
# shellcheck disable=SC2034
C_PURPLE="\033[0;35m"
# shellcheck disable=SC2034
C_CYAN="\033[0;36m"
# shellcheck disable=SC2034
C_WHITE="\033[0;37m"
#Bold
# shellcheck disable=SC2034
C_BBLACK="\033[1;30m"
# shellcheck disable=SC2034
C_BRED="\033[1;31m"
# shellcheck disable=SC2034
C_BGREEN="\033[1;32m"
# shellcheck disable=SC2034
C_BYELLOW="\033[1;33m"
# shellcheck disable=SC2034
C_BBLUE="\033[1;34m"
# shellcheck disable=SC2034
C_BPURPLE="\033[1;35m"
# shellcheck disable=SC2034
C_BCYAN="\033[1;36m"
# shellcheck disable=SC2034
C_BWHITE="\033[1;37m"
# High Intensity
# shellcheck disable=SC2034
C_IBLACK="\033[0;90m"
# shellcheck disable=SC2034
C_IRED="\033[0;91m"
# shellcheck disable=SC2034
C_IGREEN="\033[0;92m"
# shellcheck disable=SC2034
C_IYELLOW="\033[0;93m"
# shellcheck disable=SC2034
C_IBLUE="\033[0;94m"
# shellcheck disable=SC2034
C_IPURPLE="\033[0;95m"
# shellcheck disable=SC2034
C_ICYAN="\033[0;96m"
# shellcheck disable=SC2034
C_IWHITE="\033[0;97m"
# Bold High Intensity
# shellcheck disable=SC2034
C_BIBLACK="\033[1;90m"
# shellcheck disable=SC2034
C_BIRED="\033[1;91m"
# shellcheck disable=SC2034
C_BIGREEN="\033[1;92m"
# shellcheck disable=SC2034
C_BIYELLOW="\033[1;93m"
# shellcheck disable=SC2034
C_BIBLUE="\033[1;94m"
# shellcheck disable=SC2034
C_BIPURPLE="\033[1;95m"
# shellcheck disable=SC2034
C_BICYAN="\033[1;96m"
# shellcheck disable=SC2034
C_BIWHITE="\033[1;97m"
