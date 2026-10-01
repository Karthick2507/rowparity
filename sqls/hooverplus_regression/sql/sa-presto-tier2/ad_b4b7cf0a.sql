-- account:    sa-presto-tier2
-- skeleton:   3ae874c8a162bcc0f7dfa90b833d1d85
-- pattern:    b4b7cf0aa678dbb5edee08b680f6c4bf  (1 execution(s))
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
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS request_date,
  advertisement__placement_id AS placement_id,
  COUNT(*) AS total_ads_placed,
  SUM(IF(BITWISE_AND(COALESCE(advertisement__flags, 0), 2) = 0, 1, 0)) AS non_fallback_ads,
  SUM(IF(BITWISE_AND(COALESCE(advertisement__flags, 0), 2) > 0, 1, 0)) AS fallback_ads
FROM ${bcv_ad}
WHERE
  advertisement__placement_id = 94330123
GROUP BY
  1,
  2
