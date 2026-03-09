#!/usr/bin/env python3
"""
부산 강서구 명지동(EDC) 토지 매매 실거래가 Excel Export
- 감사인 제출용
- 출처: 국토교통부 실거래가 공개시스템 (data.go.kr)
"""

import argparse
import os
import sys
import time
from datetime import datetime

import openpyxl
from openpyxl.styles import Font, Alignment, Border, Side, PatternFill
from openpyxl.utils import get_column_letter

# ── 설정 ──────────────────────────────────────────────
LAWD_CD = "26440"           # 부산광역시 강서구
TARGET_DONG = "명지동"
TARGET_JIBUN_MAIN = "121"   # 본번
TARGET_JIBUN_SUB = "4"      # 부번
TARGET_JIBUN = f"{TARGET_JIBUN_MAIN}-{TARGET_JIBUN_SUB}"

START_YM = "202303"
END_YM = "202603"

OUTPUT_DIR = "land_data"

# ── 스타일 ────────────────────────────────────────────
TITLE_FONT = Font(name="맑은 고딕", size=14, bold=True)
HEADER_FONT = Font(name="맑은 고딕", size=10, bold=True, color="FFFFFF")
DATA_FONT = Font(name="맑은 고딕", size=10)
NOTE_FONT = Font(name="맑은 고딕", size=9, italic=True, color="888888")
SUMMARY_FONT = Font(name="맑은 고딕", size=10, bold=True)

HEADER_FILL = PatternFill(start_color="2F5496", end_color="2F5496", fill_type="solid")
ALT_ROW_FILL = PatternFill(start_color="D6E4F0", end_color="D6E4F0", fill_type="solid")
TARGET_HIGHLIGHT = PatternFill(start_color="FFF2CC", end_color="FFF2CC", fill_type="solid")
TOTAL_FILL = PatternFill(start_color="E2EFDA", end_color="E2EFDA", fill_type="solid")

THIN_BORDER = Border(
    left=Side(style="thin"), right=Side(style="thin"),
    top=Side(style="thin"), bottom=Side(style="thin"),
)
CENTER = Alignment(horizontal="center", vertical="center", wrap_text=True)
RIGHT = Alignment(horizontal="right", vertical="center")
LEFT = Alignment(horizontal="left", vertical="center", wrap_text=True)

# ── 컬럼 정의 ────────────────────────────────────────
COLUMNS = [
    ("No.", 6, CENTER),
    ("거래일자", 14, CENTER),
    ("법정동", 10, CENTER),
    ("지번", 12, CENTER),
    ("지목", 8, CENTER),
    ("용도지역", 16, CENTER),
    ("거래면적(㎡)", 14, RIGHT),
    ("거래금액(만원)", 16, RIGHT),
    ("단가(만원/㎡)", 14, RIGHT),
    ("단가(만원/평)", 14, RIGHT),
    ("거래유형", 10, CENTER),
]

TREND_COLUMNS = [
    ("기간", 18, CENTER),
    ("거래건수", 10, RIGHT),
    ("평균 단가(만원/㎡)", 18, RIGHT),
    ("최저 단가(만원/㎡)", 18, RIGHT),
    ("최고 단가(만원/㎡)", 18, RIGHT),
    ("평균 거래면적(㎡)", 16, RIGHT),
    ("총 거래금액(만원)", 16, RIGHT),
]


def get_api_key(args):
    """API 키를 CLI 인자 또는 환경변수에서 가져온다."""
    key = args.api_key or os.environ.get("DATA_GO_KR_API_KEY")
    if not key:
        print("=" * 60)
        print("  API 서비스키가 필요합니다!")
        print()
        print("  1. https://www.data.go.kr 에 회원가입")
        print("  2. '국토교통부_토지 매매 실거래가 자료' API 활용 신청")
        print("     https://www.data.go.kr/data/15126466/openapi.do")
        print("  3. 발급받은 서비스키로 실행:")
        print()
        print('     python3 land_transaction_export.py --api-key "서비스키"')
        print("     # 또는")
        print('     export DATA_GO_KR_API_KEY="서비스키"')
        print("     python3 land_transaction_export.py")
        print("=" * 60)
        sys.exit(1)
    return key


def fetch_with_publicdatareader(api_key, lawd_cd, start_ym, end_ym):
    """PublicDataReader 라이브러리를 사용하여 데이터 조회."""
    from PublicDataReader import TransactionPrice

    print(f"[PublicDataReader] 토지 매매 실거래가 조회 중...")
    print(f"  시군구코드: {lawd_cd}, 기간: {start_ym} ~ {end_ym}")

    api = TransactionPrice(api_key)
    df = api.get_data(
        property_type="토지",
        trade_type="매매",
        sigungu_code=lawd_cd,
        start_year_month=start_ym,
        end_year_month=end_ym,
    )

    if df is None or len(df) == 0:
        print("  → 조회된 데이터가 없습니다.")
        return []

    print(f"  → {len(df)}건 조회 완료")
    return df.to_dict("records")


def fetch_with_requests(api_key, lawd_cd, start_ym, end_ym):
    """requests + XML 파싱으로 직접 API 호출 (fallback)."""
    import xml.etree.ElementTree as ET
    import requests

    base_url = "http://apis.data.go.kr/1613000/RTMSDataSvcLandTrade/getRTMSDataSvcLandTrade"
    all_records = []

    # 월별 목록 생성
    months = []
    y, m = int(start_ym[:4]), int(start_ym[4:])
    ey, em = int(end_ym[:4]), int(end_ym[4:])
    while (y, m) <= (ey, em):
        months.append(f"{y:04d}{m:02d}")
        m += 1
        if m > 12:
            m = 1
            y += 1

    print(f"[requests] 토지 매매 실거래가 조회 중... ({len(months)}개월)")

    for i, ym in enumerate(months):
        params = {
            "serviceKey": api_key,
            "LAWD_CD": lawd_cd,
            "DEAL_YMD": ym,
            "numOfRows": "1000",
            "pageNo": "1",
        }
        try:
            resp = requests.get(base_url, params=params, timeout=30)
            resp.raise_for_status()
        except Exception as e:
            print(f"  {ym} 조회 실패: {e}")
            time.sleep(1)
            # 1회 재시도
            try:
                resp = requests.get(base_url, params=params, timeout=30)
                resp.raise_for_status()
            except Exception:
                print(f"  {ym} 재시도 실패, 건너뜀")
                continue

        root = ET.fromstring(resp.text)

        # 에러 체크
        result_code = root.findtext(".//resultCode")
        if result_code and result_code != "00":
            result_msg = root.findtext(".//resultMsg", "알 수 없는 오류")
            print(f"  {ym} API 오류: [{result_code}] {result_msg}")
            if result_code in ("SERVICE_KEY_IS_NOT_REGISTERED_ERROR", "30"):
                print("  → API 키가 유효하지 않습니다. 키를 확인해주세요.")
                sys.exit(1)
            continue

        items = root.findall(".//item")
        for item in items:
            record = {}
            for child in item:
                text = child.text.strip() if child.text else ""
                record[child.tag] = text
            all_records.append(record)

        if (i + 1) % 10 == 0:
            print(f"  {i + 1}/{len(months)} 개월 처리 완료...")
        time.sleep(0.5)

    print(f"  → 총 {len(all_records)}건 조회 완료")
    return all_records


def fetch_land_transactions(api_key, lawd_cd, start_ym, end_ym):
    """데이터 조회 - PublicDataReader 우선, 실패 시 requests fallback."""
    try:
        records = fetch_with_publicdatareader(api_key, lawd_cd, start_ym, end_ym)
        if records:
            return records
    except Exception as e:
        print(f"[PublicDataReader 오류: {e}]")
        print("→ requests 방식으로 전환합니다...")

    return fetch_with_requests(api_key, lawd_cd, start_ym, end_ym)


def normalize_records(records):
    """레코드를 통일된 형식으로 정규화."""
    # PublicDataReader 컬럼명 매핑
    key_map = {
        "법정동": ["법정동", "umdNm"],
        "지번": ["지번", "jibun", "lndpclAr"],
        "지목": ["지목", "jimok", "sggCd"],
        "용도지역": ["용도지역", "usgRgnNm"],
        "거래면적": ["거래면적", "dealArea", "dealAmount"],
        "거래금액": ["거래금액", "dealAmount"],
        "년": ["년", "dealYear"],
        "월": ["월", "dealMonth"],
        "일": ["일", "dealDay"],
        "거래유형": ["거래유형", "dealType", "reqGbn"],
    }

    normalized = []
    for r in records:
        nr = {}

        # 각 필드 추출
        for target, sources in key_map.items():
            for src in sources:
                if src in r and r[src]:
                    val = str(r[src]).strip()
                    if val:
                        nr[target] = val
                        break

        # 거래면적/거래금액 숫자 변환
        try:
            area_str = nr.get("거래면적", "0")
            nr["거래면적_num"] = float(str(area_str).replace(",", ""))
        except (ValueError, TypeError):
            nr["거래면적_num"] = 0.0

        try:
            amount_str = nr.get("거래금액", "0")
            nr["거래금액_num"] = int(str(amount_str).replace(",", "").strip())
        except (ValueError, TypeError):
            nr["거래금액_num"] = 0

        # 단가 계산
        if nr["거래면적_num"] > 0:
            nr["단가_sqm"] = round(nr["거래금액_num"] / nr["거래면적_num"], 1)
            nr["단가_pyeong"] = round(nr["단가_sqm"] * 3.3058, 1)
        else:
            nr["단가_sqm"] = 0
            nr["단가_pyeong"] = 0

        # 거래일자
        y = nr.get("년", "")
        m = nr.get("월", "")
        d = nr.get("일", "")
        if y and m:
            nr["거래일자"] = f"{y}.{int(m):02d}.{int(d):02d}" if d else f"{y}.{int(m):02d}"
            nr["정렬키"] = f"{y}{int(m):02d}{int(d or 0):02d}"
        else:
            nr["거래일자"] = ""
            nr["정렬키"] = ""

        # 반기 계산
        if y and m:
            half = "상반기" if int(m) <= 6 else "하반기"
            nr["반기"] = f"{y}년 {half}"
        else:
            nr["반기"] = ""

        normalized.append(nr)

    # 거래일자 기준 정렬
    normalized.sort(key=lambda x: x.get("정렬키", ""), reverse=True)
    return normalized


def match_jibun(jibun_str, main_num):
    """지번이 특정 본번과 매칭되는지 확인."""
    if not jibun_str:
        return False
    jibun = str(jibun_str).strip()
    # "121" 또는 "121-4" 또는 " 121" 등
    parts = jibun.replace(" ", "").split("-")
    try:
        return str(int(parts[0])) == str(main_num)
    except (ValueError, IndexError):
        return jibun.startswith(str(main_num))


def filter_target(records):
    """대상 필지(명지동 121번대) 거래 필터링."""
    return [
        r for r in records
        if r.get("법정동", "") == TARGET_DONG
        and match_jibun(r.get("지번", ""), TARGET_JIBUN_MAIN)
    ]


def filter_nearby(records):
    """주변 비교 거래(명지동 내 기타) 필터링."""
    return [
        r for r in records
        if r.get("법정동", "") == TARGET_DONG
        and not match_jibun(r.get("지번", ""), TARGET_JIBUN_MAIN)
    ]


def calculate_trend(records):
    """명지동 전체 반기별 추이 요약."""
    dong_records = [r for r in records if r.get("법정동", "") == TARGET_DONG]

    # 반기별 그룹핑
    groups = {}
    for r in dong_records:
        key = r.get("반기", "")
        if not key:
            continue
        if key not in groups:
            groups[key] = []
        groups[key].append(r)

    # 정렬된 반기 목록
    period_order = []
    for y in range(2023, 2027):
        for h in ["상반기", "하반기"]:
            p = f"{y}년 {h}"
            if p in groups:
                period_order.append(p)

    summaries = []
    for period in period_order:
        recs = groups[period]
        prices = [r["단가_sqm"] for r in recs if r["단가_sqm"] > 0]
        areas = [r["거래면적_num"] for r in recs if r["거래면적_num"] > 0]
        amounts = [r["거래금액_num"] for r in recs]

        summaries.append({
            "기간": period,
            "거래건수": len(recs),
            "평균단가": round(sum(prices) / len(prices), 1) if prices else 0,
            "최저단가": round(min(prices), 1) if prices else 0,
            "최고단가": round(max(prices), 1) if prices else 0,
            "평균면적": round(sum(areas) / len(areas), 1) if areas else 0,
            "총거래금액": sum(amounts),
        })

    return summaries


def apply_cell_style(cell, font=DATA_FONT, alignment=CENTER, border=THIN_BORDER, fill=None, number_format=None):
    """셀 스타일 적용."""
    cell.font = font
    cell.alignment = alignment
    cell.border = border
    if fill:
        cell.fill = fill
    if number_format:
        cell.number_format = number_format


def write_header_row(ws, row, columns, start_col=1):
    """헤더 행 작성."""
    for i, (name, width, align) in enumerate(columns):
        col = start_col + i
        cell = ws.cell(row=row, column=col, value=name)
        apply_cell_style(cell, font=HEADER_FONT, alignment=CENTER, fill=HEADER_FILL)
        ws.column_dimensions[get_column_letter(col)].width = width


def write_data_row(ws, row, record, idx, is_target=False, is_alt=False):
    """거래 데이터 행 작성."""
    fill = TARGET_HIGHLIGHT if is_target else (ALT_ROW_FILL if is_alt else None)

    values = [
        idx,
        record.get("거래일자", ""),
        record.get("법정동", ""),
        record.get("지번", ""),
        record.get("지목", ""),
        record.get("용도지역", ""),
        record.get("거래면적_num", 0),
        record.get("거래금액_num", 0),
        record.get("단가_sqm", 0),
        record.get("단가_pyeong", 0),
        record.get("거래유형", ""),
    ]

    formats = [
        None, None, None, None, None, None,
        "#,##0.00", "#,##0", "#,##0.0", "#,##0.0", None,
    ]

    for i, (val, nf) in enumerate(zip(values, formats)):
        col = i + 1
        cell = ws.cell(row=row, column=col, value=val)
        align = COLUMNS[i][2]
        apply_cell_style(cell, alignment=align, fill=fill, number_format=nf)


def create_sheet_transactions(wb, title, subtitle, records, sheet_name):
    """거래내역 시트 생성 (Sheet 1 & 2 공통)."""
    ws = wb.create_sheet(title=sheet_name)
    col_count = len(COLUMNS)

    # 제목
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=col_count)
    cell = ws.cell(row=1, column=1, value=title)
    apply_cell_style(cell, font=TITLE_FONT, alignment=Alignment(horizontal="center", vertical="center"), border=None)
    ws.row_dimensions[1].height = 30

    # 부제
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=col_count)
    cell = ws.cell(row=2, column=1, value=subtitle)
    apply_cell_style(cell, font=NOTE_FONT, alignment=CENTER, border=None)

    # 빈 행
    header_row = 4

    # 헤더
    write_header_row(ws, header_row, COLUMNS)

    if not records:
        ws.merge_cells(start_row=header_row + 1, start_column=1, end_row=header_row + 1, end_column=col_count)
        cell = ws.cell(row=header_row + 1, column=1,
                       value=f"해당 지번({TARGET_JIBUN})의 거래 이력이 없습니다. 인근 유사 거래를 주변 비교 시트에서 확인하세요.")
        apply_cell_style(cell, font=NOTE_FONT, alignment=CENTER)
        data_end_row = header_row + 1
    else:
        for idx, record in enumerate(records, 1):
            row = header_row + idx
            jibun = record.get("지번", "")
            is_target = TARGET_JIBUN_SUB in str(jibun) and match_jibun(jibun, TARGET_JIBUN_MAIN)
            write_data_row(ws, row, record, idx, is_target=is_target, is_alt=(idx % 2 == 0))
        data_end_row = header_row + len(records)

    # 풋터 노트
    note_row = data_end_row + 2
    ws.merge_cells(start_row=note_row, start_column=1, end_row=note_row, end_column=col_count)
    cell = ws.cell(row=note_row, column=1,
                   value="* 거래금액 단위: 만원 | 단가 = 거래금액 ÷ 거래면적 | 1평 = 3.3058㎡ | 출처: 국토교통부 실거래가 공개시스템")
    apply_cell_style(cell, font=NOTE_FONT, alignment=LEFT, border=None)

    note2_row = note_row + 1
    ws.merge_cells(start_row=note2_row, start_column=1, end_row=note2_row, end_column=col_count)
    cell = ws.cell(row=note2_row, column=1,
                   value="* 개인정보보호를 위해 지번 정보는 일부만 제공됩니다 (국토교통부 정책)")
    apply_cell_style(cell, font=NOTE_FONT, alignment=LEFT, border=None)

    return ws


def create_sheet_trend(wb, summaries):
    """추이 요약 시트 생성."""
    ws = wb.create_sheet(title="추이 요약")
    col_count = len(TREND_COLUMNS)

    # 제목
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=col_count)
    cell = ws.cell(row=1, column=1, value=f"{TARGET_DONG} 토지 매매 실거래가 추이 요약")
    apply_cell_style(cell, font=TITLE_FONT, alignment=Alignment(horizontal="center", vertical="center"), border=None)
    ws.row_dimensions[1].height = 30

    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=col_count)
    cell = ws.cell(row=2, column=1,
                   value=f"조회기간: {START_YM[:4]}.{START_YM[4:]} ~ {END_YM[:4]}.{END_YM[4:]} | 반기별 집계")
    apply_cell_style(cell, font=NOTE_FONT, alignment=CENTER, border=None)

    header_row = 4
    write_header_row(ws, header_row, TREND_COLUMNS)

    if not summaries:
        ws.merge_cells(start_row=header_row + 1, start_column=1, end_row=header_row + 1, end_column=col_count)
        cell = ws.cell(row=header_row + 1, column=1, value="조회된 거래 데이터가 없습니다.")
        apply_cell_style(cell, font=NOTE_FONT, alignment=CENTER)
        return ws

    formats = [None, "#,##0", "#,##0.0", "#,##0.0", "#,##0.0", "#,##0.0", "#,##0"]

    for idx, s in enumerate(summaries):
        row = header_row + 1 + idx
        values = [
            s["기간"], s["거래건수"], s["평균단가"],
            s["최저단가"], s["최고단가"], s["평균면적"], s["총거래금액"],
        ]
        fill = ALT_ROW_FILL if idx % 2 == 1 else None
        for i, (val, nf) in enumerate(zip(values, formats)):
            col = i + 1
            cell = ws.cell(row=row, column=col, value=val)
            align = TREND_COLUMNS[i][2]
            apply_cell_style(cell, alignment=align, fill=fill, number_format=nf)

    # 합계/평균 행
    total_row = header_row + 1 + len(summaries)
    total_count = sum(s["거래건수"] for s in summaries)
    all_avg_prices = [s["평균단가"] for s in summaries if s["평균단가"] > 0]
    all_min_prices = [s["최저단가"] for s in summaries if s["최저단가"] > 0]
    all_max_prices = [s["최고단가"] for s in summaries if s["최고단가"] > 0]
    all_areas = [s["평균면적"] for s in summaries if s["평균면적"] > 0]
    total_amount = sum(s["총거래금액"] for s in summaries)

    total_values = [
        "전체",
        total_count,
        round(sum(all_avg_prices) / len(all_avg_prices), 1) if all_avg_prices else 0,
        round(min(all_min_prices), 1) if all_min_prices else 0,
        round(max(all_max_prices), 1) if all_max_prices else 0,
        round(sum(all_areas) / len(all_areas), 1) if all_areas else 0,
        total_amount,
    ]

    for i, (val, nf) in enumerate(zip(total_values, formats)):
        col = i + 1
        cell = ws.cell(row=total_row, column=col, value=val)
        align = TREND_COLUMNS[i][2]
        apply_cell_style(cell, font=SUMMARY_FONT, alignment=align, fill=TOTAL_FILL, number_format=nf)

    return ws


def set_print_settings(ws):
    """인쇄 설정."""
    ws.page_setup.orientation = "landscape"
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.oddHeader.center.text = "감사인제출용 - 토지 매매 실거래가"
    ws.oddFooter.center.text = "Page &P of &N"


def export_to_excel(target_data, nearby_data, trend_summary, output_path):
    """Excel 파일 생성."""
    wb = openpyxl.Workbook()
    # 기본 시트 제거
    wb.remove(wb.active)

    # Sheet 1: 대상 토지 거래내역
    title1 = f"부산광역시 강서구 {TARGET_DONG} {TARGET_JIBUN} 토지 매매 실거래가"
    sub1 = f"조회기간: {START_YM[:4]}.{START_YM[4:]} ~ {END_YM[:4]}.{END_YM[4:]} | 출처: 국토교통부 실거래가 공개시스템"
    ws1 = create_sheet_transactions(wb, title1, sub1, target_data, "대상 토지 거래내역")

    # Sheet 2: 주변 비교 거래내역
    title2 = f"{TARGET_DONG} 일대 토지 매매 실거래 비교자료"
    sub2 = f"조회기간: {START_YM[:4]}.{START_YM[4:]} ~ {END_YM[:4]}.{END_YM[4:]} | {TARGET_JIBUN} 제외 명지동 전체"
    ws2 = create_sheet_transactions(wb, title2, sub2, nearby_data, "주변 비교 거래내역")

    # Sheet 3: 추이 요약
    ws3 = create_sheet_trend(wb, trend_summary)

    # 인쇄 설정
    for ws in wb.worksheets:
        set_print_settings(ws)

    # 저장
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    wb.save(output_path)
    print(f"\n✅ Excel 파일 저장 완료: {output_path}")
    print(f"   - Sheet 1: 대상 토지 거래내역 ({len(target_data)}건)")
    print(f"   - Sheet 2: 주변 비교 거래내역 ({len(nearby_data)}건)")
    print(f"   - Sheet 3: 추이 요약 ({len(trend_summary)}개 반기)")


def main():
    parser = argparse.ArgumentParser(
        description="부산 강서구 명지동(EDC) 토지 매매 실거래가 Excel Export (감사인제출용)"
    )
    parser.add_argument("--api-key", help="data.go.kr API 서비스키")
    parser.add_argument("--start-ym", default=START_YM, help=f"시작 년월 (기본: {START_YM})")
    parser.add_argument("--end-ym", default=END_YM, help=f"종료 년월 (기본: {END_YM})")
    parser.add_argument("--output", help="출력 파일 경로")
    args = parser.parse_args()

    api_key = get_api_key(args)

    start_ym = args.start_ym
    end_ym = args.end_ym

    today = datetime.now().strftime("%Y%m%d")
    output_path = args.output or os.path.join(OUTPUT_DIR, f"부산강서구_토지실거래가_{today}.xlsx")

    print("=" * 60)
    print("  부산 강서구 명지동(EDC) 토지 매매 실거래가 조회")
    print(f"  대상: {TARGET_DONG} {TARGET_JIBUN} 및 인근")
    print(f"  기간: {start_ym[:4]}.{start_ym[4:]} ~ {end_ym[:4]}.{end_ym[4:]}")
    print("=" * 60)

    # 데이터 조회
    raw_records = fetch_land_transactions(api_key, LAWD_CD, start_ym, end_ym)

    if not raw_records:
        print("\n⚠️  조회된 데이터가 없습니다.")
        print("   API 키와 기간을 확인해주세요.")
        # 빈 엑셀이라도 생성
        export_to_excel([], [], [], output_path)
        return

    # 정규화
    records = normalize_records(raw_records)
    print(f"\n총 {len(records)}건 정규화 완료")

    # 명지동 필터
    dong_count = sum(1 for r in records if r.get("법정동", "") == TARGET_DONG)
    print(f"  - {TARGET_DONG} 거래: {dong_count}건")

    # 대상 필지
    target_data = filter_target(records)
    print(f"  - 대상 필지({TARGET_JIBUN} 계열): {len(target_data)}건")

    if not target_data:
        print(f"  ⚠️  지번 {TARGET_JIBUN}의 정확한 거래 이력이 없습니다.")
        print(f"     → 유사 지번 거래를 주변 비교 시트에서 확인하세요.")

    # 주변 비교
    nearby_data = filter_nearby(records)
    print(f"  - 주변 비교 거래: {len(nearby_data)}건")

    # 추이 요약
    trend_summary = calculate_trend(records)

    # Excel 출력
    export_to_excel(target_data, nearby_data, trend_summary, output_path)


if __name__ == "__main__":
    main()
