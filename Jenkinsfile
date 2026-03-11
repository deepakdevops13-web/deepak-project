pipeline {
    agent any
    
    tools {
        maven 'maven3'
        dockerTool 'docker'
    }
    
    environment {
        DOCKER_REGISTRY = credentials('docker-registry')
        IMAGE_NAME = "${DOCKER_REGISTRY}/vprofile"
        SONAR_LOGIN = credentials('sonar-token')
        SONAR_HOST = 'https://sonarcloud.io'
        SONAR_PROJECT = credentials('sonar-project')
        SONAR_ORG = credentials('sonar-org')
        CHARTS_REPO = credentials('charts-repo-url')
        CHARTS_TOKEN = credentials('charts-repo-token')
    }
    
    stages {
        stage('Debug Variables') {
            steps {
                echo "=== DEBUG VARIABLES ==="
                echo "IMAGE_NAME=${IMAGE_NAME}"
                echo "BUILD_ID=${BUILD_ID}"
                echo "GIT_COMMIT=${GIT_COMMIT}"
                echo "========================"
            }
        }
        
        stage('Build') {
            when {
                not { branch 'main' }
            }
            steps {
                sh 'mvn clean install -DskipTests'
            }
            post {
                success {
                    archiveArtifacts artifacts: '**/target/*.war'
                }
            }
        }
        
        stage('Unit Test') {
            when {
                not { branch 'main' }
            }
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    publishTestResults testResultsPattern: 'target/surefire-reports/TEST-*.xml'
                }
            }
        }
        
        stage('Checkstyle') {
            when {
                not { branch 'main' }
            }
            steps {
                sh 'mvn checkstyle:checkstyle'
            }
        }
        
        stage('Docker Build & Push') {
            when {
                not { branch 'main' }
            }
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'docker-registry') {
                        def image = docker.build("${IMAGE_NAME}:${GIT_COMMIT}", "-f Docker-files/app/multistage/Dockerfile .")
                        image.push()
                        sh "docker rmi ${IMAGE_NAME}:${GIT_COMMIT} || true"
                    }
                }
            }
        }
        
        stage('SonarCloud Analysis') {
            when {
                not { branch 'main' }
            }
            steps {
                withSonarQubeEnv('sonarcloud') {
                    sh '''
                        sonar-scanner \\
                        -Dsonar.login=${SONAR_LOGIN} \\
                        -Dsonar.host.url=${SONAR_HOST} \\
                        -Dsonar.projectKey=${SONAR_PROJECT} \\
                        -Dsonar.organization=${SONAR_ORG} \\
                        -Dsonar.projectName=vprofile-repo \\
                        -Dsonar.projectVersion=1.0 \\
                        -Dsonar.sources=src/ \\
                        -Dsonar.java.binaries=target/classes/com/visualpathit/account/controller/ \\
                        -Dsonar.junit.reportsPath=target/surefire-reports/ \\
                        -Dsonar.jacoco.reportsPath=target/jacoco.exec \\
                        -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml
                    '''
                }
            }
        }
        
        stage('Update Deployment') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh '''
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"
                        git clone https://${CHARTS_TOKEN}@${CHARTS_REPO} charts-repo
                        cd charts-repo
                        sed -i "s|image:.*|image: ${IMAGE_NAME}:${GIT_COMMIT}|" vprofile-charts/values.yaml
                        git add vprofile-charts/values.yaml
                        git commit -m "Update image to ${GIT_COMMIT}"
                        git push origin main
                    '''
                }
            }
        }
    }
}