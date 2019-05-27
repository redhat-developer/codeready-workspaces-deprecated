#!/bin/bash 
BASE_DIR=$(cd "$(dirname "$0")"; pwd)

DEBUG=0 # set to 1 for more output

CRW_VERSION="1.2"

# new default images & versions
SSO_IMAGE="registry.redhat.io/redhat-sso-7/sso73-openshift:1.0-11"
PG_IMAGE="registry.redhat.io/rhscl/postgresql-96-rhel7:1-40"
OPERATOR_CONTAINER="server-operator-rhel8"
SERVER_CONTAINER="server-rhel8"

DEFAULT_REGISTRY_PREFIX="registry.redhat.io/codeready-workspaces" # could also use another registry, like quay.io/crw
DEFAULT_DOCKER_CONFIG_JSON="${HOME}/.docker/config.json" # where your registry auth keys are stored
DEFAULT_OPENSHIFT_PROJECT="workspaces" 
HELP="

How to use this script to migrate from CRW 1.1 to ${CRW_VERSION}:
-r=,    --registry=           | registry prefix for CodeReady Workspaces, default: ${DEFAULT_REGISTRY_PREFIX}
-p=,    --project=            | project namespace to deploy CodeReady Workspaces, default: ${DEFAULT_OPENSHIFT_PROJECT}
-d=,    --docker-config=      | path to config.json file which contains auth key for registry.redhat.io, default: ${DEFAULT_DOCKER_CONFIG_JSON}
-X,     --debug               | more console output
-h,     --help                | show this help menu
"
if [[ $# -eq 0 ]] ; then
  echo -e "$HELP"
  exit 0
fi
for key in "$@"
do
  case $key in
    -r=*| --registry=*)
      REGISTRY_PREFIX="${key#*=}"
      shift
      ;;
    -p=*| --project=*)
      OPENSHIFT_PROJECT="${key#*=}"
      shift
      ;;
    --docker-config=*)
      DOCKER_CONFIG_JSON="${key#*=}"
      shift
      ;;
    -h | --help)
      echo -e "$HELP"
      exit 1
      ;;
    -X | --debug)
      DEBUG=1
      ;;
    *)
      echo "Unknown argument passed: '$key'."
      echo -e "$HELP"
      exit 1
      ;;
  esac
done

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

if [ -x "$(command -v oc)" ]; then
  if [[ ${DEBUG} -eq 1 ]]; then printInfo "Found oc client in PATH"; fi
  export OC_BINARY="oc"
elif [[ -f "/tmp/oc" ]]; then
  printInfo "Using oc client from a tmp location"
  export OC_BINARY="/tmp/oc"
else
  printError "Command line tool oc (https://docs.openshift.org/latest/cli_reference/get_started_cli.html) not found. Download oc client and add it to your PATH."
  exit 1
fi

if [ -x "$(command -v jq)" ]; then
  if [[ ${DEBUG} -eq 1 ]]; then printInfo "Found jq in PATH"; fi
  export JQ_BINARY="jq"
elif [[ -f "/tmp/jq" ]]; then
  printInfo "Using jq from a tmp location"
  export JQ_BINARY="/tmp/jq"
else
  printError "Command line tool jq (https://stedolan.github.io/jq/) not found. Download jq client and add it to your PATH."
  exit 1
fi

# if using quay.io, operator is simply operator-rhel8; if using RHCC, it's server-operator-rhel8
if [[ ${REGISTRY_PREFIX} == "quay.io/crw" ]]; then OPERATOR_CONTAINER="operator-rhel8"; fi

export REGISTRY_PREFIX=${REGISTRY_PREFIX:-${DEFAULT_REGISTRY_PREFIX}}
export OPENSHIFT_PROJECT=${OPENSHIFT_PROJECT:-${DEFAULT_OPENSHIFT_PROJECT}}
export DOCKER_CONFIG_JSON=${DOCKER_CONFIG_JSON:-${DEFAULT_DOCKER_CONFIG_JSON}}
if [[ $DEBUG -eq 1 ]]; then printInfo "
REGISTRY_PREFIX=${REGISTRY_PREFIX}
OPENSHIFT_PROJECT=${OPENSHIFT_PROJECT}
DOCKER_CONFIG_JSON=${DOCKER_CONFIG_JSON}
"; fi

# check `oc project` for the selected project (this also confirms we're logged in)
status="$(${OC_BINARY} project 2>&1)"
if [[ $status == *"error"* ]]; then
	echo "$status" && exit 1
fi

POSTGRESQL_PASSWORD=$(${OC_BINARY} get deployment keycloak -o=jsonpath={'.spec.template.spec.containers[0].env[?(@.name=="DB_PASSWORD")].value'} -n=$OPENSHIFT_PROJECT)

# check if oc client has an active session
isLoggedIn() {
  printInfo "Checking if you are currently logged in..."
  ${OC_BINARY} whoami > /dev/null
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printError "Log in to your OpenShift cluster: ${OC_BINARY} login --server=yourServer"
    exit 1
  else
    CONTEXT=$(${OC_BINARY} whoami -c)
    printInfo "Active session found. Your current context is: ${CONTEXT}"
      ${OC_BINARY} get customresourcedefinitions > /dev/null 2>&1
      OUT=$?
      if [ ${OUT} -ne 0 ]; then
        printWarning "Creation of a CRD and RBAC rules requires cluster-admin privileges. Login in as user with cluster-admin role"
        printWarning "The installer will continue, however deployment is likely to fail"
    fi
  fi
}

checkAuthenticationWithRegistryRedhatIo()
{
  AUTH_INSTRUCTIONS="You must authenticate with registry.redhat.io in order for this script to proceed.

      Steps:

      1. Get a login for the registry.   Details: https://access.redhat.com/RegistryAuthentication#getting-a-red-hat-login-2
      2. Log in using your new username. Details: https://access.redhat.com/RegistryAuthentication#using-authentication-3
      3. If you've done the above steps and your token is stored in ${DOCKER_CONFIG_JSON} re-run this script.
      4. NOTE: you may want to import only one token (not all of them) into your cluster. If so use a different file than ${DOCKER_CONFIG_JSON}, eg.,
               $0 --docker-config=/path/to/alternate.config.json ...
      4. If it still fails, see https://access.redhat.com/RegistryAuthentication#allowing-pods-to-reference-images-from-other-secured-registries-9

  "

  # check if we already have a name=registryredhatio or type=kubernetes.io/dockerconfigjson secret
  if [[ "$(oc get secret registryredhatio 2>&1)" == *"No resources found"* ]] || \
     [[ "$(oc get secret --field-selector='type=kubernetes.io/dockerconfigjson' 2>&1)" == *"No resources found"* ]]; then

    if [[ ! -f ${DOCKER_CONFIG_JSON} ]] && [[ ${DOCKER_CONFIG_JSON} != ${DEFAULT_DOCKER_CONFIG_JSON} ]]; then
      echo; printWarning "Cannot authenticate using ${DOCKER_CONFIG_JSON} - file does not exist."
      exit 1
    fi

    echo; printInfo "Attempt to authenticate with registry.redhat.io using ${DOCKER_CONFIG_JSON}:"
    if [[ -f ${DOCKER_CONFIG_JSON} ]] && [[ ! $(grep registry.redhat.io ${DOCKER_CONFIG_JSON}) ]]; then 
      printError "Cannot authenticate using ${DOCKER_CONFIG_JSON} - registry.redhat.io key does not exist."
    fi

    # find the relevant part of the config.json file
    DOCKER_CONFIG_JSON_TMP=/tmp/registryredhatio-docker-config.json
    if [[ -f ${DOCKER_CONFIG_JSON} ]] && [[ $(grep registry.redhat.io ${DOCKER_CONFIG_JSON}) ]]; then # config is found and we probably have a key
      cat ${DOCKER_CONFIG_JSON} | ${JQ_BINARY} '{auths:{"registry.redhat.io": .auths|."registry.redhat.io"?}}' > ${DOCKER_CONFIG_JSON_TMP}
      cat  ${DOCKER_CONFIG_JSON_TMP}

      # Ensure CRW can authenticate with new registry registry.redhat.io to pull images
      ${OC_BINARY} create secret generic registryredhatio --from-file=.dockerconfigjson=${DOCKER_CONFIG_JSON_TMP} --type=kubernetes.io/dockerconfigjson
      ${OC_BINARY} secrets link default registryredhatio --for=pull
      ${OC_BINARY} secrets link builder registryredhatio
      rm -f ${DOCKER_CONFIG_JSON_TMP}
    else
      printError "${AUTH_INSTRUCTIONS}"
      exit 1
    fi
  fi
  if [[ "$(oc get secret registryredhatio 2>&1)" == *"No resources found"* ]] || \
     [[ "$(oc get secret --field-selector='type=kubernetes.io/dockerconfigjson' 2>&1)" == *"No resources found"* ]]; then 
    echo; printError "Could not authenticate with registry.redhat.io!"
    echo; printError "${AUTH_INSTRUCTIONS}"
    exit 1
  fi

  printInfo "Authenticated with registry.redhat.io:"
  if [[ $DEBUG -eq 1 ]]; then
    oc get secret registryredhatio -o=json
  else
    oc get secret registryredhatio
  fi
}

isLoggedIn
checkAuthenticationWithRegistryRedhatIo

# update to latest defaults
PATCH_JSON=$(cat << EOF
{
  "spec": {
    "database": {
      "postgresImage": "${PG_IMAGE}"
    },
    "auth": {
      "identityProviderPostgresPassword": "${REGISTRY_PREFIX}",
      "identityProviderImage": "${SSO_IMAGE}",
      "identityProviderPostgresPassword":"${POSTGRESQL_PASSWORD}"
    },
    "server": {
      "cheImage":"${REGISTRY_PREFIX}/${SERVER_CONTAINER}",
      "cheImageTag":"${CRW_VERSION}"
    }
  }
}
EOF
)

echo; printInfo "Patch checluster CR with:"
echo ${PATCH_JSON} | ${JQ_BINARY}

if [[ $DEBUG -eq 1 ]]; then printInfo "Unpatched checluster CR:"; echo "============>"; ${OC_BINARY} get checluster codeready -o json; echo "<============"; fi

${OC_BINARY} patch checluster codeready -p "${PATCH_JSON}" --type merge -n ${OPENSHIFT_PROJECT}
#  echo $?

if [[ $DEBUG -eq 1 ]]; then printInfo "Patched checluster CR:"; echo "============>>"; ${OC_BINARY} get checluster codeready -o json; echo "<<============"; fi

waitForDeployment()
{
  deploymentName=$1
  DEPLOYMENT_TIMEOUT_SEC=300
  POLLING_INTERVAL_SEC=5
  printInfo "Waiting for the deployment/${deploymentName} to be scaled to 1. Timeout ${DEPLOYMENT_TIMEOUT_SEC} seconds"
  DESIRED_REPLICA_COUNT=1
  UNAVAILABLE=1
  end=$((SECONDS+DEPLOYMENT_TIMEOUT_SEC))
  while [[ "${UNAVAILABLE}" -eq 1 ]] && [[ ${SECONDS} -lt ${end} ]]; do
    UNAVAILABLE=$(${OC_BINARY} get deployment/${deploymentName} -n="${OPENSHIFT_PROJECT}" -o=jsonpath='{.status.unavailableReplicas}')
    if [[ ${DEBUG} -eq 1 ]]; then printInfo "Deployment is in progress...(Unavailable replica count=${UNAVAILABLE}, ${timeout_in} seconds remain)"; fi
    sleep 3
  done
  if [[ "${UNAVAILABLE}" == 1 ]]; then
    printError "Deployment timeout. Aborting."
    printError "Check deployment logs and events:"
    printError "${OC_BINARY} logs deployment/${deploymentName} -n ${OPENSHIFT_PROJECT}"
    printError "${OC_BINARY} get events -n ${OPENSHIFT_PROJECT}"
    exit 1
  fi

  CURRENT_REPLICA_COUNT=-1
  while [[ "${CURRENT_REPLICA_COUNT}" -ne "${DESIRED_REPLICA_COUNT}" ]] && [[ ${SECONDS} -lt ${end} ]]; do
    CURRENT_REPLICA_COUNT=$(${OC_BINARY} get deployment/${deploymentName} -o=jsonpath='{.status.availableReplicas}')
    timeout_in=$((end-SECONDS))
    if [[ ${DEBUG} -eq 1 ]]; then printInfo "Deployment in progress...(Current replica count=${CURRENT_REPLICA_COUNT}, ${timeout_in} seconds remain)"; fi
    sleep ${POLLING_INTERVAL_SEC}
  done

  if [[ "${CURRENT_REPLICA_COUNT}" -ne "${DESIRED_REPLICA_COUNT}" ]]; then
    printError "CodeReady Workspaces ${deploymentName} deployment failed. Aborting. Run command '${OC_BINARY} logs deployment/${deploymentName}' to get more details."
    exit 1
  elif [ ${SECONDS} -ge ${end} ]; then
    printError "Deployment timeout. Aborting."
    exit 1
  fi
  elapsed=$((DEPLOYMENT_TIMEOUT_SEC-timeout_in))
  printInfo "Codeready Workspaces deployment/${deploymentName} started in ${elapsed} seconds"
}

${OC_BINARY} scale deployment/codeready --replicas=0
${OC_BINARY} scale deployment/keycloak --replicas=0
${OC_BINARY} set image deployment/codeready-operator *=${REGISTRY_PREFIX}/${OPERATOR_CONTAINER}:${CRW_VERSION} -n $OPENSHIFT_PROJECT
echo; printInfo "Successfully updated running deployment ${OPENSHIFT_PROJECT}."

waitForDeployment codeready-operator

${OC_BINARY} scale deployment/keycloak --replicas=1
waitForDeployment keycloak

${OC_BINARY} scale deployment/codeready --replicas=1
waitForDeployment codeready

# for some reason minishift dies for a minute or two here, so give it time to recover
sleep 60s

echo; printInfo "Update postgres image"
${OC_BINARY} set image deployment/postgres "*=${PG_IMAGE}" -n $OPENSHIFT_PROJECT
${OC_BINARY} scale deployment/postgres --replicas=0
${OC_BINARY} scale deployment/postgres --replicas=1
waitForDeployment postgres

echo; printInfo "Successfully updated running deployment ${OPENSHIFT_PROJECT}."
echo; printInfo "Depending on your network speed when pulling new images, rolling update may take a few minutes to complete."
echo
