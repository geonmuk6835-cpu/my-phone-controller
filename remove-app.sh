#!/data/data/com.termux/files/usr/bin/bash
# 앱 삭제 스크립트 - Termux에서 Android 앱을 삭제합니다

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 알려진 앱 패키지명 목록
declare -A KNOWN_APPS
KNOWN_APPS=(
    ["캐논프린터"]="jp.co.canon.bsd.ad.pixmaprint"
    ["canon print"]="jp.co.canon.bsd.ad.pixmaprint"
    ["canon"]="jp.co.canon.bsd.ad.pixmaprint"
)

show_help() {
    echo -e "${BLUE}📱 앱 삭제 도구${NC}"
    echo ""
    echo "사용법:"
    echo "  bash remove-app.sh <패키지명 또는 앱이름>"
    echo ""
    echo "예시:"
    echo "  bash remove-app.sh jp.co.canon.bsd.ad.pixmaprint"
    echo "  bash remove-app.sh canon"
    echo "  bash remove-app.sh 캐논프린터"
    echo ""
    echo "알려진 앱:"
    for key in "${!KNOWN_APPS[@]}"; do
        echo "  $key -> ${KNOWN_APPS[$key]}"
    done
}

resolve_package() {
    local input="$1"
    local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')

    # 알려진 앱 이름에서 검색
    for key in "${!KNOWN_APPS[@]}"; do
        local lower_key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        if [[ "$lower_key" == "$lower_input" ]]; then
            echo "${KNOWN_APPS[$key]}"
            return 0
        fi
    done

    # 패키지명 형식이면 그대로 반환 (점이 포함된 경우)
    if [[ "$input" == *.* ]]; then
        echo "$input"
        return 0
    fi

    return 1
}

uninstall_app() {
    local package="$1"

    echo -e "${YELLOW}앱 확인 중: ${package}${NC}"

    # 앱이 설치되어 있는지 확인
    if pm list packages 2>/dev/null | grep -q "$package"; then
        echo -e "${GREEN}앱이 설치되어 있습니다: ${package}${NC}"
    else
        echo -e "${RED}앱이 설치되어 있지 않거나 확인할 수 없습니다: ${package}${NC}"
        echo -e "${YELLOW}그래도 삭제를 시도합니다...${NC}"
    fi

    echo ""
    echo -e "${YELLOW}삭제 방법을 선택하세요:${NC}"
    echo "  1) 시스템 삭제 화면 열기 (권장)"
    echo "  2) 직접 삭제 시도 (pm uninstall)"
    echo "  3) 취소"
    echo ""
    read -p "선택 (1/2/3): " choice

    case $choice in
        1)
            echo -e "${BLUE}삭제 화면을 엽니다...${NC}"
            am start -a android.intent.action.DELETE -d "package:${package}" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}삭제 화면이 열렸습니다. 화면에서 '삭제'를 눌러주세요.${NC}"
            else
                echo -e "${RED}삭제 화면을 열 수 없습니다.${NC}"
                echo -e "${YELLOW}설정 > 앱 에서 직접 삭제해주세요.${NC}"
            fi
            ;;
        2)
            echo -e "${BLUE}직접 삭제를 시도합니다...${NC}"
            pm uninstall --user 0 "$package" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}앱이 삭제되었습니다!${NC}"
            else
                echo -e "${RED}직접 삭제에 실패했습니다.${NC}"
                echo -e "${YELLOW}시스템 삭제 화면을 대신 엽니다...${NC}"
                am start -a android.intent.action.DELETE -d "package:${package}" 2>/dev/null
            fi
            ;;
        3)
            echo -e "${YELLOW}취소되었습니다.${NC}"
            ;;
        *)
            echo -e "${RED}잘못된 선택입니다.${NC}"
            ;;
    esac
}

# 메인
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

# 모든 인자를 하나로 합침
INPUT="$*"

PACKAGE=$(resolve_package "$INPUT")
if [ $? -ne 0 ]; then
    echo -e "${RED}알 수 없는 앱 이름입니다: ${INPUT}${NC}"
    echo -e "${YELLOW}패키지명을 직접 입력해주세요.${NC}"
    echo ""
    show_help
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📱 앱 삭제: ${PACKAGE}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

uninstall_app "$PACKAGE"
