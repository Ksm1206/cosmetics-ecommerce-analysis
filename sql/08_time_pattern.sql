-- =====================================================================
-- 4단계-⑤. 시간대·요일별 패턴: 마케팅 메시지를 언제 보내야 하는가?
--
-- 주의: event_time은 UTC입니다. 쇼핑몰 현지 시간대가 공개되어 있지 않으므로
--       "UTC 기준"이라고 명시하고 해석하세요. (README 한계점에 기록)
-- 세션 시작 시각 기준으로 집계합니다.
-- =====================================================================

-- name: sessions_by_hour_dow
WITH s AS (
    SELECT user_session,
           MIN(event_time) AS session_start,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events WHERE user_session IS NOT NULL
    GROUP BY 1
)
SELECT ISODOW(session_start) AS dow,       -- 1=월 ... 7=일
       HOUR(session_start)   AS hour_utc,
       COUNT(*)              AS sessions,
       SUM(purchased)        AS purchase_sessions,
       ROUND(AVG(purchased) * 100, 2) AS cvr_pct
FROM s
GROUP BY 1, 2
ORDER BY 1, 2;

-- name: weekend_vs_weekday
-- 카이제곱 검정용 2x2 표: 노트북에서 scipy.stats.chi2_contingency로 검정
WITH s AS (
    SELECT user_session,
           MIN(event_time) AS session_start,
           MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
    FROM events WHERE user_session IS NOT NULL
    GROUP BY 1
)
SELECT CASE WHEN ISODOW(session_start) >= 6 THEN 'weekend' ELSE 'weekday' END AS day_type,
       SUM(purchased)                AS purchase_sessions,
       COUNT(*) - SUM(purchased)     AS no_purchase_sessions,
       COUNT(*)                      AS sessions,
       ROUND(AVG(purchased) * 100, 3) AS cvr_pct
FROM s
GROUP BY 1
ORDER BY 1;
