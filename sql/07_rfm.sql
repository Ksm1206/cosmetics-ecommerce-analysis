-- =====================================================================
-- 4단계-④. RFM 고객 세분화
--
--   R(Recency)  : 데이터 마지막 날 기준, 마지막 구매로부터 지난 일수 (작을수록 좋음)
--   F(Frequency): 구매한 세션 수 = 주문 수
--   M(Monetary) : 총 구매 금액
--
-- R, M은 NTILE(5)로 5등급. F는 1회 구매자가 대다수라 NTILE을 쓰면 같은 1회 구매자가
-- 다른 등급으로 쪼개지므로, 구매 횟수 기준 구간으로 점수를 줍니다.
-- 세그먼트 기준은 예시입니다. 분포를 보고 조정한 뒤 그 이유를 README에 적으세요.
-- =====================================================================

-- name: rfm_build
CREATE OR REPLACE TABLE rfm AS
WITH base AS (
    SELECT user_id,
           DATE_DIFF('day', MAX(event_time), (SELECT MAX(event_time) FROM events)) AS recency,
           COUNT(DISTINCT user_session) AS frequency,
           ROUND(SUM(price), 2)         AS monetary
    FROM events WHERE event_type = 'purchase'
    GROUP BY 1
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency DESC) AS r_score,   -- 최근일수록 5점
           CASE WHEN frequency >= 10 THEN 5
                WHEN frequency >= 5  THEN 4
                WHEN frequency >= 3  THEN 3
                WHEN frequency  = 2  THEN 2
                ELSE 1 END                    AS f_score,
           NTILE(5) OVER (ORDER BY monetary)  AS m_score       -- 많이 쓸수록 5점
    FROM base
)
SELECT *,
       CASE WHEN r_score >= 4 AND f_score >= 3                 THEN '1) VIP'
            WHEN r_score >= 3 AND f_score >= 2                 THEN '2) 충성 고객'
            WHEN r_score >= 4 AND f_score = 1                  THEN '3) 신규 고객'
            WHEN r_score <= 2 AND (f_score >= 2 OR m_score >= 4) THEN '4) 이탈 위험'
            WHEN r_score <= 2                                  THEN '5) 휴면'
            ELSE                                                    '6) 관심 필요'
       END AS segment
FROM scored;

-- name: rfm_segment_summary
-- 세그먼트별 고객 수·매출 비중 → "상위 X% 고객이 매출 Y%" 같은 문장으로 정리
SELECT segment,
       COUNT(*) AS customers,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)           AS customer_pct,
       ROUND(SUM(monetary), 0)                                       AS revenue,
       ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 2) AS revenue_pct,
       ROUND(AVG(recency), 1)   AS avg_recency_days,
       ROUND(AVG(frequency), 2) AS avg_orders,
       ROUND(AVG(monetary), 2)  AS avg_monetary
FROM rfm
GROUP BY 1
ORDER BY 1;

-- name: rfm_scores
-- 고객별 결과 (용량이 커서 .gitignore 처리됨)
SELECT user_id::VARCHAR AS user_id, recency, frequency, monetary, r_score, f_score, m_score, segment
FROM rfm;
