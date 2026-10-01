-- account:    sa-presto-tier2
-- skeleton:   7e05806a3ae1ce5b047445ac1a89ee39
-- pattern:    f381b04e525e2d053f7a28f8a7c3dc1f  (1 execution(s))
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
  COUNT(DISTINCT advertisement__placement_id) AS distinct_placements_june
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
