#!/bin/bash

set -e

echo "Instalando Flutter..."

git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter

export PATH="$HOME/flutter/bin:$PATH"

flutter --version

flutter pub get

flutter build web --release --dart-define=API_BASE_URL="${VITE_API_URL:-https://clausulazos.onrender.com}"

echo "Build Flutter terminado"