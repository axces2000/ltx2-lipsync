# LTX-2 LipSync – Docker Setup Guide
## For Windows 11 + RTX 3060 (12 GB) → RunPod deployment

---

## What this package contains

| File | Purpose |
|---|---|
| `Dockerfile` | Main image: ComfyUI + Manager + all custom nodes |
| `Dockerfile.runpod` | RunPod variant (adds Nginx proxy + JupyterLab) |
| `docker-compose.yml` | Local testing on your Windows machine |
| `scripts/download_models.sh` | Downloads all 6 required model files on first boot |
| `scripts/start.sh` | Container entry point (local) |
| `runpod/start_runpod.sh` | Container entry point (RunPod) |
| `runpod/nginx.conf` | Reverse proxy config for RunPod |
| `workflow/LTX2_LipSync.json` | Your workflow, auto-installed into ComfyUI |

### Models downloaded automatically (~40 GB total)

| File | Location in ComfyUI |
|---|---|
| `ltx-2-19b-distilled-fp8.safetensors` | `models/checkpoints/` |
| `LTX2_video_vae_bf16.safetensors` | `models/vae/` |
| `ltx-av-step-1751000_vocoder_24K.safetensors` | `models/checkpoints/` |
| `gemma_3_12B_it_fp8_e4m3fn.safetensors` | `models/clip/` |
| `ltx-2-19b-embeddings_connector_dev_bf16.safetensors` | `models/clip/` |
| `ltx-2-19b-distilled-lora-384.safetensors` | `models/loras/` |

---

## PART 1 – Local Testing on Windows 11 + RTX 3060

### Prerequisites (one-time setup)

**1. Enable WSL2 (if not already done)**
Open PowerShell as Administrator and run:
```powershell
wsl --install
wsl --set-default-version 2
```
Restart your PC when prompted.

**2. Install NVIDIA Container Toolkit**
This lets Docker talk to your GPU.
- Download and install the latest NVIDIA driver from https://www.nvidia.com/drivers
- Then in PowerShell:
```powershell
# Verify GPU is visible
nvidia-smi
```
You should see your RTX 3060 listed.

**3. Enable GPU in Docker Desktop**
- Open Docker Desktop → Settings → Resources → WSL Integration
- Enable integration for your WSL2 distro
- Settings → General → make sure "Use WSL 2 based engine" is checked
- Apply & Restart

**4. Verify Docker can see the GPU**
```powershell
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```
You should see your RTX 3060 in the output. If this works, you're ready.

---

### Step 1 – Copy this folder to your PC

Put the entire `ltx2-lipsync/` folder somewhere easy, e.g.:
```
C:\Users\YourName\ltx2-lipsync\
```

### Step 2 – Open a terminal in that folder

In Windows Explorer, navigate to the folder, then:
- Hold Shift and right-click in empty space
- Select "Open PowerShell window here"

### Step 3 – Build the Docker image

This downloads and installs everything. It will take **20–40 minutes** on first run depending on your internet speed.

```powershell
docker compose build
```

Watch the output scroll. Common things you'll see:
- Layers being downloaded (FROM nvidia/cuda...)
- Python packages being installed
- Custom nodes being git-cloned

If you see a red error, check the [Troubleshooting](#troubleshooting) section below.

### Step 4 – Start the container

```powershell
docker compose up
```

On **first launch**, the container will:
1. Start FileBrowser immediately (port 8189)
2. Download all 6 model files (~40 GB total) — **this takes a while**
3. Start ComfyUI after all models are downloaded (port 8188)

You'll see progress in the terminal like:
```
[DOWNLOAD] ltx-2-19b-distilled-fp8.safetensors
[OK] ltx-2-19b-distilled-fp8.safetensors
...
[start.sh] Starting ComfyUI on port 8188 ...
```

On **subsequent launches**, models already exist so it skips straight to ComfyUI.

### Step 5 – Open the interfaces

Once ComfyUI says `To see the GUI go to: http://0.0.0.0:8188`:

| Interface | URL | Purpose |
|---|---|---|
| **ComfyUI** | http://localhost:8188 | Run your LTX-2 LipSync workflow |
| **FileBrowser** | http://localhost:8189 | Upload/download files (audio, images, videos) |

### Step 6 – Load the workflow

1. Open http://localhost:8188
2. Click the **☰ menu** (top right) → **Workflows**
3. You should see **LTX2_LipSync** already listed — click it to load
4. If it doesn't appear, drag-and-drop `workflow/LTX2_LipSync.json` onto the ComfyUI canvas

### Step 7 – Test a generation

1. In FileBrowser (http://localhost:8189), navigate to `/workspace/inputs/`
2. Upload a reference image and an audio file (.wav or .mp3)
3. In ComfyUI, point the **LoadImage** node to your image and the **AudioLoader** node to your audio
4. Click **Queue Prompt**
5. Output videos appear in `/workspace/outputs/` (visible in FileBrowser)

### Stop the container

```powershell
# Stop but keep all data
docker compose down

# Start again
docker compose up
```

Your models and outputs are stored in Docker **named volumes** — they persist even if you remove the container.

---

## PART 2 – Publishing to RunPod

### Step 1 – Push your image to Docker Hub

First, create a free account at https://hub.docker.com

```powershell
# Log in
docker login

# Tag the image with your Docker Hub username
docker tag ltx2-lipsync:local YOURUSERNAME/ltx2-lipsync:latest

# Push (this uploads the image — several GB, takes time)
docker push YOURUSERNAME/ltx2-lipsync:latest
```

### Step 2 – Build the RunPod variant

The RunPod image adds an Nginx proxy (required because RunPod only exposes one HTTP port):

```powershell
# Build using the RunPod Dockerfile (builds ON TOP of the local image)
docker build -f Dockerfile.runpod -t YOURUSERNAME/ltx2-lipsync:runpod .
docker push YOURUSERNAME/ltx2-lipsync:runpod
```

### Step 3 – Create a RunPod template

1. Go to https://runpod.io → **Templates** → **New Template**
2. Fill in:
   - **Template Name**: LTX-2 LipSync
   - **Container Image**: `YOURUSERNAME/ltx2-lipsync:runpod`
   - **Container Disk**: 20 GB (for OS + ComfyUI + custom nodes)
   - **Volume Disk**: 60 GB (for models — mounted at `/workspace/comfyui/models`)
   - **Volume Mount Path**: `/workspace/comfyui/models`
   - **Expose HTTP Ports**: `3000` (Nginx proxy — ComfyUI is served here)
   - **Expose TCP Ports**: leave blank
3. Click **Save Template**

### Step 4 – Launch a pod

1. **GPU Pods** → **Deploy**
2. Choose GPU: **RTX 3090 / 4090 / A100** recommended for 19B model
   - RTX 3090 24 GB: good balance of cost and VRAM
   - A100 40 GB: fastest, most expensive
3. Select your template
4. Set volume size to **60 GB**
5. Click **Deploy**

### Step 5 – Access RunPod interfaces

Once the pod shows **Running**, click **Connect**:

| Interface | How to access |
|---|---|
| **ComfyUI** | Click "Connect to HTTP Service [3000]" — goes directly to ComfyUI |
| **FileBrowser** | Append `/files/` to the pod URL |
| **JupyterLab** | Append `/jupyter/` to the pod URL |

Example: if your pod URL is `https://abc123-3000.proxy.runpod.net`, then:
- ComfyUI → `https://abc123-3000.proxy.runpod.net/`
- FileBrowser → `https://abc123-3000.proxy.runpod.net/files/`

---

## File Management

### Uploading input files (audio, images)

**Local**: Open FileBrowser at http://localhost:8189
- Navigate to `inputs/` folder
- Click the **Upload** button (cloud icon)
- Select your audio (.wav, .mp3) or image (.png, .jpg) files

**RunPod**: Same process via the `/files/` URL above.

### Downloading outputs

**Local**: Open FileBrowser → `outputs/` folder → click file → Download icon

**RunPod**: Same via `/files/` → `outputs/`

### Persistent storage on RunPod

The volume at `/workspace/comfyui/models` persists between pod restarts. **Outputs and inputs do NOT persist** unless you also attach a volume for those paths. To avoid losing outputs:
- Download them via FileBrowser before stopping the pod, OR
- In your RunPod template, add another volume at `/workspace/outputs`

---

## Troubleshooting

### "docker: Error response from daemon: could not select device driver"
→ NVIDIA Container Toolkit is not properly installed or Docker Desktop GPU support is not enabled.
→ Re-check the Prerequisites section above.

### Build fails at a `pip install` step
→ This sometimes happens due to temporary network issues.
→ Run `docker compose build` again — Docker caches completed layers so it resumes from the failure point.

### ComfyUI starts but nodes show as "red" (missing)
→ A custom node failed to install. Open ComfyUI Manager (click Manager button in ComfyUI) → **Install Missing Custom Nodes** → restart.

### Models fail to download
→ Some LTX-2 models may require a HuggingFace account. If you see 401/403 errors:
1. Create an account at https://huggingface.co
2. Generate a token at https://huggingface.co/settings/tokens
3. Add it to `docker-compose.yml` under `environment:`:
   ```yaml
   - HF_TOKEN=hf_your_token_here
   ```
4. Modify `download_models.sh` to include the header:
   ```bash
   aria2c --header="Authorization: Bearer $HF_TOKEN" ...
   ```

### "Out of memory" errors during generation
→ The RTX 3060 12 GB is tight for the 19B model. Try:
- In ComfyUI: reduce batch size to 1
- Reduce resolution (e.g., 512×512)
- Use the distilled fp8 model (already configured)
- Add `--lowvram` to ComfyUI args in `scripts/start.sh`

### Outputs folder is empty
→ Check that the `VHS_VideoCombine` node has `save_output` set to `true` in the workflow.

---

## Updating ComfyUI or custom nodes

```powershell
# Rebuild from scratch (re-pulls latest git repos)
docker compose build --no-cache
```

Or inside a running container:
```powershell
docker exec -it ltx2-lipsync bash
cd /workspace/comfyui
git pull
cd custom_nodes/ComfyUI-LTXVideo && git pull
```

---

## Cost estimate on RunPod

| GPU | VRAM | Approx. cost | Notes |
|---|---|---|---|
| RTX 3090 | 24 GB | ~$0.44/hr | Good for this workflow |
| RTX 4090 | 24 GB | ~$0.74/hr | Faster generation |
| A100 SXM | 80 GB | ~$2.49/hr | Maximum speed |

Models download once to the volume (~40 GB). After that, pod starts in ~2 minutes.
