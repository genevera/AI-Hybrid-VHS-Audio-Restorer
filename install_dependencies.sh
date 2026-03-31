#!/usr/bin/env bash
# === AI Hybrid VHS Audio Restorer Installer (Linux) ===
# Installs: Python (venv), FFmpeg (system or local), PyTorch, Resemble-Enhance, Demucs
# Fully self-contained: No system-wide Python modifications required.

set -euo pipefail

cd "$(dirname "$0")"

echo -e "\033[0;36m=== Setting up Hybrid AI Audio Environment (Portable Mode) ===\033[0m"

# --- PRE-FLIGHT CHECKS ---

# 1. Check for Python
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found in PATH. Please install Python 3.10+ and try again." >&2
    exit 1
fi
PY_VER=$(python3 --version)
echo -e "\033[0;32mFound Python: ${PY_VER}\033[0m"

# --- INSTALLATION ---

# Step 1: Create Virtual Environment
echo -e "\n\033[0;33mStep 1: Setting up Python Environment...\033[0m"
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Created virtual environment."
fi

VENV_PY="$(pwd)/venv/bin/python"
VENV_PIP="$(pwd)/venv/bin/pip"
VENV_BIN="$(pwd)/venv/bin"

# Step 1.5: Check / Install FFmpeg
echo -e "\n\033[0;33mStep 1.5: Checking Local FFmpeg...\033[0m"

LOCAL_FFMPEG="${VENV_BIN}/ffmpeg"

if [ ! -f "${LOCAL_FFMPEG}" ]; then
    # Prefer the system FFmpeg and symlink it into the venv so the app finds it there.
    if command -v ffmpeg &>/dev/null; then
        echo -e "\033[0;32mSystem FFmpeg found. Symlinking into venv/bin...\033[0m"
        ln -sf "$(command -v ffmpeg)" "${VENV_BIN}/ffmpeg"
        if command -v ffprobe &>/dev/null; then
            ln -sf "$(command -v ffprobe)" "${VENV_BIN}/ffprobe"
        else
            echo "Note: ffprobe not found on system; skipping ffprobe symlink."
        fi
    else
        # Fall back to downloading a static build from John Van Sickle's builds.
        echo -e "\033[0;36mFFmpeg not found on system. Downloading static build...\033[0m"
        ARCH="$(uname -m)"
        if [ "${ARCH}" = "x86_64" ]; then
            FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
        elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
            FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
        else
            echo "ERROR: Unsupported architecture ${ARCH}. Please install FFmpeg manually." >&2
            exit 1
        fi

        TMPDIR_FF="$(mktemp -d)"
        trap 'rm -rf "${TMPDIR_FF}"' EXIT

        echo "Downloading FFmpeg from ${FFMPEG_URL}..."
        curl -L --user-agent "Mozilla/5.0" -o "${TMPDIR_FF}/ffmpeg.tar.xz" "${FFMPEG_URL}"

        echo "Extracting FFmpeg..."
        tar -xf "${TMPDIR_FF}/ffmpeg.tar.xz" -C "${TMPDIR_FF}"

        # Find the ffmpeg binary inside the extracted directory
        FFMPEG_EXTRACTED=$(find "${TMPDIR_FF}" -type f -name "ffmpeg" | head -n 1)
        FFPROBE_EXTRACTED=$(find "${TMPDIR_FF}" -type f -name "ffprobe" | head -n 1)

        cp "${FFMPEG_EXTRACTED}" "${VENV_BIN}/ffmpeg"
        chmod +x "${VENV_BIN}/ffmpeg"
        if [ -n "${FFPROBE_EXTRACTED}" ]; then
            cp "${FFPROBE_EXTRACTED}" "${VENV_BIN}/ffprobe"
            chmod +x "${VENV_BIN}/ffprobe"
        fi

        echo -e "\033[0;32mFFmpeg installed to virtual environment.\033[0m"
    fi
else
    echo -e "\033[0;32mLocal FFmpeg is already installed in venv.\033[0m"
fi

# Step 2: Install Python Dependencies
echo -e "\033[0;33mStep 2: Installing All Dependencies (PyTorch, AI Models, Utilities)...\033[0m"

"${VENV_PY}" -m pip install --upgrade pip

# Install base dependencies, excluding resemble-enhance to handle it separately.
echo -e "\033[0;36mInstalling base dependencies from requirements.txt...\033[0m"
TEMP_REQ="$(mktemp)"
grep -v "resemble-enhance" requirements.txt > "${TEMP_REQ}" || true
"${VENV_PIP}" install -r "${TEMP_REQ}" --no-cache-dir
rm -f "${TEMP_REQ}"

# Install resemble-enhance without its heavy optional deps (e.g. deepspeed)
# to avoid version conflicts. apply_patches.py stubs out DeepSpeed at runtime.
echo -e "\033[0;36mInstalling Resemble-Enhance (bypass deepspeed dependency)...\033[0m"
"${VENV_PIP}" install resemble-enhance --no-deps --no-cache-dir

echo -e "\033[0;32mAll dependencies installed successfully.\033[0m"

# Apply runtime patches (DeepSpeed removal + torchaudio fixes)
echo -e "\033[0;36mApplying runtime patches (DeepSpeed removal + Torchaudio fixes)...\033[0m"
"${VENV_PY}" apply_patches.py

# Step 3: Create project directories
echo -e "\033[0;33mStep 3: Creating project structure...\033[0m"
mkdir -p input output temp_work

# Step 4: Create a shell launcher
echo -e "\033[0;33mStep 4: Creating Launcher...\033[0m"
cat > start.sh << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_EXE="${SCRIPT_DIR}/venv/bin/python"
if [ ! -f "${PYTHON_EXE}" ]; then
    PYTHON_EXE="python3"
fi
"${PYTHON_EXE}" "${SCRIPT_DIR}/restore_audio_hybrid.py" "$@"
EOF
chmod +x start.sh

echo -e "\n\033[0;32m=== Installation Complete! ===\033[0m"
echo "1. Put your video files in the 'input' folder."
echo "2. Run './start.sh' to launch the Hybrid AI Cleaner."
