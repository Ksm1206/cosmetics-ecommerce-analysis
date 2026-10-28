-- =====================================================================
-- 4단계-②. 어떤 브랜드·가격대·카테고리에서 장바구니 이탈이 높은가?
--
-- 전환율 정의: 장바구니에 담긴 (세션×상품) 중 같은 세션에서 구매된 비율
--   이벤트 개수로 나누면(구매 수 / 장바구니 수) 같은 상품을 여러 번 담은 경우가 부풀려지므로
--   (세션, 상품) 쌍 단위로 셉니다.
-- 표본이 적은 그룹은 전환율이 튀므로 최소 장바구니 수 조건(HAVING)을 둡니다.
--   샘플 데이터는 작아서 기준이 낮습니다. 실제 데이터에서는 1000 정도로 올리세요.
-- =====================================================================

-- name: cart_items
CREATE OR REPLACE TEMP TABLE cart_items AS
SELECT user_session, product_id,
       ANY_VALUE(brand)       AS brand,
       ANY_VALUE(price_band)  AS price_band,
       ANY_VALUE(category_id) AS category_id,
       ANY_VALUE(price)       AS price,
       MAX(CASE WHEN event_type = 'remove_from_cart' THEN 1 ELSE 0 END) AS removed,
       MAX(CASE WHEN event_type = 'purchase'         THEN 1 ELSE 0 END) AS purchased
FROM events
WHERE user_session IS NOT NULL
GROUP BY 1, 2
HAVING MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) = 1;

-- name: conv_by_price_band
SELECT price_band,
       COUNT(*)                         AS carted_items,
       SUM(purchased)                   AS purchased_items,
       ROUND(AVG(purchased) * 100, 2)   AS cart_to_purchase_pct,
       ROUND(AVG(removed) * 100, 2)     AS remove_pct
FROM cart_items
GROUP BY 1
ORDER BY 1;

-- name: conv_by_brand
SELECT brand,
       COUNT(*)                         AS carted_items,
       SUM(purchased)                   AS purchased_items,
       ROUND(AVG(purchased) * 100, 2)   AS cart_to_purchase_pct,
       ROUND(AVG(removed) * 100, 2)     AS remove_pct,
       ROUND(AVG(price), 2)             AS avg_price
FROM cart_items
GROUP BY 1
HAVING COUNT(*) >= 100           -- 실제 데이터: 1000
ORDER BY cart_to_purchase_pct;

-- name: conv_by_category
SELECT category_id::VARCHAR             AS category_id,   -- 큰 숫자가 엑셀에서 깨지지 않게 문자로
       COUNT(*)                         AS carted_items,
       ROUND(AVG(purchased) * 100, 2)   AS cart_to_purchase_pct,
       ROUND(AVG(price), 2)             AS avg_price
FROM cart_items
GROUP BY 1
HAVING COUNT(*) >= 100           -- 실제 데이터: 1000
ORDER BY carted_items DESC
LIMIT 30;

-- name: top_products_low_conversion
-- 조회는 많은데 구매가 적은 상품: 상세페이지·가격 점검 후보
SELECT product_id::VARCHAR AS product_id,
       ANY_VALUE(brand) AS brand,
       ROUND(ANY_VALUE(price), 2) AS price,
       COUNT(*) FILTER (WHERE event_type = 'view')     AS views,
       COUNT(*) FILTER (WHERE event_type = 'purchase') AS purchases,
       ROUND(COUNT(*) FILTER (WHERE event_type = 'purchase') * 100.0
             / COUNT(*) FILTER (WHERE event_type = 'view'), 2) AS view_to_purchase_pct
FROM events
GROUP BY 1
HAVING COUNT(*) FILTER (WHERE event_type = 'view') >= 50   -- 실제 데이터: 1000
ORDER BY views DESC
LIMIT 30;
