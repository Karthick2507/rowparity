-- account:    sa-presto-tier2
-- skeleton:   8da0b61bb6947bf223c4b4c83df9f80a
-- pattern:    c26dcc4882e5b4b685a1a4cc85c459f4  (1 execution(s))
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
  request__log_sampling__magnifier AS log_sampling_magnifier,
  auction__auction_sampling__magnifier AS auction_sampling_magnifier,
  COUNT(*) AS row_count
FROM ${bcv_auction}
GROUP BY
  1,
  2
