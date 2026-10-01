-- account:    sa-presto-tier2
-- skeleton:   e781d272e6fce27587f47759c2f470d2
-- pattern:    8d55d508b9df677c8b81229101b6c93b  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(request__timestamp, '%y-%m-%d %h:00') AS hour_bucket,
  SUM(IF(BITWISE_AND(COALESCE(request__log_sampling__magnifier, 1), 1) > 0, 1, 0)) AS requests,
  SUM(IF(BITWISE_AND(COALESCE(request__phase6_outputs, 0), 1) > 0, 1, 0)) AS phase6_candidate_ads,
  SUM(IF(BITWISE_AND(COALESCE(request__phase8_outputs, 0), 1) > 0, 1, 0)) AS phase8_eligible_ads,
  SUM(IF(BITWISE_AND(COALESCE(request__phase9_outputs, 0), 1) > 0, 1, 0)) AS phase9_placed_ads
FROM ${bcv_transaction}
WHERE
  CARDINALITY(FLATTEN(request__advertisements__placement_id)) > 0
  AND CONTAINS(FLATTEN(request__advertisements__placement_id), CAST('94330123' AS BIGINT))
GROUP BY
  1
