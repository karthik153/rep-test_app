pipeline {
    agent any

    environment {
        ACE_BASE_IMAGE = 'ace:13.0.6.0'
        TAG = "v${BUILD_NUMBER}"
        // Point to the config file we copied in Phase 3
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
                   echo "--- Compiling BAR ---"
                   sh """
                       docker run --rm \
                       -e LICENSE=accept \
                       --user 0 \
                       -v \$(pwd):/tmp/workspace \
                       --entrypoint bash \
                       ${ACE_BASE_IMAGE} \
                       -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && ibmint package --input-path /tmp/workspace/src --output-bar-file /tmp/workspace/${params.APP_NAME}.bar --do-not-compile-java"
                   """
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
                    // Uses the KUBECONFIG environment variable set at the top
                    sh "kubectl apply -f deploy-app.yaml"
                }
            }
        }
    }
}