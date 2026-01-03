pipeline {
    // This script runs inside your Linux Jenkins Container
    agent any

    environment {
        // This is the base image we use to compile the BAR file
        ACE_BASE_IMAGE = 'ace:13.0.6.0'
        
        // Define Image tag based on Build Number
        TAG = "v${BUILD_NUMBER}"
    }

    parameters {
        // We set a default, but this should be passed when starting the job for 100 apps
        string(name: 'APP_NAME', defaultValue: 'test-app', description: 'Unique Name of the Microservice (e.g., account-service)')
        string(name: 'HTTP_PORT', defaultValue: '8081', description: 'External Port to expose in Kubernetes')
    }

    stages {
        stage('Cleanup') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout Code') {
            steps {
                // Gets code from your Git Repository
                checkout scm
            }
        }

        stage('Compile BAR (via Docker)') {
            steps {
                script {
                    echo "--- Compiling Source Code into BAR ---"
                    // We run a temporary ACE container just to compile the code.
                    // This avoids installing ACE Toolkit on the Jenkins server.
                    // Assumption: Your message flows are in a folder named 'src'
                    
                    sh """
                        docker run --rm \
                        --user 0 \
                        -v \$(pwd):/tmp/workspace \
                        --entrypoint bash \
                        ${ACE_BASE_IMAGE} \
                        -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && ibmint package --input-path /tmp/workspace/src --output-bar-file /tmp/workspace/${params.APP_NAME}.bar --do-not-compile-java"
                    """
                    
                    // Verify BAR file was created
                    sh "ls -l *.bar"
                }
            }
        }

        stage('Build Runtime Image') {
            steps {
                script {
                    echo "--- Building Microservice Container Image ---"
                    // Builds the image using the Dockerfile in the root
                    // Passes the dynamic App Name and BAR Name
                    
                    sh """
                        docker build -t ${params.APP_NAME}:${TAG} \
                        --build-arg BAR_NAME=${params.APP_NAME}.bar \
                        --build-arg SERVER_NAME=${params.APP_NAME} \
                        .
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "--- Injecting Config into YAML ---"
                    // We use 'sed' to replace the placeholders in deploy-app.yaml with actual values
                    // This creates the final definition for THIS specific build
                    
                    sh """
                        sed -i 's|my-ace-app|${params.APP_NAME}|g' deploy-app.yaml
                        sed -i 's|my-ace-service|${params.APP_NAME}-service|g' deploy-app.yaml
                        sed -i 's|test-runtime:v1|${params.APP_NAME}:${TAG}|g' deploy-app.yaml
                        sed -i 's|port: 8080|port: ${params.HTTP_PORT}|g' deploy-app.yaml
                    """
                    
                    echo "--- Displaying Final YAML (For Debugging) ---"
                    sh "cat deploy-app.yaml"

                    echo "--- Applying to Kubernetes ---"
                    // Since Jenkins runs in Docker Desktop K8s context (usually), this works immediately.
                    sh "kubectl apply -f deploy-app.yaml"
                }
            }
        }
    }
    
    post {
        always {
             echo "Build ${params.APP_NAME} finished."
        }
        success {
             echo "Successfully deployed to http://localhost:${params.HTTP_PORT}"
        }
    }
}