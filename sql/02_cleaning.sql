-- =====================================================================
-- 3단계-2. 데이터 정제 → 분석용 테이블 events 생성
-- 이후 모든 분석(03~08)은 events 테이블을 씁니다.
--
-- 정제 규칙 (README에 "무엇을, 왜" 그대로 옮겨 적으세요)
--   1) 완전 중복 행 제거 : 같은 시각·사용자·상품·행동이 두 번 찍힌 것은 로깅 오류로 판단
--   2) 가격 0 이하 제거 : 음수는 판매가가 아니고, 0원은 사은품·샘플로 추정돼 가격 분석을 왜곡
--   3) 시간 변환         : "2019-10-01 00:00:00 UTC" 문자열 → TIMESTAMP (UTC 기준 유지)
--   4) brand 결측        : 삭제하지 않고 'unknown'으로 채움 (삭제하면 매출의 상당 부분이 사라짐)
--   5) category_code     : 대부분 결측이라 분석에 쓰지 않고 category_id를 사용
--   6) 파생 컬럼         : 날짜, 월, 시간, 요일, 주말 여부, 가격대
--
--   7) 봇 의심 사용자    : 5개월 동안 구매 0건이면서 이벤트 1,000건 이상인 사용자 제거
--                          (사람의 쇼핑으로 보기 어렵고, 장바구니 이탈률을 부풀림)
--
-- ※ 가격대 구간은 01_eda.sql의 eda_price_summary 결과(분위수)를 보고 조정하세요.
-- ※ 봇 기준(1,000)을 바꾸려면 아래 bot_users의 숫자만 고치세요.
-- =====================================================================

-- name: build_bot_users
CREATE OR REPLACE TABLE bot_users AS
SELECT user_id,
       COUNT(*) AS events,
       COUNT(DISTINCT user_session) AS sessions
FROM events_raw
GROUP BY 1
HAVING COUNT(*) FILTER (WHERE event_type = 'purchase') = 0
   AND COUNT(*) >= 1000;

-- name: bot_users_summary
SELECT COUNT(*) AS bot_users,
       SUM(events) AS bot_events,
       ROUND(SUM(events) * 100.0 / (SELECT COUNT(*) FROM events_raw), 2) AS bot_events_pct
FROM bot_users;

-- name: build_events
CREATE OR REPLACE TABLE events AS
WITH dedup AS (
    SELECT DISTINCT
           CAST(REPLACE(event_time, ' UTC', '') AS TIMESTAMP) AS event_time,
           event_type, product_id, category_id, brand, price, user_id, user_session
    FROM events_raw
    WHERE price > 0
      AND user_id NOT IN (SELECT user_id FROM bot_users)
)
SELECT event_time,
       event_type,
       product_id,
       category_id,
       COALESCE(brand, 'unknown')                 AS brand,
       price,
       user_id,
       user_session,
       CAST(event_time AS DATE)                   AS event_date,
       DATE_TRUNC('month', event_time)::DATE      AS event_month,
       HOUR(event_time)                           AS event_hour,      -- UTC 기준
       ISODOW(event_time)                         AS dow,             -- 1=월 ... 7=일
       ISODOW(event_time) >= 6                    AS is_weekend,
       CASE WHEN price <  2  THEN '1) ~2'
            WHEN price <  5  THEN '2) 2~5'
            WHEN price < 10  THEN '3) 5~10'
            WHEN price < 20  THEN '4) 10~20'
            ELSE                  '5) 20~'
       END                                        AS price_band
FROM dedup;

-- name: cleaning_summary
-- 정제 전후 비교: README에 표로 옮기기
SELECT 'raw'   AS stage, COUNT(*) AS rows, COUNT(DISTINCT user_id) AS users FROM events_raw
UNION ALL
SELECT 'clean' AS stage, COUNT(*) AS rows, COUNT(DISTINCT user_id) AS users FROM events;
