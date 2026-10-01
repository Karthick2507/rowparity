-- account:    sa-realtime
-- skeleton:   76211120f4f5c978c7fe100a73bb71b8
-- pattern:    b92539cdd5652349c27745616aa10600  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP) - INTERVAL ? HOUR
--   request__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? HOUR

SELECT
  distributor_id,
  network_distributor.name AS distributor_name,
  cro_id,
  network_cro.name AS cro_name,
  profile_id AS profile_id,
  COUNT(*) AS no_selected_ads_with_real_acks
FROM (
  SELECT
    request__transaction_id,
    request__server_id,
    request__context__network_id AS distributor_id,
    COALESCE(
      request__context__video_cro_network_id,
      request__context__site_section_cro_network_id
    ) AS cro_id,
    request__context__profile_id AS profile_id
  FROM ${bcv_ack} AS ack
  WHERE
    BITWISE_AND(ack__flags, 65536) = 0 AND request__advertisement_count = 0
  GROUP BY
    1,
    2,
    3,
    4,
    5
)
LEFT JOIN oltp.fwmrm_oltp.network AS network_distributor
  ON distributor_id = network_distributor.id
LEFT JOIN oltp.fwmrm_oltp.network AS network_cro
  ON cro_id = network_cro.id
GROUP BY
  1,
  2,
  3,
  4,
  5
