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

---

# 대시보드 2: 장바구니 회수 모니터링

분석 보고서에서 제안한 장바구니 회수 전략(소액 장바구니 채우기, 24시간 리마인드)을 **실제로 운영한다면 매일 확인할 화면**입니다. 첫 번째 현황판이 "매출이 어떤가"를 본다면, 이 화면은 "장바구니에서 놓친 매출을 얼마나 되찾고 있는가"를 봅니다.

## 데이터 소스

`sql/11_dashboard_cart.sql` (09번에서 만든 `session_carts`, `cart_abandons` 테이블 사용)

| CSV | 단위 | 내용 |
|---|---|---|
| `dash_cart_daily.csv` | 일 | 장바구니 세션, 구매·이탈 세션, 이탈 금액, 소액(10 미만)·그 외 장바구니의 세션 수와 구매 수 |
| `dash_cart_basket_band.csv` | 일 × 총액 구간 | 장바구니 총액 구간별 세션 수와 구매 수 |
| `dash_cart_recovery.csv` | 이탈일 × 장바구니 그룹 × 경과일 × 지표 | 이탈 후 1·2·3·5·7·14일 안에 돌아온 수(`metric`=복귀율)와 다시 구매한 수(`metric`=회수 구매율)를 `hits`로 쌓은 긴 형태 |
| `dash_remind_targets.csv` | 이탈일 | 이탈 후 24시간 안에 돌아오지 않은 리마인드 대상 수와 담아 둔 금액 |
| `dash_cart_kpi.csv` | 지표 | KPI 4개의 최근 30일·이전 30일 값과 증감(%p) |

회수 지표는 이탈 후 14일을 지켜봐야 계산할 수 있어서, 데이터 마지막 14일의 이탈은 제외했습니다(보고서 가설 3과 같은 기준).

## 화면 구성

| 위치 | 내용 | 데이터 |
|---|---|---|
| 상단 KPI 카드 | 장바구니 이탈률, 소액 장바구니 비중, 24시간 복귀율, 7일 회수 구매율 (이전 30일 대비 증감) | `dash_cart_kpi` |
| 중단 왼쪽 | 주별 장바구니 이탈률 추이 | `dash_cart_daily` |
| 중단 오른쪽 | 장바구니 총액 구간별 구매 전환율 | `dash_cart_basket_band` |
| 하단 왼쪽 | 이탈 후 경과일별 복귀율·회수 구매율 곡선 (소액 vs 그 외) | `dash_cart_recovery` |
| 하단 오른쪽 | 주별 리마인드 대상 수 | `dash_remind_targets` |

## 계산식

- 장바구니 이탈률: `SUM([abandoned_sessions]) / SUM([cart_sessions])`
- 소액 장바구니 비중: `SUM([small_cart_sessions]) / SUM([cart_sessions])`
- 소액 장바구니 전환율: `SUM([small_cart_purchased]) / SUM([small_cart_sessions])`
- 총액 구간별 전환율: `SUM([purchased_sessions]) / SUM([cart_sessions])`
- 복귀율·회수 구매율: `SUM([hits]) / SUM([abandons])` (`metric`을 색으로 구분)

날짜는 주 단위로 보여 줍니다. 2019년 10월 2·6·7일에 장바구니 세션이 평소의 2~3배로 몰려(이탈률 약 96%), 일 단위로 그리면 이 며칠이 추세를 가리기 때문입니다.
