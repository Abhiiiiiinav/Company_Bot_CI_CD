pipeline {
    agent any

    parameters {
        string(name: 'TARGET_VM_IP', defaultValue: 'PASTE_TEST_VM_IP_HERE', description: 'Fallback IP for test-vm')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip pytest for fast deploy testing')
    }

    environment {
        SSH_USER    = "jenkins-deploy"
        TF_IP_FILE  = "/var/jenkins_home/keys/app_vm_ip.txt"
        TF_KEY_FILE = "/var/jenkins_home/keys/deploy_key"
    }

    stages {
        stage('1. Resolve Target VM') {
            steps {
                checkout scm
                script {
                    env.DEPLOY_IP = fileExists(env.TF_IP_FILE)
                        ? sh(script: "cat ${env.TF_IP_FILE} | tr -d '\\n\\r '", returnStdout: true)
                        : params.TARGET_VM_IP.trim()
                    echo "Deploying to VM IP: ${env.DEPLOY_IP}"
                }
            }
        }

        stage('2. Test') {
            when { expression { return !params.SKIP_TESTS } }
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install -r requirements.txt
                    pytest
                '''
            }
        }

                stage('3. Build & Push to GHCR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'ghcr-creds', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
                    sh '''
                        echo "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin

                        # Build backend and frontend images
                        docker build -t ghcr.io/abhiiiiiinav/knowlayer-backend:latest ./app
                        docker build -t ghcr.io/abhiiiiiinav/knowlayer-frontend:latest ./frontend

                        # Push images to GitHub Container Registry
                        docker push ghcr.io/abhiiiiiinav/knowlayer-backend:latest
                        docker push ghcr.io/abhiiiiiinav/knowlayer-frontend:latest
                    '''
                }
            }
        }

        stage('4. SSH Deploy to VM') {
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'vm-ssh-key', keyFileVariable: 'JENKINS_KEY'),
                    usernamePassword(credentialsId: 'ghcr-creds', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')
                ]) {
                    sh '''
                        ACTIVE_KEY=$( [ -f "$TF_KEY_FILE" ] && echo "$TF_KEY_FILE" || echo "$JENKINS_KEY" )
                        SSH_OPTS="-i $ACTIVE_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

                        scp $SSH_OPTS docker-compose.yml ${SSH_USER}@${DEPLOY_IP}:~/docker-compose.yml
                        ssh $SSH_OPTS ${SSH_USER}@${DEPLOY_IP} "
                            echo '$GH_TOKEN' | docker login ghcr.io -u '$GH_USER' --password-stdin &&
                            docker compose pull &&
                            docker compose up -d --remove-orphans &&
                            docker image prune -f
                        "
                    '''
                }
            }
        }
    }
}
