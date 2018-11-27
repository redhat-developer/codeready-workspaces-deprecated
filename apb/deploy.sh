#!/bin/bash
BASE_DIR=$(cd "$(dirname "$0")"; pwd)
HELP="
How to use this script:
-d,     --deploy          | deployment with envs from config.json
-p=,    --project=        | namespace to deploy Code Ready Workspaces
-c=,    --cert=           | absolute path to a self signed certificate which OpenShift Console uses
-oauth, --enable-oauth    | enable Log into CodeReady Workspaces with OpenShift credentials
--apb-image=              | installer image, defaults to "registry.access.redhat.com/codeready-workspaces/apb:1.0.0"
--server-image=           | server image, defaults to "registry.access.redhat.com/codeready-workspaces/server:1.0.0".
-h,     --help            | script help menu
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
    -p=*| --project=*)
      OPENSHIFT_PROJECT="${key#*=}"
      shift
      ;;
    --apb-image=*)
      APB_IMAGE_NAME=$(echo "${key#*=}")
      shift
      ;;
    --server-image=*)
      SERVER_IMAGE_NAME=$(echo "${key#*=}")
      shift
      ;;
    -d | --deploy)
      DEPLOY=true
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
DEFAULT_CHE_INFRA_KUBERNETES_PVC_STRATEGY="common"
export CHE_INFRA_KUBERNETES_PVC_STRATEGY=${CHE_INFRA_KUBERNETES_PVC_STRATEGY:-${DEFAULT_CHE_INFRA_KUBERNETES_PVC_STRATEGY}}

DEFAULT_SERVER_IMAGE_NAME="registry.access.redhat.com/codeready-workspaces/server:1.0.0"
export SERVER_IMAGE_NAME=${SERVER_IMAGE_NAME:-${DEFAULT_SERVER_IMAGE_NAME}}
DEFAULT_APB_NAME="codeready-workspaces"
export APB_NAME=${APB_NAME:-${DEFAULT_APB_NAME}}
DEFAULT_APB_IMAGE_NAME="registry.access.redhat.com/codeready-workspaces/apb:1.0.0" # TODO: switch to server-apb?
export APB_IMAGE_NAME=${APB_IMAGE_NAME:-${DEFAULT_APB_IMAGE_NAME}}


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
  printInfo "Welcome to CodeReady Workspaces Installer"
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
    OPENSHIFT_API_URI=$(${OC_BINARY} whoami --show-server)
    printInfo "Active session found. Your current context is: ${CONTEXT}"
    if [ ${ENABLE_OPENSHIFT_OAUTH} = true ] ; then
      ${OC_BINARY} get oauthclients > /dev/null 2>&1
      OUT=$?
      if [ ${OUT} -ne 0 ]; then
        printError "You have enabled OpenShift oAuth for your installation but this feature requires cluster-admin privileges. Login in as user with cluster-admin role"
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
    printInfo "You have chosen an option to enable Login With OpenShift. Granting cluster-admin privileges for apb service account"
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

  EXTRA_VARS=$(cat ${BASE_DIR}/config.json | tr -d '\n' | \
                                            sed "s@\${OPENSHIFT_PROJECT}@${OPENSHIFT_PROJECT}@g" | \
                                            sed "s@\${OPENSHIFT_API_URI}@${OPENSHIFT_API_URI}@g" | \
                                            sed "s@\${SERVER_IMAGE_NAME}@${SERVER_IMAGE_NAME}@g" | \
                                            sed "s@\${ENABLE_OPENSHIFT_OAUTH}@${ENABLE_OPENSHIFT_OAUTH}@g" | \
                                            sed "s@\${CHE_INFRA_KUBERNETES_PVC_STRATEGY}@${CHE_INFRA_KUBERNETES_PVC_STRATEGY}@g" | \
                                            sed "s@\${USE_SELF_SIGNED_CERT}@${USE_SELF_SIGNED_CERT}@g")

if [ "${JENKINS_BUILD}" = true ] ; then
  PARAMS="-i"
else
  PARAMS="-it"
fi

  ${OC_BINARY} run "${APB_NAME}-apb" ${PARAMS} --restart='Never' --image "${APB_IMAGE_NAME}" --env "OPENSHIFT_TOKEN=${OC_TOKEN}" --env "OPENSHIFT_TARGET=https://kubernetes.default.svc" --env "POD_NAME=${APB_NAME}-apb" --env "POD_NAMESPACE=${OPENSHIFT_PROJECT}" --overrides="{\"apiVersion\":\"v1\",\"spec\":{\"serviceAccountName\":\"codeready-apb\"}}" -- provision --extra-vars "${EXTRA_VARS}"

OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printError "Failed to deploy CodeReady Workspaces. Inspect error log."
    exit 1
  else

    printInfo "CodeReady Workspaces successfully deployed."
  fi
}

if [ "${DEPLOY}" = true ] ; then
  preReqs
  isLoggedIn
  createNewProject
  createServiceAccount
  createCertSecret
  deployCodeReady
fi
