#!/bin/bash
BASE_DIR=$(cd "$(dirname "$0")"; pwd)
HELP="
How to use this script:
-h,     --help            | script help menu
-p=,    --project=        | namespace to deploy Code Ready Workspaces
-c=,    --cert=           | absolute path to a self signed cert OpenShift Console uses
-oauth, --enable-oauth    | enable Login in with OpenShift
-i,     --interactive     | interactive mode
--apb-image=              | installer image, defaults to "172.30.1.1:5000/openshift/codeready-apb"
--server-image=           | server image, defaults to eclipse/che-server:nighly. Tag is MANDATORY
-f,     --fast            | fast deployment with envs from config.json
"

if [[ $# -eq 0 ]] ; then
  echo -e "$HELP"
  exit 0
fi
for key in "$@"
do
  case $key in
    -c=*| --cert=*)
      PATH_TO_SELF_SIGNED_CERT="${key#*=}"
      shift
      ;;
    -oauth| --enable-oauth)
      ENABLE_OPENSHIFT_OAUTH="true"
      shift
      ;;
    -api=*| --openshift-api=*)
      OPENSHIFT_API_URI="${key#*=}"
      shift
      ;;
    -p=*| --project=*)
      OPENSHIFT_PROJECT="${key#*=}"
      shift
      ;;
    --apb-image=*)
      APB_IMAGE="${key#*=}"
      shift
      ;;
    --server-image=*)
      SERVER_IMAGE_NAME=$(echo "${key#*=}" | sed 's/:.*//')
      SERVER_IMAGE_TAG=$(echo "${key#*=}" | sed 's/.*://')
      shift
      ;;
    -i | --interactive)
      INTERACTIVE=true
      ;;
    -f | --fast)
      FAST=true
      ;;
    -h | --help)
      echo -e "$HELP"
      exit 1
      ;;
    *)
      echo "Unknown argument passed: '$key'."
      echo -e "$HELP"
      exit 1
      ;;
  esac
done

export TERM=xterm

DEFAULT_OPENSHIFT_PROJECT="codeready"
export OPENSHIFT_PROJECT=${OPENSHIFT_PROJECT:-${DEFAULT_OPENSHIFT_PROJECT}}
DEFAULT_EXTERNAL_DB="false"
export EXTERNAL_DB=${EXTERNAL_DB:-${DEFAULT_EXTERNAL_DB}}
DEFAULT_DB_HOST="postgres"
export DB_HOST=${DB_HOST:-${DEFAULT_DB_HOST}}
DEFAULT_DB_PORT="5432"
export DB_PORT=${DB_PORT:-${DEFAULT_DB_PORT}}
DEFAULT_DB_NAME="dbcodeready"
export DB_NAME=${DB_NAME:-${DEFAULT_DB_NAME}}
DEFAULT_DB_USERNAME="pgcodeready"
export DB_USERNAME=${DB_USERNAME:-${DEFAULT_DB_USERNAME}}
DEFAULT_DB_PASSWORD="pgcodereadypassword"
export DB_PASSWORD=${DB_PASSWORD:-${DEFAULT_DB_PASSWORD}}
DEFAULT_EXTERNAL_KEYCLOAK="false"
export EXTERNAL_KEYCLOAK=${EXTERNAL_KEYCLOAK:-${DEFAULT_EXTERNAL_KEYCLOAK}}
DEFAULT_KEYCLOAK_PROVISION_REALM_USER="true"
export KEYCLOAK_PROVISION_REALM_USER=${KEYCLOAK_PROVISION_REALM_USER:-${DEFAULT_KEYCLOAK_PROVISION_REALM_USER}}
DEFAULT_KEYCLOAK_ADMIN_USERNAME="admin"
export KEYCLOAK_ADMIN_USERNAME=${KEYCLOAK_ADMIN_USERNAME:-${DEFAULT_KEYCLOAK_ADMIN_USERNAME}}
DEFAULT_KEYCLOAK_ADMIN_PASSWORD="admin"
export KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-${DEFAULT_KEYCLOAK_ADMIN_PASSWORD}}
DEFAULT_KEYCLOAK_REALM="codeready"
export KEYCLOAK_REALM=${KEYCLOAK_REALM:-${DEFAULT_KEYCLOAK_REALM}}
DEFAULT_KEYCLOAK_CLIENT_ID="codeready-public"
export KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-${DEFAULT_KEYCLOAK_CLIENT_ID}}
DEFAULT_SECURE_ROUTES="false"
export SECURE_ROUTES=${SECURE_ROUTES:-${DEFAULT_SECURE_ROUTES}}
DEFAULT_USE_SELF_SIGNED_CERT="false"
export USE_SELF_SIGNED_CERT=${USE_SELF_SIGNED_CERT:-${DEFAULT_USE_SELF_SIGNED_CERT}}
DEFAULT_ENABLE_OPENSHIFT_OAUTH="false"
export ENABLE_OPENSHIFT_OAUTH=${ENABLE_OPENSHIFT_OAUTH:-${DEFAULT_ENABLE_OPENSHIFT_OAUTH}}
DEFAULT_OPENSHIFT_API_URI=""
export OPENSHIFT_API_URI=${OPENSHIFT_API_URI:-${DEFAULT_OPENSHIFT_API_URI}}

DEFAULT_SERVER_IMAGE_NAME="eclipse/che-server"
export SERVER_IMAGE_NAME=${SERVER_IMAGE_NAME:-${DEFAULT_SERVER_IMAGE_NAME}}
DEFAULT_SERVER_IMAGE_TAG="latest"
export SERVER_IMAGE_TAG=${SERVER_IMAGE_TAG:-${DEFAULT_SERVER_IMAGE_TAG}}
DEFAULT_APB_NAME="codeready"
export APB_NAME=${APB_NAME:-${DEFAULT_APB_NAME}}
DEFAULT_APB_IMAGE="172.30.1.1:5000/openshift/codeready-apb"
export APB_IMAGE=${APB_IMAGE:-${DEFAULT_APB_IMAGE}}

printInfo() {
  green=`tput setaf 2`
  reset=`tput sgr0`
  echo "${green}[INFO]: ${1} ${reset}"
}

printWarning() {
  yellow=`tput setaf 3`
  reset=`tput sgr0`
  echo "${yellow}[WARNING]: ${1} ${reset}"
}

printError() {
  red=`tput setaf 1`
  reset=`tput sgr0`
  echo "${red}[ERROR]: ${1} ${reset}"
}

preReqs() {
  printInfo "Welcome to Code Ready Workspaces Installer"
  if [ -x "$(command -v oc)" ]; then
    printInfo "Found oc client in PATH"
    export OC_BINARY="oc"
  elif [[ -f "/tmp/oc" ]]; then
    printInfo "Using oc client from a tmp location"
    export OC_BINARY="/tmp/oc"
  else
    printError "Command line tool ${OC_BINARY} (https://docs.openshift.org/latest/cli_reference/get_started_cli.html) not found. Download oc client and add it to your \$PATH."
    exit 1
  fi
}

# check if ${OC_BINARY} client has an active session
isLoggedIn() {
  printInfo "Checking if you are currently logged in..."
  ${OC_BINARY} whoami -t > /dev/null
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printError "Log in to your OpenShift cluster: ${OC_BINARY} login --server=yourServer. Do not use system:admin login"
    exit 1
  else
    OC_TOKEN=$(${OC_BINARY} whoami -t)
    CONTEXT=$(${OC_BINARY} whoami -c)
    printInfo "Active session found. Your current context is: ${CONTEXT}"
    if [ ${ENABLE_OPENSHIFT_OAUTH} = true ] ; then
      ${OC_BINARY} get oauthclients > /dev/null 2>&1
      OUT=$?
      if [ ${OUT} -ne 0 ]; then
        printError "You have enabled OpenShift oAuth for your installation but this feature requires cluster-admin priviliges. Login in as user with cluster-admin role"
        exit $OUT
      fi
    fi
  fi
}

createNewProject() {
  printInfo "Creating namespace \"${OPENSHIFT_PROJECT}\""
  # sometimes even if the project does not exist creating a new one is impossible as it apparently exists
  sleep 1
  ${OC_BINARY} new-project "${OPENSHIFT_PROJECT}" > /dev/null
  OUT=$?
  if [ ${OUT} -eq 1 ]; then
    printError "Failed to create namespace ${OPENSHIFT_PROJECT}. It may exist in someone else's account or namespace deletion has not been fully completed. Try again in a short while or pick a different project name -p=myProject"
    exit ${OUT}
  else
    printInfo "Namespace \"${OPENSHIFT_PROJECT}\" successfully created"
  fi
}

createServiceAccount() {
  printInfo "Creating installer service account"
  ${OC_BINARY} create sa codeready-apb -n=${OPENSHIFT_PROJECT}
  if [ ${ENABLE_OPENSHIFT_OAUTH} = true ] ; then
    printInfo "You have chosen an option to enable Login With OpenShift. Granting cluster-admin priviliges for apb service account"
    ${OC_BINARY} adm policy add-cluster-role-to-user cluster-admin -z codeready-apb
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
      printError "Failed to grant cluster-admin role to abp service account"
      exit $OUT
    fi
  fi
}

createCertSecret(){
  if [ ! -z "${PATH_TO_SELF_SIGNED_CERT}" ]; then
    printInfo "You have provided a path to a self-signed certificate. Creating a secret..."
    ${OC_BINARY} create secret generic self-signed-cert --from-file=${PATH_TO_SELF_SIGNED_CERT} -n=${OPENSHIFT_PROJECT}
    OUT=$?
      if [ ${OUT} -ne 0 ]; then
        printError "Failed to create a secret"
        exit ${OUT}
      else
        printInfo "Secret openshift-identity-provider successfully created from ${PATH_TO_SELF_SIGNED_CERT}"
      fi
  fi
}

deployCodeReady() {

  if [ ! -z "${PATH_TO_SELF_SIGNED_CERT}" ]; then
  USE_SELF_SIGNED_CERT=true
  fi

  EXTRA_VARS="{\"che_external_db\": ${EXTERNAL_DB},\"che_jdbc_db_host\": \"${DB_HOST}\",\"che_jdbc_db_port\": \"${DB_PORT}\",\"che_jdbc_db_name\": \"${DB_NAME}\",\"che_jdbc_username\": \"${DB_USERNAME}\",\"che_jdbc_password\": \"${DB_PASSWORD}\",\"external_keycloak\": ${EXTERNAL_KEYCLOAK},\"che_secure_routes\": ${SECURE_ROUTES},\"keycloak_provision_realm_user\": ${KEYCLOAK_PROVISION_REALM_USER},\"che_keycloak_admin_username\": \"${KEYCLOAK_ADMIN_USERNAME}\",\"che_keycloak_admin_password\": \"${KEYCLOAK_ADMIN_PASSWORD}\",\"namespace\": \"${OPENSHIFT_PROJECT}\",\"che_keycloak_realm\": \"${KEYCLOAK_REALM}\",\"che_keycloak_client__id\": \"${KEYCLOAK_CLIENT_ID}\",\"external_keycloak_uri\": \"$KEYCLOAK_URI\",\"use_self_signed_cert\": \"${USE_SELF_SIGNED_CERT}\",\"enable_openshift_oauth\": \"${ENABLE_OPENSHIFT_OAUTH}\",\"openshift_api_uri\": \"${OPENSHIFT_API_URI}\"}"

if [ "${FAST}" = true ] ; then
  EXTRA_VARS=$(cat ${BASE_DIR}/config.json | tr -d '\n' | \
                                            sed "s@\${OPENSHIFT_PROJECT}@${OPENSHIFT_PROJECT}@g" | \
                                            sed "s@\${OPENSHIFT_API_URI}@${OPENSHIFT_API_URI}@g" | \
                                            sed "s@\${SERVER_IMAGE_NAME}@${SERVER_IMAGE_NAME}@g" | \
                                            sed "s@\${SERVER_IMAGE_TAG}@${SERVER_IMAGE_TAG}@g" | \
                                            sed "s@\${ENABLE_OPENSHIFT_OAUTH}@${ENABLE_OPENSHIFT_OAUTH}@g" | \
                                            sed "s@\${USE_SELF_SIGNED_CERT}@${USE_SELF_SIGNED_CERT}@g")
fi

if [ "${JENKINS_BUILD}" = true ] ; then
  PARAMS="-i"
else
  PARAMS="-it"
fi

  ${OC_BINARY} run "${APB_NAME}" ${PARAMS} --restart='Never' --image "${APB_IMAGE}" --env "OPENSHIFT_TOKEN=${OC_TOKEN}" --env "OPENSHIFT_TARGET=https://kubernetes.default.svc" --env "POD_NAME=${APB_NAME}" --env "POD_NAMESPACE=${OPENSHIFT_PROJECT}" --overrides="{\"apiVersion\":\"v1\",\"spec\":{\"serviceAccountName\":\"codeready-apb\"}}" -- provision --extra-vars "${EXTRA_VARS}"

OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printError "Failed to deploy Code Ready Workspaces. Inspect error log"
    exit 1
  else

    printInfo "Code Ready Workspaces succesfully deployed"
  fi
}


reviewParams() {
  printInfo "Review deployment parameters:"
  echo
  printInfo "HTTPS Support: $SECURE_ROUTES"
  printInfo "External DB: $EXTERNAL_DB"
  printInfo "Database host: $DB_HOST"
  printInfo "Database port: $DB_PORT"
  printInfo "Database name: $DB_NAME"
  printInfo "Database user: $DB_USERNAME"
  printInfo "Database password: $DB_PASSWORD"
  printInfo "Use external Red Hat SSO: $EXTERNAL_KEYCLOAK"
  printInfo "External Keycloak URI: $KEYCLOAK_URI"
  printInfo "Red Hat SSO admin username: $KEYCLOAK_ADMIN_USERNAME"
  printInfo "Red Hat SSO admin password: $KEYCLOAK_ADMIN_PASSWORD"
  printInfo "Red Hat SSO realm: $KEYCLOAK_REALM"
  printInfo "Red Hat SSO client: $KEYCLOAK_CLIENT_ID"
  printInfo "Enable Login With OpenShift: ${ENABLE_OPENSHIFT_OAUTH}"
  printInfo "OpenShift API URL: ${OPENSHIFT_API_URI}"
  read -p "Press any key to continue "

}

interactiveDeployment() {
  preReqs
  isLoggedIn
  createNewProject
  createCertSecret
  printInfo "Configure your Code Ready Workspaces Installation"
  read -r -p "Do you need https support? Defaults to http [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
  then
    export SECURE_ROUTES="true"
    printWarning "Important! If you have self signed certificates, you need to follow documentation at https://www.eclipse.org/che/docs/openshift-config.html#https-mode---self-signed-certs"
  fi

  read -r -p "Do you want to setup Login with OpenShift for Code Ready Workspaces (requires cluster-admin privileges)? Press Enter to skip [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
  then
    export ENABLE_OPENSHIFT_OAUTH="true"
    read -p "Enter your OpenShift API URL, e.g. https://172.23.126.20:8443: " response
    if [ -z "$response" ]; then
      printWarning "No valude provided, using default value"
    else
      export OPENSHIFT_API_URI=$response
    fi
  fi

  createServiceAccount

  db_array_questions=(
    "Enter DB hostname (defaults to $DEFAULT_DB_HOST): "
    "Enter DB port (defaults to $DEFAULT_DB_PORT): "
    "Enter DB Name (defaults to $DB_NAME): "
    "Enter DB Username (defaults to $DB_USERNAME): "
  )
  db_array_envs=(
    "DB_HOST"
    "DB_PORT"
    "DB_NAME"
    "DB_USERNAME"
  )
  read -r -p "Do you want to connect to an external Postgres DB? Press Enter to skip [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
  then
    export EXTERNAL_DB="true"
    printInfo "Provide connection details. Make sure database exists, and db user is a SUPERUSER"
  fi

  if [ "${EXTERNAL_DB}" = false ] ; then
    db_array_questions=( "${db_array_questions[@]:2:3}" )
    db_array_envs=( "${db_array_envs[@]:2:3}" )
  fi

  for ((i=0;i<${#db_array_questions[@]};++i)); do
    read -p "${db_array_questions[i]}" response
    if [ -z "$response" ]; then
      printWarning "No valude provided, using default value"
    else
      export ${db_array_envs[i]}=$response
    fi
  done
  # get DB password
  askForPassword() {
    while true; do
      read -s -p "$1" password
      if [ -z "$password" ]; then
        echo
        printWarning "No valude provided, using default value"
      else
        echo
        read -s -p "Confirm  password: " password2
        export $2=$password
      fi
      echo
      [ "$password" = "$password2" ] && break
      printWarning "Passwords do not match. Please try again"
      export DB_PASSWORD=$password
    done
  }

  askForPassword "Enter DB user password (defaults to $DB_PASSWORD):  " "DB_PASSWORD"

  keycloak_array_questions=(
    "Enter Red Hat SSo URL (no trailing "/auth"): "
    "Enter Red Hat SSO realm name (defaults to $KEYCLOAK_REALM): "
    "Enter Red Hat SSO client name (defaults to $KEYCLOAK_CLIENT_ID): "
    "Enter Red Hat SSO admin username (defaults to $KEYCLOAK_ADMIN_USERNAME): "
  )
  keycloak_array_envs=(
    "KEYCLOAK_URI"
    "KEYCLOAK_REALM"
    "KEYCLOAK_CLIENT_ID"
    "KEYCLOAK_ADMIN_USERNAME"
  )

  read -r -p "Do you want to connect to an external Red Hat SSO instance? Press Enter to skip [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
  then
    export EXTERNAL_KEYCLOAK="true"
    printInfo "Provide Sed Hat SSO URL, eg, http://red-hat-sso.com. No training '/auth'!"
  fi
  if [ "${EXTERNAL_KEYCLOAK}" = false ] ; then
    keycloak_array_questions=( "${keycloak_array_questions[@]:3:3}" )
    keycloak_array_envs=( "${keycloak_array_envs[@]:3:3}" )
  fi

  for ((i=0;i<${#keycloak_array_questions[@]};++i)); do
    read -p "${keycloak_array_questions[i]}" response
    if [ -z "$response" ]; then
      printWarning "No valude provided, using default value"
    else
      export ${keycloak_array_envs[i]}=$response
    fi
  done

  askForPassword "Enter Keycloak admin password (defaults to $KEYCLOAK_ADMIN_PASSWORD):  " "KEYCLOAK_ADMIN_PASSWORD"
  reviewParams
  deployCodeReady

}
if [ "${INTERACTIVE}" = true ] ; then
  interactiveDeployment
fi

if [ "${FAST}" = true ] ; then
  preReqs
  isLoggedIn
  createNewProject
  createServiceAccount
  createCertSecret
  deployCodeReady
fi
