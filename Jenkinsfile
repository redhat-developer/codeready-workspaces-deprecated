#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram||rhel7-devstudio-releng||rhel7 or rhel7-32gb||rhel7-16gb||rhel7-8gb
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

def CHE_path = "ls-dependencies"
def VER_CHE = ""
def SHA_CHE = ""
timeout(120) {
	node("${node}"){ stage 'Build Che LS Deps'
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: "{CHE_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/che-samples/${CHE_path}.git"]]])
		// dir ("${CHE_path}") { sh 'ls -1art' }
		installNPM()
		installGo()
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f ${CHE_path}/pom.xml"
		stash name: 'stashLSDeps', includes: findFiles(glob: '.repository/**').join(", ")
		sh(script:"perl -0777 -p -i -e \'s|(\ +<parent>.*?<\/parent>)| $1 =~ /<version>/?\"\":$1|gse\' ${CHE_path}/pom.xml")
		VER_CHE = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CHE = sh(returnStdout:true,script:"cd ${CHE_path}/ && git rev-parse HEAD").trim()
		echo "Built ${CHE_path} from SHA: ${SHA_CHE} (${VER_CHE})"
	}
}

def CRW_path = "codeready-workspaces-apb"
timeout(120) {
	node("${node}"){ stage 'Build CRW APB'
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: "${CRW_path}"]], 
			submoduleCfg: [], 
			credentialsId: 'devstudio-release',
			userRemoteConfigs: [[url: "git@github.com:redhat-developer/${CRW_path}.git"]]])
		// dir ("${CRW_path}") { sh "ls -lart" }
		unstash 'stashLSDeps'
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f ${CRW_path}/pom.xml"
		archiveArtifacts fingerprint: false, artifacts: "${CRW_path}/installer-package/target/*.tar.*, ${CRW_path}/stacks/dependencies/*/target/*.tar.*""

		// sh 'printenv | sort'
		VER_CRW = sh(returnStdout:true,script:"egrep \"<version>\" ${CRW_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CRW = sh(returnStdout:true,script:"cd ${CRW_path}/ && git rev-parse HEAD").trim()
		echo "Built ${CRW_path} from SHA: ${SHA_CRW} (${VER_CRW})"
		def descriptString="Build #${BUILD_NUMBER} (${BUILD_TIMESTAMP}) :: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}):: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "${descriptString}"
		currentBuild.description="${descriptString}"
	}
}

