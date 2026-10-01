-- account:    sa-presto-tier2
-- skeleton:   96aca0b403361e5304e9a6810ad19146
-- pattern:    c5bb01314ba1a0a742e95989ffb00f93  (1 execution(s))
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
  auction__integration_type,
  COUNT_IF(NOT auction__dsp_id IS NULL) AS with_dsp,
  COUNT(*) AS total
FROM ${bcv_auction}
WHERE
  BITWISE_AND(auction__auction_status, 2) > 0
GROUP BY
  1
