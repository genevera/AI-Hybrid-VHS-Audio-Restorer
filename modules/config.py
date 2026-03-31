import os
import yaml
from pathlib import Path


def load_config():
    config_path = Path("config.yaml")
    defaults = {
        "vocal_mix_volume": 1.0,
        "background_mix_volume": 1.0,
        "video_extensions": ['.mp4', '.mkv', '.avi', '.mov'],
        "audio_extensions": ['.wav', '.flac', '.mp3', '.m4a', '.aac', '.ogg'],
        # Backward compatibility: unified list used by UI scanning
        "extensions": None,
        "vocals_model": "model_bs_roformer_ep_317_sdr_12.9755.ckpt",
        "background_model": "UVR-MDX-NET-Inst_HQ_3.onnx",
        "denoise_model": "UVR-DeNoise-Lite.pth",
        "enhance_nfe": 128,
        "enhance_tau": 0.5,
        "sync_method": "dtw",    # 'check' or 'dtw'
        "dtw_resolution": 40,    # Analysis resolution in Hz (40Hz = 25ms, Sufficient for Lipsync)
        "process_mode": "hybrid",  # 'hybrid' (default) or 'denoise_only'
        "debug_logging": False
    }
    loaded_from = "Defaults"
    if config_path.exists():
        try:
            with open(config_path, "r") as f:
                user_config = yaml.safe_load(f)
                if user_config:
                    defaults.update(user_config)
                    loaded_from = "config.yaml"
        except Exception as e:
            print(f"[Warning] Failed to load config.yaml: {e}")

    return defaults, loaded_from


CONFIG, CONFIG_SOURCE = load_config()

INPUT_DIR = Path("input")
OUTPUT_DIR = Path("output")
LOG_FILE = Path("session_log.txt")

VIDEO_EXTS = set(CONFIG.get("video_extensions") or ['.mp4', '.mkv', '.avi', '.mov'])
AUDIO_EXTS = set(CONFIG.get("audio_extensions") or ['.wav', '.flac', '.mp3', '.m4a', '.aac', '.ogg'])
legacy_exts = set(CONFIG.get("extensions") or [])
_ext_union = list(VIDEO_EXTS | AUDIO_EXTS | legacy_exts)

EXTS = set(_ext_union)
KEEP_INPUT_FILES = os.environ.get("AI_RESTORE_TEST_MODE") == "1"

# Audio mix levels
VOCAL_MIX_VOL = CONFIG["vocal_mix_volume"]
BACKGROUND_MIX_VOL = CONFIG["background_mix_volume"]

# AI Configs
VOCALS_MODEL = CONFIG["vocals_model"]
BACKGROUND_MODEL = CONFIG["background_model"]
DENOISE_MODEL = CONFIG["denoise_model"]
ENHANCE_NFE = str(CONFIG["enhance_nfe"])
ENHANCE_TAU = str(CONFIG["enhance_tau"])
SYNC_METHOD = CONFIG["sync_method"]
DTW_RESOLUTION = int(CONFIG["dtw_resolution"])
PROCESS_MODE = CONFIG["process_mode"]
DEBUG_LOGGING = CONFIG.get("debug_logging", False)
