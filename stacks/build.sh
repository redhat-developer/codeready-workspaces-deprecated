#!/bin/bash
export TERM=xterm
BASE_DIR=$(cd "$(dirname "$0")"; pwd)

printInfo() {
  green=`tput setaf 2`
  reset=`tput sgr0`
  echo -e "${green}[INFO]: ${1} ${reset}"
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

# check vars unnecessary when building on a RHEL instance since Docker will user RHEL subscription credentials from the host

if [[ -z ${SUBSCRIPTION_USERNAME+x} || -z ${SUBSCRIPTION_PASSWORD+x} ]]; then
  printError "One or more mandatory environment variables are undefined:"
  printError "Subscription details: username - '${SUBSCRIPTION_USERNAME}', password: '${SUBSCRIPTION_PASSWORD}'"
  printError "Run: 'export SUBSCRIPTION_USERNAME=myusername && export SUBSCRIPTION_PASSWORD=mypassword'"
  exit 1
fi

export BUILD_ARG_USERNAME="--build-arg SUBSCRIPTION_USERNAME=${SUBSCRIPTION_USERNAME}"
export BUILD_ARG_PASSWORD="--build-arg SUBSCRIPTION_PASSWORD=${SUBSCRIPTION_PASSWORD}"
export INTERNAL_REGISTRY="docker-registry.default.svc:5000"
export TAG="latest"

checkUser(){
    printInfo "Checking if current user has access to openshift namespace..."
    OPENSHIFT_USER=$(oc whoami)
    OUT=$?
    if [ ${OUT} -ne 0 ];then
      printError "You are not logged into any cluster. Please log in with a user having cluster-admin role"
      exit ${OUT}
    fi
    oc get namespace openshift > /dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ];then
      printError "Current user '${OPENSHIFT_USER}' does not have access to openshift namespace. Please, login with a user that has cluster-admin role, and re-run the script"
      exit ${OUT}
    fi
}

checkRegistry(){
    printInfo "Logging into an internal OpenShift Registry - '${INTERNAL_REGISTRY}...'"
    OPENSHIFT_TOKEN=$(oc whoami -t)
    docker login ${INTERNAL_REGISTRY} -u ${OPENSHIFT_USER} -p ${OPENSHIFT_TOKEN}
    OUT=$?
    if [ ${OUT} -ne 0 ];then
      printError "Failed to log into an internal OpenShift registry ${INTERNAL_REGISTRY} with username ${OPENSHIFT_USER} and token ${OPENSHIFT_TOKEN}"
      printError "Check credentials an/or registry DNS availability"
      exit ${OUT}
    fi
}

buildAndPushImages(){
    # build base image first
    docker build -t ${INTERNAL_REGISTRY}/openshift/rhel-base-jdk8 ${BUILD_ARG_USERNAME} ${BUILD_ARG_PASSWORD} ${BASE_DIR}/base-jdk8
    OUT=$?
    if [ ${OUT} -ne 0 ];then
      printError "Failed to build image "${INTERNAL_REGISTRY}/openshift/rhel-base-jdk8". Existing as this is a base images for all RHEL stack image"
      exit ${OUT}
    fi
    printInfo "Base image "${INTERNAL_REGISTRY}/openshift/rhel-base-jdk8" successfully built"
    docker push ${INTERNAL_REGISTRY}/openshift/rhel-base-jdk8:${TAG}
    OUT=$?
    if [ ${OUT} -ne 0 ];then
      printError "Failed to push image "${INTERNAL_REGISTRY}/openshift/openshift/rhel-base-jdk8". Existing because this is a base images for all RHEL stack images"
      exit ${OUT}
    fi
    # get all direcotries where directoryName == repoName, skip base-jdk8 which is previously built base image
    DIRS=$(cd ${BASE_DIR} && ls -d */ | sed 's/\///' | grep -v 'base-jdk8')
    # build and push other images
    for i in ${DIRS}; do
      printInfo "Building "${INTERNAL_REGISTRY}"/rhel-"${i}:${TAG}" image..."
      docker build -t ${INTERNAL_REGISTRY}/openshift/rhel-${i}:${TAG} ${BASE_DIR}/${i}
      OUT=$?
      if [ ${OUT} -eq 0 ];then
        printInfo "Image "${INTERNAL_REGISTRY}/openshift/rhel-${i}:${TAG}" successfully built. Pushing image to an internal registry"
        docker push ${INTERNAL_REGISTRY}/openshift/rhel-${i}:${TAG}
        if [ ${OUT} -ne 0 ];then
          printError "Failed to push image "${INTERNAL_REGISTRY}/openshift/rhel-${i}:${TAG}""
          exit ${OUT}
        fi
      else
         printError "************************************************************************************"
         printError "Failed to build image "${INTERNAL_REGISTRY}/rhel-${i}:${TAG}""
         printError "Skipping push to an internal registry"
         printError "Re-run the script later or contact support. Please attach build logs!"
         printError "************************************************************************************"
      fi
    done
}

checkUser
checkRegistry
buildAndPushImages
