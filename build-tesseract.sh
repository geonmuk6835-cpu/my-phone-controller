#!/bin/bash
# Tesseract OCR 소스 빌드 스크립트
# apt 설치가 불가능할 때 사용

set -e

BUILD_DIR="/tmp/tesseract-build"
mkdir -p "$BUILD_DIR"

echo "=== Leptonica 빌드 ==="
cd "$BUILD_DIR"
if [ ! -f leptonica-1.85.0.tar.gz ]; then
    wget -q "https://github.com/DanBloomberg/leptonica/releases/download/1.85.0/leptonica-1.85.0.tar.gz"
fi
tar xzf leptonica-1.85.0.tar.gz
cd leptonica-1.85.0
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=ON 2>&1 | tail -3
make -j"$(nproc)" 2>&1 | tail -3
sudo make install 2>&1 | tail -3
sudo ldconfig

echo "=== Tesseract 빌드 ==="
cd "$BUILD_DIR"
if [ ! -f tesseract-5.5.1.tar.gz ]; then
    wget -q "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/5.5.1.tar.gz" -O tesseract-5.5.1.tar.gz
fi
tar xzf tesseract-5.5.1.tar.gz
cd tesseract-5.5.1
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_TRAINING_TOOLS=OFF 2>&1 | tail -3
make -j"$(nproc)" 2>&1 | tail -3
sudo make install 2>&1 | tail -3
sudo ldconfig

echo "=== Tesseract 빌드 완료 ==="
tesseract --version 2>&1 | head -1

# 빌드 디렉토리 정리
rm -rf "$BUILD_DIR"
