pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '5'))
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
        ansiColor('xterm')
        timestamps()
    }

    parameters {
        choice(
            name: 'DEPLOY_TARGET',
            choices: ['local', 'gcp'],
            description: 'local = Docker Desktop K8s + local Argo CD; gcp = Push to GAR + GKE'
        )
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run FastAPI contract tests and Streamlit checks inside built containers'
        )
        booleanParam(
            name: 'UPDATE_GITOPS',
            defaultValue: true,
            description: 'Update image tags in k8s/*.yaml and push [skip ci] to trigger Argo CD'
        )
    }

    environment {
        // GCP Artifact Registry settings (used when DEPLOY_TARGET == 'gcp')
        GCP_PROJECT_ID = 'your-gcp-project-id'
        GAR_REGION     = 'asia-south1'
        GAR_REPO       = 'company-bot-repo'
        REGISTRY_URL   = "${GAR_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GAR_REPO}"

        // Credentials IDs in Jenkins
        GIT_CREDS_ID   = 'githubjenkins'
        GCP_CREDS_ID   = 'gcp-gar-sa-key'

        // Set external GitOps repo if splitting manifests out later; blank = current repo (k8s/)
        GITOPS_REPO    = ''
    }

    stages {
        stage('1. Pre-Flight Checks') {
            steps {
                checkout scm
                script {
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    def branchRaw = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'abhinav-qwen-cicd'
                    env.BRANCH_CLEAN = branchRaw.replaceAll('^origin/', '')
                    env.IMAGE_TAG = "${env.BRANCH_CLEAN}-${env.BUILD_NUMBER}-${shortSha}"

                    if (params.DEPLOY_TARGET == 'gcp') {
                        env.API_IMAGE = "${env.REGISTRY_URL}/knowlayer-api"
                        env.UI_IMAGE  = "${env.REGISTRY_URL}/knowlayer-ui"
                    } else {
                        env.API_IMAGE = 'knowlayer-api'
                        env.UI_IMAGE  = 'knowlayer-ui'
                    }
                }
                echo "Starting CI Pipeline for Company_Bot (target=${params.DEPLOY_TARGET}, tag=${env.IMAGE_TAG})..."
                sh '''
                    docker --version
                    docker buildx version
                    git --version
                '''
            }
        }

        stage('2. Build Docker Images') {
            parallel {
                stage('Build API Image') {
                    steps {
                        echo "Building Backend Image: ${API_IMAGE}:${IMAGE_TAG}"
                        sh '''
                            DOCKER_BUILDKIT=1 docker build \
                                --target backend \
                                -f Dockerfile \
                                -t "${API_IMAGE}:${IMAGE_TAG}" \
                                -t "${API_IMAGE}:latest" \
                                .
                        '''
                    }
                }
                stage('Build UI Image') {
                    steps {
                        echo "Building Frontend Image: ${UI_IMAGE}:${IMAGE_TAG}"
                        sh '''
                            DOCKER_BUILDKIT=1 docker build \
                                --target frontend \
                                -f Dockerfile \
                                -t "${UI_IMAGE}:${IMAGE_TAG}" \
                                -t "${UI_IMAGE}:latest" \
                                .
                        '''
                    }
                }
            }
        }

        stage('3. Automated Testing') {
            when {
                expression { return params.RUN_TESTS }
            }
            parallel {
                stage('Test Backend (FastAPI)') {
                    steps {
                        sh '''
                            mkdir -p reports
                            CID=$(docker create "${API_IMAGE}:${IMAGE_TAG}" sh -c \
                                "mkdir -p /app/reports && uv pip install --system --no-cache -q pytest pytest-asyncio && timeout 120 pytest tests/contract --ignore=tests/contract/test_chat_api_contract.py --ignore=tests/contract/test_documents_project_api.py -k 'not test_chat_allows_authorized_project_selection' --junitxml=/app/reports/junit.xml -q")
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
                stage('Test Frontend (Streamlit)') {
                    steps {
                        sh '''
                            docker run --rm "${UI_IMAGE}:${IMAGE_TAG}" \
                                python -c "import streamlit, py_compile; py_compile.compile('streamlit_app/app.py', doraise=True); print('UI OK:', streamlit.__version__)"
                        '''
                    }
                }
            }
        }

        stage('4. Push to Google Artifact Registry') {
            when {
                expression { return params.DEPLOY_TARGET == 'gcp' }
            }
            steps {
                withCredentials([file(credentialsId: "${GCP_CREDS_ID}", variable: 'GCP_KEY')]) {
                    sh '''
                        echo "Authenticating with Google Artifact Registry..."
                        cat "$GCP_KEY" | docker login -u _json_key --password-stdin "https://${GAR_REGION}-docker.pkg.dev"

                        echo "Pushing images..."
                        docker push "${API_IMAGE}:${IMAGE_TAG}"
                        docker push "${API_IMAGE}:latest"
                        docker push "${UI_IMAGE}:${IMAGE_TAG}"
                        docker push "${UI_IMAGE}:latest"
                    '''
                }
            }
        }

        stage('5. Trigger Argo CD (Update GitOps Manifests)') {
            when {
                expression { return params.UPDATE_GITOPS }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${GIT_CREDS_ID}",
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PAT'
                )]) {
                    sh '''
                        ASKPASS_SCRIPT=$(mktemp)
                        cat > "$ASKPASS_SCRIPT" << 'EOF'
#!/bin/sh
case "$1" in
    *Username*) echo "$GIT_USER" ;;
    *Password*) echo "$GIT_PAT" ;;
esac
EOF
                        chmod +x "$ASKPASS_SCRIPT"

                        if [ -n "$GITOPS_REPO" ]; then
                            GIT_ASKPASS="$ASKPASS_SCRIPT" GIT_TERMINAL_PROMPT=0 git clone "https://${GITOPS_REPO}" gitops-workspace
                            cd gitops-workspace
                            TARGET_BRANCH="main"
                        else
                            TARGET_BRANCH="$BRANCH_CLEAN"
                        fi

                        echo "Updating Kubernetes manifests with image tag ${IMAGE_TAG}..."
                        sed -i "s|image: .*knowlayer-api:.*|image: ${API_IMAGE}:${IMAGE_TAG}|g" k8s/backend-deployment.yaml
                        sed -i "s|image: .*knowlayer-ui:.*|image: ${UI_IMAGE}:${IMAGE_TAG}|g" k8s/frontend-deployment.yaml

                        git config user.name "Jenkins Automation"
                        git config user.email "jenkins@company_bot.internal"
                        git add k8s/backend-deployment.yaml k8s/frontend-deployment.yaml

                        if ! git diff --cached --quiet; then
                            git commit -m "chore: deploy Company_Bot ${IMAGE_TAG} [skip ci]"
                            GIT_ASKPASS="$ASKPASS_SCRIPT" GIT_TERMINAL_PROMPT=0 git push origin "HEAD:${TARGET_BRANCH}"
                        else
                            echo "No manifest changes to commit."
                        fi
                        rm -f "$ASKPASS_SCRIPT"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                if [ "${DEPLOY_TARGET:-local}" = "gcp" ]; then
                    docker rmi "${API_IMAGE}:${IMAGE_TAG}" "${UI_IMAGE}:${IMAGE_TAG}" || true
                    docker logout "https://${GAR_REGION}-docker.pkg.dev" || true
                fi
            '''
            cleanWs()
        }
        success {
            echo "Build #${BUILD_NUMBER} succeeded (${IMAGE_TAG}). Argo CD is syncing!"
        }
        failure {
            echo "Build #${BUILD_NUMBER} failed. Check console logs."
        }
    }
}
