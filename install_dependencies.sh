#!/usr/bin/env bash
set -euo pipefail

# Linux/Posix installer for AI Hybrid VHS Audio Restorer
# Creates a virtual environment, installs dependencies, and applies runtime patches.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Setting up Hybrid AI Audio Environment (Posix) ==="
cd "$SCRIPT_DIR"

# --- Pre-flight: Python detection ---
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "Python 3.10+ is required but was not found on PATH." >&2
  exit 1
fi

PY_VERSION="$($PYTHON_BIN -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')"
echo "Using Python ${PY_VERSION}"

# --- Virtual environment ---
if [ ! -d "$SCRIPT_DIR/venv" ]; then
  echo "Creating virtual environment..."
  "$PYTHON_BIN" -m venv "$SCRIPT_DIR/venv"
else
  echo "Virtual environment already exists. Reusing."
fi

VENV_PY="$SCRIPT_DIR/venv/bin/python"
VENV_PIP="$SCRIPT_DIR/venv/bin/pip"

# --- Dependency installation ---
echo "Upgrading pip/setuptools/wheel..."
"$VENV_PY" -m pip install --upgrade pip setuptools wheel

echo "Installing project requirements..."
"$VENV_PIP" install -r "$SCRIPT_DIR/requirements.txt"

echo "Applying runtime patches..."
"$VENV_PY" "$SCRIPT_DIR/apply_patches.py"

# --- FFmpeg setup ---
FFMPEG_TARGET="$SCRIPT_DIR/venv/bin/ffmpeg"
FFPROBE_TARGET="$SCRIPT_DIR/venv/bin/ffprobe"

if [ -x "$FFMPEG_TARGET" ]; then
  echo "FFmpeg already present in venv."
elif command -v ffmpeg >/dev/null 2>&1; then
  echo "Using system FFmpeg from PATH."
else
  echo "FFmpeg not found. Downloading portable static build (linux/amd64)..."
  TMP_DIR="$(mktemp -d)"
  STATIC_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"

  if command -v curl >/dev/null 2>&1; then
    curl -L "$STATIC_URL" -o "$TMP_DIR/ffmpeg.tar.xz"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$TMP_DIR/ffmpeg.tar.xz" "$STATIC_URL"
  else
    echo "Neither curl nor wget is available to download FFmpeg. Please install FFmpeg manually." >&2
    exit 1
  fi

  tar -xJf "$TMP_DIR/ffmpeg.tar.xz" -C "$TMP_DIR"
  BIN_DIR="$(find "$TMP_DIR" -type f -name ffmpeg -print -quit | xargs dirname)"

  if [ -z "$BIN_DIR" ]; then
    echo "Failed to locate FFmpeg binary in downloaded archive." >&2
    exit 1
  fi

  install -m 755 "$BIN_DIR/ffmpeg" "$FFMPEG_TARGET"
  if [ -f "$BIN_DIR/ffprobe" ]; then
    install -m 755 "$BIN_DIR/ffprobe" "$FFPROBE_TARGET"
  fi
  rm -rf "$TMP_DIR"
fi

# --- Project folders ---
mkdir -p "$SCRIPT_DIR/input" "$SCRIPT_DIR/output" "$SCRIPT_DIR/temp_work"

echo "=== Installation Complete ==="
echo "Activate the environment with: source venv/bin/activate"
echo "Run the cleaner via: $VENV_PY restore_audio_hybrid.py <your-video-file>"
