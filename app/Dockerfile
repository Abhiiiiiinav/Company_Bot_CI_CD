# ==============================================================================
# KnowLayer Backend Service Dockerfile (FastAPI Modular Monolith)
# ==============================================================================
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace

WORKDIR /workspace

# Install system build dependencies required by ChromaDB, SQLite, OpenCV, and Docling
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libgl1 \
    libglib2.0-0 \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast, reliable package installations
RUN pip install --no-cache-dir uv

# Pre-install PyTorch CPU wheel explicitly (avoids multi-gigabyte CUDA downloads)
RUN uv pip install --system --no-cache --extra-index-url https://download.pytorch.org/whl/cpu "torch>=2.2"

# Install Python backend dependencies from requirements.txt
COPY requirements.txt .
RUN uv pip install --system --no-cache --index-strategy unsafe-best-match --extra-index-url https://download.pytorch.org/whl/cpu -r requirements.txt

# Create internal mount points for persistent storage and model caching
RUN mkdir -p /data/sqlite /data/chroma /data/uploads /root/.cache/huggingface /workspace/data /workspace/input

# Copy application package into /workspace/app
COPY . /workspace/app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
