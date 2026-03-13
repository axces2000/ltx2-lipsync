#!/bin/bash
# ============================================================
#  start.sh  –  Container entry point
# ============================================================

set +e

# ── GPU verification ──────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo "  GPU CHECK"
echo "======================================================"
nvidia-smi || echo "[WARN] nvidia-smi not available - GPU may not be passed through!"
echo ""
python3 - << 'EOF'
import torch
print(f"  PyTorch version : {torch.__version__}")
print(f"  CUDA available  : {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"  CUDA version    : {torch.version.cuda}")
    print(f"  GPU name        : {torch.cuda.get_device_name(0)}")
    print(f"  VRAM total      : {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
    print(f"  GPU count       : {torch.cuda.device_count()}")
else:
    print("  [ERROR] CUDA is NOT available - ComfyUI will run on CPU!")
    print("  Check that 'runtime: nvidia' is set in docker-compose.yml")
    print("  and that NVIDIA Container Toolkit is installed on the host.")
EOF
echo "======================================================"
echo ""

# ── FileBrowser setup ─────────────────────────────────────────────────────────
FB_DB=/workspace/.filebrowser.db

echo "[start.sh] Initialising FileBrowser database ..."
rm -f "$FB_DB"
filebrowser config init --database "$FB_DB"
filebrowser config set \
    --database "$FB_DB" \
    --address 0.0.0.0 \
    --port 8189 \
    --root /workspace \
    --log stdout \
    --auth.method=noauth
filebrowser users add admin admin --perm.admin --database "$FB_DB" 2>/dev/null || true

echo "[start.sh] Launching FileBrowser on port 8189 ..."
filebrowser --database "$FB_DB" &

# ── JupyterLab ────────────────────────────────────────────────────────────────
echo "[start.sh] Launching JupyterLab on port 8888 ..."
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --notebook-dir=/workspace \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*' &

# ── Model download ────────────────────────────────────────────────────────────
echo "[start.sh] Checking / downloading models ..."
bash /workspace/download_models.sh

# ── Check if flash-attn is available ─────────────────────────────────────────
FLASH_ATTN_FLAG=""
if python3 -c "import flash_attn" 2>/dev/null; then
    echo "[start.sh] flash-attn detected, enabling"
    FLASH_ATTN_FLAG="--use-flash-attention"
else
    echo "[start.sh] flash-attn not available, using default attention"
fi

# ── ComfyUI ───────────────────────────────────────────────────────────────────
echo "[start.sh] Starting ComfyUI on port 8188 ..."
cd /workspace/comfyui
python3 main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --output-directory /workspace/outputs \
    --input-directory /workspace/inputs \
    --enable-cors-header "*" \
    --lowvram \
    $FLASH_ATTN_FLAG
