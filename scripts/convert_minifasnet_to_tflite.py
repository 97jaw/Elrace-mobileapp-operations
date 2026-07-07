#!/usr/bin/env python3
"""Download MiniFASNet ONNX weights and convert to TFLite for Flutter assets."""

from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "antispoof"
MODELS = [
    (
        "MiniFASNetV2",
        "https://github.com/yakhyo/face-anti-spoofing/releases/download/weights/MiniFASNetV2.onnx",
        "minifasnet_v2_2.7_80x80.tflite",
        2.7,
    ),
    (
        "MiniFASNetV1SE",
        "https://github.com/yakhyo/face-anti-spoofing/releases/download/weights/MiniFASNetV1SE.onnx",
        "minifasnet_v1se_4.0_80x80.tflite",
        4.0,
    ),
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 1000:
        print(f"skip download (exists): {dest.name}")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(["curl", "-fsSL", "-o", str(dest), url])


def onnx_to_tflite(onnx_path: Path, tflite_path: Path) -> None:
    import onnx
    from onnx2tf import convert

    tmp_saved = tflite_path.parent / f"_tf_{onnx_path.stem}"
    if tmp_saved.exists():
        import shutil

        shutil.rmtree(tmp_saved)

    convert(
        input_onnx_file_path=str(onnx_path),
        output_folder_path=str(tmp_saved),
        copy_onnx_input_output_names_to_tflite=True,
        non_verbose=True,
    )

    candidates = list(tmp_saved.rglob("*.tflite"))
    if not candidates:
        raise RuntimeError(f"No .tflite produced under {tmp_saved}")
    # Prefer float32 saved model.
    preferred = [p for p in candidates if "float32" in p.name]
    src = preferred[0] if preferred else candidates[0]
    tflite_path.parent.mkdir(parents=True, exist_ok=True)
    src.replace(tflite_path)
    print(f"wrote {tflite_path} ({tflite_path.stat().st_size} bytes)")


def main() -> int:
    ASSETS.mkdir(parents=True, exist_ok=True)
    specs_path = ASSETS / "MODEL_SPECS.txt"
    lines: list[str] = []

    for name, url, tflite_name, scale in MODELS:
        onnx_local = ASSETS / f"{name}.onnx"
        tflite_local = ASSETS / tflite_name
        print(f"\n=== {name} (crop scale {scale}) ===")
        download(url, onnx_local)
        onnx_to_tflite(onnx_local, tflite_local)
        digest = sha256(tflite_local)
        lines.append(
            f"{name}: asset={tflite_name}, input=80x80 RGB, crop_scale={scale}, "
            f"classes=3 [live, print, replay], sha256={digest}, "
            f"bytes={tflite_local.stat().st_size}"
        )

    specs_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\nSpecs written to {specs_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
