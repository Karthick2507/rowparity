-- account:    ychan375
-- skeleton:   f568fde190f33e8b7a984ceb4a96fc50
-- pattern:    7f746fcfa535ac8e27dadc42900f8843  (3 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE(request__timestamp) AS ack_date,
  slot__time_position_class,
  visitor__platform_group,
  visitor__platform_browser_id AS "browser",
  visitor__platform_os_id AS "os",
  o.display_name,
  CASE
    WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos)-[0-9]).*', 'admanager') = 'admanager'
    THEN 'ad manager'
    ELSE 'other'
  END AS "integration",
  COALESCE(
    SUM(
      (
        1 * (
          COALESCE(request__magnifier, 1)
        ) * (
          COALESCE(request__multiplier, 1)
        )
      )
    ),
    0
  ) AS ad_views
FROM ${bcv_ack}
LEFT JOIN db.default.d_lu_user_agent_platform AS b
  ON b.id = visitor__platform_browser_id AND b.type = 'product'
LEFT JOIN db.default.d_lu_user_agent_platform AS o
  ON o.id = visitor__platform_os_id AND o.type = 'os'
WHERE
  (
    (
      (
        ack__event_type = 'i' AND ack__event_name = 'defaultimpression'
      )
      AND BITWISE_AND(ack__flags, 1) = 1
    )
    AND BITWISE_AND(ack__flags, 16) = 0
  )
  AND BITWISE_AND((
    COALESCE(advertisement__flags, 0)
  ), 128) = 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7
ORDER BY
  7 DESC
