FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV TORCH_CUDA_ARCH_LIST="8.6"
ENV MAX_JOBS=4

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    python3.11 python3.11-venv python3-pip python3.11-dev \
    git git-lfs wget curl ffmpeg libgl1 libglib2.0-0 \
    libsm6 libxext6 libxrender-dev libgomp1 \
    aria2 unzip nano build-essential ninja-build && \
    git lfs install && \
    ln -sf /usr/bin/python3.11 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.11 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

# ── Python base packages ──────────────────────────────────────────────────────
RUN pip3 install --upgrade pip setuptools wheel packaging

# ── PyTorch with CUDA 12.8 ────────────────────────────────────────────────────
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# ── flash-attn via pre-built wheel (no compilation needed) ───────────────────
RUN pip3 install \
    https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.0.0/flash_attn-2.8.3+cu128torch2.10-cp311-cp311-linux_x86_64.whl \
    || pip3 install \
    https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.0.0/flash_attn-2.7.4+cu128torch2.7-cp311-cp311-linux_x86_64.whl \
    || echo "flash-attn wheel not found - ComfyUI will use default attention"

# ── JupyterLab ────────────────────────────────────────────────────────────────
RUN pip3 install jupyterlab ipywidgets jupyterlab-widgets && \
    mkdir -p /workspace/notebooks

# ── ComfyUI ───────────────────────────────────────────────────────────────────
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git comfyui

WORKDIR /workspace/comfyui
RUN pip3 install -r requirements.txt

# ── ComfyUI Manager ───────────────────────────────────────────────────────────
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    custom_nodes/ComfyUI-Manager && \
    pip3 install -r custom_nodes/ComfyUI-Manager/requirements.txt

# ── Custom Nodes ──────────────────────────────────────────────────────────────

# 1. ComfyUI-LTXVideo (LTX-2 core nodes)
RUN git clone https://github.com/Lightricks/ComfyUI-LTXVideo.git \
    custom_nodes/ComfyUI-LTXVideo && \
    pip3 install -r custom_nodes/ComfyUI-LTXVideo/requirements.txt

# 2. ComfyUI-GGUF (DualCLIPLoaderGGUF)
RUN git clone https://github.com/city96/ComfyUI-GGUF.git \
    custom_nodes/ComfyUI-GGUF && \
    pip3 install -r custom_nodes/ComfyUI-GGUF/requirements.txt

# 3. ComfyUI-VideoHelperSuite (VHS_VideoCombine, VHS_LoadVideo, VHS_VideoInfo)
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    custom_nodes/ComfyUI-VideoHelperSuite && \
    pip3 install -r custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt

# 4. ComfyUI-KJNodes (PathchSageAttentionKJ)
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    custom_nodes/ComfyUI-KJNodes && \
    pip3 install -r custom_nodes/ComfyUI-KJNodes/requirements.txt

# 5. ComfyUI-Custom-Scripts (MathExpression, MarkdownNote)
RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git \
    custom_nodes/ComfyUI-Custom-Scripts

# 6. ComfyUI-WanVideoWrapper (NormalizeAudioLoudness)
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git \
    custom_nodes/ComfyUI-WanVideoWrapper && \
    pip3 install -r custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt || true

# 7. audio-separation-nodes-comfyui (AudioSeparation)
RUN git clone https://github.com/christian-byrne/audio-separation-nodes-comfyui.git \
    custom_nodes/audio-separation-nodes-comfyui && \
    pip3 install librosa==0.10.2 numpy moviepy || true

# 8. comfyui-axces2000 (AudioLoader + GetNode/SetNode)
RUN git clone https://github.com/axces2000/comfyui-axces2000.git \
    custom_nodes/comfyui-axces2000 && \
    pip3 install -r custom_nodes/comfyui-axces2000/requirements.txt 2>/dev/null || true

# 9. rgthree (Label, Image Comparer)
RUN git clone https://github.com/rgthree/rgthree-comfy.git \
    custom_nodes/rgthree-comfy && \
    pip3 install -r custom_nodes/rgthree-comfy/requirements.txt 2>/dev/null || true

# 10. ComfyMath (CM_FloatToInt)
RUN git clone https://github.com/evanspearman/ComfyMath.git \
    custom_nodes/ComfyMath && \
    pip3 install -r custom_nodes/ComfyMath/requirements.txt 2>/dev/null || true

# 11. ComfyUI-Impact-Pack (ImpactExecutionOrderController)
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    custom_nodes/ComfyUI-Impact-Pack && \
    pip3 install -r custom_nodes/ComfyUI-Impact-Pack/requirements.txt 2>/dev/null || true

# 12. ComfyUI_essentials (ImageResize+ - needed by Video_Enhancer)
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git \
    custom_nodes/ComfyUI_essentials && \
    pip3 install -r custom_nodes/ComfyUI_essentials/requirements.txt 2>/dev/null || true

# 13. SeedVR2 VideoUpscaler (SeedVR2LoadDiTModel, SeedVR2LoadVAEModel, SeedVR2VideoUpscaler)
#     Must be cloned to exactly 'seedvr2_videoupscaler' to match cnr_id in workflows
RUN git clone https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git \
    custom_nodes/seedvr2_videoupscaler && \
    pip3 install -r custom_nodes/seedvr2_videoupscaler/requirements.txt || true

# ── SageAttention (optional speed boost) ─────────────────────────────────────
RUN pip3 install sageattention 2>/dev/null || echo "SageAttention skipped"

# ── Extra Python deps ─────────────────────────────────────────────────────────
RUN pip3 install \
    huggingface_hub \
    transformers \
    accelerate \
    diffusers \
    imageio imageio-ffmpeg \
    av \
    soundfile \
    librosa \
    pyloudnorm \
    gguf \
    opencv-python-headless

# ── Workflow JSONs → ComfyUI user workflows ───────────────────────────────────
RUN mkdir -p /workspace/comfyui/user/default/workflows
COPY workflow/LTX2_LipSync.json      /workspace/comfyui/user/default/workflows/LTX2_LipSync.json
COPY workflow/LTX2_I2V.json          /workspace/comfyui/user/default/workflows/LTX2_I2V.json
COPY workflow/Video_Enhancer.json    /workspace/comfyui/user/default/workflows/Video_Enhancer.json
COPY workflow/VideoUpscaler-1080.json /workspace/comfyui/user/default/workflows/VideoUpscaler-1080.json
COPY workflow/VideoUpscaler-720.json  /workspace/comfyui/user/default/workflows/VideoUpscaler-720.json
COPY workflow/Upscaler.json          /workspace/comfyui/user/default/workflows/Upscaler.json

# ── FileBrowser binary ────────────────────────────────────────────────────────
RUN wget -q https://github.com/filebrowser/filebrowser/releases/download/v2.30.0/linux-amd64-filebrowser.tar.gz \
    -O /tmp/fb.tar.gz && \
    tar -xzf /tmp/fb.tar.gz -C /usr/local/bin filebrowser && \
    chmod +x /usr/local/bin/filebrowser && \
    rm /tmp/fb.tar.gz

# ── Startup scripts ───────────────────────────────────────────────────────────
COPY scripts/download_models.sh  /workspace/download_models.sh
COPY scripts/start.sh            /workspace/start.sh
RUN chmod +x /workspace/download_models.sh /workspace/start.sh

# ── Model directories ─────────────────────────────────────────────────────────
RUN mkdir -p \
    /workspace/comfyui/models/checkpoints \
    /workspace/comfyui/models/vae \
    /workspace/comfyui/models/clip \
    /workspace/comfyui/models/loras \
    /workspace/comfyui/models/unet \
    /workspace/comfyui/models/latent_upscale_models \
    /workspace/comfyui/models/SEEDVR2 \
    /workspace/inputs \
    /workspace/outputs \
    /workspace/notebooks

WORKDIR /workspace

# ComfyUI → 8188   FileBrowser → 8189   JupyterLab → 8888
EXPOSE 8188 8189 8888

CMD ["/workspace/start.sh"]
