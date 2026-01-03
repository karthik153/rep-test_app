pipeline {
    agent any

    environment {
        ACE_BASE_IMAGE = 'ace:13.0.6.0'
        TAG = "v${BUILD_NUMBER}"
        KUBECONFIG = '/var/jenkins_home/kube_config'
    }

    parameters {
        string(name: 'APP_NAME', defaultValue: 'test-app', description: 'Name of the Microservice')
        string(name: 'HTTP_PORT', defaultValue: '8081', description: 'External Port')
    }

    stages {
        stage('Cleanup') {
            steps {
                cleanWs()
            }
        }
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }
        stage('Compile BAR') {
            steps {
                script {
                    echo "--- Compiling BAR (Using Docker Copy Method) ---"
                    
                    // 1. Start a temporary background container (keeping it alive with 'tail')
                    // We capture the Container ID into a variable 'CID'
                    def CID = sh(script: "docker run -d -e LICENSE=accept --user 0 --entrypoint tail ${ACE_BASE_IMAGE} -f /dev/null", returnStdout: true).trim()
                    
                    try {
                        echo "Builder Container ID: ${CID}"

                        // 2. Create the temp directory inside
                        sh "docker exec ${CID} mkdir -p /tmp/workspace/src"

                        // 3. COPY your 'src' folder from Jenkins into the ACE Container
                        sh "docker cp src/. ${CID}:/tmp/workspace/src"

                        // 4. Run 'ibmint package' inside the container
                        sh """
                            docker exec ${CID} bash -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && ibmint package --input-path /tmp/workspace/src --output-bar-file /tmp/workspace/${params.APP_NAME}.bar --do-not-compile-java"
                        """

                        // 5. COPY the resulting BAR file back to Jenkins
                        sh "docker cp ${CID}:/tmp/workspace/${params.APP_NAME}.bar ./"

                    } finally {
                        // 6. Always clean up (remove the temp container)
                        sh "docker rm -f ${CID}"
                    }
                    
                    // Debug: Verify we have the BAR file
                    sh "ls -l *.bar"
                }
            }
        }
        stage('Build Runtime Image') {
            steps {
                 script {
                    echo "--- Building Docker Image ---"
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