#!/bin/bash -xe
# script to build eclipse-che in #projectncl

# read commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-MVNFLAGS') MVNFLAGS="$2"; shift 1;; # add more mvn flags
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

##########################################################################################
# set up npm environment
##########################################################################################

uname -a
go version
node -v
npm version
mvn -v

export NCL_PROXY="http://${buildContentId}+tracking:${accessToken}@${proxyServer}:${proxyPort}"
# wget proxies
export http_proxy="${NCL_PROXY}"
export https_proxy="${NCL_PROXY}"

# PHP/composer proxies
export HTTP_PROXY="${NCL_PROXY}"
export HTTPS_PROXY="${NCL_PROXY}"
export HTTP_PROXY_REQUEST_FULLURI=0 # or false
export HTTPS_PROXY_REQUEST_FULLURI=0 #

export nodeDownloadRoot=http://nodejs.org:80/dist/
export npmDownloadRoot=http://registry.npmjs.org:80/npm/-/
export npmRegistryURL=http://registry.npmjs.org:80/

npm config set https-proxy ${NCL_PROXY}
npm config set https_proxy ${NCL_PROXY}
npm config set proxy ${NCL_PROXY}
#silent, warn, info, verbose, silly
npm config set loglevel warn 
# do not use maxsockets 2 or build will stall & die
npm config set maxsockets 80 
npm config set fetch-retries 10
npm config set fetch-retry-mintimeout 60000
npm config set registry ${npmRegistryURL}

##########################################################################################
# configure maven build 
##########################################################################################

MVNFLAGS="${MVNFLAGS} -V -ff -B -e -Dskip-enforce -DskipTests -Dskip-validate-sources -Dfindbugs.skip -DskipIntegrationTests=true"
MVNFLAGS="${MVNFLAGS} -Dmdep.analyze.skip=true -Dmaven.javadoc.skip -Dgpg.skip -Dorg.slf4j.simpleLogger.showDateTime=true"
MVNFLAGS="${MVNFLAGS} -Dorg.slf4j.simpleLogger.dateTimeFormat=HH:mm:ss "
MVNFLAGS="${MVNFLAGS} -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"
MVNFLAGS="${MVNFLAGS} -DnodeDownloadRoot=${nodeDownloadRoot} -DnpmDownloadRoot=${npmDownloadRoot}"
MVNFLAGS="${MVNFLAGS} -DnpmRegistryURL=${npmRegistryURL}"

##########################################################################################
# run maven build 
##########################################################################################

mvn clean deploy ${MVNFLAGS}