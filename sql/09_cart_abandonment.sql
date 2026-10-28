-- =====================================================================
-- 분석 보고서용 핵심 쿼리: 가설 1·2·3 (장바구니 이탈)
--
--   가설 1. 장바구니에 담은 상품의 절반 이상이 구매되지 않는다
--   가설 2. 저가 상품·소액 장바구니일수록 구매로 이어지지 않는다
--   가설 3. 장바구니에 담고 떠난 고객의 상당수는 며칠 안에 다시 돌아온다
--
-- 용어
--   장바구니 상품   : 한 세션에서 장바구니에 담긴 (세션, 상품) 쌍
--   장바구니 총액   : 한 세션에서 장바구니에 담긴 상품 가격의 합
--   장바구니 이탈   : 장바구니에 담았지만 그 세션에서 아무것도 사지 않은 세션
-- =====================================================================

-- name: build_session_carts
-- 세션별 요약 테이블 (가설 2·3에서 공통으로 사용)
CREATE OR REPLACE TABLE session_carts AS
WITH sp AS (                                   -- 세션 × 상품
    SELECT user_id, user_session, product_id,
           ANY_VALUE(price) AS price,
           MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events
    WHERE user_session IS NOT NULL
    GROUP BY 1, 2, 3
),
s AS (                                         -- 세션
    SELECT user_id, user_session,
           MIN(event_time) AS session_start,
           MAX(event_time) AS session_end
    FROM events
    WHERE user_session IS NOT NULL
    GROUP BY 1, 2
)
SELECT s.user_id, s.user_session, s.session_start, s.session_end,
       COALESCE(SUM(sp.price) FILTER (WHERE sp.carted = 1), 0) AS basket_value,
       COUNT(*) FILTER (WHERE sp.carted = 1)                    AS basket_items,
       MAX(sp.carted)    AS carted,
       MAX(sp.purchased) AS purchased
FROM s JOIN sp USING (user_id, user_session)
GROUP BY 1, 2, 3, 4;

-- name: h1_abandoned_value
-- 가설 1: 장바구니에 담겼지만 같은 세션에서 구매되지 않은 금액은 실제 매출의 몇 배인가
WITH sp AS (
    SELECT user_session, product_id, ANY_VALUE(price) AS price,
           MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events
    WHERE user_session IS NOT NULL
    GROUP BY 1, 2
)
SELECT COUNT(*) FILTER (WHERE carted = 1)                              AS carted_items,
       COUNT(*) FILTER (WHERE carted = 1 AND purchased = 0)            AS not_purchased_items,
       ROUND(COUNT(*) FILTER (WHERE carted = 1 AND purchased = 0) * 100.0
             / COUNT(*) FILTER (WHERE carted = 1), 2)                  AS not_purchased_pct,
       ROUND(SUM(price) FILTER (WHERE carted = 1 AND purchased = 0), 0) AS abandoned_value,
       (SELECT ROUND(SUM(price), 0) FROM events WHERE event_type = 'purchase') AS actual_revenue,
       ROUND(SUM(price) FILTER (WHERE carted = 1 AND purchased = 0)
             / (SELECT SUM(price) FROM events WHERE event_type = 'purchase'), 2) AS abandoned_to_revenue_x
FROM sp;

-- name: h2_basket_value_conversion
-- 가설 2: 장바구니 총액이 작을수록 그 세션의 구매 전환율이 낮은가
-- ※ 구간은 eda_price_summary 분포를 보고 조정하세요
SELECT CASE WHEN basket_value <  5 THEN '1) ~5'
            WHEN basket_value < 10 THEN '2) 5~10'
            WHEN basket_value < 20 THEN '3) 10~20'
            WHEN basket_value < 40 THEN '4) 20~40'
            ELSE                        '5) 40~' END AS basket_band,
       COUNT(*)                         AS cart_sessions,
       SUM(purchased)                   AS purchase_sessions,
       ROUND(AVG(purchased) * 100, 2)   AS cvr_pct,
       ROUND(AVG(basket_items), 2)      AS avg_items
FROM session_carts
WHERE carted = 1
GROUP BY 1
ORDER BY 1;

-- name: build_cart_abandons
-- 가설 3: 장바구니 이탈 세션마다 "다음 방문"과 "다음 구매" 시각을 붙인 테이블
-- 데이터 마지막 14일 안의 이탈은 복귀를 지켜볼 기간이 모자라 제외합니다.
CREATE OR REPLACE TABLE cart_abandons AS
WITH ordered AS (
    SELECT *,
           LEAD(session_start) OVER w AS next_visit,
           MIN(CASE WHEN purchased = 1 THEN session_start END) OVER (
               PARTITION BY user_id ORDER BY session_start
               ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING) AS next_purchase
    FROM session_carts
    WINDOW w AS (PARTITION BY user_id ORDER BY session_start)
)
SELECT user_id, user_session, session_end AS abandon_time, basket_value, basket_items,
       DATE_DIFF('hour', session_end, next_visit)    / 24.0 AS days_to_return,
       DATE_DIFF('hour', session_end, next_purchase) / 24.0 AS days_to_purchase
FROM ordered
WHERE carted = 1 AND purchased = 0
  AND session_end <= (SELECT MAX(event_time) FROM events) - INTERVAL 14 DAY;

-- name: h3_return_rate
-- 이탈 후 N일 안에 다시 방문한 비율(복귀율)과 구매한 비율(회수 구매율)
SELECT n_days,
       COUNT(*) AS abandons,
       ROUND(AVG(CASE WHEN days_to_return   <= n_days THEN 100.0 ELSE 0 END), 2) AS return_pct,
       ROUND(AVG(CASE WHEN days_to_purchase <= n_days THEN 100.0 ELSE 0 END), 2) AS recovered_purchase_pct
FROM cart_abandons, (VALUES (1), (3), (7), (14)) AS t(n_days)
GROUP BY 1
ORDER BY 1;

-- name: h3_days_to_return
-- 복귀한 고객은 이탈 후 며칠째에 돌아왔나 (리마인드 발송 시점 근거)
SELECT CASE WHEN days_to_return < 1  THEN '0) 24시간 이내'
            WHEN days_to_return < 2  THEN '1) 1일째'
            WHEN days_to_return < 3  THEN '2) 2일째'
            WHEN days_to_return < 4  THEN '3) 3일째'
            WHEN days_to_return < 8  THEN '4) 4~7일째'
            WHEN days_to_return < 15 THEN '5) 8~14일째'
            ELSE                          '6) 15일 이후' END AS return_day,
       COUNT(*) AS returns,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct,
       ROUND(SUM(COUNT(*)) OVER (ORDER BY return_day) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS cumulative_pct
FROM cart_abandons
WHERE days_to_return IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- name: h3_return_by_basket
-- 가설 2와 연결: 소액 장바구니 이탈 고객이 "미룬" 것이라면 더 많이 돌아와야 한다
SELECT CASE WHEN basket_value < 10 THEN '소액(10 미만)' ELSE '그 외(10 이상)' END AS basket_group,
       COUNT(*) AS abandons,
       ROUND(AVG(CASE WHEN days_to_return   <= 7 THEN 100.0 ELSE 0 END), 2) AS return_7d_pct,
       ROUND(AVG(CASE WHEN days_to_purchase <= 7 THEN 100.0 ELSE 0 END), 2) AS purchase_7d_pct
FROM cart_abandons
GROUP BY 1
ORDER BY 1;

-- name: h1_never_bought_value
-- 가설 1 보정: 고객 × 상품 단위로 "담았지만 5개월 동안 끝내 사지 않은" 금액
-- (같은 세션 기준은 나중에 돌아와 산 경우와 여러 세션에 중복으로 담긴 금액이 섞여 과대 추정됨)
WITH up AS (
    SELECT user_id, product_id, ANY_VALUE(price) AS price,
           MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events
    GROUP BY 1, 2
)
SELECT COUNT(*) FILTER (WHERE carted = 1) AS carted_pairs,
       ROUND(AVG(CASE WHEN purchased = 0 THEN 100.0 ELSE 0 END) FILTER (WHERE carted = 1), 2) AS never_bought_pct,
       ROUND(SUM(price) FILTER (WHERE carted = 1 AND purchased = 0), 0) AS never_bought_value,
       ROUND(SUM(price) FILTER (WHERE carted = 1 AND purchased = 0)
             / (SELECT SUM(price) FROM events WHERE event_type = 'purchase'), 2) AS x_revenue
FROM up;

-- name: h2_single_item_basket
-- 가설 2 교란 요인 점검: 상품을 1개만 담은 세션끼리 총액별 전환율 (상품 수 효과 제거)
SELECT CASE WHEN basket_value <  5 THEN '1) ~5'
            WHEN basket_value < 10 THEN '2) 5~10'
            WHEN basket_value < 20 THEN '3) 10~20'
            ELSE                        '4) 20~' END AS basket_band,
       COUNT(*) AS sessions,
       ROUND(AVG(purchased) * 100, 2) AS cvr_pct
FROM session_carts
WHERE carted = 1 AND basket_items = 1
GROUP BY 1
ORDER BY 1;
