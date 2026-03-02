#!/bin/bash
# PDF OCR 실행 스크립트
# 스캔된 PDF에서 텍스트를 추출합니다
#
# 사용법:
#   bash pdf-ocr.sh input.pdf                    # 영어 OCR
#   bash pdf-ocr.sh input.pdf -l kor             # 한국어 OCR
#   bash pdf-ocr.sh input.pdf -l kor+eng         # 한국어+영어 OCR
#   bash pdf-ocr.sh input.pdf -l kor+eng -t      # 텍스트만 추출 (PDF 생성 안함)

set -e

# TESSDATA_PREFIX 설정
export TESSDATA_PREFIX="${TESSDATA_PREFIX:-/usr/local/share/tessdata}"

INPUT=""
LANG="eng"
TEXT_ONLY=false

# 인자 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--lang)
            LANG="$2"
            shift 2
            ;;
        -t|--text)
            TEXT_ONLY=true
            shift
            ;;
        -h|--help)
            echo "사용법: bash pdf-ocr.sh <input.pdf> [-l 언어] [-t]"
            echo ""
            echo "옵션:"
            echo "  -l, --lang LANG   OCR 언어 (기본: eng, 예: kor, kor+eng)"
            echo "  -t, --text        텍스트만 추출 (stdout 출력)"
            echo "  -h, --help        도움말"
            exit 0
            ;;
        *)
            INPUT="$1"
            shift
            ;;
    esac
done

if [ -z "$INPUT" ]; then
    echo "오류: 입력 PDF 파일을 지정하세요"
    echo "사용법: bash pdf-ocr.sh <input.pdf> [-l 언어] [-t]"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "오류: 파일을 찾을 수 없습니다: $INPUT"
    exit 1
fi

# 출력 파일명 생성
BASENAME="${INPUT%.pdf}"
OUTPUT="${BASENAME}_ocr.pdf"

echo "=== PDF OCR 처리 ==="
echo "  입력: $INPUT"
echo "  언어: $LANG"

# OCR 실행
ocrmypdf -l "$LANG" --skip-text --optimize 1 "$INPUT" "$OUTPUT" 2>&1

if [ "$TEXT_ONLY" = true ]; then
    echo ""
    echo "=== 추출된 텍스트 ==="
    python3 -c "
from pdfminer.high_level import extract_text
text = extract_text('$OUTPUT')
print(text)
"
else
    echo ""
    echo "=== OCR 완료 ==="
    echo "  출력: $OUTPUT"
    echo ""
    echo "텍스트 추출: bash pdf-ocr.sh $INPUT -l $LANG -t"
fi
