# 진행 가이드: 4주 체크리스트

계획서의 1~8단계를 이 프로젝트 파일에 맞춰 정리했습니다. 위에서부터 순서대로 체크하면서 진행하세요.
명령어는 모두 **프로젝트 폴더(이 README가 있는 곳)** 에서 실행합니다.

---

## 1주차 — 환경 세팅, 질문 정의, 탐색·정제

### 1단계. 환경 세팅
- [ ] Python 3.10 이상 설치 확인: `python --version`
- [ ] 가상환경 만들기 (권장)
  ```bash
  python -m venv .venv
  # 윈도우: .venv\Scripts\activate   /  맥: source .venv/bin/activate
  pip install -r requirements.txt
  ```
- [ ] **연습 실행**: 실제 데이터를 받기 전에 가짜 데이터로 전체가 돌아가는지 확인
  ```bash
  python scripts/make_sample_data.py
  python scripts/load_data.py --sample
  python scripts/run_sql.py all
  ```
  여기서 나온 숫자는 가짜입니다. 흐름만 익히고 버리세요.
- [ ] 실제 데이터 받기: [data/README.md](../data/README.md) 참고 → `data/raw/`에 CSV 5개
- [ ] 실제 데이터 적재: `python scripts/load_data.py` (노트북 사양에 따라 1~3분)
- [ ] GitHub 저장소 만들고 첫 커밋 (`.gitignore` 덕분에 데이터와 DB는 안 올라감)

### 2단계. 분석 목표와 가설 정의 ⭐
- [ ] 분석 보고서의 "분석 목표"와 가설 3개를 읽고 내 말로 다시 쓰기
  - 가설 1: 장바구니에 담은 상품의 절반 이상이 구매되지 않는다 (어디서)
  - 가설 2: 저가 상품·소액 장바구니일수록 구매로 이어지지 않는다 (누가)
  - 가설 3: 장바구니 이탈 고객의 상당수는 며칠 안에 돌아온다 (다시 데려올 수 있나)
- [ ] 각 가설의 **채택 기준을 데이터를 보기 전에** 확정 (보고서 "검정 지표와 기준" 표)
- [ ] 보고서 흐름: 가설 설정 → 검정 지표 설정 → 쿼리로 지표 추출 → 결과 해석과 가설 검정 → 비즈니스 인사이트

### 3단계. 데이터 탐색과 정제
- [ ] `python scripts/run_sql.py sql/01_eda.sql` 실행
- [ ] 결과를 보고 README "데이터 품질 점검 결과" 표의 ○ 채우기
  - `eda_daily_events.csv`를 엑셀이나 노트북으로 그려서 **빠진 날·튀는 날** 확인
  - `eda_heavy_users.csv`로 봇 의심 사용자 확인 → 제거 기준을 정했으면 `02_cleaning.sql` WHERE 절에 추가
  - `eda_price_summary.csv` 분위수를 보고 `02_cleaning.sql`의 가격대 구간 조정
- [ ] `python scripts/run_sql.py sql/02_cleaning.sql` → 정제 전후 행 수 기록
- [ ] 블로그 1편: "데이터 소개와 정제 과정"

> **면접 대비** — "결측치를 왜 그렇게 처리했나요?" 질문에 답할 수 있도록 처리 이유를 꼭 적어 두세요.

---

## 2주차 — SQL 분석

| 파일 | 답하는 질문 | 볼 결과 |
|---|---|---|
| `03_kpi.sql` | 전체 현황은? | `kpi_overall`, `kpi_monthly`, `kpi_daily` |
| `04_funnel.sql` | 어디서 이탈하나? | `funnel_session` (loose vs strict 비교), `funnel_product_level` |
| `05_conversion_breakdown.sql` | 어떤 브랜드·가격대에서 이탈하나? | `conv_by_price_band`, `conv_by_brand`, `top_products_low_conversion` |
| `06_cohort.sql` | 재구매하나? 언제? 누가? | `cohort_retention`, `repurchase_gap`, `repeat_vs_onetime` |
| `07_rfm.sql` | 누가 매출을 만드나? | `rfm_segment_summary` |
| `08_time_pattern.sql` | 언제 사나? (보조) | `sessions_by_hour_dow`, `weekend_vs_weekday` |
| `09_cart_abandonment.sql` | **보고서 가설 1·2·3** | `h1_abandoned_value`, `h2_basket_value_conversion`, `h3_return_rate`, `h3_days_to_return`, `h3_return_by_basket` |
| `10_dashboard.sql` | 대시보드용 일별 데이터 | `dash_daily_metrics`, `dash_period_compare` 등 |

보고서 본문은 04·05·09번이 중심이고, 06·07·08번은 보조 분석입니다. 보고서에 넣지 않아도 되지만,
면접에서 "다른 것도 봤나요?"라는 질문에 답할 거리가 됩니다.

- [ ] `python scripts/run_sql.py all`
- [ ] **실제 데이터에서는** `05_conversion_breakdown.sql`의 `HAVING` 기준(100, 50)을 1000으로 올리기
- [ ] 쿼리마다 "그래서 뭘 알게 됐나"를 한 줄씩 메모 (노트북 마지막 표에 정리)
- [ ] 쿼리를 **직접 고쳐 보기**: 그대로 쓰기만 하면 면접에서 설명하기 어렵습니다.
  아래 중 2개 이상은 직접 작성해 보세요.
  - [ ] 장바구니에 담고 `remove_from_cart` 한 상품이 많은 브랜드 TOP 10
  - [ ] 첫 구매 고객이 산 브랜드별 재구매율
  - [ ] 11월(블랙프라이데이 주간) vs 다른 달 객단가 비교
  - [ ] 세션당 조회 상품 수와 구매 전환율의 관계
- [ ] 블로그 2편: "퍼널·코호트 분석 SQL"

> **면접 대비** — 퍼널을 이벤트 수가 아닌 세션 단위로, 전환율을 (세션, 상품) 쌍 단위로 계산한 이유를 설명할 수 있어야 합니다.
> 이벤트 수로 나누면 같은 상품을 여러 번 담은 경우가 부풀려집니다.

---

## 3주차 — Python 시각화·통계 검정, 대시보드

### 5단계. 노트북
- [ ] `jupyter notebook notebooks/analysis.ipynb` → 위에서부터 실행
- [ ] `images/`에 차트 7개 생성 확인
- [ ] 통계 검정 결과(차이 %p, p-value, Cramér's V) 기록
  - 데이터가 커서 p-value는 거의 항상 0.05보다 작게 나옵니다.
    "유의하다"에서 멈추지 말고 **차이가 실무적으로 의미 있는 크기인지**를 함께 말하세요.
- [ ] 차트 제목·축 이름을 결론이 드러나게 고치기 (예: "가격대별 전환율" → "5 미만 저가 상품은 전환율이 절반 수준")

### 6단계. 대시보드
- [ ] [dashboard/README.md](../dashboard/README.md)를 보고 Tableau Public 또는 Looker Studio로 제작
- [ ] 게시 링크를 README 상단에 넣고, 캡처를 `dashboard/dashboard.png`로 저장
- [ ] 블로그 3편: "시각화와 통계 검정"

---

## 4주차 — 인사이트·제안, README, 회고

### 7단계. 분석 보고서 완성 ⭐
- [ ] 보고서의 ○와 (작성)을 실제 결과로 채우기
- [ ] 가설마다 판정(채택/기각)을 쓰고, 결과에 맞춰 **다음 가설의 출발 문장**을 고치기
- [ ] 세 가설을 통틀어 **하나의 종합 결론**을 한 문장으로 쓰고, 요약 맨 위에 두기
- [ ] 기대효과는 노트북 9번 셀처럼 **가정을 밝힌 추정치**로 계산
- [ ] "해석"은 데이터로 확인한 사실이 아니면 "추정"이라고 쓰기 (이 데이터에는 배송비·쿠폰 정보가 없음)

### 8단계. README
- [ ] 루트 `README.md`의 ○와 (작성) 모두 채우기
- [ ] 한 줄 요약에 **숫자**가 들어갔는지 확인
- [ ] 차트 이미지가 GitHub에서 보이는지 확인
- [ ] 한계점 2~3개 확인 (이미 예시 있음)
- [ ] 블로그 4편: 프로젝트 회고 (잘한 점, 아쉬운 점, 다음에 해볼 것)

---

## 문제가 생기면

| 증상 | 해결 |
|---|---|
| `CSV가 없습니다` | `data/raw/`에 CSV가 있는지, 폴더명이 맞는지 확인 |
| 적재 중 메모리 부족 | 다른 프로그램을 닫거나, 월별 파일을 2~3개만 넣고 먼저 진행 |
| 차트 한글이 네모로 보임 | 윈도우는 맑은 고딕이 기본 탑재. 코랩은 `!apt install fonts-nanum` 후 런타임 재시작 |
| 쿼리가 느림 | DuckDB는 첫 실행 후 빨라집니다. 그래도 느리면 `02_cleaning.sql`로 만든 `events` 테이블을 쓰는지 확인 |
| DB 파일이 잠겨 있다는 오류 | 노트북이나 다른 창에서 `ecommerce.duckdb`를 열고 있으면 닫기 |
