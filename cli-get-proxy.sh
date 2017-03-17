#! /bin/bash

INTERACTIVE=YES
export WATTSON_URL=https://watts-dev.data.kit.edu
pluginName="X509_RCauth_Pilot"

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
    --remove)
      USE=YES
      REMOVE=YES
      # shift
      ;;
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
    exit 1
  fi
  executable=`which jq`
  if [ -z "$executable" ]; then
    echo "Please install jq, it's needed to parse json. Exiting..."
    exit 1
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
    echo -e "\e[91mwrong provider, exiting\033[1m"
    exit
  fi

  export oidcProvider
}

function input_access_token () {

  echo "Paste your OIDC access token, that correspond to correct issuer, in this case "$WATTSON_ISSUER
  read OIDC_AT
  if [ -z "$OIDC_AT" ]; then
    echo -e "\e[93mAccess token is empty, something is wrong, exiting...\033[1;m"
    exit
  fi
  export OIDC_AT

}

function get_proxy () {


  userid=`id -u`

  echo "Requesting certificate from WaTTS"
  result=`wattson -j request $pluginName`
  error_val=`echo $result | grep -i error`
  if [[ ! -z $error_val ]]; then
    echo -e "\e[101m$error_val \033[1;m"
    echo "Exiting.."
    exit 1
  fi
  echo $result | jq -r .credential.entries[0].value > /tmp/x509up_u$userid
  chmod 600 /tmp/x509up_u$userid
  echo "Certificate received and save as /tmp/x509up_u$userid"
  echo "Checking whether grid-proxy-info is present"
  local executable=`which grid-proxy-info`

  if [ -z "$executable" ]; then
    echo "it seems you don't have grid utils"
    echo "on Debian OS' it's usually globus-proxy-utils package"
    echo "stopping the script without running grid-proxy-info "
    echo "your proxy cert is /tmp/x509up_u$userid"
    exit 0
  fi
  echo "grid-proxy-init found"
  echo "Running grid-proxy-info"
  grid-proxy-info

}

function remove_certificate () {
  echo "Removing certificate.."
  # result=`wattson -j lscred | jq -r .credential_list `
  result=`wattson -j lscred`
  error_val=`echo $result | grep -i error`
  if [[ ! -z $error_val ]]; then
    echo -e "\e[101m$error_val \033[1;m"
    echo "Exiting.."
    exit 1
  fi

  result=`echo $result | jq -r .credential_list`
  length=`echo $result | jq length`
  if [[ "$length" == "0" ]]; then
    echo "No credentials stored, exiting.."
    exit 0
  fi
  # serviceId=`echo $result | jq -r .credential_list[0].serviceId`
  echo "get credential id"
  for ((j=0; j<$length;j++)); do
    serviceId=`echo $result | jq -r .[$j].service_id`
    if [[ "$serviceId" == "$pluginName"  ]]; then
      credId=`echo $result | jq -r .[$j].cred_id`
      # echo "cred id is:" $credId
      break
    fi

  done


  result_revoke=`wattson -j revoke $credId`
  # echo "$result_revoke"
  echo "Certificate removed"

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
          echo -e "\e[91mwrong provider, exiting\033[1m"
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
          echo -e "\e[93mTOKEN is empty, exiting\033[1;m"
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
      echo -e "\e[91mwrong provider, exiting\033[1m"
      exit 1
    fi
    export WATTSON_TOKEN=$TOKEN
    export WATTSON_ISSUER=$PROVIDER
  fi

  if [[ $REMOVE ]]; then
    remove_certificate
    exit 0
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
