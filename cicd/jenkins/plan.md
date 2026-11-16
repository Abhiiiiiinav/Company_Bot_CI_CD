**TL;DR:** Since Abhinav already knows Jenkins, let him own the entire **Jenkins environment, credentials, and `Jenkinsfile.app` pipeline logic**, while you own the **GCP `test-vm` provisioning (using Google Cloud Shell to bypass your local WSL2 issue), GHCR access token, and `docker-compose.yml` alignment**. Work in parallel for the first 25 minutes, hand him 3 values (`TEST_VM_IP`, `test_deploy_key`, and `GHCR_TOKEN`), and run the end-to-end deployment test together in the remaining 35 minutes.

---

**Your Track (Akaash): GCP Test-VM, GHCR Token & Docker Compose**

1. **Generate the GitHub Container Registry (GHCR) Token (5 mins)**
* Go to GitHub -> **Settings** -> **Developer settings** -> **Personal access tokens** -> **Tokens (classic)** -> **Generate new token (classic)**.
* Select scopes: **`write:packages`**, **`read:packages`**, **`delete:packages`**, and **`repo`**.
* Copy the `ghp_...` token and save it for Abhinav.


2. **Spin Up `test-vm` in Google Cloud Shell (10 mins)**
* Open [Google Cloud Console](https://console.cloud.google.com/) and click the **Activate Cloud Shell** (`>_`) icon at the top right (zero local WSL setup needed).
* Run this block to generate the SSH key, create the startup script, open ports, and boot `test-vm`:
```bash
# 1. Generate SSH keypair for Jenkins
ssh-keygen -t ed25519 -f test_deploy_key -C "jenkins-deploy" -N ""

# 2. Create startup script (Installs Docker & creates persistent /data folders)
cat << 'EOF' > app-startup.sh
#!/bin/bash
apt-get update && apt-get install -y ca-certificates curl
curl -fsSL https://get.docker.com | sh
usermod -aG docker jenkins-deploy
mkdir -p /data/sqlite /data/chroma /data/hf_cache /data/uploads
chmod -R 777 /data
EOF

# 3. Allow SSH (22), FastAPI (8000), and Streamlit (8501)
gcloud compute firewall-rules create allow-app-ports \
    --allow=tcp:22,tcp:8000,tcp:8501 \
    --target-tags=app-server || true

# 4. Boot test-vm
gcloud compute instances create test-vm \
    --zone=asia-south1-a \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB \
    --tags=app-server \
    --metadata="ssh-keys=jenkins-deploy:$(cat test_deploy_key.pub)" \
    --metadata-from-file=startup-script=app-startup.sh

```




3. **Extract & Send 3 Items to Abhinav (2 mins)**
* Run these two commands in Cloud Shell and send the outputs + your GHCR token to Abhinav:
```bash
# 1. Get External IP
gcloud compute instances describe test-vm --zone=asia-south1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)'

# 2. Print Private SSH Key (Copy everything including BEGIN and END lines)
cat test_deploy_key

```




4. **Finalize `docker-compose.yml` in the Repo (8 mins)**
* Make sure `docker-compose.yml` at the root of your repo uses lowercase `ghcr.io/<github-owner>/...` image tags and mounts `/data/*`:
```yaml
services:
  backend:
    image: ghcr.io/<your_lowercase_github_owner>/knowlayer-backend:latest
    build:
      context: ./app
    container_name: knowlayer-backend
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - /data/sqlite:/data/sqlite
      - /data/chroma:/data/chroma
      - /data/hf_cache:/root/.cache/huggingface
      - /data/uploads:/data/uploads

  frontend:
    image: ghcr.io/<your_lowercase_github_owner>/knowlayer-frontend:latest
    build:
      context: ./frontend
    container_name: knowlayer-frontend
    restart: unless-stopped
    ports:
      - "8501:8501"
    environment:
      - BACKEND_URL=http://backend:8000
    depends_on:
      - backend

```




5. **Lifecycle Commands (Stop / Start / Destroy `test-vm`)**
* **Stop when done today (saves $300 credit, keeps `/data` disk):**
```bash
gcloud compute instances stop test-vm --zone=asia-south1-a

```


* **Destroy on Monday when switching to production `app-vm`:**
```bash
gcloud compute instances delete test-vm --zone=asia-south1-a --quiet

```





---

**Abhinav's Track: Jenkins Credentials & Pipeline 2 (`Jenkinsfile.app`)**

1. **Add the 2 Credentials in Jenkins UI (5 mins)**
* Go to **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials** -> **Add Credentials**:
* **Credential 1 (GHCR):** Kind = `Username with password` | Username = `<lowercase-github-username>` | Password = `<GHCR_TOKEN Akaash from>` | ID = **`ghcr-creds`**.
* **Credential 2 (SSH Key):** Kind = `SSH Username with private key` | ID = **`vm-ssh-key`** | Username = **`jenkins-deploy`** | Private Key = Paste `test_deploy_key` from Akaash.




2. **Adapt His Existing `Jenkinsfile` into `cicd/Jenkinsfile.app` (15 mins)**
* Ensure his pipeline uses these 4 core stages and includes the automatic file check so it works on `test-vm` today and switches to Neha & Roshan's `app-vm` on Monday without edits:
```groovy
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
                    // Uses Neha/Roshan's Terraform IP on Monday if present, else uses test-vm parameter today
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
                        docker compose build
                        docker compose push
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

```




3. **Create Pipeline Job & Trigger Test Run (10 mins)**
* Create a **Pipeline** job in Jenkins -> Select **Pipeline script from SCM** -> Git -> Point **Script Path** to `cicd/Jenkinsfile.app`.
* Click **Build with Parameters**, enter `TEST_VM_IP` from Akaash, and verify `http://<TEST_VM_IP>:8501` and `http://<TEST_VM_IP>:8000/docs` load in the browser.



---

**Joint Checklist for You & Abhinav**

---

**2 Quick Limitations to Keep in Mind:**

* **Abhinav's Local Jenkins Environment:** If Abhinav is running Jenkins on Windows natively (not in Docker/WSL), replace `sh '''` with `bat '''` only if necessary—or ideally run his local Jenkins inside Docker/WSL2 so the Linux `sh`, `scp`, and `ssh` commands match the cloud `ci-vm` 100%.
* **Wait 90 Seconds After Creating `test-vm`:** Give `app-startup.sh` about 90 seconds to finish installing Docker on `test-vm` before Abhinav triggers Stage 4 (`SSH Deploy`).