-- =====================================================================
-- 대시보드(현황판)용 데이터
--
-- 대시보드는 분석 보고서와 다릅니다.
--   - 분석 X, "지금 상태가 어떤가"를 차트만 보고 알 수 있으면 됨
--   - 기간 개념 필수: 기준일, 최근 30일, 월별 등으로 걸러 볼 수 있어야 함
-- 그래서 모든 결과를 "일(day)" 단위로 내보내고, 기간 필터·집계는 Tableau에서 합니다.
-- =====================================================================

-- name: dash_daily_metrics
-- 일별 핵심 지표. Tableau에서 기간 필터 + 일/주/월 집계
SELECT event_date,
       COUNT(DISTINCT user_id)                                              AS users,
       COUNT(DISTINCT user_session)                                         AS sessions,
       COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'cart')      AS cart_sessions,
       COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'purchase')  AS purchase_sessions,
       COUNT(DISTINCT user_id)      FILTER (WHERE event_type = 'purchase')  AS buyers,
       ROUND(SUM(price) FILTER (WHERE event_type = 'purchase'), 2)          AS revenue,
       COUNT(*) FILTER (WHERE event_type = 'purchase')                      AS items_sold
FROM events
GROUP BY 1
ORDER BY 1;

-- name: dash_daily_brand
-- 일별 브랜드 매출 (상위 브랜드 순위 차트용)
SELECT event_date, brand,
       ROUND(SUM(price), 2) AS revenue,
       COUNT(*)             AS items_sold
FROM events
WHERE event_type = 'purchase'
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- name: dash_daily_price_band
-- 일별 가격대 매출 구성
SELECT event_date, price_band,
       ROUND(SUM(price), 2) AS revenue,
       COUNT(*)             AS items_sold
FROM events
WHERE event_type = 'purchase'
GROUP BY 1, 2
ORDER BY 1, 2;

-- name: dash_period_compare
-- 기준일(데이터 마지막 날) 기준 최근 30일 vs 그 이전 30일 (KPI 카드의 증감 표시용)
WITH d AS (
    SELECT *, CASE WHEN event_date >  (SELECT MAX(event_date) FROM events) - 30 THEN 'last_30d'
                   WHEN event_date >  (SELECT MAX(event_date) FROM events) - 60 THEN 'prev_30d' END AS period
    FROM events
)
SELECT period,
       MIN(event_date) AS start_date,
       MAX(event_date) AS end_date,
       COUNT(DISTINCT user_id)                                              AS users,
       COUNT(DISTINCT user_session)                                         AS sessions,
       COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'purchase')  AS purchase_sessions,
       ROUND(COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'purchase') * 100.0
             / COUNT(DISTINCT user_session), 2)                             AS session_cvr_pct,
       ROUND(SUM(price) FILTER (WHERE event_type = 'purchase'), 0)          AS revenue
FROM d
WHERE period IS NOT NULL
GROUP BY 1
ORDER BY 1;
