#!/bin/bash
BASE_DIR=$(cd "$(dirname "$0")"; pwd)

DEFAULT_OPENSHIFT_PROJECT="workspaces"
DEFAULT_ENABLE_OPENSHIFT_OAUTH="false"
DEFAULT_TLS_SUPPORT="false"
DEFAULT_SELF_SIGNED_CERT="true"
DEFAULT_SERVER_IMAGE_NAME="registry.access.redhat.com/codeready-workspaces/server"
DEFAULT_SERVER_IMAGE_TAG="latest"
DEFAULT_OPERATOR_IMAGE_NAME="registry.access.redhat.com/codeready-workspaces/server-operator:latest"
DEFAULT_NAMESPACE_CLEANUP="false"

HELP="

How to use this script:
-d,     --deploy              | deploy using settings in codeready-cr.yaml
-p=,    --project=            | project namespace to deploy CodeReady Workspaces, default: ${DEFAULT_OPENSHIFT_PROJECT}
-o, --oauth                   | enable Log into CodeReady Workspaces with OpenShift credentials, default: ${DEFAULT_ENABLE_OPENSHIFT_OAUTH}
-s,     --secure              | tls support, default: ${DEFAULT_TLS_SUPPORT}
--public-certs                | skip creating a secret with OpenShift router cert, default: false, which means operator will auto fetch router cert
--operator-image=             | operator image, default: ${DEFAULT_OPERATOR_IMAGE_NAME}
--server-image=               | server image, default: ${DEFAULT_SERVER_IMAGE_NAME}
-v=, --version=               | server image tag, default: ${DEFAULT_SERVER_IMAGE_TAG}
--verbose                     | stream deployment logs to console, default: false
-h,     --help                | show this help menu
"
if [[ $# -eq 0 ]] ; then
  echo -e "$HELP"
  exit 0
fi
for key in "$@"
do
  case $key in
    --verbose)
      FOLLOW_LOGS="true"
      shift
      ;;
    --public-certs)
      SELF_SIGNED_CERT="false"
      shift
      ;;
    -o| --oauth)
      ENABLE_OPENSHIFT_OAUTH="true"
      shift
      ;;
    -s| --secure)
      TLS_SUPPORT="true"
      shift
      ;;
    -p=*| --project=*)
      OPENSHIFT_PROJECT="${key#*=}"
      shift
      ;;
    --operator-image=*)
      OPERATOR_IMAGE_NAME=$(echo "${key#*=}")
      shift
      ;;
    --server-image=*)
      SERVER_IMAGE_NAME=$(echo "${key#*=}")
      shift
      ;;
    -v=*|--version=*)
      SERVER_IMAGE_TAG=$(echo "${key#*=}")
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

export TLS_SUPPORT=${TLS_SUPPORT:-${DEFAULT_TLS_SUPPORT}}

export SELF_SIGNED_CERT=${SELF_SIGNED_CERT:-${DEFAULT_SELF_SIGNED_CERT}}

export OPENSHIFT_PROJECT=${OPENSHIFT_PROJECT:-${DEFAULT_OPENSHIFT_PROJECT}}

export ENABLE_OPENSHIFT_OAUTH=${ENABLE_OPENSHIFT_OAUTH:-${DEFAULT_ENABLE_OPENSHIFT_OAUTH}}

export SERVER_IMAGE_NAME=${SERVER_IMAGE_NAME:-${DEFAULT_SERVER_IMAGE_NAME}}

export SERVER_IMAGE_TAG=${SERVER_IMAGE_TAG:-${DEFAULT_SERVER_IMAGE_TAG}}

export OPERATOR_IMAGE_NAME=${OPERATOR_IMAGE_NAME:-${DEFAULT_OPERATOR_IMAGE_NAME}}

DEFAULT_NO_NEW_NAMESPACE="false"
export NO_NEW_NAMESPACE=${NO_NEW_NAMESPACE:-${DEFAULT_NO_NEW_NAMESPACE}}

export NAMESPACE_CLEANUP=${NAMESPACE_CLEANUP:-${DEFAULT_NAMESPACE_CLEANUP}}

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
    if [[ ${ENABLE_OPENSHIFT_OAUTH} == "true" ]]; then
      ${OC_BINARY} get oauthclients > /dev/null 2>&1
      OUT=$?
      if [ ${OUT} -ne 0 ]; then
        printError "Creation of a CRD requires cluster-admin privileges. Login in as user with cluster-admin role"
        exit $OUT
      fi
    fi
  fi
}

createNewProject() {
  ${OC_BINARY} get namespace "${OPENSHIFT_PROJECT}" > /dev/null 2>&1
  OUT=$?
      if [ ${OUT} -ne 0 ]; then
           printWarning "Namespace '${OPENSHIFT_PROJECT}' not found, or current user does not have access to it. Installer will try to create namespace '${OPENSHIFT_PROJECT}'"
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
      fi
}

createServiceAccount() {
  printInfo "Creating operator service account"
  ${OC_BINARY} get sa codeready-operator > /dev/null 2>&1
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    ${OC_BINARY} create sa codeready-operator -n=${OPENSHIFT_PROJECT} > /dev/null
  else
    printInfo "Serviceaccount already exists"
  fi
  ${OC_BINARY} get rolebinding codeready-operator > /dev/null 2>&1
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    ${OC_BINARY} create rolebinding codeready-operator --clusterrole=admin --serviceaccount=${OPENSHIFT_PROJECT}:codeready-operator -n=${OPENSHIFT_PROJECT} > /dev/null
  else
    printInfo "Role Binding already exists"
  fi
  printInfo "Granting cluster-admin privileges for operator service account"
  ${OC_BINARY} adm policy add-cluster-role-to-user cluster-admin -z codeready-operator > /dev/null
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printError "Failed to grant cluster-admin role to operator service account"
  exit $OUT
  fi
}

checkCRD() {

  ${OC_BINARY} get customresourcedefinitions/checlusters.org.eclipse.che > /dev/null 2>&1
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printInfo "Creating custom resource definition"
    createCRD > /dev/null
  else
    printInfo "Custom resource definition already exists"
  fi

}

createCRD() {
  ${OC_BINARY} create -f - <<EOF
  apiVersion: apiextensions.k8s.io/v1beta1
  kind: CustomResourceDefinition
  metadata:
    name: checlusters.org.eclipse.che
  spec:
    group: org.eclipse.che
    names:
      kind: CheCluster
      listKind: CheClusterList
      plural: checlusters
      singular: checluster
    scope: Namespaced
    version: v1
    subresources:
      status: {}
EOF

OUT=$?
if [ ${OUT} -ne 0 ]; then
  printError "Failed to create custom resource definition"
  exit $OUT
fi
}


createOperatorDeployment() {

DEPLOYMENT=$(cat <<EOF
kind: Template
apiVersion: v1
metadata:
  name: codeready-operator
objects:
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: codeready-operator
  spec:
    replicas: 1
    selector:
      matchLabels:
        name: codeready-operator
    template:
      metadata:
        labels:
          name: codeready-operator
      spec:
        serviceAccountName: codeready-operator
        containers:
          - name: codeready-operator
            image: \${IMAGE}
            ports:
            - containerPort: 60000
              name: metrics
            command:
            - che-operator
            imagePullPolicy: Always
            env:
              - name: WATCH_NAMESPACE
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.namespace
              - name: POD_NAME
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.name
              - name: OPERATOR_NAME
                value: "codeready-operator"
parameters:
- name: IMAGE
  displayName: Operator Image
  description: Operator Image
  required: true
EOF
  )

printInfo "Creating Operator Deployment"
echo "${DEPLOYMENT}" | ${OC_BINARY} new-app -p IMAGE=$OPERATOR_IMAGE_NAME -n="${OPENSHIFT_PROJECT}" -f - > /dev/null
OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printError "Failed to deploy CodeReady Operator"
    exit 1
  else
    printInfo "Waiting for the Operator deployment to be scaled to 1"
    DESIRED_REPLICA_COUNT=1
    UNAVAILABLE=$(${OC_BINARY} get deployment/codeready-operator -n="${OPENSHIFT_PROJECT}" -o=jsonpath='{.status.unavailableReplicas}')
    DEPLOYMENT_TIMEOUT_SEC=300
    POLLING_INTERVAL_SEC=5
    end=$((SECONDS+DEPLOYMENT_TIMEOUT_SEC))
    while [ "${UNAVAILABLE}" == 1 ]; do
      UNAVAILABLE=$(${OC_BINARY} get deployment/codeready-operator -n="${OPENSHIFT_PROJECT}" -o=jsonpath='{.status.unavailableReplicas}')
      sleep 3
    done
    CURRENT_REPLICA_COUNT=$(${OC_BINARY} get deployment/codeready-operator -n="${OPENSHIFT_PROJECT}" -o=jsonpath='{.status.availableReplicas}')
    while [ "${CURRENT_REPLICA_COUNT}" -ne "${DESIRED_REPLICA_COUNT}" ] && [ ${SECONDS} -lt ${end} ]; do
      CURRENT_REPLICA_COUNT=$(${OC_BINARY} get deployment/codeready-operator -o=jsonpath='{.status.availableReplicas}')
      timeout_in=$((end-SECONDS))
      printInfo "Deployment is in progress...(Current replica count=${CURRENT_REPLICA_COUNT}, ${timeout_in} seconds remain)"
      sleep ${POLLING_INTERVAL_SEC}
    done

    if [ "${CURRENT_REPLICA_COUNT}" -ne "${DESIRED_REPLICA_COUNT}"  ]; then
      printError "CodeReady Operator deployment failed. Aborting. Run command 'oc logs deployment/codeready-operator' to get more details."
      exit 1
    elif [ ${SECONDS} -ge ${end} ]; then
      printError "Deployment timeout. Aborting."
      exit 1
    fi
    printInfo "Codeready Operator successfully deployed"
  fi
}

createCustomResource() {
  printInfo "Creating Custom resource. This will initiate CodeReady Workspaces deployment"
  printInfo "CodeReady is going to be deployed with the following settings:"
  printInfo "TLS support:       ${TLS_SUPPORT}"
  printInfo "OpenShift oAuth:   ${ENABLE_OPENSHIFT_OAUTH}"
  printInfo "Self-signed certs: ${SELF_SIGNED_CERT}"

  ${OC_BINARY} new-app -f ${BASE_DIR}/codeready-cr.yaml \
               -p SERVER_IMAGE_NAME=${SERVER_IMAGE_NAME} \
               -p SERVER_IMAGE_TAG=${SERVER_IMAGE_TAG} \
               -p TLS_SUPPORT=${TLS_SUPPORT} \
               -p ENABLE_OPENSHIFT_OAUTH=${ENABLE_OPENSHIFT_OAUTH} \
               -p SELF_SIGNED_CERT=${SELF_SIGNED_CERT} \
               -n="${OPENSHIFT_PROJECT}" > /dev/null
  OUT=$?
    if [ ${OUT} -ne 0 ]; then
      printError "Failed to create Custom Resource"
      exit 1
    else
      DEPLOYMENT_TIMEOUT_SEC=1200
      printInfo "Waiting for CodeReady to boot. Timeout: ${DEPLOYMENT_TIMEOUT_SEC} seconds"
      if [ "${FOLLOW_LOGS}" == "true" ]; then
        printInfo "You may exist this script as soon as the log reports a successful CodeReady deployment"
        ${OC_BINARY} logs -f deployment/codeready-operator -n="${OPENSHIFT_PROJECT}"
      else
        DESIRED_STATE="Available"
        CURRENT_STATE=$(${OC_BINARY} get checluster/codeready -n="${OPENSHIFT_PROJECT}" -o=jsonpath='{.status.cheClusterRunning}')
        POLLING_INTERVAL_SEC=5
        end=$((SECONDS+DEPLOYMENT_TIMEOUT_SEC))
        while [ "${CURRENT_STATE}" != "${DESIRED_STATE}" ] && [ ${SECONDS} -lt ${end} ]; do
          CURRENT_STATE=$(${OC_BINARY} get checluster/codeready -n="${OPENSHIFT_PROJECT}" -o=jsonpath='{.status.cheClusterRunning}')
          timeout_in=$((end-SECONDS))
          sleep ${POLLING_INTERVAL_SEC}
        done

        if [ "${CURRENT_STATE}" != "${DESIRED_STATE}"  ]; then
          printError "CodeReady deployment failed. Aborting. Codeready operator logs: oc logs deployment/codeready-operator"
          exit 1
        elif [ ${SECONDS} -ge ${end} ]; then
          printError "Deployment timeout. Aborting. Codeready operator logs: oc logs deployment/codeready-operator"
          exit 1
        fi
        CODEREADY_ROUTE=$(${OC_BINARY} get checluster/codeready -o=jsonpath='{.status.cheURL}')
        printInfo "CodeReady Workspaces successfully deployed and is available at ${CODEREADY_ROUTE}"
    fi
  fi
}

if [ "${DEPLOY}" = true ] ; then
  preReqs
  isLoggedIn
  createNewProject
  createServiceAccount
  checkCRD
  createOperatorDeployment
  createCustomResource
fi
