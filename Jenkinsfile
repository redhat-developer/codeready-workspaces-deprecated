#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram or rhel7-32gb
// branchToBuild = */master or some branch like 6.16.x

def installNPM(){
	def nodeHome = tool 'nodejs-10.9.0'
	env.PATH="${env.PATH}:${nodeHome}/bin"
	sh "npm install -g yarn"
	sh "npm version"
}

def installGo(){
	def goHome = tool 'go-1.10'
	env.PATH="${env.PATH}:${goHome}/bin"
	sh "go version"
}

def MVN_FLAGS="-Pfast -Dmaven.repo.local=.repository/ -V -ff -B -e -Dskip-enforce -DskipTests -Dskip-validate-sources -Dfindbugs.skip -DskipIntegrationTests=true \
-Dmdep.analyze.skip=true -Dmaven.javadoc.skip -Dgpg.skip -Dorg.slf4j.simpleLogger.showDateTime=true -Dorg.slf4j.simpleLogger.dateTimeFormat=HH:mm:ss \
-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"

def buildMaven(){
	def mvnHome = tool 'maven-3.5.4'
	env.PATH="${env.PATH}:${mvnHome}/bin"
}

timeout(20) {
    node("${node}"){ stage 'Build Che LS Deps'
    	checkout([$class: 'GitSCM', 
    		branches: [[name: "${branchToBuild}"]], 
    		doGenerateSubmoduleConfigurations: false, 
    		extensions: [[$class: 'RelativeTargetDirectory', 
    			relativeTargetDir: 'ls-dependencies']], 
    		submoduleCfg: [], 
    		userRemoteConfigs: [[url: 'https://github.com/che-samples/ls-dependencies.git']]])
    	// dir ('ls-dependencies') { sh 'ls -1art' }
    	installNPM()
    	installGo()
    	buildMaven()
    	sh "mvn clean install ${MVN_FLAGS} -f ls-dependencies/pom.xml"
    	stash name: 'stashLSDeps', includes: findFiles(glob: '.repository/**').join(", ")
    }
}

timeout(20) {
    node("${node}"){ stage 'Build CRW APB'
    	checkout([$class: 'GitSCM', 
    		branches: [[name: "${branchToBuild}"]], 
    		doGenerateSubmoduleConfigurations: false, 
    		extensions: [[$class: 'RelativeTargetDirectory', 
    			relativeTargetDir: 'codeready-workspaces-apb']], 
    		submoduleCfg: [], 
    		credentialsId: 'devstudio-release',
    		userRemoteConfigs: [[url: 'git@github.com:redhat-developer/codeready-workspaces-apb.git']]])
    	// dir ('codeready-workspaces-apb') { sh "ls -lart" }
    	unstash 'stashLSDeps'
    	buildMaven()
    	sh "mvn clean install ${MVN_FLAGS} -f codeready-workspaces-apb/pom.xml"
    	archive includes:"codeready-workspaces-apb/installer-package/target/*.tar.*, codeready-workspaces-apb/stacks/dependencies/*/target/*.tar.*"

        // sh 'printenv | sort'
        sh 'BUILD_DESC=$(egrep "<version>" codeready-workspaces-apb/pom.xml|head -1|sed -e "s#.*<version>\\(.\\+\\)</version>#\\1#")'
        sh 'BUILD_DESC=${BUILD_DESC} :: $(cd codeready-workspaces-apb/ && git rev-parse HEAD) :: $(date -u +%Y-%m-%d_%H-%M-%S)'
        currentBuild.description = "Build #${BUILD_NUMBER} :: ${BUILD_DESC}"
    }
}

