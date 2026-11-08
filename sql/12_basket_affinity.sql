-- =====================================================================
-- 후속 분석. 함께 사는 상품: 전략 1의 "함께 많이 사는 상품 추천" 후보 찾기
--
-- 같은 세션에서 함께 구매된 상품 쌍으로 연관 규칙을 계산합니다.
--   지지도(support)    : 전체 구매 세션 중 A와 B를 함께 산 세션 비율
--   신뢰도(confidence) : A를 산 세션 중 B도 산 비율 = P(B | A)
--   향상도(lift)       : 신뢰도 / B의 기본 구매 비율. 1보다 크면 A가 B 구매를 끌어올림
--
-- 표본이 작은 쌍은 우연히 향상도가 크게 나오므로 최소 횟수 기준을 둡니다.
-- 기준값(상품 100세션, 쌍 30세션)은 실제 데이터 분포를 보고 조정하세요.
-- =====================================================================

-- name: build_basket_rules
CREATE OR REPLACE TABLE basket_rules AS
WITH purchased AS (
    SELECT DISTINCT user_session, product_id
    FROM events
    WHERE event_type = 'purchase' AND user_session IS NOT NULL
),
n AS (
    SELECT COUNT(DISTINCT user_session) AS sessions FROM purchased
),
item AS (
    SELECT product_id, COUNT(*) AS item_sessions
    FROM purchased
    GROUP BY 1
    HAVING COUNT(*) >= 100
),
item_price AS (
    SELECT product_id, MEDIAN(price) AS price
    FROM events WHERE event_type = 'purchase'
    GROUP BY 1
),
pairs AS (
    SELECT a.product_id AS antecedent, b.product_id AS consequent, COUNT(*) AS together
    FROM purchased a
    JOIN purchased b
      ON a.user_session = b.user_session AND a.product_id <> b.product_id
    WHERE a.product_id IN (SELECT product_id FROM item)
      AND b.product_id IN (SELECT product_id FROM item)
    GROUP BY 1, 2
    HAVING COUNT(*) >= 30
)
SELECT p.antecedent, pa.price AS antecedent_price,
       p.consequent, pc.price AS consequent_price,
       p.together,
       ROUND(p.together * 1.0 / n.sessions, 5)                   AS support,
       ROUND(p.together * 1.0 / ia.item_sessions, 4)             AS confidence,
       ROUND((p.together * 1.0 / ia.item_sessions)
             / (ib.item_sessions * 1.0 / n.sessions), 2)         AS lift
FROM pairs p
JOIN item ia ON p.antecedent = ia.product_id
JOIN item ib ON p.consequent = ib.product_id
JOIN item_price pa ON p.antecedent = pa.product_id
JOIN item_price pc ON p.consequent = pc.product_id
CROSS JOIN n;

-- name: basket_affinity
-- 향상도 상위 상품 쌍
SELECT *
FROM basket_rules
ORDER BY lift DESC, together DESC
LIMIT 200;

-- name: small_basket_recommendations
-- 전략 1용: 저가 상품(5 미만)마다 향상도가 1보다 큰 짝 상품을 최대 3개 추천합니다.
-- 짝 상품을 더하면 장바구니가 무료배송 기준(예시 10)에 가까워지는지 pair_value로 확인합니다.
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY antecedent ORDER BY lift DESC, together DESC) AS rec_rank
    FROM basket_rules
    WHERE antecedent_price < 5 AND lift > 1
)
SELECT antecedent, antecedent_price, rec_rank, consequent, consequent_price,
       ROUND(antecedent_price + consequent_price, 2) AS pair_value,
       together, confidence, lift
FROM ranked
WHERE rec_rank <= 3
ORDER BY antecedent, rec_rank;
