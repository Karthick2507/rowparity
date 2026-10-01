-- account:    sa-presto-tier2
-- skeleton:   42da3f374ce07130b6ca41f0c5ba50d4
-- pattern:    bc75b592186588e9b35b1e425160ea54  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  candidate__internal_deal_id AS deal_id,
  COUNT(1) AS total_candidates,
  COUNT_IF(BITWISE_AND(candidate__bid_status, 8) > 0) AS delivered,
  AVG(candidate__price) AS avg_price,
  MIN(candidate__price) AS min_price,
  MAX(candidate__price) AS max_price,
  COUNT_IF(candidate__price < 0.1) AS very_low_price_count
FROM ${bcv_candidate}
WHERE
  (
    request__context__video_cro_network_id = 520311
    AND candidate__integration_type = 'openrtb_pg_td'
  )
  AND NOT candidate__internal_deal_id IS NULL
GROUP BY
  1
