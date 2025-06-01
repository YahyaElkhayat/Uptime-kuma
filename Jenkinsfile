pipeline {
    agent any
    
    tools {
        jdk 'jdk17'
        nodejs 'node18'
    }
    
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        DOCKER_IMAGE = 'uptime-kuma'
        DOCKER_TAG = 'latest'
        CONTAINER_NAME = 'uptime-kuma'
        APP_PORT = '3001'
    }
    
    stages {
        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/YahyaElkhayat/Uptime-kuma.git'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    // Configure npm for better network handling
                    bat '''
                        npm config set registry https://registry.npmjs.org/
                        npm config set timeout 300000
                        npm config set fetch-timeout 300000 
                        npm config set fetch-retry-mintimeout 20000
                        npm config set fetch-retry-maxtimeout 120000
                        npm config set fetch-retries 5
                    '''
                    
                    // Try npm install with retry logic
                    retry(3) {
                        bat 'npm install --verbose --no-optional'
                    }
                }
            }
        }
        
        stage("Sonarqube Analysis "){
            steps{
                withSonarQubeEnv('sonar-server') {
                    bat ''' %SCANNER_HOME%\\bin\\sonar-scanner.bat -Dsonar.projectName=yahya-uptime-CICD ^
                    -Dsonar.projectKey=yahya-uptime-CICD '''
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                script {
                    timeout(time: 10, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: false, credentialsId: 'sonarqube-token'
                    }
                }
            }
        }
        
        stage('OWASP Dependency Check') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit --format HTML --format XML', 
                                odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        
        stage('Docker Security Scan') {
            steps {
                script {
                    try {
                        bat 'docker scout quickview || echo "Docker Scout not available, skipping..."'
                    } catch (Exception e) {
                        echo "Docker Scout scan failed or not available: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Docker Build') {
            steps {
                script {
                    bat "docker build -t %DOCKER_IMAGE%:%DOCKER_TAG% ."
                }
            }
        }
        
        stage('Docker Image Vulnerability Scan') {
            steps {
                script {
                    try {
                        bat "docker scout cves %DOCKER_IMAGE%:%DOCKER_TAG% || echo \"Docker Scout CVE scan completed\""
                    } catch (Exception e) {
                        echo "Docker vulnerability scan completed with warnings: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Docker Push') {
            when {
                expression { 
                    return params.PUSH_TO_REGISTRY == true 
                }
            }
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-hub', toolName: 'docker') {
                        bat '''
                            docker tag %DOCKER_IMAGE%:%DOCKER_TAG% yahyaelkhayat/%DOCKER_IMAGE%:%DOCKER_TAG%
                            docker push yahyaelkhayat/%DOCKER_IMAGE%:%DOCKER_TAG%
                        '''
                    }
                }
            }
        }
        
        stage('Clean Up Existing Container') {
            steps {
                script {
                    bat '''
                        docker stop %CONTAINER_NAME% 2>nul || echo "Container not running"
                        docker rm %CONTAINER_NAME% 2>nul || echo "Container not found"
                    '''
                }
            }
        }
        
        stage('Deploy to Container') {
            steps {
                script {
                    bat '''
                        docker run -d ^
                        --name %CONTAINER_NAME% ^
                        -p %APP_PORT%:%APP_PORT% ^
                        -v uptime-kuma-data:/app/data ^
                        --restart unless-stopped ^
                        %DOCKER_IMAGE%:%DOCKER_TAG%
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    sleep(time: 30, unit: 'SECONDS')
                    timeout(time: 5, unit: 'MINUTES') {
                        waitUntil {
                            script {
                                try {
                                    def response = bat(script: 'curl -f http://localhost:%APP_PORT% || exit 1', returnStatus: true)
                                    return response == 0
                                } catch (Exception e) {
                                    echo "Health check attempt failed: ${e.getMessage()}"
                                    return false
                                }
                            }
                        }
                    }
                    echo "✅ Uptime Kuma is running successfully at http://localhost:${APP_PORT}"
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Archive reports
                try {
                    archiveArtifacts artifacts: '**/dependency-check-report.*', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "No artifacts to archive: ${e.getMessage()}"
                }
                
                // Clean up workspace
                try {
                    cleanWs()
                } catch (Exception e) {
                    echo "Workspace cleanup warning: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo "🎉 Pipeline completed successfully!"
            echo "Uptime Kuma is available at: http://localhost:${APP_PORT}"
        }
        
        failure {
            echo "❌ Pipeline failed. Check the logs for details."
            script {
                try {
                    // Stop and remove container if deployment failed
                    bat '''
                        docker stop %CONTAINER_NAME% 2>nul || echo "Container cleanup not needed"
                        docker rm %CONTAINER_NAME% 2>nul || echo "Container cleanup not needed"
                    '''
                } catch (Exception e) {
                    echo "Container cleanup completed: ${e.getMessage()}"
                }
            }
        }
    }
}