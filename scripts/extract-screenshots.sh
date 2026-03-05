#!/bin/bash
#
# extract-screenshots.sh
# Runs screenshot UI tests and extracts screenshots from xcresult bundle.
#
# Usage:
#   ./scripts/extract-screenshots.sh [locale] [appearance]
#
# Examples:
#   ./scripts/extract-screenshots.sh           # English, light mode
#   ./scripts/extract-screenshots.sh de        # German, light mode
#   ./scripts/extract-screenshots.sh en dark   # English, dark mode
#

set -euo pipefail

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="PasteShelf"
TEST_TARGET="PasteShelfUITests/ScreenshotUITests"
DERIVED_DATA_PATH="${PROJECT_DIR}/DerivedData"
RESULT_PATH="${PROJECT_DIR}/build/screenshots.xcresult"
OUTPUT_DIR="${PROJECT_DIR}/screenshots"

# Arguments
LOCALE="${1:-en}"
APPEARANCE="${2:-light}"

echo "=============================================="
echo "PasteShelf App Store Screenshot Generator"
echo "=============================================="
echo "Locale: ${LOCALE}"
echo "Appearance: ${APPEARANCE}"
echo "Output: ${OUTPUT_DIR}/${LOCALE}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}/${LOCALE}"

# Clean previous results
rm -rf "${RESULT_PATH}"

echo "Running screenshot UI tests..."
echo ""

# Run the screenshot tests with environment variables
export SCREENSHOT_LOCALE="${LOCALE}"
export SCREENSHOT_APPEARANCE="${APPEARANCE}"

xcodebuild test \
    -project "${PROJECT_DIR}/PasteShelf.xcodeproj" \
    -scheme "${SCHEME}" \
    -destination 'platform=macOS' \
    -only-testing:"${TEST_TARGET}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -resultBundlePath "${RESULT_PATH}" \
    2>&1 | xcpretty || true

# Check if xcresult exists
if [ ! -d "${RESULT_PATH}" ]; then
    echo ""
    echo "Warning: xcresult bundle not found at ${RESULT_PATH}"
    echo "Tests may have failed. Checking for any screenshots..."

    # Try to find xcresult in DerivedData
    RESULT_PATH=$(find "${DERIVED_DATA_PATH}" -name "*.xcresult" -type d | head -1)

    if [ -z "${RESULT_PATH}" ]; then
        echo "Error: No xcresult bundle found."
        exit 1
    fi

    echo "Found: ${RESULT_PATH}"
fi

echo ""
echo "Extracting screenshots from xcresult..."
echo ""

# Extract screenshots using xcresulttool
# First, get the list of attachments
ATTACHMENTS=$(xcrun xcresulttool get --path "${RESULT_PATH}" --format json 2>/dev/null | \
    python3 -c "
import sys
import json

try:
    data = json.load(sys.stdin)

    def find_attachments(obj, path=''):
        results = []
        if isinstance(obj, dict):
            if obj.get('_type', {}).get('_name') == 'ActionTestAttachment':
                name = obj.get('name', {}).get('_value', '')
                identifier = obj.get('payloadRef', {}).get('id', {}).get('_value', '')
                if name and identifier and name.endswith('.png'):
                    results.append((name, identifier))
            for key, value in obj.items():
                results.extend(find_attachments(value, f'{path}.{key}'))
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                results.extend(find_attachments(item, f'{path}[{i}]'))
        return results

    attachments = find_attachments(data)
    for name, identifier in attachments:
        print(f'{name}|{identifier}')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null) || true

if [ -z "${ATTACHMENTS}" ]; then
    echo "No screenshot attachments found in xcresult."
    echo ""
    echo "Alternative: Screenshots may be in test output directory."
    echo "Check: ${DERIVED_DATA_PATH}/Logs/Test/"

    # Try to find any PNG files in test logs
    find "${DERIVED_DATA_PATH}/Logs/Test/" -name "*.png" 2>/dev/null | while read -r png; do
        filename=$(basename "${png}")
        echo "Found: ${filename}"
        cp "${png}" "${OUTPUT_DIR}/${LOCALE}/"
    done

    exit 0
fi

# Extract each screenshot
echo "${ATTACHMENTS}" | while IFS='|' read -r name identifier; do
    if [ -n "${name}" ] && [ -n "${identifier}" ]; then
        output_file="${OUTPUT_DIR}/${LOCALE}/${name}"
        echo "Extracting: ${name}"

        xcrun xcresulttool get \
            --path "${RESULT_PATH}" \
            --id "${identifier}" \
            --output-path "${output_file}" 2>/dev/null || {
            echo "  Warning: Failed to extract ${name}"
        }
    fi
done

echo ""
echo "=============================================="
echo "Screenshot extraction complete!"
echo "=============================================="
echo ""
echo "Screenshots saved to: ${OUTPUT_DIR}/${LOCALE}/"
echo ""

# List extracted files
if ls "${OUTPUT_DIR}/${LOCALE}/"*.png 1> /dev/null 2>&1; then
    echo "Generated screenshots:"
    ls -la "${OUTPUT_DIR}/${LOCALE}/"*.png
else
    echo "No screenshots were generated."
    echo ""
    echo "Troubleshooting:"
    echo "1. Ensure the app builds successfully"
    echo "2. Check that UI tests can run (accessibility permissions)"
    echo "3. Run manually: xcodebuild test -scheme PasteShelf -only-testing:PasteShelfUITests/ScreenshotUITests"
fi

echo ""
echo "For localized screenshots, run:"
echo "  ./scripts/extract-screenshots.sh de       # German"
echo "  ./scripts/extract-screenshots.sh ja       # Japanese"
echo "  ./scripts/extract-screenshots.sh zh-Hans  # Chinese (Simplified)"
echo ""
echo "For dark mode screenshots, run:"
echo "  ./scripts/extract-screenshots.sh en dark"
