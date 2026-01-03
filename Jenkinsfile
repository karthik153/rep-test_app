pipeline {
    agent any

    environment {
        ACE_BASE_IMAGE = 'ace:13.0.6.0'
        TAG = "v${BUILD_NUMBER}"
        KUBECONFIG = '/var/jenkins_home/kube_config'
        // Define your GitHub User/Org here to make it easy to change later
        GITHUB_BASE = 'https://github.com/karthik153'
    }

    stages {
        stage('Cleanup') {
            steps {
                cleanWs()
            }
        }
        
        stage('Checkout Target Application') {
            steps {
                script {
                    // CONSTRUCT THE URL DYNAMICALLY
                    def fullUrl = "${GITHUB_BASE}/${params.REPO_NAME}.git"
                    
                    echo "--- Cloning Repo: ${fullUrl} ---"
                    
                    // Pull code using the constructed URL
                    // Note: If you need credentials, add credentialsId: 'your-id' inside the brackets
                    git branch: 'main', url: fullUrl
                }
            }
        }

        stage('Compile BAR') {
            steps {
                script {
                    echo "--- Compiling BAR ---"
                    def CID = sh(script: "docker run -d -e LICENSE=accept --user 0 --entrypoint tail ${ACE_BASE_IMAGE} -f /dev/null", returnStdout: true).trim()
                    try {
                        sh "docker exec ${CID} mkdir -p /tmp/workspace/src"
                        sh "docker cp src/. ${CID}:/tmp/workspace/src"
                        
                        sh """
                            docker exec ${CID} bash -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && ibmint package --input-path /tmp/workspace/src --output-bar-file /tmp/workspace/${params.APP_NAME}.bar --do-not-compile-java"
                        """
                        sh "docker cp ${CID}:/tmp/workspace/${params.APP_NAME}.bar ./"
                    } finally {
                        sh "docker rm -f ${CID}"
                    }
                    sh "ls -l *.bar"
                }
            }
        }

        stage('Build Image') {
            steps {
                 script {
                    echo "--- Building Image ---"
                    sh "docker build -t ${params.APP_NAME}:${TAG} --build-arg BAR_NAME=${params.APP_NAME}.bar --build-arg SERVER_NAME=${params.APP_NAME} ."
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "--- Updating YAML ---"
                    sh """
                        sed -i 's|my-ace-app|${params.APP_NAME}|g' deploy-app.yaml
                        sed -i 's|my-ace-service|${params.APP_NAME}-service|g' deploy-app.yaml
                        sed -i 's|test-runtime:v1|${params.APP_NAME}:${TAG}|g' deploy-app.yaml
                        sed -i 's|port: 8080|port: ${params.HTTP_PORT}|g' deploy-app.yaml
                    """
                    echo "--- Applying to K8s ---"
                    sh "kubectl apply -f deploy-app.yaml"
                }
            }
        }
    }
}