// Jenkins prerequisites:
//  1. a Jenkins node with the name or label set to "OpendocsBuilder" (can be customised)
//  2. docker daemon installed on this node
//  3. apache2/httpd daemon installed on this node
//  4. the Jenkins node user (if not root) has sudo no password permission to run "systemctl * httpd"
//  5. the Jenkins node user (if not root) has ownership of folder /opt/openshift-previews/
//  6. the Jenkins server needs the following managed files:
//    - axway-dot-npmrc: file to tell npm to install packages using internal Axway servers
//    - opendocs-preview-live: script for managing the httpd service and preview content

// CI docker images for internal Axway use.
def HUGO_DOCKER_IMAGE = docker.image('apigateway-docker-release-ptx.artifactory-ptx.ecd.axway.int/build/hugo-extended:0.101.0')
def MARKDOWN_LINT_IMAGE = docker.image('apigateway-docker-release-ptx.artifactory-ptx.ecd.axway.int/build/markdownlint-cli:0.28.1')

// By default the script that creates the previews will do so for the master/main and pull request branches. The
// variable env.PREVIEW_FOR_BRANCHES can be used to tell the script to create previews for feature branches. Use
// the same variable but with comma or space separated list if you need to enable previews for multiple branches.
// e.g. env.PREVIEW_FOR_BRANCHES = "developaug22 developdec22"
env.PREVIEW_FOR_BRANCHES = "developmay22 developaug22 developnov22"

node('OpendocsBuilder') {
  timestamps{  // enable timestamp in the console logs
    ansiColor('xterm') { // using ansi colours
      properties([
        disableConcurrentBuilds(),
        buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '20', daysToKeepStr: '', numToKeepStr: '20')),
        parameters([
          string(
            name: 'test',
            defaultValue: 'test',
            description: 'test',
            trim: false),
          string(
            name: 'test2',
            defaultValue: 'test2',
            description: 'test2',
            trim: false)
        ])
      ])

      try {
        // Checkout stage
        stage('Checkout & Setup') {
          checkout scm
          String currentCommit = sh ( script: 'git rev-parse --short --verify HEAD',returnStdout: true).trim()
          currentBuild.description="[commit] <strong>${currentCommit}</strong>"
        } // end stage

      } // end try
      // Catch the failure
      catch(Exception e) {
        // Set the build result as a fail, if not in place the pipeline will fail successfully
        currentBuild.result = "FAILURE"
        //
        echo e
        // Send email to maintainer and developers that caused the build failure.
        emailext subject: "Build Failure - ${env.JOB_NAME} Build Number - [${env.BUILD_NUMBER}]",
          body: '${DEFAULT_CONTENT}',
          to: 'wlai@axway.com'
        //   recipientProviders: [
        //     [$class: 'CulpritsRecipientProvider']
        //   ]
      } // end catch
      finally {
        if (fileExists("public.zip")) {
          archiveArtifacts artifacts: "public.zip", fingerprint: true
        } else {
          echo "[WARN] The folder [build/public/] not found!"
        }
        echo "[INFO] Fin!"
      }
    } // end ansiColor
  } // end timestamps
} // end node

