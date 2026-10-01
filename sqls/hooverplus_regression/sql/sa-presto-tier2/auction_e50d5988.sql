-- account:    sa-presto-tier2
-- skeleton:   979fe411b4196bbd4e1de65a35ed64e3
-- pattern:    e50d5988a8281ac184c77d3ae40d1b22  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp >= CURRENT_TIMESTAMP - INTERVAL ? HOUR

SELECT
  MAX(process_batch_id) AS max_batch
FROM ${bcv_auction}
WHERE
  auction__network_id = 169843
