-- account:    sa-presto-tier2
-- skeleton:   7da554f37405fd5915816328d8b4f706
-- pattern:    d5792cbd4c4e9e0f40d1aa5e8054219e  (1 execution(s))
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
  ROUND(SUM(dsps_per_anc_group * num_groups * 1.0) / SUM(num_groups), 3) AS weighted_avg_dsps_per_anc,
  ROUND(AVG(dsps_per_anc_group * 1.0), 3) AS simple_avg_dsps_per_anc,
  SUM(num_groups) AS total_anc_groups
FROM (
  SELECT
    request__transaction_id,
    auction__network_id,
    COUNT(DISTINCT auction__dsp_id) AS dsps_per_anc_group,
    COUNT(*) AS num_groups
  FROM ${bcv_auction}
  WHERE
    NOT auction__dsp_id IS NULL
  GROUP BY
    request__transaction_id,
    auction__network_id
) AS sub
GROUP BY
  ()
