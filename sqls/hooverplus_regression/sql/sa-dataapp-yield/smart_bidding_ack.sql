-- account:    sa-dataapp-yield
-- skeleton:   e80187476218e59f9e9ff8780b3dff5d
-- pattern:    99195f4d5211bbcec957d55a1d3c3cfc  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
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
    ELSE 'na'
  END AS market_integration_type,
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  COALESCE(d_dsp.name, 'na') AS dsp_name,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(auc_network.name, 'na') AS auction_network_name,
  IF(
    auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
    -1
  ) AS auction_upstream_network_id,
  COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
  COALESCE(NULLIF(auction__ab_test_items__bucket_id, ARRAY[]), ARRAY[-1]) AS bucket_id,
  COALESCE(NULLIF(auction__ab_test_items__collection_id, ARRAY[]), ARRAY[-1]) AS collection_id,
  COALESCE(ack__traffic_type, -1) AS ack_traffic_type,
  BITWISE_AND(COALESCE(auction__flags, 0), 1075838976) > 0 AS is_smart_bidding_traffic,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 2097152) > 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_smartly_bidding_baseline,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 4194304) > 0
      AND BITWISE_AND(auction__flags, 1048576) = 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_smartly_bidding_probe_original,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 4194304) > 0
      AND BITWISE_AND(auction__flags, 1048576) > 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_smartly_bidding_probe_additional,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 8388608) > 0
      AND BITWISE_AND(auction__flags, 1048576) = 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_smartly_bidding_feedback_original,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 8388608) > 0
      AND BITWISE_AND(auction__flags, 1048576) > 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_smartly_bidding_feedback_additional,
  SUM(
    CASE
      WHEN candidate__integration_type IN ('reseller_tag', 'openrtb_sfx')
      AND NOT advertisement__external_reseller__up_revenue IS NULL
      THEN advertisement__external_reseller__up_revenue * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0)
      WHEN candidate__integration_type IN ('openrtb_normal', 'openrtb_pg_td')
      THEN COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000
      WHEN candidate__integration_type IN ('mkpl_partner_tag')
      THEN COALESCE(
        ELEMENT_AT(
          REVERSE(partners__revenue),
          ARRAY_POSITION(REVERSE(partners__network_id), auction__network_id)
        ),
        0
      ) * COALESCE(
        ELEMENT_AT(
          MAP_FROM_ENTRIES(ARRAY[(62, 1.0), (49, 1.1421), (44, 1.3196), (21, 0.1097)]),
          auc_network.default_currency_id
        ),
        1
      ) * COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS ack_ad_revenue,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 2097152) > 0,
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
      0
    )
  ) AS ack_ad_revenue_smartly_bidding_baseline,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 4194304) > 0
      AND BITWISE_AND(auction__flags, 1048576) = 0,
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
      0
    )
  ) AS ack_ad_revenue_smartly_bidding_probe_original,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 4194304) > 0
      AND BITWISE_AND(auction__flags, 1048576) > 0,
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
      0
    )
  ) AS ack_ad_revenue_smartly_bidding_probe_additional,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 8388608) > 0
      AND BITWISE_AND(auction__flags, 1048576) = 0,
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
      0
    )
  ) AS ack_ad_revenue_smartly_bidding_feedback_original,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 8388608) > 0
      AND BITWISE_AND(auction__flags, 1048576) > 0,
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
      0
    )
  ) AS ack_ad_revenue_smartly_bidding_feedback_additional
FROM ${bcv_ack} AS t1
LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
  ON d_dsp.id = candidate__dsp_id
LEFT JOIN db.default.d_network AS auc_network
  ON auction__network_id = auc_network.id
LEFT JOIN db.default.d_network AS auc_upstream
  ON auc_upstream.id = IF(
    auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
    -1
  )
WHERE
  (
    candidate__integration_type IN (
      'openrtb_normal',
      'openrtb_pg_td',
      'reseller_tag',
      'openrtb_sfx',
      'mkpl_partner_tag'
    )
    AND BITWISE_AND(auction__flags, 8) = 0
  )
  AND ack__ack_entity_type = 'ad'
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
