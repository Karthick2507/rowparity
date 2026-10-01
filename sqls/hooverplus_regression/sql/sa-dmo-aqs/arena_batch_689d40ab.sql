-- account:    sa-dmo-aqs
-- skeleton:   3be522900671b5ca44adeab2148007d6
-- pattern:    689d40ab6d448a9d050349b5345d014f  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   process_batch_id > ?

SELECT
  COALESCE(deal_id, -1) AS deal_id,
  -1 AS buyer_group_id,
  COALESCE(auction__dsp_id, -1) AS dsp_id,
  IF(supply_source = 6, content_owner_network_id, -1) AS upstream_network_id,
  SUM(COALESCE(auction__bid_request_count, 1)) AS bid_request,
  0 AS bid_received,
  BITWISE_AND(COALESCE(auction__extra_flags, 0), 262144) > 0 AS is_prog_order_drop_baseline,
  DATE_TRUNC('HOUR', request__timestamp) AS event_date,
  process_batch_id
FROM ${bcv_auction}
CROSS JOIN UNNEST(auction__impression__deals__internal_deal_id) AS imp(deals__internal_deal_id)
CROSS JOIN UNNEST(imp.deals__internal_deal_id) AS deal(deal_id)
CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__supply_source, partners__entity_source) AS partner(network_id, content_owner_network_id, supply_source, entity_source)
WHERE
  (
    (
      (
        entity_source = 'auction' AND auction__is_faked_auction = FALSE
      )
      AND BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
    )
    AND COALESCE(auction__integration_type, '') IN ('normal', 'pg_td')
  )
  AND COALESCE(deal_id, -1) > 0
GROUP BY
  1,
  2,
  3,
  4,
  7,
  8,
  process_batch_id
UNION ALL
SELECT
  -1 AS deal_id,
  COALESCE(auction__buyer_group_id, -1) AS buyer_group_id,
  COALESCE(auction__dsp_id, -1) AS dsp_id,
  IF(supply_source = 6, content_owner_network_id, -1) AS upstream_network_id,
  SUM(COALESCE(auction__bid_request_count, 1)) AS bid_request,
  0 AS bid_received,
  BITWISE_AND(COALESCE(auction__extra_flags, 0), 262144) > 0 AS is_prog_order_drop_baseline,
  DATE_TRUNC('HOUR', request__timestamp) AS event_date,
  process_batch_id
FROM ${bcv_auction}
CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__supply_source, partners__entity_source) AS partner(network_id, content_owner_network_id, supply_source, entity_source)
WHERE
  (
    (
      (
        entity_source = 'auction' AND auction__is_faked_auction = FALSE
      )
      AND BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
    )
    AND COALESCE(auction__integration_type, '') IN ('normal', 'pg_td')
  )
  AND COALESCE(auction__buyer_group_id, -1) > 0
GROUP BY
  1,
  2,
  3,
  4,
  7,
  8,
  process_batch_id
UNION ALL
SELECT
  COALESCE(candidate__internal_deal_id, -1) AS deal_id,
  COALESCE(candidate__buyer_group_id, -1) AS buyer_group_id,
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  IF(supply_source = 6, content_owner_network_id, -1) AS upstream_network_id,
  0 AS bid_request,
  SUM(IF(BITWISE_AND(candidate__bid_status, 1) > 0, 1, 0)) AS bid_received,
  BITWISE_AND(COALESCE(auction__extra_flags, 0), 262144) > 0 AS is_prog_order_drop_baseline,
  DATE_TRUNC('HOUR', request__timestamp) AS event_date,
  process_batch_id
FROM ${bcv_candidate}
CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__supply_source, partners__entity_source) AS partner(network_id, content_owner_network_id, supply_source, entity_source)
WHERE
  entity_source = 'auction'
  AND COALESCE(candidate__integration_type, '') IN ('openrtb_normal', 'openrtb_pg_td')
GROUP BY
  1,
  2,
  3,
  4,
  7,
  8,
  process_batch_id
