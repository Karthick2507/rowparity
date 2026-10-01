-- account:    sa-dmo-aqs
-- skeleton:   38fa4208b9a7f309269a0b9abae090ab
-- pattern:    34a2be6cc5d7ca73265becfd66674bc5  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_TRUNC(?, LOCALTIMESTAMP)
--   request__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, LOCALTIMESTAMP))

SELECT
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  CASE
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
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
  COALESCE(slot__time_position_class, 'na') AS time_position_class,
  CASE
    WHEN candidate__integration_type = 'openrtb_pg_td'
    THEN 'fullstack_pg'
    WHEN candidate__integration_type = 'openrtb_normal'
    THEN 'fullstack_non_pg'
    WHEN candidate__integration_type = 'openrtb_sfx'
    THEN 'sfx_openrtb'
    WHEN candidate__integration_type = 'reseller_tag'
    AND advertisement__external_reseller__network_id = 127719
    THEN 'sfx_tag'
    WHEN candidate__integration_type = 'reseller_tag'
    THEN 'ssp_others'
    WHEN NOT advertisement__external_reseller__network_id IS NULL
    AND BITWISE_AND(advertisement__inventory_protection_flags, 8) > 0
    THEN 'reseller_tag_sstf'
    WHEN NOT advertisement__external_reseller__network_id IS NULL
    THEN 'reseller_tag_non_sstf'
    WHEN advertisement__external_reseller__network_id IS NULL
    AND BITWISE_AND(advertisement__inventory_protection_flags, 8) > 0
    THEN 'direct_sold_sstf'
    ELSE 'direct_sold_non_sstf'
  END AS market_integration_type,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  COALESCE(request__context__standard_genre_ids, ARRAY[]) AS genre_ids,
  COALESCE(visitor__standard_environment_id, -1) AS environment_id,
  COALESCE(visitor__standard_os_id, -1) AS os_id,
  COALESCE(visitor__standard_device_type_ids, ARRAY[]) AS device_type_ids,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) = 0, 1, 0)) AS ad_delivered_ad_primary,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) = 0, advertisement__duration, 0)) AS primary_ad_total_duration
FROM ${bcv_ad}
WHERE
  (
    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
  )
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
  11,
  12,
  13
