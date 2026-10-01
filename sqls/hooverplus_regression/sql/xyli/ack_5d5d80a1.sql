-- account:    xyli
-- skeleton:   c879565aaf7eb242f427a5d922fef59f
-- pattern:    5d5d80a1e90d1ee48647c82bdc782eee  (2767 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  SUM(ack__metrics__ad_impression) AS ivt_ad_impression
FROM ${bcv_ack}
WHERE
  ack__traffic_type = 0
