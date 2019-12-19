#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram||rhel7-devstudio-releng||rhel7 or rhel7-32gb||rhel7-16gb||rhel7-8gb
// branchToBuildParent = refs/tags/7.0.0-RC-2.0, */7.0.0-RC-2.x, or */master
// branchToBuildCRW = */7.0.0-RC-2.x or */master

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

def CRW_path = "codeready-workspaces-deprecated"
timeout(120) {
	node("${node}"){ stage "Build ${CRW_path}"
		cleanWs()
		// for private repo, use checkout(credentialsId: 'devstudio-release')
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildCRW}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f ${CRW_path}/pom.xml"
		archiveArtifacts fingerprint: true, artifacts: "${CRW_path}/stacks/dependencies/*/target/*.tar.*"

		sh "perl -0777 -p -i -e 's|(\\ +<parent>.*?<\\/parent>)| ${1} =~ /<version>/?\"\":${1}|gse' ${CRW_path}/pom.xml"
		VER_CRW = sh(returnStdout:true,script:"egrep \"<version>\" ${CRW_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CRW = sh(returnStdout:true,script:"cd ${CRW_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "Built ${CRW_path} from SHA: ${SHA_CRW} (${VER_CRW})"

		// sh 'printenv | sort'
		def descriptString="Build #${BUILD_NUMBER} (${BUILD_TIMESTAMP}) <br/> :: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "${descriptString}"
		currentBuild.description="${descriptString}"
	}
}
