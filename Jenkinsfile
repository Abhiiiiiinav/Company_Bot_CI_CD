pipeline {
    agent any

    environment {
        TF_DIR      = 'terraform/environments/gcp-app'
        DEPLOY_USER = 'deployer'
    }

    parameters {
        choice(name: 'ACTION', choices: ['apply', 'plan', 'destroy'], description: 'Terraform action to perform')
        choice(name: 'CPU_COUNT', choices: ['2', '1', '4'], description: 'vCPU count for the application VM')
    }

    stages {
        stage('Checkout Source') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh "terraform -chdir=${TF_DIR} init -upgrade"
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'app-deploy-ssh-key', keyFileVariable: 'DEPLOY_KEY', usernameVariable: 'SSH_USER')]) {
                    sh """
                        # Extract the public SSH key directly from the configured private key
                        SSH_PUB_KEY=\$(ssh-keygen -y -f "\${DEPLOY_KEY}")

                        terraform -chdir=${TF_DIR} plan \
                            -var="cpu_count=${params.CPU_COUNT}" \
                            -var="ssh_public_key=\${SSH_PUB_KEY}" \
                            -out=tfplan
                    """
                }
            }
        }

        stage('Terraform Apply (Provision App VM)') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                sh "terraform -chdir=${TF_DIR} apply -auto-approve tfplan"
                script {
                    env.APP_IP = sh(
                        script: "terraform -chdir=${TF_DIR} output -raw app_public_ip",
                        returnStdout: true
                    ).trim()
                    echo "Provisioned Application Host VM at IP: ${env.APP_IP}"
                }
            }
        }

        stage('Deploy Application Stack') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'app-deploy-ssh-key', keyFileVariable: 'DEPLOY_KEY', usernameVariable: 'SSH_USER')]) {
                    sh """
                        SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i \${DEPLOY_KEY}"

                        echo "Waiting for SSH to be reachable on \${APP_IP}:22..."
                        until ssh \${SSH_OPTS} \${SSH_USER}@\${APP_IP} "echo 'SSH is online'" 2>/dev/null; do
                            echo "SSH daemon initializing, retrying in 5 seconds..."
                            sleep 5
                        done

                        echo "Waiting for Docker installation to complete on application VM..."
                        until ssh \${SSH_OPTS} \${SSH_USER}@\${APP_IP} "docker --version && docker compose version" 2>/dev/null; do
                            echo "Docker is still installing on app VM, retrying in 10 seconds..."
                            sleep 10
                        done
                        echo "Docker and Docker Compose are fully initialized!"

                        echo "Packaging source files for deployment..."
                        tar -czf /tmp/app_bundle.tar.gz \
                            --exclude='.git' \
                            --exclude='.venv' \
                            --exclude='__pycache__' \
                            --exclude='terraform' \
                            --exclude='.terraform' \
                            --exclude='instance' \
                            --exclude='.chroma' \
                            .

                        echo "Transferring bundle to target application VM..."
                        scp \${SSH_OPTS} /tmp/app_bundle.tar.gz \${SSH_USER}@\${APP_IP}:/tmp/app_bundle.tar.gz
                        rm -f /tmp/app_bundle.tar.gz

                        echo "Extracting code and bootstrapping Docker containers on application VM..."
                        ssh \${SSH_OPTS} \${SSH_USER}@\${APP_IP} '
                            set -e
                            mkdir -p ~/company-bot
                            tar -xzf /tmp/app_bundle.tar.gz -C ~/company-bot
                            rm -f /tmp/app_bundle.tar.gz
                            cd ~/company-bot

                            # Ensure .env exists if not provided
                            [ -f .env ] || cp .env.example .env

                            # Pull/build images and start Docker Compose stack
                            docker compose up -d --build
                        '
                    """
                }
            }
        }

        stage('Smoke Test & Health Probe') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                sh """
                    echo "Probing FastAPI backend health endpoint at http://\${APP_IP}:8000/health..."
                    SUCCESS=false
                    for i in \$(seq 1 18); do
                        if curl -s -f http://\${APP_IP}:8000/health; then
                            echo ""
                            echo "FastAPI backend reported HEALTHY!"
                            SUCCESS=true
                            break
                        fi
                        echo "Waiting for containers to initialize... (\$i/18)"
                        sleep 10
                    done

                    if [ "\$SUCCESS" != "true" ]; then
                        echo "ERROR: Backend health check timed out."
                        exit 1
                    fi
                """
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'app-deploy-ssh-key', keyFileVariable: 'DEPLOY_KEY', usernameVariable: 'SSH_USER')]) {
                    sh """
                        SSH_PUB_KEY=\$(ssh-keygen -y -f "\${DEPLOY_KEY}")
                        terraform -chdir=${TF_DIR} destroy -auto-approve \
                            -var="cpu_count=${params.CPU_COUNT}" \
                            -var="ssh_public_key=\${SSH_PUB_KEY}"
                    """
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            script {
                if (params.ACTION == 'apply') {
                    echo "=========================================================="
                    echo "DEPLOYMENT COMPLETE!"
                    echo "FastAPI Backend:  http://${env.APP_IP}:8000"
                    echo "Streamlit UI:     http://${env.APP_IP}:8501"
                    echo "Interactive Docs: http://${env.APP_IP}:8000/docs"
                    echo "=========================================================="
                } else if (params.ACTION == 'destroy') {
                    echo "Application VM destroyed successfully."
                }
            }
        }
        failure {
            echo "Pipeline step failed. Check the console log above for details."
        }
    }
}
