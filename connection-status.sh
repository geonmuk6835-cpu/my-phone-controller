#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# 폰-컴퓨터 연결 상태 빠른 확인 스크립트
# =====================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "===== 연결 상태 ====="
echo ""

# IP 주소
ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)
if [ -z "$ip" ]; then
    ip=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' || echo "없음")
fi
echo -e "IP 주소:    ${GREEN}${ip}${NC}"

# WiFi
if command -v termux-wifi-connectioninfo &>/dev/null; then
    wifi=$(termux-wifi-connectioninfo 2>/dev/null || echo '{}')
    ssid=$(echo "$wifi" | grep -o '"ssid":"[^"]*"' | cut -d'"' -f4 || echo "-")
    echo -e "WiFi:       ${GREEN}${ssid}${NC}"
fi

# SSH
if pgrep -x sshd >/dev/null 2>&1; then
    echo -e "SSH:        ${GREEN}실행 중${NC} (포트 8022)"
else
    echo -e "SSH:        ${RED}중지${NC}"
fi

# HTTP
if pgrep -f "python.*http.server.*8080" >/dev/null 2>&1; then
    echo -e "HTTP 서버:  ${GREEN}실행 중${NC} (포트 8080)"
else
    echo -e "HTTP 서버:  ${RED}중지${NC}"
fi

# 배터리 (Termux:API)
if command -v termux-battery-status &>/dev/null; then
    battery=$(termux-battery-status 2>/dev/null || echo '{}')
    pct=$(echo "$battery" | grep -o '"percentage":[0-9]*' | cut -d: -f2 || echo "?")
    status=$(echo "$battery" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "?")
    echo -e "배터리:     ${GREEN}${pct}%${NC} (${status})"
fi

echo ""
echo "===== 접속 명령어 ====="
echo ""
user=$(whoami)
echo -e "SSH:  ${YELLOW}ssh ${user}@${ip} -p 8022${NC}"
echo -e "SCP:  ${YELLOW}scp -P 8022 file ${user}@${ip}:~/${NC}"
echo -e "HTTP: ${YELLOW}http://${ip}:8080${NC}"
echo ""
