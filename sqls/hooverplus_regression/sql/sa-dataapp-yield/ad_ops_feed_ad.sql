-- account:    sa-dataapp-yield
-- skeleton:   18d725606db7228fd6a70e66de4998dc
-- pattern:    041ed5897f0c6208fa2ee501aad2b3b0  (695 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  timestamp,
  COALESCE(video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(distributor_network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(ad_network_id, -1) AS ad_network_id,
  COALESCE(ad_nw.name, 'na') AS ad_network_name,
  COALESCE(ad_original_network_id, -1) AS ad_original_network_id,
  COALESCE(ad_orig_nw.name, 'na') AS ad_original_network_name,
  COALESCE(advertisement__external_reseller__network_id, -1) AS ad_external_network_id,
  IF(advertisement__external_reseller__network_id = -1, 'na', COALESCE(ex_nw.name, 'na')) AS ad_external_network_name,
  COALESCE(co_id, -1) AS upstream_network_id,
  COALESCE(up_nw.name, 'na') AS upstream_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
  is_filtered,
  service_type,
  platform,
  server_group,
  linear_campaign_type,
  COALESCE(advertisement__ad_id, -1) AS ad_id,
  COALESCE(advertisement__placement_id, -1) AS placement_id,
  COALESCE(plc.name, 'na') AS placement_name,
  COALESCE(advertisement__creative_id, -1) AS creative_id,
  COALESCE(advertisement__rendition_id, -1) AS rendition_id,
  COALESCE(advertisement__io_id, -1) AS io_id,
  COALESCE(advertisement__campaign_id, -1) AS campaign_id,
  COALESCE(campaign.name, 'na') AS campaign_name,
  is_mrm2mrm_integration,
  sales_channel,
  market_integration_type,
  CASE
    WHEN plc.budget_model IN ('all_impression', 'sov', 'sop', 'soi')
    THEN 'sponsorship'
    WHEN plc.budget_model IN ('demographic_impression_target', 'demographic_currency_target')
    THEN 'rbp'
    WHEN plc.budget_model IN ('custom_event_target', 'custom_currency_target')
    THEN 'cpx'
    WHEN plc.budget_model = 'evergreen'
    THEN 'evergreen'
    WHEN plc.budget_model IN ('currency_target', 'impression_target')
    THEN 'standard'
    WHEN io.event_goal = -2
    THEN 'evergreen'
    WHEN NOT io.event_goal IS NULL OR NOT io.currency_goal IS NULL
    THEN 'standard'
    ELSE 'na'
  END AS budget_model,
  ad_unit_type,
  COALESCE(advertisement__agency_id, -1) AS ad_agency_id,
  COALESCE(advertisement__advertiser_id, -1) AS ad_advertiser_id,
  COALESCE(advertiser.name, 'na') AS ad_advertiser_name,
  COALESCE(agency.name, 'na') AS ad_agency_name,
  COALESCE(plc.gurantee_mode, 'na') AS guarantee_mode,
  spot_type,
  spot_id,
  bid_shading_enabled,
  bid_shading_applied,
  COALESCE(candidate__internal_deal_id, -1) AS deal_id,
  COALESCE(d_ssp_deal_metadata.external_id, 'na') AS public_deal_id,
  COALESCE(tvn.mrm_network_id, -1) AS tv_network_mrm_id,
  ad_delivered_ad,
  ad_delivered_ad_primary,
  ad_delivered_ad_fallback,
  ad_err_sstf_failed,
  ad_err_playlist_ack_failed,
  ad_err_sstf_failed_as_primary,
  ad_err_playlist_ack_failed_as_primary,
  ad_err_sstf_failed_as_fallback,
  ad_err_playlist_ack_failed_as_fallback,
  ad_creative_audience_targeting_success,
  ad_creative_audience_targeting_fail,
  ad_creative_audience_targeting_default,
  ad_split_avail_pacing_capped,
  ad_split_avail_no_candidates,
  ad_bidding_revenue,
  ad_bidding_original_revenue,
  ad_bidding_modified_revenue,
  ad_delivered_ad_with_geo_targeting,
  ad_delivered_as_sstf_fallback,
  ad_delivered_in_high_value_bucket
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    request__context__video_cro_network_id AS video_cro_network_id,
    request__context__network_id AS distributor_network_id,
    n_id AS ad_network_id,
    advertisement__ad_oo_network_id AS ad_original_network_id,
    IF(
      candidate__integration_type = 'mkpl_partner_tag',
      advertisement__ad_oo_network_id,
      advertisement__external_reseller__network_id
    ) AS advertisement__external_reseller__network_id,
    co_id,
    request__context__profile_id,
    candidate__dsp_id,
    CASE WHEN request__is_filtered THEN 'true' ELSE 'false' END AS is_filtered,
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
    COALESCE(visitor__user_agent_device_type, 'na') AS platform,
    COALESCE(request__server_group, 'na') AS server_group,
    CASE
      WHEN BITWISE_AND(request__extra_flags, 1024) > 0
      AND NOT advertisement__extra_flags IS NULL
      AND BITWISE_AND(advertisement__extra_flags, 3) = 1
      THEN 'dynvar'
      WHEN BITWISE_AND(request__extra_flags, 1024) > 0
      AND NOT advertisement__extra_flags IS NULL
      AND BITWISE_AND(advertisement__extra_flags, 3) = 2
      THEN 'dynear'
      WHEN BITWISE_AND(request__extra_flags, 1024) > 0
      AND NOT advertisement__extra_flags IS NULL
      AND BITWISE_AND(advertisement__extra_flags, 3) = 3
      THEN 'default'
      WHEN BITWISE_AND(request__extra_flags, 1024) > 0
      AND NOT advertisement__extra_flags IS NULL
      AND BITWISE_AND(advertisement__extra_flags, 3) = 0
      THEN 'linear'
      ELSE 'na'
    END AS linear_campaign_type,
    advertisement__ad_id,
    advertisement__placement_id,
    advertisement__creative_id,
    advertisement__rendition_id,
    advertisement__io_id,
    advertisement__campaign_id,
    CASE
      WHEN request__context__video_cro_network_id <> IF(
        NOT candidate__ad_id IS NULL,
        COALESCE(advertisement__replaced_ad_network_id, advertisement__ad_oo_network_id),
        advertisement__ad_oo_network_id
      )
      THEN 'true'
      ELSE 'false'
    END AS is_mrm2mrm_integration,
    CASE
      WHEN BITWISE_AND(advertisement__flags, 4194304) > 0
      THEN 'markets'
      WHEN BITWISE_AND(advertisement__extra_flags2, 2) > 0
      THEN 'markets'
      WHEN NOT advertisement__external_reseller__network_id IS NULL
      THEN 'markets'
      ELSE 'direct_sold'
    END AS sales_channel,
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
      WHEN candidate__integration_type = 'mkpl_partner_tag'
      THEN 'mkpl_partner_tag'
      WHEN NOT advertisement__external_reseller__network_id IS NULL
      THEN 'reseller_tag'
      ELSE 'na'
    END AS market_integration_type,
    candidate__internal_deal_id,
    CASE
      WHEN STRPOS(slot__time_position_class, 'preroll') > 0
      THEN 'preroll'
      WHEN STRPOS(slot__time_position_class, 'midroll') > 0
      THEN 'midroll'
      WHEN STRPOS(slot__time_position_class, 'postroll') > 0
      THEN 'postroll'
      WHEN STRPOS(slot__time_position_class, 'overlay') > 0
      THEN 'overlay'
      WHEN STRPOS(slot__time_position_class, 'display') > 0
      THEN 'display'
      ELSE 'na'
    END AS ad_unit_type,
    advertisement__agency_id,
    advertisement__advertiser_id,
    COALESCE(slot__avail_type, 'na') AS spot_type,
    IF(
      advertisement__ad_oo_network_id = 384777
      AND BITWISE_AND(request__extra_flags, 1024) > 0
      AND BITWISE_AND(request__extra_flags, 16384) = 0
      AND BITWISE_AND(request__extra_flags, 67108864) = 0,
      COALESCE(advertisement__spot_id, ''),
      ''
    ) AS spot_id,
    IF(
      BITWISE_AND(request__extra_flags, 1024) > 0,
      COALESCE(request__context__tv_network_id, -1),
      -1
    ) AS tv_network_id,
    IF(BITWISE_AND(advertisement__extra_flags2, 128) > 0, 'true', 'false') AS bid_shading_enabled,
    IF(BITWISE_AND(advertisement__extra_flags2, 256) > 0, 'true', 'false') AS bid_shading_applied,
    COUNT(1) AS ad_delivered_ad,
    SUM(IF(BITWISE_AND(advertisement__flags, 67108864) > 0, 1, 0)) AS ad_err_sstf_failed,
    SUM(IF(BITWISE_AND(advertisement__flags, 8388608) > 0, 1, 0)) AS ad_err_playlist_ack_failed,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 32) = 0,
        1,
        0
      )
    ) AS ad_err_sstf_failed_as_primary,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 8388608) > 0
        AND BITWISE_AND(advertisement__flags, 32) = 0,
        1,
        0
      )
    ) AS ad_err_playlist_ack_failed_as_primary,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 32) > 0,
        1,
        0
      )
    ) AS ad_err_sstf_failed_as_fallback,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 8388608) > 0
        AND BITWISE_AND(advertisement__flags, 32) > 0,
        1,
        0
      )
    ) AS ad_err_playlist_ack_failed_as_fallback,
    SUM(IF(BITWISE_AND(advertisement__flags, 32) = 0, 1, 0)) AS ad_delivered_ad_primary,
    SUM(IF(BITWISE_AND(advertisement__flags, 32) > 0, 1, 0)) AS ad_delivered_ad_fallback,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 32) > 0
        AND BITWISE_AND(advertisement__flags, 33554432) > 0,
        1,
        0
      )
    ) AS ad_delivered_as_sstf_fallback,
    SUM(IF(BITWISE_AND(advertisement__extra_flags, 2097152) > 0, 1, 0)) AS ad_creative_audience_targeting_success,
    SUM(IF(BITWISE_AND(advertisement__extra_flags, 4194304) > 0, 1, 0)) AS ad_creative_audience_targeting_fail,
    SUM(IF(BITWISE_AND(advertisement__extra_flags, 1024) > 0, 1, 0)) AS ad_creative_audience_targeting_default,
    SUM(
      IF(
        slot__avail_type = 'addressable_split_avail'
        AND BITWISE_AND(request__decision_info__value3, 65535) > 0
        AND BITWISE_AND(request__decision_info__value3 / 65536, 65535) = 0,
        1,
        0
      )
    ) AS ad_split_avail_pacing_capped,
    SUM(
      IF(
        slot__avail_type = 'addressable_split_avail'
        AND BITWISE_AND(request__decision_info__value3 / 4294967296, 65535) = 0,
        1,
        0
      )
    ) AS ad_split_avail_no_candidates,
    SUM(COALESCE(bidding_modified_revenue, 0)) AS ad_bidding_modified_revenue,
    SUM(COALESCE(bidding_original_revenue, 0)) AS ad_bidding_original_revenue,
    SUM(COALESCE(bidding_revenue, 0)) AS ad_bidding_revenue,
    SUM(
      IF(
        CARDINALITY(
          ARRAY_INTERSECT(
            TRANSFORM(
              advertisement__active_term_id,
              x -> BITWISE_AND(BITWISE_LOGICAL_SHIFT_RIGHT(x, 48, 64), 255)
            ),
            ARRAY[2, 3, 4, 16, 17]
          )
        ) > 0,
        1,
        0
      )
    ) AS ad_delivered_ad_with_geo_targeting,
    SUM(IF(BITWISE_AND(COALESCE(advertisement__extra_flags2, 0), 131072) > 0, 1, 0)) AS ad_delivered_in_high_value_bucket
  FROM ${bcv_ad} AS a
  CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__network_is_extra_item_owner, partners__content_owner_bidding_modified_revenue, partners__content_owner_bidding_original_revenue, partners__content_owner_bidding_revenue) AS network(n_id, co_id, is_extra_item_owner, bidding_modified_revenue, bidding_original_revenue, bidding_revenue)
  WHERE
    (
      (
        request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
      )
      AND NOT advertisement__ad_id IS NULL
    )
    AND is_extra_item_owner
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
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32
) AS tmp
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_network AS ad_nw
  ON ad_nw.id = tmp.ad_network_id
LEFT JOIN db.default.d_network AS ad_orig_nw
  ON ad_orig_nw.id = tmp.ad_original_network_id
LEFT JOIN db.default.d_network AS ex_nw
  ON ex_nw.id = advertisement__external_reseller__network_id
LEFT JOIN db.default.d_network AS up_nw
  ON up_nw.id = tmp.co_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = candidate__dsp_id
LEFT JOIN db.default.d_placement AS plc
  ON plc.id = advertisement__placement_id
LEFT JOIN db.default.d_campaign AS campaign
  ON campaign.id = tmp.advertisement__campaign_id
LEFT JOIN db.default.d_io AS io
  ON io.ad_group_id = tmp.advertisement__io_id
LEFT JOIN db.default.d_advertiser AS advertiser
  ON advertiser.id = tmp.advertisement__advertiser_id
LEFT JOIN db.default.d_agency AS agency
  ON agency.id = tmp.advertisement__agency_id
LEFT JOIN db.default.d_ssp_deal_metadata AS d_ssp_deal_metadata
  ON d_ssp_deal_metadata.id = candidate__internal_deal_id
LEFT JOIN db.default.d_linear_television_network AS tvn
  ON tvn.id = tv_network_id
