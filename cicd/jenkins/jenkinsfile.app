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
        stage('1. Resolve Target VM & Git SHA') {
            steps {
                checkout scm
                script {
                    env.DEPLOY_IP = fileExists(env.TF_IP_FILE)
                        ? sh(script: "cat ${env.TF_IP_FILE} | tr -d '\\n\\r '", returnStdout: true)
                        : params.TARGET_VM_IP.trim()
                    echo "Deploying to VM IP: ${env.DEPLOY_IP}"

                    // Extract short commit SHA (7 chars) for receipt stamping
                    env.GIT_SHA = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    echo "Deploying Git Commit SHA: ${env.GIT_SHA}"
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
                    sh """
                        # 1. Log in to GitHub Container Registry
                        echo "\$GH_TOKEN" | docker login ghcr.io -u "\$GH_USER" --password-stdin

                        # 2. Ensure docker socket permissions (without -it flag for non-interactive CI)
                        docker exec -u 0 Jenkins chmod 666 /var/run/docker.sock || true

                        # 3. Build multi-stage targets with embedded receipt stamp
                        docker build --build-arg GIT_COMMIT=${env.GIT_SHA} \\
                            --target backend \\
                            -t ghcr.io/abhiiiiiinav/knowlayer-backend:${env.GIT_SHA} \\
                            -t ghcr.io/abhiiiiiinav/knowlayer-backend:latest .

                        docker build --build-arg GIT_COMMIT=${env.GIT_SHA} \\
                            --target frontend \\
                            -t ghcr.io/abhiiiiiinav/knowlayer-frontend:${env.GIT_SHA} \\
                            -t ghcr.io/abhiiiiiinav/knowlayer-frontend:latest .

                        # 4. Push images to GitHub Container Registry (both SHA and latest)
                        docker push ghcr.io/abhiiiiiinav/knowlayer-backend:${env.GIT_SHA}
                        docker push ghcr.io/abhiiiiiinav/knowlayer-backend:latest
                        docker push ghcr.io/abhiiiiiinav/knowlayer-frontend:${env.GIT_SHA}
                        docker push ghcr.io/abhiiiiiinav/knowlayer-frontend:latest
                    """
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
                    sh """
                        ACTIVE_KEY=\$( [ -f "\$TF_KEY_FILE" ] && echo "\$TF_KEY_FILE" || echo "\$JENKINS_KEY" )
                        SSH_OPTS="-i \$ACTIVE_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

                        # Clean previous .env and copy docker-compose.yml and secret .env to test-vm
                        ssh \$SSH_OPTS \${SSH_USER}@\${DEPLOY_IP} "rm -f ~/.env"
                        scp \$SSH_OPTS docker-compose.yml \${SSH_USER}@\${DEPLOY_IP}:~/docker-compose.yml
                        scp \$SSH_OPTS "\$ENV_FILE" \${SSH_USER}@\${DEPLOY_IP}:~/.env

                        # Inject the exact receipt number (IMAGE_TAG) and pull/recreate containers
                        ssh \$SSH_OPTS \${SSH_USER}@\${DEPLOY_IP} "
                            sed -i '/^IMAGE_TAG=/d' ~/.env || true
                            echo 'IMAGE_TAG=${env.GIT_SHA}' >> ~/.env
                            echo '\$GH_TOKEN' | docker login ghcr.io -u '\$GH_USER' --password-stdin &&
                            docker compose -f ~/docker-compose.yml pull &&
                            docker rm -f knowlayer-backend knowlayer-frontend 2>/dev/null || true &&
                            docker compose -f ~/docker-compose.yml up -d --remove-orphans --force-recreate &&
                            docker image prune -f
                        "
                    """
                }
            }
        }

        stage('5. Verify Deployment (Show Me the Receipt)') {
            steps {
                script {
                    echo "Verifying live deployment matches commit receipt: ${env.GIT_SHA}..."
                    sh """
                        for i in \$(seq 1 10); do
                            LIVE_COMMIT=\$(curl -sf http://${env.DEPLOY_IP}:8000/health | grep -o '"commit":"[^"]*"' | cut -d'"' -f4 || echo "unreachable")
                            echo "Attempt \$i: Live health commit is '\$LIVE_COMMIT' (expected: ${env.GIT_SHA})"
                            if [ "\$LIVE_COMMIT" = "${env.GIT_SHA}" ]; then
                                echo "======================================================="
                                echo "VERIFIED: Live VM is serving exact commit ${env.GIT_SHA}!"
                                echo "======================================================="
                                exit 0
                            fi
                            sleep 5
                        done

                        echo "======================================================="
                        echo "ERROR: Receipt mismatch! Expected ${env.GIT_SHA} but live server reported \$LIVE_COMMIT"
                        echo "======================================================="
                        exit 1
                    """
                }
            }
        }
    }
}
