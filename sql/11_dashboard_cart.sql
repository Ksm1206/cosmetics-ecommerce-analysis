-- =====================================================================
-- 대시보드 2: 장바구니 회수 모니터링
--
-- 분석 보고서에서 제안한 장바구니 회수 전략(소액 장바구니 채우기, 24시간 리마인드)을
-- 실제로 운영할 때 매일 확인할 지표입니다. 10_dashboard.sql과 같이 모두 "일" 단위로 내보내고,
-- 기간 필터와 집계는 Tableau에서 합니다.
--
-- 필요 테이블: session_carts, cart_abandons (09_cart_abandonment.sql에서 생성)
--
-- 기준
--   - 날짜는 세션 시작일(장바구니 지표) / 이탈 시각의 날짜(회수 지표), UTC 기준
--   - 소액 장바구니 = 장바구니 총액 10 미만 (가설 2의 기준)
--   - 회수 지표는 이탈 후 14일을 지켜봐야 하므로, cart_abandons와 같이 데이터 마지막 14일의 이탈은 제외
-- =====================================================================

-- name: dash_cart_daily
-- 일별 장바구니 현황: 이탈률, 이탈 금액, 소액 장바구니 비중과 전환율
SELECT CAST(session_start AS DATE)                                        AS cart_date,
       COUNT(*)                                                           AS cart_sessions,
       SUM(purchased)                                                     AS purchased_sessions,
       COUNT(*) - SUM(purchased)                                          AS abandoned_sessions,
       ROUND(SUM(basket_value), 2)                                        AS basket_value,
       ROUND(SUM(basket_value) FILTER (WHERE purchased = 0), 2)           AS abandoned_value,
       COUNT(*) FILTER (WHERE basket_value < 10)                          AS small_cart_sessions,
       COUNT(*) FILTER (WHERE basket_value < 10 AND purchased = 1)        AS small_cart_purchased,
       COUNT(*) FILTER (WHERE basket_value >= 10)                         AS large_cart_sessions,
       COUNT(*) FILTER (WHERE basket_value >= 10 AND purchased = 1)       AS large_cart_purchased
FROM session_carts
WHERE carted = 1
GROUP BY 1
ORDER BY 1;

-- name: dash_cart_basket_band
-- 일별 × 장바구니 총액 구간: 구간별 전환율 막대 차트용 (구간은 h2_basket_value_conversion과 동일)
SELECT CAST(session_start AS DATE) AS cart_date,
       CASE WHEN basket_value <  5 THEN '1) ~5'
            WHEN basket_value < 10 THEN '2) 5~10'
            WHEN basket_value < 20 THEN '3) 10~20'
            WHEN basket_value < 40 THEN '4) 20~40'
            ELSE                        '5) 40~' END AS basket_band,
       COUNT(*)       AS cart_sessions,
       SUM(purchased) AS purchased_sessions
FROM session_carts
WHERE carted = 1
GROUP BY 1, 2
ORDER BY 1, 2;

-- name: dash_cart_recovery
-- 이탈일 × 장바구니 그룹 × 경과일 × 지표: 이탈 후 N일 안에 돌아온 수(복귀)와 다시 구매한 수(회수 구매)
-- 지표를 행으로 쌓은 긴 형태라서 Tableau에서 경과일을 x축, 지표를 색으로 두면 바로 두 곡선이 그려짐
SELECT CAST(abandon_time AS DATE)                                              AS abandon_date,
       CASE WHEN basket_value < 10 THEN '소액(10 미만)' ELSE '그 외(10 이상)' END AS basket_group,
       n_days,
       metric,
       COUNT(*)                                                                AS abandons,
       COUNT(*) FILTER (WHERE CASE metric WHEN '복귀율' THEN days_to_return
                                          ELSE days_to_purchase END <= n_days) AS hits
FROM cart_abandons,
     (VALUES (1), (2), (3), (5), (7), (14)) AS t(n_days),
     (VALUES ('복귀율'), ('회수 구매율')) AS m(metric)
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4;

-- name: dash_remind_targets
-- 일별 리마인드 대상: 이탈 후 24시간 안에 돌아오지 않은 고객 (전략 2의 발송 대상)
SELECT CAST(abandon_time AS DATE)                                                AS abandon_date,
       COUNT(*)                                                                  AS abandons,
       COUNT(*) FILTER (WHERE days_to_return IS NULL OR days_to_return > 1)      AS remind_targets,
       ROUND(SUM(basket_value) FILTER (WHERE days_to_return IS NULL OR days_to_return > 1), 2)
                                                                                 AS remind_target_value,
       COUNT(*) FILTER ((days_to_return IS NULL OR days_to_return > 1)
                        AND days_to_purchase <= 7)                               AS targets_recovered_7d
FROM cart_abandons
GROUP BY 1
ORDER BY 1;

-- name: dash_cart_kpi
-- KPI 카드: 기준일 기준 최근 30일 vs 이전 30일 (지표마다 한 행)
-- 회수 지표는 이탈 데이터가 끝나는 날(기준일 - 14일)을 기준으로 따로 자름
WITH c AS (
    SELECT CAST(session_start AS DATE) AS d, basket_value, purchased
    FROM session_carts
    WHERE carted = 1
),
c_last AS (SELECT MAX(d) AS last_d FROM c),
a AS (
    SELECT CAST(abandon_time AS DATE) AS d, days_to_return, days_to_purchase
    FROM cart_abandons
),
a_last AS (SELECT MAX(d) AS last_d FROM a),
cart AS (
    SELECT CASE WHEN d > last_d - 30 THEN 'last' WHEN d > last_d - 60 THEN 'prev' END AS period,
           (COUNT(*) - SUM(purchased)) * 100.0 / COUNT(*)                       AS abandon_rate,
           COUNT(*) FILTER (WHERE basket_value < 10) * 100.0 / COUNT(*)         AS small_cart_share
    FROM c, c_last
    GROUP BY 1
),
rec AS (
    SELECT CASE WHEN d > last_d - 30 THEN 'last' WHEN d > last_d - 60 THEN 'prev' END AS period,
           COUNT(*) FILTER (WHERE days_to_return <= 1) * 100.0 / COUNT(*)       AS return_24h,
           COUNT(*) FILTER (WHERE days_to_purchase <= 7) * 100.0 / COUNT(*)     AS recovered_7d
    FROM a, a_last
    GROUP BY 1
),
w AS (
    SELECT period, abandon_rate, small_cart_share, return_24h, recovered_7d
    FROM cart JOIN rec USING (period)
    WHERE period IS NOT NULL
),
k AS (
    SELECT 1 AS kpi_order, '장바구니 이탈률' AS kpi, period, abandon_rate AS v FROM w
    UNION ALL SELECT 2, '소액 장바구니 비중', period, small_cart_share FROM w
    UNION ALL SELECT 3, '24시간 복귀율', period, return_24h FROM w
    UNION ALL SELECT 4, '7일 회수 구매율', period, recovered_7d FROM w
)
SELECT kpi_order, kpi,
       ROUND(MAX(v) FILTER (WHERE period = 'last'), 2)                                   AS last_30d_pct,
       ROUND(MAX(v) FILTER (WHERE period = 'prev'), 2)                                   AS prev_30d_pct,
       ROUND(MAX(v) FILTER (WHERE period = 'last') - MAX(v) FILTER (WHERE period = 'prev'), 2) AS change_pp
FROM k
GROUP BY 1, 2
ORDER BY 1;
