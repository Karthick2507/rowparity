-- account:    sa-presto-tier2
-- skeleton:   a05f5a1800c64f16403b37037e6fd9cc
-- pattern:    db99a1a3bf4371297e9265d0081f328b  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  dsps_per_anc_group,
  COUNT(*) AS num_groups,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM (
  SELECT
    request__transaction_id,
    auction__network_id,
    COUNT(DISTINCT auction__dsp_id) AS dsps_per_anc_group
  FROM ${bcv_auction}
  WHERE
    NOT auction__dsp_id IS NULL
  GROUP BY
    request__transaction_id,
    auction__network_id
) AS sub
GROUP BY
  dsps_per_anc_group
