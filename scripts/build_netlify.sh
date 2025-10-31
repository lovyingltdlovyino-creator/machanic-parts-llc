#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Flutter stable ==="
FLUTTER_DIR="$PWD/.flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  echo "Flutter already present at $FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --no-analytics
flutter precache --web
flutter pub get

echo "=== Building Flutter Web (release) ==="
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

flutter build web --release \
  --tree-shake-icons \
  --dart-define "SUPABASE_URL=$SUPABASE_URL" \
  --dart-define "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

echo "Build complete. Publish directory: build/web"
