#!/bin/bash
# ============================================================
#  download_models.sh
#  Forces ALL huggingface cache to the volume (/workspace)
#  to avoid filling the container disk on RunPod.
# ============================================================

set +e

COMFY=/workspace/comfyui/models

# ── Force HF cache onto the volume, never /tmp or ~ ──────────────────────────
export HF_HOME=/workspace/.hf_cache
export HUGGINGFACE_HUB_CACHE=/workspace/.hf_cache
export XDG_CACHE_HOME=/workspace/.cache
mkdir -p /workspace/.hf_cache
mkdir -p /workspace/.cache

# ── Size validation ───────────────────────────────────────────────────────────
declare -A MIN_SIZES
MIN_SIZES["ltx-2-19b-distilled-fp8.safetensors"]=10000000000
MIN_SIZES["LTX2_video_vae_bf16.safetensors"]=100000000
MIN_SIZES["LTX2_audio_vae_bf16.safetensors"]=100000000
MIN_SIZES["gemma_3_12B_it_fp8_e4m3fn.safetensors"]=5000000000
MIN_SIZES["ltx-2-19b-embeddings_connector_dev_bf16.safetensors"]=50000000
MIN_SIZES["ltx-2-19b-distilled-lora-384.safetensors"]=50000000
MIN_SIZES["ltx-2-spatial-upscaler-x2-1.0.safetensors"]=10000000
MIN_SIZES["seedvr2_ema_3b-Q4_K_M.gguf"]=1000000000
MIN_SIZES["ema_vae_fp16.safetensors"]=100000000

is_file_valid() {
    local filepath="$1"
    local filename
    filename="$(basename "$filepath")"
    local min_size="${MIN_SIZES[$filename]}"
    if [ ! -f "$filepath" ]; then return 1; fi
    if [ -n "$min_size" ]; then
        local actual_size
        actual_size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
        if [ "$actual_size" -lt "$min_size" ]; then
            echo "[WARN] $filename too small (${actual_size} bytes) - corrupted, re-downloading"
            rm -f "$filepath"
            return 1
        fi
    fi
    return 0
}

# ── HuggingFace download with cache forced to volume ─────────────────────────
hf_download() {
    local repo="$1"
    local filename="$2"
    local dest_dir="$3"
    local subfolder="$4"   # optional

    local dest="$dest_dir/$filename"

    if is_file_valid "$dest"; then
        echo "[SKIP] Already exists and valid: $filename"
        return 0
    fi

    echo "[DOWNLOAD] $filename  (from $repo)"
    mkdir -p "$dest_dir"

    local hf_filename="$filename"
    if [ -n "$subfolder" ]; then
        hf_filename="$subfolder/$filename"
    fi

    python3 - <<EOF
import os, shutil

# Force cache to volume before importing huggingface_hub
os.environ["HF_HOME"] = "/workspace/.hf_cache"
os.environ["HUGGINGFACE_HUB_CACHE"] = "/workspace/.hf_cache"

from huggingface_hub import hf_hub_download

dest_dir = "$dest_dir"
dest = "$dest"
os.makedirs(dest_dir, exist_ok=True)

try:
    path = hf_hub_download(
        repo_id="$repo",
        filename="$hf_filename",
        local_dir=dest_dir,
    )
    # If placed in subfolder, move to dest_dir root
    if path != dest and os.path.exists(path):
        shutil.move(path, dest)
        # Clean up empty subfolder
        subdir = os.path.join(dest_dir, "$subfolder") if "$subfolder" else None
        if subdir and os.path.isdir(subdir):
            try: os.rmdir(subdir)
            except: pass
    print(f"Saved to {dest}")
except Exception as e:
    print(f"ERROR: {e}")
    raise
EOF

    if is_file_valid "$dest"; then
        echo "[OK] $filename"
    else
        echo "[ERROR] $filename download failed or file invalid"
    fi
}

# ── Direct URL download ───────────────────────────────────────────────────────
url_download() {
    local dest="$1"
    local url="$2"

    if is_file_valid "$dest"; then
        echo "[SKIP] Already exists and valid: $(basename $dest)"
        return 0
    fi

    echo "[DOWNLOAD] $(basename $dest)  (direct URL)"
    mkdir -p "$(dirname $dest)"
    rm -f "$dest"

    python3 - <<EOF
import urllib.request, os, sys

url = "$url"
dest = "$dest"

def progress(count, block_size, total_size):
    if total_size > 0:
        pct = min(count * block_size * 100 // total_size, 100)
        sys.stdout.write(f"\r  {pct}%")
        sys.stdout.flush()

try:
    urllib.request.urlretrieve(url, dest, reporthook=progress)
    print(f"\n  Saved to {dest}")
except Exception as e:
    print(f"\n  ERROR: {e}")
    sys.exit(1)
EOF

    if is_file_valid "$dest"; then
        echo "[OK] $(basename $dest)"
    else
        echo "[ERROR] $(basename $dest) download failed or file invalid"
    fi
}

echo "======================================================"
echo "  LTX-2 + SeedVR2 - Model download starting"
echo "  HF cache → /workspace/.hf_cache (on volume)"
echo "======================================================"

echo ""
echo "Disk space:"
df -h /workspace
echo ""

# ── LTX-2 models ─────────────────────────────────────────────────────────────
echo "--- LTX-2 Models ---"

hf_download "Lightricks/LTX-2" \
    "ltx-2-19b-distilled-fp8.safetensors" \
    "$COMFY/checkpoints"

hf_download "Kijai/LTXV2_comfy" \
    "LTX2_video_vae_bf16.safetensors" \
    "$COMFY/vae" "VAE"

hf_download "Kijai/LTXV2_comfy" \
    "LTX2_audio_vae_bf16.safetensors" \
    "$COMFY/vae" "VAE"

hf_download "GitMylo/LTX-2-comfy_gemma_fp8_e4m3fn" \
    "gemma_3_12B_it_fp8_e4m3fn.safetensors" \
    "$COMFY/clip"

hf_download "Kijai/LTXV2_comfy" \
    "ltx-2-19b-embeddings_connector_dev_bf16.safetensors" \
    "$COMFY/clip" "text_encoders"

hf_download "Lightricks/LTX-2" \
    "ltx-2-19b-distilled-lora-384.safetensors" \
    "$COMFY/loras"

hf_download "Lightricks/LTX-2" \
    "ltx-2-spatial-upscaler-x2-1.0.safetensors" \
    "$COMFY/latent_upscale_models"

# ── SeedVR2 models ────────────────────────────────────────────────────────────
echo ""
echo "--- SeedVR2 Models ---"

url_download \
    "$COMFY/SEEDVR2/seedvr2_ema_3b-Q4_K_M.gguf" \
    "https://huggingface.co/cmeka/SeedVR2-GGUF/resolve/main/seedvr2_ema_3b-Q4_K_M.gguf"

url_download \
    "$COMFY/SEEDVR2/ema_vae_fp16.safetensors" \
    "https://huggingface.co/hoveyc/comfyui-models/resolve/20989ff62115cbc0bb8c9b74ba5a734b2cdccfc1/SEEDVR2/ema_vae_fp16.safetensors"

# ── Clean up HF cache after successful downloads ──────────────────────────────
echo ""
echo "Cleaning HF cache..."
rm -rf /workspace/.hf_cache
echo "Done."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo "  Download summary:"
for f in \
    "$COMFY/checkpoints/ltx-2-19b-distilled-fp8.safetensors" \
    "$COMFY/vae/LTX2_video_vae_bf16.safetensors" \
    "$COMFY/vae/LTX2_audio_vae_bf16.safetensors" \
    "$COMFY/clip/gemma_3_12B_it_fp8_e4m3fn.safetensors" \
    "$COMFY/clip/ltx-2-19b-embeddings_connector_dev_bf16.safetensors" \
    "$COMFY/loras/ltx-2-19b-distilled-lora-384.safetensors" \
    "$COMFY/latent_upscale_models/ltx-2-spatial-upscaler-x2-1.0.safetensors" \
    "$COMFY/SEEDVR2/seedvr2_ema_3b-Q4_K_M.gguf" \
    "$COMFY/SEEDVR2/ema_vae_fp16.safetensors"; do
    if [ -f "$f" ]; then
        size=$(du -sh "$f" 2>/dev/null | cut -f1)
        echo "  [OK]      $(basename $f) ($size)"
    else
        echo "  [MISSING] $(basename $f)"
    fi
done
echo "======================================================"
