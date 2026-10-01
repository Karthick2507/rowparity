-- account:    sa-presto-tier2
-- skeleton:   573c75d33c1014b442dec46525ba4c7b
-- pattern:    f3b7651f62c6f07aff5c61b72ec0c546  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)
--   process_batch_id <= ?
--   process_batch_id >= ?

SELECT
  meta.frequency_cap,
  COUNT(DISTINCT yf.placement_id) AS placement_count,
  SUM(yf.impressions) AS total_impressions
FROM (
  SELECT
    advertisement__placement_id AS placement_id,
    SUM(COALESCE(ack__metrics__ad_impression, 0)) AS impressions
  FROM ${bcv_ack}
  WHERE
    (
      (
        (
          request__context__network_id = 10613 AND request__is_filtered = FALSE
        )
        AND advertisement__is_bumper = FALSE
      )
      AND ack__is_private_impression = FALSE
    )
    AND COALESCE(ack__metrics__ad_impression, 0) <> 0
  GROUP BY
    advertisement__placement_id
) AS yf
LEFT JOIN db.default.d_placement_metadata AS meta
  ON meta.id = yf.placement_id
GROUP BY
  meta.frequency_cap
ORDER BY
  placement_count DESC
