-- =====================================================================
-- 3단계-1. 데이터 탐색 (원본 테이블 events_raw 대상)
-- 목적: 정제 전에 데이터 상태를 숫자로 확인하고, README "데이터 정제" 절에 기록
-- 실행: python scripts/run_sql.py sql/01_eda.sql
-- =====================================================================

-- name: eda_rows_by_file
-- 파일(월)별 행 수, 사용자 수, 세션 수
SELECT source_file,
       COUNT(*)                     AS events,
       COUNT(DISTINCT user_id)      AS users,
       COUNT(DISTINCT user_session) AS sessions
FROM events_raw
GROUP BY 1
ORDER BY MIN(event_time);

-- name: eda_event_type_counts
-- 이벤트 타입별 건수와 비중
SELECT event_type,
       COUNT(*) AS events,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM events_raw
GROUP BY 1
ORDER BY 2 DESC;

-- name: eda_null_check
-- 컬럼별 결측 개수와 비율
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE brand IS NULL)          AS brand_null,
       ROUND(AVG(CASE WHEN brand IS NULL THEN 100.0 ELSE 0 END), 2)         AS brand_null_pct,
       COUNT(*) FILTER (WHERE category_code IS NULL)  AS category_code_null,
       ROUND(AVG(CASE WHEN category_code IS NULL THEN 100.0 ELSE 0 END), 2) AS category_code_null_pct,
       COUNT(*) FILTER (WHERE user_session IS NULL)   AS session_null,
       COUNT(*) FILTER (WHERE price IS NULL)          AS price_null
FROM events_raw;

-- name: eda_price_summary
-- 가격 분포와 이상치(0 이하) 확인. 가격대 구간(02_cleaning.sql)을 정할 때 참고
SELECT COUNT(*) FILTER (WHERE price < 0)  AS negative_price,
       COUNT(*) FILTER (WHERE price = 0)  AS zero_price,
       MIN(price) AS min_price,
       QUANTILE_CONT(price, 0.25) AS p25,
       MEDIAN(price)              AS p50,
       QUANTILE_CONT(price, 0.75) AS p75,
       QUANTILE_CONT(price, 0.95) AS p95,
       MAX(price) AS max_price,
       ROUND(AVG(price), 2) AS avg_price
FROM events_raw;

-- name: eda_duplicates
-- 모든 컬럼이 똑같은 완전 중복 행이 몇 개인지
SELECT COUNT(*) AS total_rows,
       (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM events_raw)) AS distinct_rows,
       COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM events_raw)) AS duplicate_rows
FROM events_raw;

-- name: eda_daily_events
-- 일별 이벤트 수: 데이터가 빠진 날이나 급증한 날이 있는지 그래프로 확인
SELECT CAST(REPLACE(event_time, ' UTC', '') AS TIMESTAMP)::DATE AS event_date,
       COUNT(*) AS events
FROM events_raw
GROUP BY 1
ORDER BY 1;

-- name: eda_heavy_users
-- 이벤트가 비정상적으로 많은 사용자 (봇 의심). 상위 20명
SELECT user_id,
       COUNT(*) AS events,
       COUNT(*) FILTER (WHERE event_type = 'view')     AS views,
       COUNT(*) FILTER (WHERE event_type = 'purchase') AS purchases,
       COUNT(DISTINCT user_session) AS sessions
FROM events_raw
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
