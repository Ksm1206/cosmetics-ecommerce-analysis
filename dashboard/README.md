# 대시보드 설계

[Tableau Public – Cosmetics Shop Dashboard](https://public.tableau.com/views/CosmeticsShopDashboard/sheet6)

## 분석 보고서와의 역할 구분

| | 분석 보고서 | 대시보드 |
|---|---|---|
| 목적 | 왜 그런지 밝히고 전략을 제안 | 지금 상태를 한눈에 보여 줌 |
| 내용 | 가설, 검정, 해석, 인사이트 | 차트와 숫자만 (해석은 넣지 않음) |
| 시점 | 한 번 작성 | 새 데이터가 들어오면 갱신되는 현황판 |
| 기간 | 전체 기간 | 기준일과 기간 필터 |

원본 데이터가 2020년 2월에 끝나 자동 갱신은 하지 않지만, 실제 현황판처럼 쓸 수 있도록 **기준일(2020-02-29)과 기간 필터**를 넣었습니다. 가설 검정 결과(카이제곱, 복귀율 분석 등)는 보고서에만 두고 대시보드에는 넣지 않았습니다.

## 데이터 소스

원본 1,900만 행을 그대로 연결하면 무거워서, `sql/10_dashboard.sql`로 **일 단위 요약 테이블**을 만들어 Tableau에 연결했습니다. 일 단위라서 Tableau에서 기간 필터와 일·주·월 집계를 자유롭게 바꿀 수 있습니다.

| CSV | 내용 |
|---|---|
| `dash_daily_metrics.csv` | 일별 사용자, 세션, 장바구니 세션, 구매 세션, 구매 고객, 매출, 판매 수량 |
| `dash_daily_brand.csv` | 일별 브랜드 매출 |
| `dash_daily_price_band.csv` | 일별 가격대 매출 |
| `dash_period_compare.csv` | 최근 30일 vs 이전 30일 (KPI 증감) |

## 화면 구성

| 위치 | 내용 | 데이터 |
|---|---|---|
| 맨 위 | 제목, 기준일, 기간 필터(날짜 범위, 월 선택) | `dash_daily_metrics` |
| 상단 KPI 카드 | 매출, 구매 고객, 세션 구매 전환율, 객단가 (이전 기간 대비 증감) | `dash_period_compare` |
| 중단 왼쪽 | 일별 매출 추이 (일/주/월 전환) | `dash_daily_metrics` |
| 중단 오른쪽 | 조회 → 장바구니 → 구매 세션 수 (선택 기간 퍼널) | `dash_daily_metrics` |
| 하단 왼쪽 | 브랜드 매출 상위 10 | `dash_daily_brand` |
| 하단 오른쪽 | 가격대별 매출 구성 | `dash_daily_price_band` |

## 계산식

- 세션 구매 전환율: `SUM([purchase_sessions]) / SUM([sessions])`
- 장바구니 전환율: `SUM([cart_sessions]) / SUM([sessions])`
- 객단가: `SUM([revenue]) / SUM([purchase_sessions])`

비율은 일별 값의 평균이 아니라 **합계끼리 나눠** 계산했습니다. 일별 비율을 평균하면 방문이 적은 날과 많은 날이 같은 무게로 섞여, 기간을 바꿀 때 값이 틀어지기 때문입니다.
