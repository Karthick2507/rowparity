-- account:    sa-dmo-aqs
-- skeleton:   94aa932a4a1d63a2d0e0cf6e29c5e34d
-- pattern:    da9f31a1a99b6189fd78a780837fe639  (694 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   process_batch_id > ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS event_date,
  COALESCE(network_id, -1) AS network_id,
  COALESCE(mapped_asset_ids, ARRAY[]) AS mapped_asset_ids,
  COALESCE(mapped_site_section_ids, ARRAY[]) AS mapped_site_section_ids,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS requests,
  process_batch_id
FROM ${bcv_request}
CROSS JOIN UNNEST(execution_networks__network_id, execution_networks__mapped_asset_ids, execution_networks__mapped_site_section_ids) AS t(network_id, mapped_asset_ids, mapped_site_section_ids)
GROUP BY
  1,
  2,
  3,
  4,
  process_batch_id
