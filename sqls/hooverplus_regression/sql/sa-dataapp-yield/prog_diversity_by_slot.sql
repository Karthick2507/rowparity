-- account:    sa-dataapp-yield
-- skeleton:   69e62851047a995a7aa086f39079522f
-- pattern:    a906dd5f68c50ec625abf9ae08bc1fa4  (698 execution(s))
-- in suite:   daily commitment
-- hoover:     candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  tmp.timestamp,
  market_integration_type,
  ab_test_bucket,
  video_cro_network_id,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  auction_site_id,
  COALESCE(site.name, 'na') AS auction_site_name,
  auction_network_id,
  COALESCE(auc_network.name, 'na') AS auction_network_name,
  dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
  buyer_platform_id,
  COALESCE(dp.name, 'na') AS buyer_platform_name,
  time_position_class,
  deal_diversity,
  buyer_diversity,
  global_advertiser_diversity,
  global_brand_diversity,
  global_industry_diversity,
  creative_diversity,
  duration_diversity,
  received_bid_density,
  resolved_bid_diversity,
  selected_bid_diversity,
  SUM(1) AS count,
  SUM(1) * received_bid_density AS bid_received,
  SUM(1) * resolved_bid_diversity AS bid_resolved,
  SUM(1) * selected_bid_diversity AS bid_selected
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    CASE
      WHEN ARRAYS_OVERLAP(auction__ab_test_items__bucket_id, ARRAY[230, 297, 303, 348, 351, 443, 445, 447])
      THEN 'pod-bidding'
      ELSE 'others'
    END AS ab_test_bucket,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(auction__site_id, -1) AS auction_site_id,
    COALESCE(auction__network_id, -1) AS auction_network_id,
    COALESCE(candidate__dsp_id, -1) AS dsp_id,
    COALESCE(candidate__buyer_platform_id, -1) AS buyer_platform_id,
    COALESCE(auction__time_position_class, 'na') AS time_position_class,
    request__transaction_id,
    request__server_id,
    COALESCE(candidate__rtb_impression_slot_index, -1) AS slot_index,
    candidate__integration_type AS market_integration_type,
    COUNT(DISTINCT candidate__internal_deal_id) AS deal_diversity,
    COUNT(
      DISTINCT CONCAT(
        CAST(COALESCE(candidate__dsp_id, -1) AS VARCHAR),
        COALESCE(candidate__external_seat_id, 'na'),
        CAST(COALESCE(candidate__bidding_buyer_id, -1) AS VARCHAR)
      )
    ) AS buyer_diversity,
    COUNT(DISTINCT COALESCE(ELEMENT_AT(candidate__global_advertiser_ids, 1), -1)) AS global_advertiser_diversity,
    COUNT(DISTINCT COALESCE(ELEMENT_AT(candidate__global_brand_ids, 1), -1)) AS global_brand_diversity,
    COUNT(DISTINCT COALESCE(ELEMENT_AT(candidate__global_industry_ids, 1), -1)) AS global_industry_diversity,
    COUNT(DISTINCT candidate__market_ad_id) AS creative_diversity,
    COUNT(DISTINCT candidate__duration) AS duration_diversity,
    SUM(1) AS received_bid_density,
    SUM(IF(BITWISE_AND(candidate__bid_status, 2) > 0, 1, 0)) AS resolved_bid_diversity,
    SUM(IF(BITWISE_AND(candidate__bid_status, 8) > 0, 1, 0)) AS selected_bid_diversity
  FROM ${bcv_candidate}
  WHERE
    (
      BITWISE_AND(candidate__bid_status, 1) > 0
      AND candidate__integration_type IN ('openrtb_normal', 'mkpl_partner_tag')
    )
    AND request__is_filtered = FALSE
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
    12
) AS tmp
LEFT JOIN db.default.d_network AS cro
  ON video_cro_network_id = cro.id
LEFT JOIN db.default.d_network AS auc_network
  ON auction_network_id = auc_network.id
LEFT JOIN (
  SELECT
    id,
    name
  FROM db.default.d_site_section_group
  WHERE
    group_type = 'site'
) AS site
  ON site.id = auction_site_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = dsp_id
LEFT JOIN db.default.d_ssp_buyer_platform AS dp
  ON dp.id = buyer_platform_id
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
  24
