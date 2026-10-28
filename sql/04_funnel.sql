-- =====================================================================
-- 4단계-①. 퍼널 분석: 조회 → 장바구니 → 구매 중 어디서 가장 많이 이탈하는가?
--
-- 세션 단위로 "이 세션에서 해당 행동을 한 번이라도 했는가"를 봅니다.
-- 주의: 이 데이터에는 장바구니를 거치지 않은 구매나, 이전 세션에서 담고 다음 세션에서
--       구매한 경우가 섞여 있습니다. 그래서 "단계를 순서대로 밟은 세션"만 세는
--       엄격한 퍼널(strict)도 함께 계산해 비교합니다. 둘 중 무엇을 썼는지 README에 명시하세요.
-- =====================================================================

-- name: funnel_session
WITH s AS (
    SELECT user_session,
           MAX(CASE WHEN event_type = 'view'     THEN 1 ELSE 0 END) AS viewed,
           MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events
    WHERE user_session IS NOT NULL
    GROUP BY 1
)
SELECT 'loose'  AS funnel_type,
       SUM(viewed)    AS view_sessions,
       SUM(carted)    AS cart_sessions,
       SUM(purchased) AS purchase_sessions,
       ROUND(SUM(carted)    * 100.0 / SUM(viewed), 2) AS view_to_cart_pct,
       ROUND(SUM(purchased) * 100.0 / SUM(carted), 2) AS cart_to_purchase_pct,
       ROUND(SUM(purchased) * 100.0 / SUM(viewed), 2) AS view_to_purchase_pct
FROM s
UNION ALL
SELECT 'strict' AS funnel_type,
       SUM(viewed),
       SUM(viewed * carted),
       SUM(viewed * carted * purchased),
       ROUND(SUM(viewed * carted) * 100.0 / SUM(viewed), 2),
       ROUND(SUM(viewed * carted * purchased) * 100.0 / SUM(viewed * carted), 2),
       ROUND(SUM(viewed * carted * purchased) * 100.0 / SUM(viewed), 2)
FROM s;

-- name: funnel_monthly
-- 월별로 퍼널이 달라지는가? (11월 할인 시즌에 장바구니→구매가 오르는지 등)
WITH s AS (
    SELECT user_session,
           MIN(event_month) AS event_month,
           MAX(CASE WHEN event_type = 'view'     THEN 1 ELSE 0 END) AS viewed,
           MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events
    WHERE user_session IS NOT NULL
    GROUP BY 1
)
SELECT event_month,
       SUM(viewed) AS view_sessions,
       SUM(carted) AS cart_sessions,
       SUM(purchased) AS purchase_sessions,
       ROUND(SUM(carted)    * 100.0 / SUM(viewed), 2) AS view_to_cart_pct,
       ROUND(SUM(purchased) * 100.0 / NULLIF(SUM(carted), 0), 2) AS cart_to_purchase_pct
FROM s
GROUP BY 1
ORDER BY 1;

-- name: funnel_product_level
-- 상품 단위 퍼널: 장바구니에 담긴 상품(세션×상품) 중 몇 %가 삭제/구매/방치되었나
WITH sp AS (
    SELECT user_session, product_id,
           MAX(CASE WHEN event_type = 'cart'             THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'remove_from_cart' THEN 1 ELSE 0 END) AS removed,
           MAX(CASE WHEN event_type = 'purchase'         THEN 1 ELSE 0 END) AS purchased
    FROM events
    WHERE user_session IS NOT NULL
    GROUP BY 1, 2
)
SELECT COUNT(*) AS carted_items,
       ROUND(AVG(purchased) * 100, 2)                                     AS purchased_pct,
       ROUND(AVG(CASE WHEN removed = 1 AND purchased = 0 THEN 100.0 ELSE 0 END), 2) AS removed_pct,
       ROUND(AVG(CASE WHEN removed = 0 AND purchased = 0 THEN 100.0 ELSE 0 END), 2) AS abandoned_pct
FROM sp
WHERE carted = 1;
