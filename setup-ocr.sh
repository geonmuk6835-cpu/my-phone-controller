#!/bin/bash
# PDF OCR 환경 설치 스크립트
# tesseract-ocr + ocrmypdf 설치 (한국어/영어 지원)

set -e

echo "=== PDF OCR 환경 설치 ==="

# 1. Python 패키지 설치
echo "[1/4] Python 패키지 설치 중..."
pip install ocrmypdf pytesseract tesserocr 2>&1 | tail -3

# 2. Tesseract 설치 (apt 사용 가능 시)
echo "[2/4] Tesseract OCR 설치 중..."
if command -v apt &>/dev/null; then
    if sudo apt install -y tesseract-ocr tesseract-ocr-kor 2>/dev/null; then
        echo "  apt로 tesseract 설치 완료"
    else
        echo "  apt 설치 실패 - 소스에서 빌드합니다..."
        bash "$(dirname "$0")/build-tesseract.sh"
    fi
elif command -v pkg &>/dev/null; then
    # Termux 환경
    pkg install -y tesseract 2>/dev/null && echo "  Termux에서 tesseract 설치 완료"
else
    echo "  패키지 매니저를 찾을 수 없습니다. 소스에서 빌드합니다..."
    bash "$(dirname "$0")/build-tesseract.sh"
fi

# 3. tessdata 다운로드 (언어 데이터가 없을 경우)
echo "[3/4] 언어 데이터 확인 중..."
TESSDATA_DIR="${TESSDATA_PREFIX:-/usr/local/share/tessdata}"
mkdir -p "$TESSDATA_DIR"

for lang in eng kor osd; do
    if [ ! -f "$TESSDATA_DIR/$lang.traineddata" ]; then
        echo "  $lang.traineddata 다운로드 중..."
        wget -q -O "$TESSDATA_DIR/$lang.traineddata" \
            "https://github.com/tesseract-ocr/tessdata_best/raw/main/$lang.traineddata"
    else
        echo "  $lang.traineddata 이미 존재"
    fi
done

# 4. 설치 확인
echo "[4/4] 설치 확인..."
echo "  Tesseract: $(tesseract --version 2>&1 | head -1)"
echo "  ocrmypdf: $(python3 -c 'import ocrmypdf; print(ocrmypdf.__version__)')"
export TESSDATA_PREFIX="$TESSDATA_DIR"
echo "  사용 가능한 언어: $(tesseract --list-langs 2>&1 | grep -v '^Error\|^List\|^$')"

echo ""
echo "=== 설치 완료! ==="
echo "사용법: ocrmypdf -l kor+eng input.pdf output.pdf"
echo "환경변수: export TESSDATA_PREFIX=$TESSDATA_DIR"
