# Phone Controller Project

이 프로젝트는 Termux:API를 활용하여 Android 폰을 제어하는 프로젝트입니다.
사용자가 자연어로 요청하면 아래 명령어들을 활용하여 실행합니다.

## 사용 가능한 Termux:API 명령어

### 기기 정보
- `termux-battery-status` - 배터리 상태 확인
- `termux-wifi-connectioninfo` - WiFi 연결 정보
- `termux-wifi-scaninfo` - 주변 WiFi 스캔
- `termux-telephony-deviceinfo` - 전화 디바이스 정보
- `termux-telephony-cellinfo` - 셀 정보

### 카메라
- `termux-camera-photo -c 0 FILE` - 후면 카메라 촬영 (0=후면, 1=전면)
- `termux-camera-info` - 카메라 정보

### SMS / 전화
- `termux-sms-send -n NUMBER "MESSAGE"` - SMS 보내기
- `termux-sms-list -l LIMIT` - SMS 목록 읽기
- `termux-telephony-call NUMBER` - 전화 걸기

### 위치
- `termux-location -p gps` - GPS 위치 (gps/network/passive)

### 알림 / UI
- `termux-notification -t "TITLE" -c "CONTENT"` - 알림 보내기
- `termux-notification-remove ID` - 알림 제거
- `termux-toast "MESSAGE"` - 토스트 메시지
- `termux-dialog` - 다이얼로그 표시
- `termux-vibrate -d MS` - 진동 (밀리초)

### 미디어
- `termux-media-player play FILE` - 미디어 재생
- `termux-media-player pause` - 일시정지
- `termux-media-player stop` - 정지
- `termux-media-scan FILE` - 미디어 스캔
- `termux-volume STREAM VOLUME` - 볼륨 조절 (music/ring/alarm/notification, 0-15)
- `termux-tts-speak "TEXT"` - TTS 음성 출력
- `termux-microphone-record -f FILE` - 마이크 녹음
- `termux-microphone-record -q` - 녹음 중지

### 센서
- `termux-sensor -s SENSOR -n 1` - 센서 데이터 읽기
- `termux-sensor -l` - 센서 목록
- `termux-brightness VALUE` - 화면 밝기 (0-255)
- `termux-torch on/off` - 손전등

### 클립보드
- `termux-clipboard-get` - 클립보드 읽기
- `termux-clipboard-set "TEXT"` - 클립보드 쓰기

### 기타
- `termux-share FILE` - 공유 메뉴 열기
- `termux-open URL` - URL/파일 열기
- `termux-open-url URL` - 브라우저로 URL 열기
- `termux-download URL` - 파일 다운로드
- `termux-contact-list` - 연락처 목록
- `termux-call-log -l LIMIT` - 통화 기록
- `termux-fingerprint` - 지문 인증
- `termux-wallpaper -f FILE` - 배경화면 설정
- `termux-wallpaper -u URL` - URL로 배경화면 설정

## 폰-컴퓨터 연결

### 연결 스크립트
- `bash connect.sh` - 대화형 연결 메뉴 실행
- `bash connect.sh start` - SSH + HTTP 서버 동시 시작
- `bash connect.sh ssh` - SSH 서버만 시작
- `bash connect.sh http` - HTTP 파일 서버만 시작
- `bash connect.sh stop` - 모든 서버 중지
- `bash connect.sh status` - 연결 상태 확인
- `bash connect.sh adb` - ADB 무선 연결 안내

### 빠른 상태 확인
- `bash connection-status.sh` - 현재 연결 상태 + 접속 명령어 표시

### 연결 방법 요약
| 방법 | 포트 | 용도 |
|------|------|------|
| SSH | 8022 | 터미널 접속, 파일 전송 (scp) |
| HTTP | 8080 | 브라우저로 파일 탐색 |
| ADB 무선 | 5555 | Android 디버그 브리지 |

## 앱 관리

### 앱 삭제
- `bash remove-app.sh <패키지명 또는 앱이름>` - 앱 삭제
- `bash remove-app.sh canon` - 캐논 프린터 앱 삭제
- `bash remove-app.sh 캐논프린터` - 캐논 프린터 앱 삭제 (한국어)

### 지원되는 앱 삭제 방법
| 방법 | 명령 | 설명 |
|------|------|------|
| 시스템 삭제 화면 | `am start -a android.intent.action.DELETE -d package:PACKAGE` | 확인 후 삭제 (권장) |
| 직접 삭제 | `pm uninstall --user 0 PACKAGE` | 바로 삭제 |

## 사용 규칙
- 사용자가 한국어로 요청하면 해당하는 termux-api 명령을 Bash로 실행
- 결과를 한국어로 알기 쉽게 요약하여 보여줌
- SMS, 전화 등 민감한 작업은 실행 전 반드시 확인
- 사진/녹음 파일은 /data/data/com.termux/files/home/my-project/media/ 에 저장
