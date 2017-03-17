#! /bin/bash

INTERACTIVE=YES
export WATTSON_URL=https://watts-dev.data.kit.edu

input=$@
while :; do
  case $1 in
    -h)
      USE=YES
      SHOW_USAGE=YES
      shift
      ;;
    #-i)
      #INTERACTIVE=YES
      #shift
      #;;
    -p)
      USE=YES
      PROVIDER="$2"
      shift
      ;;
    -lsprov)
      USE=YES
      SHOW_PROVIDERS=YES
      ;;
    -watts)
      USE=YES
      WATTSON_URL="$2"
      shift
      ;;
    #-t=*)
      #TOKEN="${i#*=}"
      #shift
      #;;
    #*)
      #WRONG=YES
      #shift
      #;;
    *)               # Default case: If no more options then break out of the loop.
      break
  esac
  shift
done

if [[ ! -z "$input" && -z $USE ]]; then
  WRONG=YES
fi

function print_help () {
    echo -e ""
    echo "  Usage: $0 [option]"
    echo -e "  Options are:"
    echo -e ""
    echo -e "\e[33m      -h:      \033[1;m print this message and exit"
    echo -e "\e[33m      -p:      \033[1;m provider name"
    echo -e "\e[33m      -lsprov: \033[1;m show available providers"
    echo -e "\e[33m      -watts:  \033[1;m URL to reach WaTTS. (Default: $WATTSON_URL)"
    echo -e "  You can combine \e[33m-p\033[1;m and \e[33m-watts\033[1;m."
    echo -e "  Arguments \e[33mlsprov\033[1;m and \e[33mh\033[1;m have priority."
    echo -e "  Wrong arguments will be ignored, or shown an error."
    echo -e '\n  The OIDC Token will be taken from the $OIDC environment variable, if available. Otherwise you will be promted.\n'
}


function check_wattson () {

  local executable=`which wattson`

  if [ -z "$executable" ]; then
    echo "you don't have wattson app installed!!"
    echo "plase download a package or the binary from"
    echo "https://github.com/indigo-dc/wattson/releases/latest"
    echo "and install the package or copy the binary into your $PATH"
    exit
  fi

}

function show_providers () {
  echo "checking for providers"
  PROVS=`wattson lsprov | grep Provider | awk '{print $2}'`
  PROVS=($PROVS)
  numProvs=`echo ${#PROVS[@]}`

  echo "available providers, listed as [name][status]"
  # echo "input the desired ready provider"
  echo "-----"
  for ((j=0; j<${#PROVS[@]};j++)); do
    echo "${PROVS[$j]}"
  done
  echo "-----"
}

function show_providers_and_select () {
  show_providers
  echo -e "input the desired provider (WaTTS Issuer Id) with \e[33m ready \033[1;m status "
  read oidcProvider
  if [[ ${PROVS[@]} != *$oidcProvider* ]]; then
    echo "wrong provider, exiting"
    exit
  fi

  export oidcProvider
}

function input_access_token () {

  echo "Paste your OIDC access token, that correspond to correct issuer, in this case "$WATTSON_ISSUER
  read OIDC_AT
  if [ -z "$OIDC_AT" ]; then
    echo "Access token is empty, something is wrong, exiting..."
    exit
  fi
  export OIDC_AT

}

function get_proxy () {

  pluginName="X509_RCauth_Pilot"

  userid=`id -u`

  # echo "remove existing proxy with name x509up_u$userid in current folder"
  #echo "check and remove old cert"
  #if [ -f /tmp/x509up_u$userid ]; then
    #rm /tmp/x509up_u$userid
  #fi
  #if [ -f x509up_u$userid ]; then
    #rm x509up_u$userid
  #fi
  echo "request certificate from WaTTS"
  result=`wattson -j request $pluginName`
  error_val=`echo $result | grep -i error`
  if [[ ! -z $error_val ]]; then
    echo "Received '$error_val'. Wrong access token? Exiting..."
    exit 1
  fi
  echo $result | jq -r .credential.entries[0].value > /tmp/x509up_u$userid
  echo "done"
  chmod 600 /tmp/x509up_u$userid
  echo "checking for grid-proxy-info"
  local executable=`which grid-proxy-info`

  if [ -z "$executable" ]; then
    echo "it seems you don't have grid utils"
    echo "on Debian OS' it's usually globus-proxy-utils package"
    echo "stopping the script without running grid-proxy-info "
    echo "your proxy cert is x509up_u$userid in $PWD"
    exit
  fi
  echo "grid-proxy-init found"
  echo "running grid-proxy-info"
  grid-proxy-info

}


function main () {

  check_wattson
  if [[ "$INTERACTIVE" ]]; then
    if [ -z "$PROVIDER" ]; then
        show_providers_and_select
        export WATTSON_ISSUER=$oidcProvider
    else
        PROVS=`wattson lsprov | grep Provider | awk '{print $2}'`
        PROVS=($PROVS)
        if [[ ${PROVS[@]} != *$PROVIDER* ]]; then
          echo "wrong provider, exiting"
          exit 1
        fi
        export WATTSON_ISSUER=$PROVIDER
    fi
    if [ -z $OIDC ]; then
        input_access_token
        export WATTSON_TOKEN=$OIDC_AT
    else
        echo 'Using OIDC Access Token from ENV $OIDC'
        export WATTSON_TOKEN=$OIDC
    fi
  else
    if [ -z "$TOKEN" ]; then
      if [ -z "$OIDC" ]; then
          echo "TOKEN is empty, exiting"
          exit
      else
          echo 'Using OIDC Access Token from ENV $OIDC'
          TOKEN=$OIDC
      fi
    fi
    if [ -z "$PROVIDER" ]; then
      echo "issuer (provider) is empty, exiting"
    fi
    PROVS=`wattson lsprov | grep Provider | awk '{print $2}'`
    PROVS=($PROVS)
    if [[ ${PROVS[@]} != *$PROVIDER* ]]; then
      echo "wrong provider, exiting"
      exit 1
    fi
    export WATTSON_TOKEN=$TOKEN
    export WATTSON_ISSUER=$PROVIDER
  fi

  get_proxy
  exit 0

}
# script starts here
if [ "$SHOW_USAGE" ]; then
    print_help
    exit 0
fi
if [ "$WRONG" ]; then
    echo -e "\e[31m!!!WRONG ARGUMENT!!! check $0 -h \033[1;m"
    exit 1
fi
#if [ -z "$input" ]; then
    #print_help
    #exit 0
#fi
if [ "x$SHOW_PROVIDERS" == "xYES" ]; then
    show_providers
    exit 0
fi
main
