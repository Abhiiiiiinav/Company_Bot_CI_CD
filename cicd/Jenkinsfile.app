pipeline {
    agent any

    parameters {
        string(name: 'TARGET_VM_IP', defaultValue: '34.47.150.171', description: 'Fallback IP for test-vm')
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
                    docker run --rm \
                        -v "$(pwd)":/workspace \
                        -w /workspace \
                        python:3.11-slim \
                        sh -c "pip install --no-cache-dir -r requirements.txt && pytest"
                '''
            }
        }

        stage('3. Build & Push to GHCR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'ghcr-creds', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
                    sh '''
                        # 1. Log in to GitHub Container Registry
                        echo "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin

                        # 2. Ensure docker socket permissions (without -it flag for non-interactive CI)
                        docker exec -u 0 Jenkins chmod 666 /var/run/docker.sock || true

                        # 3. Build multi-stage targets from root context (.)
                        docker build --target backend -t ghcr.io/abhiiiiiinav/knowlayer-backend:latest .
                        docker build --target frontend -t ghcr.io/abhiiiiiinav/knowlayer-frontend:latest .

                        # 4. Push images to GitHub Container Registry
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
                    usernamePassword(credentialsId: 'ghcr-creds', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN'),
                    file(credentialsId: 'app-env-file', variable: 'ENV_FILE')
                ]) {
                    sh '''
                        ACTIVE_KEY=$( [ -f "$TF_KEY_FILE" ] && echo "$TF_KEY_FILE" || echo "$JENKINS_KEY" )
                        SSH_OPTS="-i $ACTIVE_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

                        # Copy docker-compose.yml and the secret .env to test-vm
                        scp $SSH_OPTS docker-compose.yml ${SSH_USER}@${DEPLOY_IP}:~/docker-compose.yml
                        scp $SSH_OPTS "$ENV_FILE" ${SSH_USER}@${DEPLOY_IP}:~/.env

                        # Pull latest images and recreate containers
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
