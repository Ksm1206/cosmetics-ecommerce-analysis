# 6단계. 대시보드(현황판) 만들기

## 분석 보고서와 무엇이 다른가

| | 분석 보고서 | 대시보드 |
|---|---|---|
| 목적 | 왜 그런지 밝히고 전략을 제안 | 지금 상태를 한눈에 보여 줌 |
| 내용 | 가설, 검정, 해석, 인사이트 | 차트와 숫자만. 분석·해석은 넣지 않음 |
| 시점 | 한 번 작성하면 끝 | 최신 데이터가 들어오면 갱신되는 현황판 |
| 기간 | 전체 기간 | **기간 개념 필수** (기준일, 최근 30일, 월별) |

이 데이터는 2020년 2월에 끝나서 자동 갱신은 안 되지만, **기준일과 기간 필터**는 꼭 넣습니다.
보고서의 가설 검정 결과(카이제곱, 복귀율 분석 등)는 대시보드에 넣지 않습니다.

## 연결할 데이터

`python scripts/run_sql.py sql/10_dashboard.sql` → `outputs/`에 아래 CSV가 생깁니다. 전부 **일 단위**라서
Tableau에서 기간 필터와 일·주·월 집계를 자유롭게 할 수 있습니다.

| CSV | 내용 |
|---|---|
| `dash_daily_metrics.csv` | 일별 사용자, 세션, 장바구니 세션, 구매 세션, 구매 고객, 매출, 판매 수량 |
| `dash_daily_brand.csv` | 일별 브랜드 매출 |
| `dash_daily_price_band.csv` | 일별 가격대 매출 |
| `dash_period_compare.csv` | 최근 30일 vs 이전 30일 (KPI 증감) |

## 화면 구성 (한 장)

| 위치 | 내용 | 데이터 |
|---|---|---|
| 맨 위 | 제목 + **기준일: 2020-02-29** + 기간 필터(날짜 범위, 월 선택) | `dash_daily_metrics` |
| 상단 KPI 카드 | 매출, 구매 고객, 세션 구매 전환율, 객단가. 각 카드에 **이전 기간 대비 증감** | `dash_period_compare` |
| 중단 왼쪽 | 일별 매출 추이 (일/주/월 전환) | `dash_daily_metrics` |
| 중단 오른쪽 | 조회 → 장바구니 → 구매 세션 수 (선택 기간의 퍼널) | `dash_daily_metrics` |
| 하단 왼쪽 | 브랜드 매출 상위 10 | `dash_daily_brand` |
| 하단 오른쪽 | 가격대별 매출 구성 | `dash_daily_price_band` |

**Tableau 계산식 예시**
- 세션 구매 전환율: `SUM([purchase_sessions]) / SUM([sessions])`
- 장바구니 전환율: `SUM([cart_sessions]) / SUM([sessions])`
- 객단가: `SUM([revenue]) / SUM([purchase_sessions])`

비율은 일별 값을 평균하지 말고 **합계끼리 나눠야** 기간을 바꿔도 맞게 계산됩니다.

## 완성 후
1. Tableau Public에 게시하고 링크를 루트 README와 분석 보고서에 넣기
2. 화면 캡처를 이 폴더에 `dashboard.png`로 저장
