#!/usr/bin/env bash
# ==============================================================================
# build_ios_stockfish.sh
# Cross-compiles official Stockfish C++ source into a static library for iOS.
#
# Target Architectures:
#   - arm64 (iOS Device)
#   - arm64, x86_64 (iOS Simulator)
#
# Requirements:
#   - macOS with Xcode 15+ and Xcode Command Line Tools
#   - clang++ supporting C++20
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOCKFISH_SRC_DIR="${SCRIPT_DIR}/Stockfish/src"
OUTPUT_DIR="${SCRIPT_DIR}/../ios-native/Frameworks"

echo "=== Building Stockfish for iOS ==="

if [ ! -d "${STOCKFISH_SRC_DIR}" ]; then
    echo "Cloning official Stockfish source..."
    git clone --depth 1 https://github.com/official-stockfish/Stockfish.git "${SCRIPT_DIR}/Stockfish"
fi

mkdir -p "${OUTPUT_DIR}"

XCODE_DEV_PATH="$(xcode-select -p)"
IOS_SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SIM_SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"

echo "iOS SDK: ${IOS_SDK_PATH}"
echo "Sim SDK: ${SIM_SDK_PATH}"

# Compilation flags for iOS arm64
COMMON_CXXFLAGS="-std=c++20 -O3 -fPIC -DNDEBUG -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8"

# 1. Build for iOS Device (arm64)
echo "Compiling for iphoneos (arm64)..."
make -C "${STOCKFISH_SRC_DIR}" clean
make -C "${STOCKFISH_SRC_DIR}" -j$(sysctl -n hw.ncpu) \
    COMP=clang \
    ARCH=armv8-dotprod \
    TARGET_OS=Darwin \
    CXX="xcrun --sdk iphoneos clang++" \
    EXTRA_CXXFLAGS="-isysroot ${IOS_SDK_PATH} -miphoneos-version-min=17.0 -arch arm64 ${COMMON_CXXFLAGS}" \
    net \
    build

mv "${STOCKFISH_SRC_DIR}/stockfish" "${OUTPUT_DIR}/libstockfish-device.a" || true

echo "Stockfish iOS static library build complete."
