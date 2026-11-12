pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    parameters {
        booleanParam(
            name: 'RUN_CONTRACT_TESTS',
            defaultValue: true,
            description: 'Run pytest contract tests inside the built container'
        )
        booleanParam(
            name: 'PUSH_IMAGE',
            defaultValue: false,
            description: 'Push built Docker image to container registry (requires DOCKER_CREDS)'
        )
        booleanParam(
            name: 'UPDATE_GITOPS',
            defaultValue: false,
            description: 'Update image tag in deploy/k8s/*.yaml for Argo CD sync (requires GIT_CREDS)'
        )
    }

    environment {
        // Update IMAGE_REPO to your Docker Hub (e.g. "username/company-bot")
        // or GCP Artifact Registry ("us-central1-docker.pkg.dev/PROJECT_ID/REPO/company-bot")
        IMAGE_REPO   = 'your-dockerhub-username/company-bot'
        DOCKER_CREDS = 'dockerhub-creds'
        GIT_CREDS    = 'github-creds'
        GITOPS_DIR   = 'deploy/k8s'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.SHORT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.SHORT_SHA}-${env.BUILD_NUMBER}"
                    env.BRANCH_NAME_CLEAN = (env.GIT_BRANCH ?: 'Abhinav').replaceAll('^origin/', '')
                }
                echo "Building branch=${env.BRANCH_NAME_CLEAN} tag=${env.IMAGE_TAG}"
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                        -f Dockerfile \
                        -t "$IMAGE_REPO:$IMAGE_TAG" \
                        -t "$IMAGE_REPO:latest" \
                        .
                '''
            }
        }

        stage('Container Smoke Test') {
            steps {
                sh '''
                    docker run --rm "$IMAGE_REPO:$IMAGE_TAG" \
                        python -c "from app.main import app; print('FastAPI routes:', len(app.routes))"
                '''
            }
        }

        stage('Contract Tests (Pytest)') {
            when {
                expression { return params.RUN_CONTRACT_TESTS }
            }
            steps {
                sh '''
                    mkdir -p reports
                    docker run --rm \
                        -v "$WORKSPACE/tests:/app/tests:ro" \
                        -v "$WORKSPACE/reports:/app/reports" \
                        "$IMAGE_REPO:$IMAGE_TAG" \
                        pytest tests/contract --junitxml=reports/junit.xml -q
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                sh '''
                    if command -v trivy >/dev/null 2>&1; then
                        trivy image --exit-code 0 --severity HIGH,CRITICAL "$IMAGE_REPO:$IMAGE_TAG"
                    else
                        echo "Trivy not installed on agent; skipping image scan."
                    fi
                '''
            }
        }

        stage('Push to Registry') {
            when {
                expression { return params.PUSH_IMAGE }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDS}",
                    usernameVariable: 'REGISTRY_USER',
                    passwordVariable: 'REGISTRY_PASS'
                )]) {
                    sh '''
                        echo "$REGISTRY_PASS" | docker login -u "$REGISTRY_USER" --password-stdin
                        docker push "$IMAGE_REPO:$IMAGE_TAG"
                        docker push "$IMAGE_REPO:latest"
                    '''
                }
            }
        }

        stage('Update GitOps Manifest (Argo CD)') {
            when {
                expression { return params.UPDATE_GITOPS && params.PUSH_IMAGE }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${GIT_CREDS}",
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    sh '''
                        if [ -d "$GITOPS_DIR" ]; then
                            sed -i "s|image: ${IMAGE_REPO}:.*|image: ${IMAGE_REPO}:${IMAGE_TAG}|g" "$GITOPS_DIR"/*.yaml
                            git config user.name "jenkins-ci"
                            git config user.email "jenkins-ci@local"
                            git add "$GITOPS_DIR"/*.yaml
                            if ! git diff --cached --quiet; then
                                git commit -m "chore(gitops): bump image to ${IMAGE_TAG} [skip ci]"
                                REPO_URL=$(git remote get-url origin | sed "s|https://|https://${GIT_USER}:${GIT_PASS}@|")
                                git push "$REPO_URL" "HEAD:${BRANCH_NAME_CLEAN}"
                            else
                                echo "No manifest changes to commit."
                            fi
                        else
                            echo "Directory $GITOPS_DIR not found; skipping Argo CD manifest update."
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker logout || true
                docker rmi "$IMAGE_REPO:$IMAGE_TAG" || true
            '''
        }
        success {
            echo "Pipeline succeeded for $IMAGE_REPO:$IMAGE_TAG"
        }
        failure {
            echo "Pipeline failed for tag $IMAGE_TAG"
        }
    }
}
