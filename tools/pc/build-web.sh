#!/usr/bin/env bash
set -euo pipefail

version=$(awk '/^version:/ {split($2, parts, "+"); print parts[1]; exit}' pubspec.yaml)
flutter build web --release --no-web-resources-cdn \
  --base-href "/pc/$version/" --dart-define="RPG_APP_VERSION=$version" "$@"
