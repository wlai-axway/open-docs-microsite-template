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

String CURRENT_COMMIT

// By default the script that creates the previews will do so for the master/main and pull request branches. The
// variable env.PREVIEW_FOR_BRANCHES can be used to tell the script to create previews for feature branches. Use
// the same variable but with comma or space separated list if you need to enable previews for multiple branches.
// e.g. env.PREVIEW_FOR_BRANCHES = "developaug22 developdec22"
env.PREVIEW_FOR_BRANCHES = "developmay22 developaug22 developnov22 wingtest2"

node('OpendocsBuilder') {
  timestamps{  // enable timestamp in the console logs
    ansiColor('xterm') { // using ansi colours
      properties([
        disableConcurrentBuilds(),
        buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '20', daysToKeepStr: '', numToKeepStr: '20'))
      ])

      try {
        // Checkout stage
        stage('Checkout & Setup') {
          checkout scm
          // Pulls docker images used in the pipeline. This is not strictly necessary but if the images
          // are not available then the pipeline will fail early without wasting time doing the earlier steps.
          HUGO_DOCKER_IMAGE.pull()
          MARKDOWN_LINT_IMAGE.pull()

          CURRENT_COMMIT = sh ( script: 'git rev-parse --short --verify HEAD',returnStdout: true).trim()
          currentBuild.description="[commit] <strong>${CURRENT_COMMIT}</strong>"
        } // end stage

        // Potentially duplicating something already done using github workflows but it runs quick.
        stage ('Markdown Lint') {
          MARKDOWN_LINT_IMAGE.inside() {
            sh 'markdownlint "content/en/**/*.md"'
          }
        } // end stage

        stage ('Build') {
          HUGO_DOCKER_IMAGE.inside() {
            // Add the .npmrc file hosted on Jenkins to the workspace so npm pulls packages from internal servers.
            configFileProvider([configFile(fileId: "axway-dot-npmrc", variable: 'DOT_NPMRC_FILE')]) {
              sh '''
                cp ${DOT_NPMRC_FILE} ${WORKSPACE}/.npmrc
                bash build.sh -m ci
              '''
            }
          }
        } // end stage

        // Notes:
        //  - the opendocs-preview script is hosted on Jenkins and it's used to manage the preview sites on the Jenkins slave
        //  - the Jenkinsfile just need to access it using the configFileProvider configuration
        //  - it will always generate previews for the master/main branch and pull request branches (PR-n)
        //  - use the env.PREVIEW_FOR_BRANCHES variable to enable previews for development branches
        //  - the script will cleanup old previews if the corresponding branches have been deleted
        stage ('Start Preview') {
          withCredentials([
            string(credentialsId: 'AXWAY_KEYSTORE_PASSWORD', variable: 'AXWAY_KEYSTORE_PASSWORD'),
            usernamePassword(credentialsId: 'GITHUB_OPENDOCS_CREDS', passwordVariable: 'GITHUB_TOKEN', usernameVariable: 'GITHUB_USER')
          ]) {
            //configFileProvider([configFile(fileId: "opendocs-preview-live", variable: 'PREVIEW_SCRIPT')]) {
            configFileProvider([configFile(fileId: "opendocs-preview-test", variable: 'PREVIEW_SCRIPT')]) {
              sh 'bash ${PREVIEW_SCRIPT} 2>&1 | tee ${WORKSPACE}/opendocs-preview.log'
            }
          }

          // the _preview_url.txt file is generated by the opendocs-preview.sh script
          if (fileExists('_preview_url.txt')) {
            echo readFile('_preview_url.txt').trim() // print it so it's available in the blue ocean log page
            currentBuild.description = readFile('_preview_build_description.html').trim() // set the job description with generated links

            // send email only to axway.com email addresses
            if (fileExists('_preview_email_author.txt') ) {
              emailext subject: '${FILE,path="_preview_email_subject.txt"}', mimeType: 'text/html', to: '${FILE,path="_preview_email_author.txt"}', body: '${FILE,path="_preview_email_body.html"}'
            }
          } else {
            catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
              error('throwing error to make stage yellow')
            }
          }
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

