#!/bin/bash
# 캐논 프린트 앱(Canon PRINT Inkjet/SELPHY) 삭제 스크립트

PACKAGE="jp.co.canon.bsd.ad.pixmaprint"

echo "캐논 프린트 앱 삭제를 시작합니다..."
echo "패키지: $PACKAGE"

# 앱 설치 여부 확인
if pm list packages 2>/dev/null | grep -q "$PACKAGE"; then
    echo "앱이 설치되어 있습니다. 삭제를 진행합니다..."
    pm uninstall "$PACKAGE"
    if [ $? -eq 0 ]; then
        echo "캐논 프린트 앱이 삭제되었습니다."
    else
        echo "일반 삭제 실패. 시스템 앱일 수 있습니다."
        echo "사용자 영역에서 비활성화를 시도합니다..."
        pm uninstall -k --user 0 "$PACKAGE"
        if [ $? -eq 0 ]; then
            echo "현재 사용자에서 캐논 프린트 앱이 제거되었습니다."
        else
            echo "삭제에 실패했습니다. 설정 > 앱에서 직접 삭제해 주세요."
        fi
    fi
else
    echo "캐논 프린트 앱이 설치되어 있지 않습니다."
fi
