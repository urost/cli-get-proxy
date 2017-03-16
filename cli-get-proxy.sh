#! /bin/bash

INTERACTIVE=YES

input=$@
for i in "$@";do
  case $i in
    -h)
      SHOW_USAGE=YES
      shift
      ;;
    #-i)
      #INTERACTIVE=YES
      #shift
      #;;
    -p=*)
      PROVIDER="${i#*=}"
      shift
      ;;
    -t=*)
      TOKEN="${i#*=}"
      shift
      ;;
    *)
      WRONG=YES
      shift
      ;;
  esac
done

function print_help () {
    echo -e ""
    echo "Usage: cmd_line_get_proxy [option]"
    echo -e "Options are:"
    echo -e ""
    echo -e "\e[33m      -h: \033[1;m print this message and exit"
    #echo -e "\e[33m      -i: \033[1;m interactive, promts user for provider and access token"
    echo -e "\e[33m      -p=: \033[1;m provider name"
    echo -e "\e[33m      -t=: \033[1;m token value"
    echo -e " when using interactive mode, -p and -t values are ignored"
}


function check_wattson () {

  local executable=`which wattson`

  if [ -z "$executable" ]; then
    echo "you don't have wattson app installed!!"
    echo "please clone https://github.com/indigo-dc/wattson"
    echo "build and place the wattson executable in the PATH"
    echo "build instructions: https://indigo-dc.gitbooks.io/wattson/content/admin.html"
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
  echo "check and remove old cert"
  if [ -f /tmp/x509up_u$userid ]; then
    rm /tmp/x509up_u$userid
  fi
  if [ -f x509up_u$userid ]; then
    rm x509up_u$userid
  fi
  echo "request certificate from WaTTS"
  wattson -j request $pluginName | jq -r .credential.entries[0].value > /tmp/x509up_u$userid
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

  export WATTSON_URL=https://watts-dev.data.kit.edu
  check_wattson
  if [[ "$INTERACTIVE" ]]; then
    if [ -z "$PROVIDER" ]; then
        show_providers
        export WATTSON_ISSUER=$oidcProvider
    else
        export WATTSON_ISSUER=$PROVIDER
    fi
    if [ -z $OIDC ]; then
        input_access_token
        export WATTSON_TOKEN=$OIDC_AT
        echo inp
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
      exit
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
    echo -e "\e[31m  !!!WRONG ARGUMENT!!! check cmd_line_get_proxy -h \033[1;m"
    exit
fi
#if [ -z "$input" ]; then
    #print_help
    #exit 0
#fi
main



