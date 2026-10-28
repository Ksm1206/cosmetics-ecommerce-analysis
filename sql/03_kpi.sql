-- =====================================================================
-- 4단계-0. 핵심 KPI (대시보드 상단 카드용)
--
-- 지표 정의 (면접 단골 질문이니 README에도 적어 두세요)
--   매출(revenue)     : purchase 이벤트의 price 합 (수량 컬럼이 없어 1행 = 1개로 가정)
--   주문(order)       : 주문 ID가 없으므로 "구매가 일어난 세션 1개 = 주문 1건"으로 근사
--   객단가(AOV)       : 매출 / 주문 수
--   구매 전환율(CVR)  : 구매가 일어난 세션 / 전체 세션
--   재구매율          : 2번 이상 다른 세션에서 구매한 고객 / 전체 구매 고객
-- =====================================================================

-- name: kpi_overall
WITH s AS (
    SELECT user_session,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events WHERE user_session IS NOT NULL
    GROUP BY 1
),
buyer AS (
    SELECT user_id, COUNT(DISTINCT user_session) AS orders
    FROM events WHERE event_type = 'purchase'
    GROUP BY 1
)
SELECT (SELECT ROUND(SUM(price), 0) FROM events WHERE event_type = 'purchase')        AS revenue,
       (SELECT COUNT(DISTINCT user_id) FROM events)                                     AS users,
       (SELECT COUNT(*) FROM buyer)                                                     AS buyers,
       (SELECT SUM(orders) FROM buyer)                                                  AS orders,
       ROUND((SELECT SUM(price) FROM events WHERE event_type = 'purchase')
             / (SELECT SUM(orders) FROM buyer), 2)                                      AS aov,
       ROUND((SELECT AVG(purchased) * 100 FROM s), 2)                                   AS session_cvr_pct,
       ROUND((SELECT AVG(CASE WHEN orders >= 2 THEN 100.0 ELSE 0 END) FROM buyer), 2)   AS repurchase_rate_pct;

-- name: kpi_monthly
SELECT event_month,
       COUNT(DISTINCT user_id)                                          AS active_users,
       COUNT(DISTINCT user_session)                                     AS sessions,
       COUNT(DISTINCT user_id) FILTER (WHERE event_type = 'purchase')   AS buyers,
       COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'purchase') AS orders,
       ROUND(SUM(price) FILTER (WHERE event_type = 'purchase'), 0)      AS revenue,
       ROUND(SUM(price) FILTER (WHERE event_type = 'purchase')
             / COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'purchase'), 2) AS aov,
       ROUND(COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'purchase') * 100.0
             / COUNT(DISTINCT user_session), 2)                         AS session_cvr_pct
FROM events
GROUP BY 1
ORDER BY 1;

-- name: kpi_daily
-- 일별 추이: 대시보드 중단 라인차트 + 블랙프라이데이(2019-11-29) 같은 이벤트 확인
SELECT event_date,
       COUNT(DISTINCT user_id)                                          AS active_users,
       COUNT(DISTINCT user_session) FILTER (WHERE event_type = 'purchase') AS orders,
       ROUND(SUM(price) FILTER (WHERE event_type = 'purchase'), 0)      AS revenue
FROM events
GROUP BY 1
ORDER BY 1;
