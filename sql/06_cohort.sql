-- =====================================================================
-- 4단계-③. 코호트 리텐션: 첫 구매 고객이 다음 달에도 다시 사는가?
--
-- 코호트 = 첫 구매월. month_n = 첫 구매월로부터 몇 달 뒤인지 (0 = 첫 구매월)
-- 데이터가 5개월뿐이라 10월 코호트만 4개월 뒤까지 볼 수 있습니다 (README 한계점에 기록).
-- =====================================================================

-- name: cohort_retention
WITH first_buy AS (
    SELECT user_id, MIN(event_month) AS cohort
    FROM events WHERE event_type = 'purchase'
    GROUP BY 1
),
buys AS (
    SELECT DISTINCT user_id, event_month AS buy_month
    FROM events WHERE event_type = 'purchase'
),
counts AS (
    SELECT f.cohort,
           DATE_DIFF('month', f.cohort, b.buy_month) AS month_n,
           COUNT(DISTINCT b.user_id) AS users
    FROM first_buy f JOIN buys b USING (user_id)
    GROUP BY 1, 2
)
SELECT cohort, month_n, users,
       FIRST_VALUE(users) OVER (PARTITION BY cohort ORDER BY month_n) AS cohort_size,
       ROUND(users * 100.0 / FIRST_VALUE(users) OVER (PARTITION BY cohort ORDER BY month_n), 2) AS retention_pct
FROM counts
ORDER BY cohort, month_n;

-- name: repurchase_gap
-- 첫 구매 → 두 번째 구매까지 걸린 일수 분포 (재구매 리마인드 메시지 타이밍 근거)
WITH orders AS (
    SELECT user_id, user_session, MIN(event_time) AS order_time
    FROM events WHERE event_type = 'purchase'
    GROUP BY 1, 2
),
ranked AS (
    SELECT user_id, order_time,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_time) AS rn
    FROM orders
),
gap AS (
    SELECT DATE_DIFF('day', r1.order_time, r2.order_time) AS days_to_2nd
    FROM ranked r1 JOIN ranked r2 ON r1.user_id = r2.user_id AND r1.rn = 1 AND r2.rn = 2
)
SELECT CASE WHEN days_to_2nd <= 7  THEN '1) 1주 이내'
            WHEN days_to_2nd <= 14 THEN '2) 2주 이내'
            WHEN days_to_2nd <= 30 THEN '3) 1달 이내'
            WHEN days_to_2nd <= 60 THEN '4) 2달 이내'
            ELSE                        '5) 2달 초과' END AS gap_bucket,
       COUNT(*) AS users,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM gap
GROUP BY 1
ORDER BY 1;

-- name: repeat_vs_onetime
-- 재구매 고객은 첫 주문에서 무엇이 달랐나? (첫 주문 금액·상품 수·가격대 비교)
WITH orders AS (
    SELECT user_id, user_session,
           MIN(event_time) AS order_time,
           SUM(price) AS order_value,
           COUNT(*) AS items
    FROM events WHERE event_type = 'purchase'
    GROUP BY 1, 2
),
u AS (
    SELECT user_id,
           COUNT(*) AS n_orders,
           ARG_MIN(order_value, order_time) AS first_order_value,
           ARG_MIN(items, order_time)       AS first_order_items
    FROM orders
    GROUP BY 1
)
SELECT CASE WHEN n_orders >= 2 THEN 'repeat' ELSE 'one_time' END AS customer_type,
       COUNT(*) AS customers,
       ROUND(AVG(first_order_value), 2)   AS avg_first_order_value,
       ROUND(MEDIAN(first_order_value), 2) AS median_first_order_value,
       ROUND(AVG(first_order_items), 2)   AS avg_first_order_items
FROM u
GROUP BY 1;
