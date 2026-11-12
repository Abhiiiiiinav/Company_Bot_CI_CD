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
            description: 'Run pytest contract tests inside the built backend container'
        )
        booleanParam(
            name: 'PUSH_IMAGE',
            defaultValue: false,
            description: 'Push backend and frontend images to container registry (requires DOCKER_CREDS)'
        )
        booleanParam(
            name: 'UPDATE_GITOPS',
            defaultValue: false,
            description: 'Update image tags in deploy/k8s/*.yaml for Argo CD sync (requires GIT_CREDS)'
        )
    }

    environment {
        // Update IMAGE_PREFIX to your Docker Hub (e.g. "username/company-bot")
        // or GCP Artifact Registry ("us-central1-docker.pkg.dev/PROJECT_ID/REPO/company-bot")
        IMAGE_PREFIX   = 'your-dockerhub-username/company-bot'
        BACKEND_IMAGE  = "${IMAGE_PREFIX}-backend"
        FRONTEND_IMAGE = "${IMAGE_PREFIX}-frontend"
        DOCKER_CREDS   = 'dockerhub-creds'
        GIT_CREDS      = 'github-creds'
        GITOPS_DIR     = 'deploy/k8s'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.SHORT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.SHORT_SHA}-${env.BUILD_NUMBER}"
                    env.BRANCH_NAME_CLEAN = (env.GIT_BRANCH ?: 'abhinav-qwen-cicd').replaceAll('^origin/', '')
                }
                echo "Building branch=${env.BRANCH_NAME_CLEAN} tag=${env.IMAGE_TAG}"
            }
        }

        stage('Build Docker Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        sh '''
                            docker build \
                                --target backend \
                                -f Dockerfile \
                                -t "$BACKEND_IMAGE:$IMAGE_TAG" \
                                -t "$BACKEND_IMAGE:latest" \
                                .
                        '''
                    }
                }
                stage('Build Frontend') {
                    steps {
                        sh '''
                            docker build \
                                --target frontend \
                                -f Dockerfile \
                                -t "$FRONTEND_IMAGE:$IMAGE_TAG" \
                                -t "$FRONTEND_IMAGE:latest" \
                                .
                        '''
                    }
                }
            }
        }

        stage('Container Smoke Tests') {
            parallel {
                stage('Smoke Test Backend') {
                    steps {
                        sh '''
                            docker run --rm "$BACKEND_IMAGE:$IMAGE_TAG" \
                                python -c "from app.main import app; print('Backend routes:', len(app.routes))"
                        '''
                    }
                }
                stage('Smoke Test Frontend') {
                    steps {
                        sh '''
                            docker run --rm "$FRONTEND_IMAGE:$IMAGE_TAG" \
                                python -c "import streamlit; print('Streamlit:', streamlit.__version__)"
                        '''
                    }
                }
            }
        }

        stage('Contract Tests (Pytest)') {
            when {
                expression { return params.RUN_CONTRACT_TESTS }
            }
            steps {
                sh '''
                    mkdir -p reports
                    CID=$(docker create "$BACKEND_IMAGE:$IMAGE_TAG" sh -c \
                        "mkdir -p /app/reports && uv pip install --system --no-cache -q pytest pytest-asyncio && pytest tests/contract --junitxml=/app/reports/junit.xml -q")
                    docker cp "$WORKSPACE/tests" "$CID:/app/tests"
                    docker cp "$WORKSPACE/streamlit_app" "$CID:/app/streamlit_app"
                    docker cp "$WORKSPACE/pyproject.toml" "$CID:/app/pyproject.toml"
                    set +e
                    docker start -a "$CID"
                    TEST_EXIT=$?
                    set -e
                    docker cp "$CID:/app/reports/junit.xml" reports/junit.xml || true
                    docker rm -f "$CID" >/dev/null 2>&1 || true
                    exit $TEST_EXIT
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
                        trivy image --exit-code 0 --severity HIGH,CRITICAL "$BACKEND_IMAGE:$IMAGE_TAG"
                        trivy image --exit-code 0 --severity HIGH,CRITICAL "$FRONTEND_IMAGE:$IMAGE_TAG"
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
                        docker push "$BACKEND_IMAGE:$IMAGE_TAG"
                        docker push "$BACKEND_IMAGE:latest"
                        docker push "$FRONTEND_IMAGE:$IMAGE_TAG"
                        docker push "$FRONTEND_IMAGE:latest"
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
                            sed -i "s|image: ${BACKEND_IMAGE}:.*|image: ${BACKEND_IMAGE}:${IMAGE_TAG}|g" "$GITOPS_DIR"/*.yaml
                            sed -i "s|image: ${FRONTEND_IMAGE}:.*|image: ${FRONTEND_IMAGE}:${IMAGE_TAG}|g" "$GITOPS_DIR"/*.yaml
                            git config user.name "jenkins-ci"
                            git config user.email "jenkins-ci@local"
                            git add "$GITOPS_DIR"/*.yaml
                            if ! git diff --cached --quiet; then
                                git commit -m "chore(gitops): bump images to ${IMAGE_TAG} [skip ci]"
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
                docker rmi "$BACKEND_IMAGE:$IMAGE_TAG" "$FRONTEND_IMAGE:$IMAGE_TAG" || true
            '''
        }
        success {
            echo "Pipeline succeeded for $BACKEND_IMAGE:$IMAGE_TAG and $FRONTEND_IMAGE:$IMAGE_TAG"
        }
        failure {
            echo "Pipeline failed for tag $IMAGE_TAG"
        }
    }
}
