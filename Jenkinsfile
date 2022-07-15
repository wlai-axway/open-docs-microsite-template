
def HUGO_DOCKER_IMAGE = docker.image('apigateway-docker-release-ptx.artifactory-ptx.ecd.axway.int/build/hugo-extended:0.66.0')
def MARKDOWN_LINT_IMAGE = docker.image('apigateway-docker-release-ptx.artifactory-ptx.ecd.axway.int/build/markdownlint-cli:0.28.1')

node('OpenDocsNode') {
  timestamps{
    ansiColor('xterm') { // using ansi colours
      properties([
        disableConcurrentBuilds(),
        buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '30', daysToKeepStr: '', numToKeepStr: '30')),
        parameters([
          booleanParam(
            name: 'UPDATE_JENKINS_PARAMETERS',
            defaultValue: false,
            description: 'Update the Jenkins parameters by failing the build.'
          )
        ])
      ])

      try {
        // Checkout stage
        stage('Checkout & Setup') {
          checkout scm

          // Pulls docker images used in the pipeline. This is not strictly necessary but if the images
          // are not available then the pipeline will fail early without wasting time doing the earlier steps.
          HUGO_DOCKER_IMAGE.pull()
          MARKDOWN_LINT_IMAGE.pull()

          // Set some default parameter values so first build don't fail!
          // if (BUILD_NUMBER=="1") {
          //   echo "[INFO] Build running for first time so setting some default values to job parameters!"
          //   env.MAKE_RELEASE=false
          //   env.SKIP_SONAR=false
          // }
          String currentCommit = sh ( script: 'git rev-parse --short --verify HEAD',returnStdout: true).trim()
          currentBuild.description="[commit] <strong>${currentCommit}</strong><br>[preview] <strong><a href=\"${previewUrl}\">#LINK#</a></strong>"
        } // end stage

        // Potentially duplicating something already done using github workflows but it runs quick.
        stage ('MarkdownLint') {
          MARKDOWN_LINT_IMAGE.inside() {
            sh 'markdownlint "content/en/**/*.md"'
          }
        } // end stage

        stage ('Build') {
          HUGO_DOCKER_IMAGE.inside() {
             sh 'bash build.sh -m ci'
          }

        } // end stage

        stage ('Start Preview') {
          sh 'bash scripts/ci-run-docker-preview.sh'
          String previewUrl = readFile('_preview_url.txt').trim()
          echo "${previewUrl}"
          currentBuild.description = currentBuild.description + "<br>[preview] <strong><a href=\"${previewUrl}\">#LINK#</a></strong>"
        } // end stage

      } // end try
      // Catch the failure
      catch(Exception e) {
        // Set the build result as a fail, if not in place the pipeline will fail successfully
        currentBuild.result = "FAILURE"
        //
        echo e
        // Send email to maintainer and developers that caused the build failure.
        // emailext subject: "Build Failure - ${env.JOB_NAME} Build Number - [${env.BUILD_NUMBER}]",
        //   body: '${DEFAULT_CONTENT}',
        //   to: 'wlai@axway.com',
        //   recipientProviders: [
        //     [$class: 'CulpritsRecipientProvider']
        //   ]
      } // end catch
      finally {
        echo "[INFO] Fin!"
      }
    } // end ansiColor
  } // end timestamps
} // end node

def setYellowStatus(message) {
  catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
    error("${message}") //this set the stage yellow
  }
}
