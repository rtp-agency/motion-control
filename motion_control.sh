#!/bin/bash

# Сначала чиним путь к ComfyUI (КРИТИЧНО для Vast.ai)
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "[Fix] ComfyUI missing in workspace. Linking..."
    rm -rf /workspace/ComfyUI
    ln -s /opt/workspace-internal/ComfyUI /workspace/ComfyUI
fi

BASE="/workspace/ComfyUI/models"

# Функция для скачивания
get() {
    local url="$1"
    local folder="$2"
    local file=$(basename "$url")

    echo ">>> Downloading: $file"
    wget -nc --show-progress "$url" -O "$folder/$file"
}

echo "===================================================="
echo " DOWNLOADING WAN 2.2 PACK + PATCHES"
echo "===================================================="


# ---------------------------------------------------------
# Diffusion models
# ---------------------------------------------------------
echo ">>> Diffusion Models..."
get "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_animate_14B_bf16.safetensors" \
    "$BASE/diffusion_models"


# ---------------------------------------------------------
# LoRAs
# ---------------------------------------------------------
echo ">>> LoRAs..."

get "https://huggingface.co/rahul7star/wan2.2Lora/resolve/main/BounceHighWan2_2.safetensors" \
    "$BASE/loras"

get "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
    "$BASE/loras"


# ---------------------------------------------------------
# VAE
# ---------------------------------------------------------
echo ">>> VAE..."
get "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "$BASE/vae"


# ---------------------------------------------------------
# CLIP Vision
# ---------------------------------------------------------
echo ">>> CLIP Vision..."
get "https://huggingface.co/laion/CLIP-ViT-H-14-laion2B-s32B-b79K/resolve/main/model.safetensors" \
    "$BASE/clip_vision"


# ---------------------------------------------------------
# Upscale model
# ---------------------------------------------------------
echo ">>> Upscale..."
get "https://huggingface.co/dtarnow/UPscaler/resolve/main/RealESRGAN_x2plus.pth" \
    "$BASE/upscale_models"

get "https://huggingface.co/WedManHK/test2/resolve/20c1bfd934423c265890d1084d548837a68b56ae/2xNomosUni_span_multijpg.pth" \
    "$BASE/upscale_models"
# ---------------------------------------------------------
# Detection models (create folder!)
# ---------------------------------------------------------
echo ">>> Creating detection folder..."
mkdir -p "$BASE/detection"

echo ">>> Detection models..."
get "https://huggingface.co/JunkyByte/easy_ViTPose/resolve/main/onnx/wholebody/vitpose-l-wholebody.onnx" \
    "$BASE/detection"

get "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" \
    "$BASE/detection"

# ---------------------------------------------------------
# Detection models (create folder!)
# ---------------------------------------------------------

get "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "$BASE/text_encoders"

# # # ---------------------------------------------------------
# # # SageAttention reinstall
# # # ---------------------------------------------------------
echo ">>> Reinstalling SageAttention..."
pip install flash-attn --no-build-isolation


# ---------------------------------------------------------
# Patch config.ini (security_level = weak)
# ---------------------------------------------------------
CFG="/workspace/ComfyUI/user/__manager/config.ini"

if [ -f "$CFG" ]; then
    echo ">>> Patching config.ini (security_level = weak)..."
    sed -i 's/security_level *= *normal/security_level = weak/g' "$CFG"
else
    echo "WARNING: config.ini not found: $CFG"
fi

# Настройка путей
COMFY_NODES_DIR="/workspace/ComfyUI/custom_nodes"
mkdir -p "$COMFY_NODES_DIR"
cd "$COMFY_NODES_DIR"

echo "==============================================="
echo "STARTING CUSTOM NODES INSTALLATION TEST"
echo "==============================================="

# Список репозиториев
REPOS=(
    "https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
    "https://github.com/storyicon/comfyui_segment_anything"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/Azornes/Comfyui-Resolution-Master"
    "https://github.com/kijai/ComfyUI-segment-anything-2"
    "https://github.com/un-seen/comfyui-tensorops"
)

# 1. Клонирование репозиториев
for repo in "${REPOS[@]}"; do
    folder=$(basename "$repo" .git)
    if [ ! -d "$folder" ]; then
        echo ">>> Cloning $folder..."
        git clone "$repo"
    else
        echo ">>> $folder already exists, pulling updates..."
        cd "$folder" && git pull && cd ..
    fi
done

echo "-----------------------------------------------"
echo "INSTALLING DEPENDENCIES"
echo "-----------------------------------------------"

# Обновляем pip перед установкой
pip install --upgrade pip setuptools wheel

# Внутри download_models.sh вместо обычного pip install:
MAIN_PIP="/venv/main/bin/pip"
for folder in /workspace/ComfyUI/custom_nodes/*; do
    if [ -f "$folder/requirements.txt" ]; then
        $MAIN_PIP install --no-cache-dir -r "$folder/requirements.txt" --no-build-isolation
        if [ $? -eq 0 ]; then
            echo " [OK] $folder dependencies installed."
        else
            echo " [ERROR] Failed to install dependencies for $folder"
        fi
    else
        echo ">>> No requirements.txt in $folder, skipping."
    fi
done
