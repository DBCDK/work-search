def dockerRepository = 'https://docker-os.dbc.dk'
def workerNode = 'devel10'
def teamEmail = 'de-team@dbc.dk'
def teamSlack = 'de-team'

properties([
    disableConcurrentBuilds()
])
if (env.BRANCH_NAME == 'master') {
    properties([
        pipelineTriggers([
            triggers: [
                [
                    $class: 'jenkins.triggers.ReverseBuildTrigger',
                    upstreamProjects: "Docker-payara5-bump-trigger", threshold: hudson.model.Result.SUCCESS
                ]
            ]
        ])
    ])
}
pipeline {
    agent { label "devel10" }
    tools {
        maven "Maven 3"
    }
    environment {
        MAVEN_OPTS = "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
        DOCKER_PUSH_TAG = "${env.BUILD_NUMBER}"
        GITLAB_PRIVATE_TOKEN = credentials("metascrum-gitlab-api-token")
    }
    triggers {
        pollSCM("H/3 * * * *")
    }
    options {
        buildDiscarder(logRotator(artifactDaysToKeepStr: "", artifactNumToKeepStr: "", daysToKeepStr: "30", numToKeepStr: "30"))
        timestamps()
    }
    stages {
        stage("build") {
            steps {
                script {
                    def status = sh returnStatus: true, script:  """
                        rm -rf \$WORKSPACE/.repo
                        mvn -B -Dmaven.repo.local=\$WORKSPACE/.repo dependency:resolve dependency:resolve-plugins >/dev/null 2>&1 || true
                        mvn -B -Dmaven.repo.local=\$WORKSPACE/.repo clean
                        mvn -B -Dmaven.repo.local=\$WORKSPACE/.repo --fail-at-end org.jacoco:jacoco-maven-plugin:prepare-agent install -Dsurefire.useFile=false
                    """

                    // We want code-coverage and pmd/spotbugs even if unittests fails
                    // status += sh returnStatus: true, script:  """
                    //     mvn -B -Dmaven.repo.local=\$WORKSPACE/.repo pmd:pmd pmd:cpd spotbugs:spotbugs javadoc:aggregate
                    // """

                    // junit testResults: '**/target/*-reports/TEST-*.xml'

                    // def java = scanForIssues tool: [$class: 'Java']
                    // def javadoc = scanForIssues tool: [$class: 'JavaDoc']
                    // publishIssues issues:[java, javadoc], failedTotalAll: 1

                    // def pmd = scanForIssues tool: [$class: 'Pmd', pattern: '**/target/pmd.xml']
                    // publishIssues issues:[pmd], failedTotalAll: 1

                    // def cpd = scanForIssues tool: [$class: 'Cpd', pattern: '**/target/cpd.xml']
                    // publishIssues issues:[cpd], failedTotalAll: 1

                    // def spotbugs = scanForIssues tool: [$class: 'SpotBugs', pattern: '**/target/spotbugsXml.xml']
                    // publishIssues issues:[spotbugs], failedTotalAll: 1

                    // step([$class: 'JacocoPublisher',
                    //       execPattern: 'target/*.exec,**/target/*.exec',
                    //       classPattern: 'target/classes,**/target/classes',
                    //       sourcePattern: 'src/main/java,**/src/main/java',
                    //       exclusionPattern: 'src/test*,**/src/test*,**/*?Request.*,**/*?Response.*,**/*?Request$*,**/*?Response$*,**/*?DTO.*,**/*?DTO$*'
                    // ])

                    // warnings consoleParsers: [
                    //      [parserName: "Java Compiler (javac)"],
                    //      [parserName: "JavaDoc Tool"]],
                    //      unstableTotalAll: "0",
                    //      failedTotalAll: "0"

                    if ( status != 0 ) {
                        error("Build failed")
                    }
                }
            }
        }

        stage("docker") {
            steps {
                script {
                    def allDockerFiles = findFiles glob: '**/Dockerfile'
                    def dockerFiles = allDockerFiles.findAll { f -> f.path.endsWith("target/docker/Dockerfile") }
                    def version = readMavenPom().version.replace('-SNAPSHOT', '')

                    for (def f : dockerFiles) {
                        def dirName = f.path.take(f.path.length() - "target/docker/Dockerfile".length())
                        if ( dirName == '' )
                            dirName = '.'
                        dir(dirName) {
                            modulePom = readMavenPom file: 'pom.xml'
                            def projectArtifactId = modulePom.getArtifactId()
                            def imageName = "${projectArtifactId}-${version}".toLowerCase()
                            if (! env.CHANGE_BRANCH) {
                                imageLabel = env.BRANCH_NAME.toLowerCase()
                            } else {
                                imageLabel = env.CHANGE_BRANCH.toLowerCase()
                            }
                            if ( ! (imageLabel ==~ /master|trunk/) ) {
                                println("Using branch_name ${imageLabel}")
                                imageLabel = imageLabel.split(/\//)[-1]
                            } else {
                                println(" Using Master branch ${BRANCH_NAME}")
                                imageLabel = env.BUILD_NUMBER
                            }

                            println("In ${dirName} build ${projectArtifactId} as ${imageName}:$imageLabel")

                            def app = docker.build("$imageName:${imageLabel}", '--pull --no-cache --file target/docker/Dockerfile .')

                            if (currentBuild.resultIsBetterOrEqualTo('SUCCESS')) {
                                docker.withRegistry(dockerRepository, 'docker') {
                                    app.push()
                                    if (env.BRANCH_NAME ==~ /master|trunk/) {
                                        app.push "latest"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // stage("Update DIT") {
        //     agent {
        //         docker {
        //             label workerNode
        //             image "docker.dbc.dk/build-env:latest"
        //             alwaysPull true
        //         }
        //     }
        //     when {
        //         expression {
        //             (currentBuild.result == null || currentBuild.result == 'SUCCESS') && env.BRANCH_NAME == 'master'
        //         }
        //     }
        //     steps {
        //         script {
        //             dir("deploy") {
        //                 sh "set-new-version services/search/work-presentation-service.yml ${env.GITLAB_PRIVATE_TOKEN} metascrum/dit-gitops-secrets ${DOCKER_PUSH_TAG} -b master"
        //                 sh "set-new-version services/search/work-presentation-worker.yml ${env.GITLAB_PRIVATE_TOKEN} metascrum/dit-gitops-secrets ${DOCKER_PUSH_TAG} -b master"
        //             }
        //         }
        //     }
        // }
    }
    post {
        fixed {
            script {
                if ("${env.BRANCH_NAME}" == 'master') {
                    emailext(
                            recipientProviders: [developers(), culprits()],
                            to: teamEmail,
                            subject: "[Jenkins] ${env.JOB_NAME} #${env.BUILD_NUMBER} back to normal",
                            mimeType: 'text/html; charset=UTF-8',
                            body: "<p>The master is back to normal.</p><p><a href=\"${env.BUILD_URL}\">Build information</a>.</p>",
                            attachLog: false)
                    slackSend(channel: teamSlack,
                            color: 'good',
                            message: "${env.JOB_NAME} #${env.BUILD_NUMBER} back to normal: ${env.BUILD_URL}",
                            tokenCredentialId: 'slack-global-integration-token')
                }
            }
        }
        failure {
            script {
                if ("${env.BRANCH_NAME}" == 'master') {
                    emailext(
                            recipientProviders: [developers(), culprits()],
                            to: teamEmail,
                            subject: "[Jenkins] ${env.JOB_NAME} #${env.BUILD_NUMBER} failed",
                            mimeType: 'text/html; charset=UTF-8',
                            body: "<p>The master build failed. Log attached.</p><p><a href=\"${env.BUILD_URL}\">Build information</a>.</p>",
                            attachLog: true
                    )
                    slackSend(channel: teamSlack,
                            color: 'warning',
                            message: "${env.JOB_NAME} #${env.BUILD_NUMBER} failed and needs attention: ${env.BUILD_URL}",
                            tokenCredentialId: 'slack-global-integration-token')

                } else {
                    emailext(
                            recipientProviders: [developers()],
                            subject: "[Jenkins] ${env.BUILD_TAG} failed and needs your attention",
                            mimeType: 'text/html; charset=UTF-8',
                            body: "<p>${env.BUILD_TAG} failed and needs your attention. </p><p><a href=\"${env.BUILD_URL}\">Build information</a>.</p>",
                            attachLog: false
                    )
                }
            }
        }
    }
}
