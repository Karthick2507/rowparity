-- account:    sa-presto-tier2
-- skeleton:   e9262ebe9ddb975a8b23d72204acc91c
-- pattern:    22c7a82250ae2f3cc1e66d8cb67b6e47  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS request_day,
  COUNT(*) AS total_ads,
  SUM(IF(BITWISE_AND(COALESCE(advertisement__flags, 0), 32) > 0, 1, 0)) AS fallback_ads,
  SUM(IF(BITWISE_AND(COALESCE(advertisement__flags, 0), 67108864) > 0, 1, 0)) AS sstf_failed_ads,
  SUM(IF(ack__metrics__ad_impression > 0, 1, 0)) AS acked_ads
FROM ${bcv_ad}
WHERE
  advertisement__placement_id = 94330123
GROUP BY
  1
