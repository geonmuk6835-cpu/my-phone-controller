#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# Phone-Computer Connection Script
# Termux에서 실행하여 폰과 컴퓨터를 연결합니다
# =====================================================

set -e

MEDIA_DIR="$HOME/my-project/media"
PORT_SSH=8022
PORT_HTTP=8080

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "============================================"
    echo "   Phone <-> Computer 연결 도구"
    echo "============================================"
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[X]${NC} $1"
}

# 현재 IP 주소 가져오기
get_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
    if [ -z "$ip" ]; then
        ip=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' || true)
    fi
    if [ -z "$ip" ]; then
        ip="(IP를 찾을 수 없음 - WiFi 연결을 확인하세요)"
    fi
    echo "$ip"
}

# 필수 패키지 설치 확인
check_packages() {
    echo -e "\n${BLUE}[1/3] 필수 패키지 확인 중...${NC}"

    local packages=("openssh" "nmap" "python")
    local missing=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        print_warn "설치되지 않은 패키지: ${missing[*]}"
        echo "설치하시겠습니까? (y/n)"
        read -r answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            pkg install -y "${missing[@]}"
            print_status "패키지 설치 완료"
        else
            print_warn "일부 연결 방식이 동작하지 않을 수 있습니다"
        fi
    else
        print_status "필수 패키지 모두 설치됨"
    fi
}

# SSH 서버 시작
start_ssh() {
    echo -e "\n${BLUE}[SSH 서버 시작]${NC}"

    # SSH 키가 없으면 생성
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_warn "SSH 호스트 키 생성 중..."
        ssh-keygen -A 2>/dev/null || true
    fi

    # 비밀번호 설정 확인
    if ! passwd -S 2>/dev/null | grep -q " P "; then
        print_warn "Termux 비밀번호가 설정되지 않았습니다"
        echo "SSH 접속을 위해 비밀번호를 설정하세요:"
        passwd
    fi

    # sshd 시작
    if pgrep -x sshd >/dev/null 2>&1; then
        print_status "SSH 서버가 이미 실행 중입니다"
    else
        sshd
        if pgrep -x sshd >/dev/null 2>&1; then
            print_status "SSH 서버 시작됨"
        else
            print_error "SSH 서버 시작 실패"
            return 1
        fi
    fi

    local ip
    ip=$(get_ip)
    local user
    user=$(whoami)

    echo ""
    echo -e "  ${GREEN}컴퓨터에서 다음 명령어로 접속하세요:${NC}"
    echo ""
    echo -e "  ${YELLOW}ssh ${user}@${ip} -p ${PORT_SSH}${NC}"
    echo ""
    echo -e "  또는 파일 복사:"
    echo -e "  ${YELLOW}scp -P ${PORT_SSH} file.txt ${user}@${ip}:~/${NC}"
    echo ""
}

# HTTP 파일 서버 시작
start_http() {
    echo -e "\n${BLUE}[HTTP 파일 서버 시작]${NC}"

    # 미디어 디렉토리 생성
    mkdir -p "$MEDIA_DIR"

    # 기존 HTTP 서버 종료
    if pgrep -f "python.*http.server.*${PORT_HTTP}" >/dev/null 2>&1; then
        print_status "HTTP 서버가 이미 실행 중입니다"
    else
        cd "$HOME"
        python -m http.server "$PORT_HTTP" &>/dev/null &
        sleep 1

        if pgrep -f "python.*http.server.*${PORT_HTTP}" >/dev/null 2>&1; then
            print_status "HTTP 파일 서버 시작됨"
        else
            print_error "HTTP 서버 시작 실패"
            return 1
        fi
    fi

    local ip
    ip=$(get_ip)

    echo ""
    echo -e "  ${GREEN}컴퓨터 브라우저에서 접속하세요:${NC}"
    echo ""
    echo -e "  ${YELLOW}http://${ip}:${PORT_HTTP}${NC}"
    echo ""
    echo -e "  폰의 홈 디렉토리 파일을 브라우저에서 볼 수 있습니다"
    echo ""
}

# 연결 상태 표시
show_status() {
    echo -e "\n${BLUE}[연결 상태]${NC}"

    local ip
    ip=$(get_ip)
    echo -e "  폰 IP 주소: ${GREEN}${ip}${NC}"
    echo ""

    # WiFi 상태
    if command -v termux-wifi-connectioninfo &>/dev/null; then
        local wifi_info
        wifi_info=$(termux-wifi-connectioninfo 2>/dev/null || echo '{}')
        local ssid
        ssid=$(echo "$wifi_info" | grep -o '"ssid":"[^"]*"' | cut -d'"' -f4 || echo "알 수 없음")
        echo -e "  WiFi SSID: ${GREEN}${ssid}${NC}"
    fi

    # SSH 상태
    if pgrep -x sshd >/dev/null 2>&1; then
        echo -e "  SSH 서버:   ${GREEN}실행 중${NC} (포트 ${PORT_SSH})"
    else
        echo -e "  SSH 서버:   ${RED}중지됨${NC}"
    fi

    # HTTP 상태
    if pgrep -f "python.*http.server.*${PORT_HTTP}" >/dev/null 2>&1; then
        echo -e "  HTTP 서버:  ${GREEN}실행 중${NC} (포트 ${PORT_HTTP})"
    else
        echo -e "  HTTP 서버:  ${RED}중지됨${NC}"
    fi

    echo ""
}

# 모든 서버 중지
stop_all() {
    echo -e "\n${BLUE}[서버 중지]${NC}"

    if pgrep -x sshd >/dev/null 2>&1; then
        pkill sshd
        print_status "SSH 서버 중지됨"
    fi

    if pgrep -f "python.*http.server.*${PORT_HTTP}" >/dev/null 2>&1; then
        pkill -f "python.*http.server.*${PORT_HTTP}"
        print_status "HTTP 서버 중지됨"
    fi

    print_status "모든 서버가 중지되었습니다"
}

# ADB 무선 연결 설정 (USB 연결 상태에서)
setup_adb_wireless() {
    echo -e "\n${BLUE}[ADB 무선 디버깅 안내]${NC}"
    echo ""
    echo "  ADB 무선 연결 방법:"
    echo ""
    echo "  1. 폰에서 '개발자 옵션' 활성화"
    echo "     설정 > 휴대전화 정보 > 빌드번호 7번 터치"
    echo ""
    echo "  2. '무선 디버깅' 활성화"
    echo "     설정 > 개발자 옵션 > 무선 디버깅"
    echo ""
    echo "  3. 컴퓨터에서 ADB로 연결:"

    local ip
    ip=$(get_ip)
    echo ""
    echo -e "     ${YELLOW}adb connect ${ip}:5555${NC}"
    echo ""
    echo "  4. 연결 후 사용 가능한 명령어:"
    echo -e "     ${YELLOW}adb shell${NC}        - 폰 쉘 접속"
    echo -e "     ${YELLOW}adb push/pull${NC}    - 파일 전송"
    echo -e "     ${YELLOW}adb install${NC}      - 앱 설치"
    echo ""
}

# 메인 메뉴
main_menu() {
    print_header

    echo "연결 방식을 선택하세요:"
    echo ""
    echo "  1) SSH 연결    - 컴퓨터에서 폰 터미널 접속 + 파일 전송"
    echo "  2) HTTP 서버   - 브라우저로 폰 파일 접근"
    echo "  3) 모두 시작   - SSH + HTTP 동시 시작"
    echo "  4) ADB 무선    - ADB 무선 디버깅 설정 안내"
    echo "  5) 상태 확인   - 현재 연결 상태 보기"
    echo "  6) 모두 중지   - 모든 서버 중지"
    echo "  0) 종료"
    echo ""
    echo -n "선택: "
    read -r choice

    case $choice in
        1)
            check_packages
            start_ssh
            ;;
        2)
            check_packages
            start_http
            ;;
        3)
            check_packages
            start_ssh
            start_http
            echo -e "\n${GREEN}============================================${NC}"
            echo -e "${GREEN}  모든 연결 서비스가 시작되었습니다!${NC}"
            echo -e "${GREEN}============================================${NC}"
            show_status
            ;;
        4)
            setup_adb_wireless
            ;;
        5)
            show_status
            ;;
        6)
            stop_all
            ;;
        0)
            echo "종료합니다."
            exit 0
            ;;
        *)
            print_error "잘못된 선택입니다"
            ;;
    esac
}

# 명령줄 인수 처리
case "${1:-}" in
    ssh)
        check_packages
        start_ssh
        ;;
    http)
        check_packages
        start_http
        ;;
    start)
        check_packages
        start_ssh
        start_http
        show_status
        ;;
    stop)
        stop_all
        ;;
    status)
        show_status
        ;;
    adb)
        setup_adb_wireless
        ;;
    *)
        main_menu
        ;;
esac
