#!/bin/bash
# install wrk
set -o errexit -o pipefail -o noclobber -o nounset
## include libs
LIB_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit ; pwd -P )
# shellcheck source=libs/util.sh
. "${LIB_PATH}/libs/util.sh"

yum -y install git

force_cd /data/tools
prepare_source_by_git "https://github.com/wg/wrk.git" "wrk"

cd wrk || exit
make

./wrk -v

echo -e "${C_BGREEN}install wrk successfully${C_NONE}"