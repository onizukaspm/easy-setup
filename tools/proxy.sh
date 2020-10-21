# just change ip & port
PROXY_URL="http://192.168.7.253:7777/"

export HTTP_PROXY="${PROXY_URL}"
export HTTPS_PROXY="${PROXY_URL}"
export FTP_PROXY="${PROXY_URL}"
export NO_PROXY="127.0.0.1,localhost"
export http_proxy="${PROXY_URL}"
export https_proxy="${PROXY_URL}"
export ftp_proxy="${PROXY_URL}"
export no_proxy="127.0.0.1,localhost"

# proxy on : source proxy.sh
# proxy off: unset HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY http_proxy https_proxy ftp_proxy no_proxy
