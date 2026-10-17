#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
build_args=(CODE_SIGNING_ALLOWED=NO)
case "${1:-}" in
  --smoke-test)
    echo '구형 SDK 컴파일 검증: 앱 열기 동작은 제외됩니다. 배포하지 마세요.'
    build_args+=(IPHONEOS_DEPLOYMENT_TARGET=17.4 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG REELSBAN_SDK_SMOKE_TEST')
    ;;
  '')
    if ! awk -v version="$sdk_version" 'BEGIN { split(version,v,"."); exit !(v[1]>26 || (v[1]==26 && v[2]>=5)) }'; then
      echo "iOS 26.5 이상 SDK가 필요합니다. 현재 SDK: $sdk_version. Xcode 업데이트 후 다시 실행하세요." >&2
      exit 1
    fi
    ;;
  *) echo '사용법: ./ios/build.sh [--smoke-test]' >&2; exit 2 ;;
esac
xcodebuild -project "$project_dir/ReelsBan.xcodeproj" -scheme ReelsBan \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "${TMPDIR:-/tmp}/reelsban-ios-build" \
  "${build_args[@]}" build
