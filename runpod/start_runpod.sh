#!/bin/bash
# ============================================================
#  start_runpod.sh  –  RunPod container entry point
#  Nginx routes all three services through port 3000:
#    /          → ComfyUI  (8188)
#    /files/    → FileBrowser (8189)
#    /jupyter/  → JupyterLab (8888)
# ============================================================

set +e

# ── Nginx ─────────────────────────────────────────────────────────────────────
echo "[RunPod] Starting Nginx on port 3000 ..."
nginx

# ── FileBrowser ───────────────────────────────────────────────────────────────
FB_DB=/workspace/.filebrowser.db
rm -f "$FB_DB"
filebrowser config init --database "$FB_DB"
filebrowser config set --database "$FB_DB" \
    --address 127.0.0.1 --port 8189 \
    --root /workspace --log stdout \
    --auth.method=noauth
filebrowser users add admin admin --perm.admin --database "$FB_DB" 2>/dev/null || true
echo "[RunPod] Starting FileBrowser on port 8189 ..."
filebrowser --database "$FB_DB" &

# ── JupyterLab ────────────────────────────────────────────────────────────────
echo "[RunPod] Starting JupyterLab on port 8888 ..."
jupyter lab \
    --ip=127.0.0.1 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --notebook-dir=/workspace \
    --ServerApp.base_url=/jupyter \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.disable_check_xsrf=True &

# ── Model download ────────────────────────────────────────────────────────────
echo "[RunPod] Checking / downloading models ..."
bash /workspace/download_models.sh

# ── ComfyUI ───────────────────────────────────────────────────────────────────
echo "[RunPod] Starting ComfyUI on port 8188 ..."
cd /workspace/comfyui
python3 main.py \
    --listen 127.0.0.1 \
    --port 8188 \
    --output-directory /workspace/outputs \
    --input-directory /workspace/inputs \
    --enable-cors-header "*"
