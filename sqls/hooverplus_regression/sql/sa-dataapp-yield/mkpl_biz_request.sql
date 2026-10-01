-- account:    sa-dataapp-yield
-- skeleton:   8fa52f951fc87f4032ef9fe982647d33
-- pattern:    1e5cac512dfb0689c2cff61931259595  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COUNT(1) AS req_ad_request
FROM ${bcv_transaction}
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
WHERE
  request__is_first_request
  AND CARDINALITY(FILTER(FLATTEN(request__slots__outbound_order__order_id), x -> NOT x IS NULL)) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5
