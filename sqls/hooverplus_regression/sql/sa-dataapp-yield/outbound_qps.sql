-- account:    sa-dataapp-yield
-- skeleton:   0ff929f8483a4defddccd4e9e679a182
-- pattern:    729d2f9682dd5177bf51d30316c82a69  (1735 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_TRUNC('MINUTE', request_time) AS timestamp,
  video_cro_network_id,
  IF(video_cro_network_id = -2, 'all', COALESCE(nw.name, 'na')) AS video_cro_network_name,
  dsp_id,
  IF(dsp_id = -2, 'all', COALESCE(d_dsp.name, 'na')) AS dsp_name,
  server_group,
  MAX(qps) AS max_qps
FROM (
  SELECT
    request_time,
    COALESCE(video_cro_network_id, -2) AS video_cro_network_id,
    COALESCE(dsp_id, -2) AS dsp_id,
    COALESCE(server_group, 'all') AS server_group,
    SUM(request_number) AS qps
  FROM (
    SELECT
      request__timestamp AS request_time,
      COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
      COALESCE(auction__dsp_id, -1) AS dsp_id,
      COALESCE(request__server_group, 'na') AS server_group,
      SUM(
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
      ) AS request_number
    FROM ${bcv_auction}
    GROUP BY
      1,
      2,
      3,
      4
  ) AS a
  GROUP BY
    GROUPING SETS (
      (request_time, video_cro_network_id, dsp_id, server_group),
      (request_time, video_cro_network_id, dsp_id),
      (request_time, video_cro_network_id, server_group),
      (request_time, video_cro_network_id),
      (request_time, dsp_id),
      (
        request_time
      )
    )
)
LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
  ON d_dsp.id = dsp_id
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
