-- account:    sa-presto-tier2
-- skeleton:   cee493cb4798efd9371e133c1600144b
-- pattern:    cf56e39488f6d3314474d9a23b9e2e30  (1 execution(s))
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
  COALESCE(plc.exclusivity, 'unknown') AS exclusivity,
  CASE
    WHEN NOT plc.frequency_cap_display IS NULL AND plc.frequency_cap_display <> ''
    THEN 'yes'
    ELSE 'no'
  END AS has_freq_cap,
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
LEFT JOIN db.default.d_placement AS plc
  ON plc.id = yf.placement_id
GROUP BY
  plc.exclusivity,
  CASE
    WHEN NOT plc.frequency_cap_display IS NULL AND plc.frequency_cap_display <> ''
    THEN 'yes'
    ELSE 'no'
  END
ORDER BY
  placement_count DESC
