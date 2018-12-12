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

def MVN_FLAGS="-Dmaven.repo.local=.repository/ -V -B -e"

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
		archiveArtifacts fingerprint: false, artifacts: 'codeready-workspaces-apb/installer-package/target/*.tar.*, codeready-workspaces-apb/stacks/dependencies/*/target/*.tar.*'

		// sh 'printenv | sort'
		BUILD_VER = sh(returnStdout:true,script:'egrep "<version>" codeready-workspaces-apb/pom.xml|head -1|sed -e "s#.*<version>\\(.\\+\\)</version>#\\1#"').trim()
		BUILD_SHA = sh(returnStdout:true,script:'cd codeready-workspaces-apb/ && git rev-parse HEAD').trim()
		echo "Build #${BUILD_NUMBER} :: ${BUILD_VER} :: ${BUILD_SHA} :: ${BUILD_TIMESTAMP}"
		currentBuild.description="Build #${BUILD_NUMBER} :: ${BUILD_VER} :: ${BUILD_SHA} :: ${BUILD_TIMESTAMP}"
	}
}

