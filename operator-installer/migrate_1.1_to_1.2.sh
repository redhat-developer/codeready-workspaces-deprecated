#!/bin/bash 
BASE_DIR=$(cd "$(dirname "$0")"; pwd)

DEBUG=0 # set to 1 for more output

CRW_VERSION="1.2"

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
    -d=*| --docker-config=*)
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
else
  printError "Command line tool ${OC_BINARY} (https://docs.openshift.org/latest/cli_reference/get_started_cli.html) not found. Download oc client and add it to your \$PATH."
  exit 1
fi

# new default images & versions
SSO_IMAGE="registry.redhat.io/redhat-sso-7/sso73-openshift:1.0-11"
PG_IMAGE="registry.redhat.io/rhscl/postgresql-96-rhel7:1-40"
# if using quay.io, operator is simply operator-rhel8; if using RHCC, it's server-operator-rhel8
if [[ ${REGISTRY_PREFIX} == "quay.io/crw" ]]; then OPERATOR_CONTAINER="operator-rhel8"; else OPERATOR_CONTAINER="server-operator-rhel8"; fi
SERVER_CONTAINER="server-rhel8"

export REGISTRY_PREFIX=${REGISTRY_PREFIX:-${DEFAULT_REGISTRY_PREFIX}}
export OPENSHIFT_PROJECT=${OPENSHIFT_PROJECT:-${DEFAULT_OPENSHIFT_PROJECT}}
export DOCKER_CONFIG_JSON=${DOCKER_CONFIG_JSON:-${DEFAULT_DOCKER_CONFIG_JSON}}
if [[ $DEBUG -eq 1 ]]; then printInfo "
REGISTRY_PREFIX=${REGISTRY_PREFIX}
OPENSHIFT_PROJECT=${OPENSHIFT_PROJECT}
DOCKER_CONFIG_JSON=${DOCKER_CONFIG_JSON}
"; fi

${OC_BINARY} adm policy --as system:admin add-cluster-role-to-user cluster-admin developer
${OC_BINARY} login --username developer --password developer

# check `${OC_BINARY} status` for an error
status="$(${OC_BINARY} status 2>&1)"
if [[ $status == *"Error"* ]]; then
	printError "$status" 
	printError "You must log in to your cluster to use this script. For example,

 ${OC_BINARY} login --username developer --password developer

	" && exit 1
fi
# check `${OC_BINARY} project` for a selected project
status="$(${OC_BINARY} project 2>&1)"
if [[ $status == *"error"* ]]; then
	echo "$status" && exit 1
fi

POSTGRESQL_PASSWORD=$(${OC_BINARY} get deployment keycloak -o=jsonpath={'.spec.template.spec.containers[0].env[?(@.name=="DB_PASSWORD")].value'} -n=$OPENSHIFT_PROJECT)

# Ensure CRW can authenticate with new registry registry.redhat.io to pull images
if [[ -f ${DOCKER_CONFIG_JSON} ]] && [[ $(grep registry.redhat.io ${DOCKER_CONFIG_JSON}) ]]; then # config is found and we probably have a key
  echo; printInfo "Authenticate with registry.redhat.io:"
  ${OC_BINARY} create secret generic registryredhatio --from-file=.dockerconfigjson=${DOCKER_CONFIG_JSON} --type=kubernetes.io/dockerconfigjson
  ${OC_BINARY} secrets link default registryredhatio --for=pull
  ${OC_BINARY} secrets link builder registryredhatio
else
  printError "You must authenticate with registry.redhat.io in order for this script to proceed!

Steps:

1. Get a login for the registry.   Details: https://access.redhat.com/RegistryAuthentication#getting-a-red-hat-login-2
2. Log in using your new username. Details: https://access.redhat.com/RegistryAuthentication#using-authentication-3
3. If you've done the above steps and your token is stored in ${DOCKER_CONFIG_JSON} re-run this script.
4. NOTE: you may want to import only one token (not all of them) into your cluster. If so use a different file than ${DOCKER_CONFIG_JSON}, eg.,
         $0 --docker-config=/path/to/alternate.config.json ...
4. If it still fails, see https://access.redhat.com/RegistryAuthentication#allowing-pods-to-reference-images-from-other-secured-registries-9"
  exit 1
fi

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
if [[ -x /usr/bin/jq ]]; then echo ${PATCH_JSON} | jq; else echo ${PATCH_JSON}; fi

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

${OC_BINARY} login --username developer --password developer

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

${OC_BINARY} login --username developer --password developer

echo; printInfo "Update postgres image"
${OC_BINARY} set image deployment/postgres "*=${PG_IMAGE}" -n $OPENSHIFT_PROJECT
${OC_BINARY} scale deployment/postgres --replicas=0
${OC_BINARY} scale deployment/postgres --replicas=1
waitForDeployment postgres

echo; printInfo "Successfully updated running deployment ${OPENSHIFT_PROJECT}."
echo; printInfo "Depending on your network speed when pulling new images, rolling update may take a few minutes to complete."
echo
