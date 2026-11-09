#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
corpus="${1:-${repo_root}/flutter_receipt_scanner/test/fixtures/ocr-contracts/v1/contract.json}"
simulator="${SIMULATOR_UDID:-booted}"
sources="${repo_root}/flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/swift-geometry.XXXXXX")"
trap 'rm -f "$build_dir/geometry-conformance" "$build_dir/corrupted.json" "$build_dir/corruption.log"; rmdir "$build_dir"' EXIT
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
architecture="$(uname -m)"

xcrun --sdk iphonesimulator swiftc \
	-sdk "${sdk}" -target "${architecture}-apple-ios16.0-simulator" \
	"${sources}/OcrGeometry.swift" "${sources}/QuadDetector.swift" \
	"${repo_root}/flutter_receipt_scanner_ios/ios/tests/GeometryConformance.swift" \
	-o "${build_dir}/geometry-conformance"
codesign --force --sign - "${build_dir}/geometry-conformance"
xcrun simctl spawn "${simulator}" "${build_dir}/geometry-conformance" "${corpus}"

if [[ ${VERIFY_CORRUPTION:-0} == 1 ]]; then
	python3 - "${corpus}" "${build_dir}/corrupted.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    corpus = json.load(source)
corpus["geometry"]["boxCases"][1]["expectedRotated"][0] += 1
with open(sys.argv[2], "w", encoding="utf-8") as output:
    json.dump(corpus, output)
PY
	set +e
	xcrun simctl spawn "${simulator}" "${build_dir}/geometry-conformance" "${build_dir}/corrupted.json" >"${build_dir}/corruption.log" 2>&1
	corruption_exit=$?
	set -e
	cat "${build_dir}/corruption.log"
	if [[ ${corruption_exit} != 1 ]] || ! grep -q 'FAIL: rotate-90: rotated box' "${build_dir}/corruption.log"; then
		echo "FAIL: expected rotate-90 mismatch with exit 1, got exit ${corruption_exit}" >&2
		exit 1
	fi
	echo "PASS: corrupted box expectation rejected"
fi
