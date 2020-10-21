#!/bin/bash
# check and refresh let's encrypt SSL
set -o errexit -o pipefail -o noclobber -o nounset
#set -o verbose
## include libs
LIB_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")" || exit
  pwd -P
)
# shellcheck source=/dns.apis.sh
. "${LIB_PATH}/dns.apis.sh"

# log function
LOG() {
  echo -e "$(date +"[%F %T.%N]") ${*}"
}

exists_command() {
  command -v "$1" >/dev/null 2>&1
}

# check openssl
if ! exists_command openssl; then
  dnf install -y openssl
fi

# check acme.sh upgrade
if [ ! -x /root/.acme.sh/acme.sh ]; then
  LOG "${C_BRED}acme.sh not exists! abort checking.${C_NONE}"
  exit 0
fi

# /root/.acme.sh/acme.sh --upgrade >/dev/null 2>&1

# list all fullchain.cer files
SSL_PATH="/data/nginx/ssl"
if [ ! -d "${SSL_PATH}" ]; then
  LOG "${C_BRED}${SSL_PATH} not exists! abort checking.${C_NONE}"
  exit 0
fi
current_time=$(date +"%s")
for cert_file in "${SSL_PATH}"/*fullchain.cer; do
  file_name=${cert_file##*/}
  domain=${file_name%%.fullchain*}
  if [[ -v API_KEYS[${domain}] ]]; then
    LOG "certificate ${C_BBLUE}${domain}${C_NONE} ${file_name}"
    # get expired time
    not_after=$(openssl x509 -in "${cert_file}" -noout -dates | grep notAfter)
    if [[ -v not_after ]]; then
      expire_time=${not_after##*=}
      expire_time=$(date -u -d "$expire_time" +"%s")
      LOG "    expired at $(date -d @"$expire_time" +"%F %T")"
      if [[ $((expire_time - current_time)) -lt 86400 ]]; then
        LOG "    certification will be expired in 86400 seconds, refresh it."
        export Ali_Key="${API_KEYS[${domain}]}"
        export Ali_Secret="${API_SECRETS[${domain}]}"
        /root/.acme.sh/acme.sh --force --renew -d "${domain}" >/dev/null 2>&1
        /root/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file "${SSL_PATH}/${domain}.key" --fullchain-file "${SSL_PATH}/${domain}.fullchain.cer" >/dev/null 2>&1
        systemctl reload nginx
        # check new expired time, $cert_file will be the same
        new_not_after=$(openssl x509 -in "${cert_file}" -noout -dates | grep notAfter)
        new_expire_time=${new_not_after##*=}
        LOG "    ${C_BGREEN}renewed, expired to $(date -d @"$new_expire_time" +"%F %T")${C_NONE}"
        if [[ expire_time -lt new_expire_time ]]; then
          LOG "    ${C_BGREEN}renew certification success.${C_NONE}"
        else
          LOG "    ${C_BRED}renew certification failed.${C_NONE}"
        fi
      else
        LOG "    certification still available, exit."
      fi
    else
      LOG "    expire time not found. [${not_after}]"
    fi
  else
    LOG "certificate ${C_BBLUE}${domain}${C_NONE} ${file_name} ${C_BRED}no app_key found!${C_NONE}"
  fi
done
