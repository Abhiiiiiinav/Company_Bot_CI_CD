#!/bin/bash
set -e

# 1. Generate SSH keypair for Jenkins
if [ ! -f test_deploy_key ]; then
    ssh-keygen -t ed25519 -f test_deploy_key -C "jenkins-deploy" -N ""
fi

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

echo "=== EXTERNAL IP ==="
gcloud compute instances describe test-vm --zone=asia-south1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
echo "=== PRIVATE SSH KEY ==="
cat test_deploy_key
