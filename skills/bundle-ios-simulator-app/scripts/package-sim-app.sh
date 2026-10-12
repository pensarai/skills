#!/usr/bin/env bash
# Build (or repackage) a standalone iOS Simulator .app and wrap it in a
# shareable .tar.gz with a checksum, manifest, and run instructions.
#
#   package-sim-app.sh --workspace ios/App.xcworkspace --scheme App
#   package-sim-app.sh --project App.xcodeproj --scheme App --configuration Debug
#   package-sim-app.sh --from build/ios/iphonesimulator/Runner.app
#   package-sim-app.sh --from eas-build.tar.gz --smoke-test
#   package-sim-app.sh --workspace ios/App.xcworkspace --scheme App -- MY_SETTING=1
#
# Arguments after `--` are passed straight to xcodebuild.

set -euo pipefail

WORKSPACE=""
PROJECT=""
SCHEME=""
CONFIGURATION="Release"
FROM=""
OUT_DIR="dist/simulator"
ARCHS="arm64 x86_64"
SMOKE_TEST=0
EXTRA_ARGS=()

log() { printf '[sim-app] %s\n' "$*" >&2; }
fail() { printf '\n[sim-app] ERROR: %s\n\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options:
  --workspace PATH       .xcworkspace to build (use this when a Podfile exists)
  --project PATH         .xcodeproj to build (when there is no workspace)
  --scheme NAME          Scheme that builds the app target
  --configuration NAME   Build configuration (default: Release)
  --from PATH            Skip building; package an existing .app, .tar.gz, or .zip
  --out DIR              Output directory (default: dist/simulator)
  --arm64-only           Build arm64 only (when a dependency lacks x86_64 simulator slices)
  --smoke-test           Install and launch the packaged app on a simulator
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="${2:?--workspace needs a path}"; shift 2 ;;
    --project) PROJECT="${2:?--project needs a path}"; shift 2 ;;
    --scheme) SCHEME="${2:?--scheme needs a name}"; shift 2 ;;
    --configuration) CONFIGURATION="${2:?--configuration needs a name}"; shift 2 ;;
    --from) FROM="${2:?--from needs a path}"; shift 2 ;;
    --out) OUT_DIR="${2:?--out needs a directory}"; shift 2 ;;
    --arm64-only) ARCHS="arm64"; shift ;;
    --smoke-test) SMOKE_TEST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; EXTRA_ARGS=("$@"); break ;;
    *) fail "unknown argument: $1 (see --help)" ;;
  esac
done

command -v xcrun >/dev/null || fail "Xcode command line tools not found. Install Xcode and run: xcode-select --install"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

build_app() {
  [[ -n "$SCHEME" ]] || fail "--scheme is required when building (list schemes with: xcodebuild -list -workspace/-project ...)"
  local container=()
  if [[ -n "$WORKSPACE" ]]; then
    container=(-workspace "$WORKSPACE")
  elif [[ -n "$PROJECT" ]]; then
    container=(-project "$PROJECT")
  else
    fail "pass --workspace, --project, or --from"
  fi

  local derived="$OUT_DIR/.derived-data"
  local args=(
    "${container[@]}"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -sdk iphonesimulator
    -destination "generic/platform=iOS Simulator"
    -derivedDataPath "$derived"
    ARCHS="$ARCHS"
    ONLY_ACTIVE_ARCH=NO
  )
  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    args+=("${EXTRA_ARGS[@]}")
  fi

  log "building $SCHEME ($CONFIGURATION, $ARCHS) — full log: $OUT_DIR/xcodebuild.log"
  if ! xcodebuild "${args[@]}" build >"$OUT_DIR/xcodebuild.log" 2>&1; then
    grep -E "error:|BUILD FAILED" "$OUT_DIR/xcodebuild.log" | tail -20 >&2 || true
    fail "xcodebuild failed — see $OUT_DIR/xcodebuild.log"
  fi

  local product_name
  product_name="$(xcodebuild "${args[@]}" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^ *FULL_PRODUCT_NAME = .*\.app$/ { print $2; exit }')"
  local products="$derived/Build/Products/$CONFIGURATION-iphonesimulator"

  if [[ -n "$product_name" && -d "$products/$product_name" ]]; then
    APP_PATH="$products/$product_name"
  else
    local found=()
    while IFS= read -r app; do found+=("$app"); done \
      < <(find "$products" -maxdepth 1 -name "*.app" -type d 2>/dev/null)
    [[ ${#found[@]} -eq 1 ]] || fail "could not identify the app in $products (found ${#found[@]} .app bundles)"
    APP_PATH="${found[0]}"
  fi
}

load_from() {
  [[ -e "$FROM" ]] || fail "--from path does not exist: $FROM"
  case "$FROM" in
    *.app) APP_PATH="$(cd "$FROM" && pwd)" ;;
    *.tar.gz|*.tgz) tar -xzf "$FROM" -C "$WORK_DIR" ;;
    *.zip) ditto -x -k "$FROM" "$WORK_DIR" ;;
    *) fail "--from must be a .app, .tar.gz, .tgz, or .zip" ;;
  esac
  if [[ -z "${APP_PATH:-}" ]]; then
    APP_PATH="$(find "$WORK_DIR" -maxdepth 3 -name "*.app" -type d -not -path "*.app/*" | head -1)"
    [[ -n "$APP_PATH" ]] || fail "no .app bundle found inside $FROM"
  fi
}

plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP_PATH/Info.plist" 2>/dev/null || echo "unknown"; }

if [[ -n "$FROM" ]]; then load_from; else build_app; fi
[[ -f "$APP_PATH/Info.plist" ]] || fail "$APP_PATH has no Info.plist — not an app bundle"

PLATFORM="$(plist DTPlatformName)"
[[ "$PLATFORM" == "iphonesimulator" ]] \
  || fail "$(basename "$APP_PATH") was built for '$PLATFORM', not the simulator. Rebuild with -sdk iphonesimulator."

APP_NAME="$(basename "$APP_PATH" .app)"
BUNDLE_ID="$(plist CFBundleIdentifier)"
VERSION="$(plist CFBundleShortVersionString)"
BUILD_NUMBER="$(plist CFBundleVersion)"
MIN_OS="$(plist MinimumOSVersion)"
BUILT_WITH_SDK="$(plist DTSDKName)"
EXECUTABLE="$APP_PATH/$(plist CFBundleExecutable)"
BINARY_ARCHS="$(lipo -archs "$EXECUTABLE" 2>/dev/null || echo unknown)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
STAMP="$(date -u +%Y%m%d-%H%M)"
SAFE_NAME="$(printf '%s' "$APP_NAME" | tr -c 'A-Za-z0-9._-' '-')"
STEM="$SAFE_NAME-$VERSION-$BUILD_NUMBER-sim-$COMMIT-$STAMP"
TARBALL="$OUT_DIR/$STEM.tar.gz"

[[ "$BINARY_ARCHS" == *arm64* ]] || log "WARNING: binary lacks arm64 ($BINARY_ARCHS) — it will not run on Apple Silicon simulators"
[[ "$BINARY_ARCHS" == *x86_64* ]] || log "note: binary lacks x86_64 ($BINARY_ARCHS) — it will not run on Intel Macs"

log "packaging $(basename "$APP_PATH") → $(basename "$TARBALL")"
COPYFILE_DISABLE=1 tar -czf "$TARBALL" -C "$(dirname "$APP_PATH")" "$(basename "$APP_PATH")"

DIGEST="$(shasum -a 256 "$TARBALL" | awk '{ print $1 }')"
printf '%s  %s\n' "$DIGEST" "$(basename "$TARBALL")" >"$TARBALL.sha256"
SIZE_BYTES="$(stat -f %z "$TARBALL")"

MANIFEST="$OUT_DIR/$STEM.manifest.json"
plutil -create xml1 "$MANIFEST"
for kv in \
  "name=$APP_NAME" "bundleId=$BUNDLE_ID" "version=$VERSION" "build=$BUILD_NUMBER" \
  "configuration=$([[ -n "$FROM" ]] && echo prebuilt || echo "$CONFIGURATION")" "platform=ios-simulator" \
  "minimumOSVersion=$MIN_OS" "sdk=$BUILT_WITH_SDK" "architectures=$BINARY_ARCHS" \
  "gitCommit=$COMMIT" "sha256=$DIGEST" "artifact=$(basename "$TARBALL")" \
  "createdAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; do
  plutil -insert "${kv%%=*}" -string "${kv#*=}" "$MANIFEST"
done
plutil -insert sizeBytes -integer "$SIZE_BYTES" "$MANIFEST"
plutil -convert json -r "$MANIFEST"

cat >"$OUT_DIR/RUN.md" <<EOF
# $APP_NAME — iOS Simulator build

$APP_NAME $VERSION ($BUILD_NUMBER), bundle ID \`$BUNDLE_ID\`, built for the iOS
Simulator ($BINARY_ARCHS, iOS $MIN_OS+). Requires a Mac with Xcode; no signing,
source code, or dev server needed.

\`\`\`bash
shasum -a 256 -c $(basename "$TARBALL").sha256
tar -xzf $(basename "$TARBALL")
open -a Simulator            # boots the default simulator
xcrun simctl install booted "$(basename "$APP_PATH")"
xcrun simctl launch booted $BUNDLE_ID
\`\`\`

Or drag \`$(basename "$APP_PATH")\` onto a running Simulator window.
EOF

if [[ $SMOKE_TEST -eq 1 ]]; then
  DEVICE="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
  if [[ -z "$DEVICE" ]]; then
    DEVICE="$(xcrun simctl list devices available | grep -E '^\s+iPhone' | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
    [[ -n "$DEVICE" ]] || fail "no available iPhone simulator for the smoke test (create one in Xcode > Settings > Components)"
    log "booting simulator $DEVICE"
    xcrun simctl boot "$DEVICE"
  fi
  SMOKE_DIR="$WORK_DIR/smoke"
  mkdir -p "$SMOKE_DIR"
  tar -xzf "$TARBALL" -C "$SMOKE_DIR"
  log "smoke test: installing and launching on $DEVICE"
  xcrun simctl install "$DEVICE" "$SMOKE_DIR/$(basename "$APP_PATH")"
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" >/dev/null
  sleep 8
  if xcrun simctl spawn "$DEVICE" launchctl list | grep -q "$BUNDLE_ID"; then
    log "smoke test passed: $BUNDLE_ID is still running after 8s"
  else
    fail "smoke test failed: $BUNDLE_ID exited after launch. Check crash logs in ~/Library/Logs/DiagnosticReports"
  fi
fi

cat >&2 <<EOF

[sim-app] artifact ready:
  tarball : $TARBALL ($(( SIZE_BYTES / 1024 / 1024 )) MB)
  sha256  : $DIGEST
  manifest: $MANIFEST
  run docs: $OUT_DIR/RUN.md
  app     : $BUNDLE_ID $VERSION ($BUILD_NUMBER), $BINARY_ARCHS, iOS $MIN_OS+

EOF
