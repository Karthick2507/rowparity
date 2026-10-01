-- account:    sa-dataapp-yield
-- skeleton:   ba1f4c74aedd780f8915e564d70842ff
-- pattern:    f14efca4e7bbcc45811de12fabe08611  (2 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   tr.request__timestamp < CAST(? AS TIMESTAMP) + INTERVAL ? HOUR
--   tr.request__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? HOUR

SELECT
  DATE_TRUNC(
    'DAY',
    UTC_TIMESTAMP_TO_LOCAL(
      tr.request__timestamp,
      TIMEZONE_OF_NETWORK(tr.request__context__video_cro_network_id)
    )
  ) AS eventdate,
  tr.request__context__video_cro_network_id AS network_id,
  COALESCE(d_network.name, 'unknown') AS network,
  COALESCE(d_country.description, 'unknown') AS country,
  COALESCE(d_state.description, 'unknown') AS state,
  COALESCE(d_dma.description, 'unknown dma') AS dma,
  IF(NOT nf.function_id IS NULL, 'true', 'false') AS is_report,
  SUM(1) AS requests,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS raw_requests
FROM ${bcv_request} AS tr
LEFT JOIN db.default.d_lu_dma AS d_dma
  ON tr.visitor__dma_code_id = d_dma.id
LEFT JOIN db.default.d_network AS d_network
  ON tr.request__context__video_cro_network_id = d_network.id
LEFT JOIN db.default.d_country AS d_country
  ON tr.visitor__country_id = d_country.id
LEFT JOIN db.default.d_lu_state AS d_state
  ON tr.visitor__state_id = d_state.id
LEFT JOIN db.default.d_network_function AS nf
  ON nf.network_id = request__context__video_cro_network_id AND nf.function_id = 1021
WHERE
  (
    UTC_TIMESTAMP_TO_LOCAL(
      tr.request__timestamp,
      TIMEZONE_OF_NETWORK(tr.request__context__video_cro_network_id)
    ) >= CAST('2026-08-01 00:00:00' AS TIMESTAMP)
    AND UTC_TIMESTAMP_TO_LOCAL(
      tr.request__timestamp,
      TIMEZONE_OF_NETWORK(tr.request__context__video_cro_network_id)
    ) < CAST('2026-08-02 00:00:00' AS TIMESTAMP)
  )
  AND request__traffic_type = 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7
