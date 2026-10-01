-- account:    sa-dmo-aqs
-- skeleton:   d30537df6fb01e9fb0c69f5e1e894b2e
-- pattern:    f4bbcb2ae8592aa53a48e25406588f59  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, candidate, request, slot
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   process_batch_id > ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS event_date,
  COALESCE(ELEMENT_AT(t.inbound_listing_id, 1), -1) AS mkpl_listing_id,
  COALESCE(t.network_id, -1) AS buyer_network_id,
  COALESCE(request__context__site_section_id, -1) AS site_section_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  SUM(COALESCE(t.avails, 0)) AS true_avails,
  0 AS received_ads,
  0 AS impression,
  process_batch_id
FROM ${bcv_slot}
CROSS JOIN UNNEST(partners__network_id, partners__supply_source, partners__inbound_listing_id, partners__avails_category__avails) AS t(network_id, supply_source, inbound_listing_id, avails)
WHERE
  t.supply_source = 6 AND COALESCE(t.avails, 0) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  process_batch_id
UNION ALL
SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS event_date,
  COALESCE(ELEMENT_AT(t.inbound_listing_id, 1), -1) AS mkpl_listing_id,
  COALESCE(t.network_id, -1) AS buyer_network_id,
  COALESCE(request__context__site_section_id, -1) AS site_section_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  0 AS true_avails,
  SUM(
    COALESCE(t2.phase8_input_ad_number, 0) - COALESCE(t2.phase8_competition_failure_in_pick_many, 0)
  ) AS received_ads,
  0 AS impression,
  process_batch_id
FROM ${bcv_request}
CROSS JOIN UNNEST(execution_networks__network_id, execution_networks__supply_source, execution_networks__inbound_listing_id, execution_networks__network_selection_info__candidate_ad_funnel_metrics__demand_type, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__input_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__competition_failure_in_pick_many) AS t(network_id, supply_source, inbound_listing_id, demand_type, phase8_input_ad_number, phase8_competition_failure_in_pick_many)
CROSS JOIN UNNEST(t.demand_type, t.phase8_input_ad_number, t.phase8_competition_failure_in_pick_many) AS t2(demand_type, phase8_input_ad_number, phase8_competition_failure_in_pick_many)
WHERE
  (
    t.supply_source = 6 AND t2.demand_type = 2
  )
  AND COALESCE(t2.phase8_input_ad_number, 0) - COALESCE(t2.phase8_competition_failure_in_pick_many, 0) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  process_batch_id
UNION ALL
SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS event_date,
  COALESCE(ELEMENT_AT(t.inbound_listing_id, 1), -1) AS mkpl_listing_id,
  COALESCE(t.network_id, -1) AS buyer_network_id,
  COALESCE(request__context__site_section_id, -1) AS site_section_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  0 AS true_avails,
  SUM(1) AS received_ads,
  0 AS impression,
  process_batch_id
FROM ${bcv_candidate}
CROSS JOIN UNNEST(partners__network_id, partners__supply_source, partners__inbound_listing_id) AS t(network_id, supply_source, inbound_listing_id)
WHERE
  t.supply_source = 6 AND BITWISE_AND(COALESCE(candidate__bid_status, 0), 1) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  process_batch_id
UNION ALL
SELECT
  DATE_TRUNC('HOUR', ack__timestamp) AS event_date,
  COALESCE(ELEMENT_AT(t.inbound_listing_id, 1), -1) AS mkpl_listing_id,
  COALESCE(t.network_id, -1) AS buyer_network_id,
  COALESCE(request__context__site_section_id, -1) AS site_section_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  0 AS true_avails,
  0 AS received_ads,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS impression,
  process_batch_id
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__supply_source, partners__inbound_listing_id) AS t(network_id, supply_source, inbound_listing_id)
WHERE
  t.supply_source = 6 AND COALESCE(ack__metrics__raw_ad_impression, 0) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  process_batch_id
