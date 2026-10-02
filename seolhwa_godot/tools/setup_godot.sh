#!/usr/bin/env bash
# Godot 4 + 소프트웨어 Vulkan(lavapipe) + Xvfb 설치. 클라우드 컨테이너가 새로 뜨면 다시 실행한다.
set -euo pipefail
V="${GODOT_VERSION:-4.7.2}"
if ! command -v godot >/dev/null || ! godot --version 2>/dev/null | grep -q "^${V}"; then
  mkdir -p /opt/godot
  curl -sSL -o /opt/godot/godot.zip "https://github.com/godotengine/godot/releases/download/${V}-stable/Godot_v${V}-stable_linux.x86_64.zip"
  python3 -c "import zipfile;zipfile.ZipFile('/opt/godot/godot.zip').extractall('/opt/godot')"
  chmod +x "/opt/godot/Godot_v${V}-stable_linux.x86_64"
  ln -sf "/opt/godot/Godot_v${V}-stable_linux.x86_64" /usr/local/bin/godot
  rm -f /opt/godot/godot.zip
fi
if [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ] || ! command -v xvfb-run >/dev/null; then
  apt-get update -q >/dev/null 2>&1 || true
  apt-get install -y -q mesa-vulkan-drivers xvfb >/dev/null
fi
godot --version
