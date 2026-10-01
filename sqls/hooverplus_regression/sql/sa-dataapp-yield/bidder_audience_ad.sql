-- account:    sa-dataapp-yield
-- skeleton:   eb6cefbadc5b0a1f472c5146a51706e7
-- pattern:    5f07b3f2d85fcc051b328cee880d1f5b  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  COALESCE(request__bid_request__publisher_id, 'na') AS publisher_id,
  COALESCE(request__bid_request__app_id, 'na') AS app_id,
  COALESCE(advertisement__ad_unit_id, -1) AS ad_unit_id,
  COALESCE(au.name, 'na') AS ad_unit_name,
  COALESCE(advertisement__ad_oo_network_id, -1) AS buyer_network_id,
  COALESCE(n.name, 'na') AS buyer_network_name,
  COALESCE(advertisement__placement_id, -1) AS placement_id,
  COALESCE(p.name, 'na') AS placement_name,
  COALESCE(request__server_pool, 'na') AS server_pool,
  CASE
    WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 1
    THEN 'sspu vast'
    WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 7
    THEN 'sspu ortb'
    WHEN BITWISE_AND(request__extra_flags3, 1) > 0
    THEN 'streaminghub openrtb'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND COALESCE(request__server_pool, 'na') = 'ads-sfx'
    THEN 'smi bidder'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    THEN 'mrm bidder'
    WHEN request__delivery_method = 'gateway'
    THEN 'linear - scheduled based'
    WHEN (
      BITWISE_AND(request__extra_flags, 1024) > 0
      AND BITWISE_AND(request__extra_flags, 16384) > 0
    )
    OR BITWISE_AND(request__extra_flags, 128) > 0
    THEN 'linear - gateway dai'
    WHEN (
      BITWISE_AND(request__extra_flags, 1024) > 0
      AND BITWISE_AND(request__extra_flags, 67108864) > 0
    )
    THEN 'linear - ip player'
    WHEN BITWISE_AND(request__extra_flags, 1024) > 0
    OR request__delivery_method = 'casucpsu'
    THEN 'linear - stb dai'
    WHEN visitor__user_agent_device_type = 'set top box'
    THEN 'stb vod'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live ott'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND NOT visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live others'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live ott'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND NOT visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live others'
    ELSE 'na'
  END AS service_type,
  COUNT(1) AS bid_total
FROM ${bcv_ad}
JOIN db.default.d_network AS n
  ON advertisement__ad_oo_network_id = n.id
JOIN db.default.d_ad_unit AS au
  ON advertisement__ad_unit_id = au.id
JOIN db.default.d_placement AS p
  ON advertisement__placement_id = p.id
WHERE
  BITWISE_AND(request__extra_flags2, 8) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11
