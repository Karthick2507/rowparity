-- account:    sa-dataapp-yield
-- skeleton:   cc9cf69738300e90159974c4a5507b43
-- pattern:    21c39a8198ba0aba7b5178190a66f2f8  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  tmp.*,
  COALESCE(nw.name, 'na') AS network_name,
  IF(
    COALESCE(raw_sales_channel, CAST(-1 AS INTEGER)) = 4,
    COALESCE(dsp_id, CAST(-1 AS BIGINT)),
    COALESCE(reseller_network_id, CAST(-1 AS BIGINT))
  ) AS third_party_partner_id,
  IF(COALESCE(raw_sales_channel, CAST(-1 AS INTEGER)) = 4, 'dsp', 'network') AS third_party_partner_type,
  CASE
    WHEN COALESCE(raw_sales_channel, CAST(-1 AS INTEGER)) = 4
    THEN dsp.name
    ELSE third_party_nw.name
  END AS third_party_partner_name,
  CASE
    WHEN raw_supply_source = 1
    THEN 'o_o'
    WHEN raw_supply_source = 2
    THEN 'direct_io_sold'
    WHEN raw_supply_source = 3
    THEN 'mrm_rule'
    WHEN raw_supply_source = 4
    THEN 'programmatic'
    WHEN raw_supply_source = 5
    THEN 'mpp'
    WHEN raw_supply_source = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS supply_source,
  CASE
    WHEN raw_sales_channel = 2
    THEN 'direct sold'
    WHEN raw_sales_channel = 3
    THEN 'reseller tag'
    WHEN raw_sales_channel = 4
    THEN 'programmatic'
    WHEN raw_sales_channel = 5
    THEN 'partner tag'
    ELSE 'na'
  END AS sales_channel,
  COALESCE(prof.name, 'na') AS profile_name,
  COALESCE(section.name, 'na') AS site_section_name
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(partner.network_id, CAST(-1 AS BIGINT)) AS network_id,
    COALESCE(auction.auction__dsp_id, -1) AS dsp_id,
    COALESCE(partner.reseller_network_id, -1) AS reseller_network_id,
    partner.supply_source AS raw_supply_source,
    partner.sales_channel AS raw_sales_channel,
    CASE
      WHEN auction__integration_type = 'normal'
      THEN 'fullstack_non_pg'
      WHEN auction__integration_type = 'pg_td'
      THEN 'fullstack_pg'
      WHEN auction__integration_type = 'mkpl_partner_tag'
      THEN 'mkpl_partner_tag'
      ELSE 'unknown'
    END AS integration_type,
    CASE
      WHEN BITWISE_AND(COALESCE(auction.auction__flags, 0), 512) > 0
      THEN 'pre-decision'
      WHEN BITWISE_AND(COALESCE(auction.auction__flags, 0), 1024) > 0
      THEN 'post-decision'
      ELSE ''
    END AS selection_phase,
    IF(
      BITWISE_AND(request__extra_flags, 1073741824) = 1073741824
      AND COALESCE(partner.supply_source, CAST(-1 AS INTEGER)) = 1,
      CAST(-3 AS BIGINT),
      COALESCE(request__context__profile_id, -1)
    ) AS profile_id,
    request__context__profile_type AS profile_type,
    IF(
      COALESCE(partner.sales_channel, CAST(-1 AS INTEGER)) = 4,
      COALESCE(auction.auction__site_section_id, CAST(-1 AS BIGINT)),
      COALESCE(partner.site_section_id, CAST(-1 AS BIGINT))
    ) AS site_section_id,
    SUM(
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
    ) AS third_party_ad_request,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'timeout',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_timeout,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'http_error',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_http_error,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'malformed_response',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_malformed_response,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'bid_response_id_nomatch',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_bid_response_id_nomatch,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'empty_bid_dealid',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_empty_bid_dealid,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'unexpected_bid_dealid',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_unexpected_bid_dealid,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'unknown_seat',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_unknown_seat,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'unexpected_external_ad_id',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_unexpected_external_ad_id,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'bid_impression_id_nomatch',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_bid_impression_id_nomatch,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'floor_price_notmet',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_floor_price_notmet,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'inapplicable_for_https',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_inaplicable_for_https,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'no_valid_price',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_no_valid_price,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'no_ad_markup',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_no_ad_markup,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'no_content',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_no_content,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'invalid_wrapper_url',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_invalid_wrapper_url,
    SUM(
      IF(
        COALESCE(auction.auction__error, '') = 'no_bids',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        CAST(0 AS BIGINT)
      )
    ) AS third_party_ad_no_bids,
    CAST(0 AS BIGINT) AS third_party_creative_request,
    CAST(0 AS BIGINT) AS third_party_creative_timeout,
    CAST(0 AS BIGINT) AS third_party_creative_http_error,
    CAST(0 AS BIGINT) AS third_party_creative_malformed_response,
    CAST(0 AS BIGINT) AS third_party_creative_max_wrapper_redirect,
    CAST(0 AS BIGINT) AS third_party_creative_inaplicable_for_https,
    CAST(0 AS BIGINT) AS third_party_creative_no_valid_creative,
    CAST(0 AS BIGINT) AS third_party_creative_no_ad_markup,
    CAST(0 AS BIGINT) AS third_party_creative_no_content,
    CAST(0 AS BIGINT) AS third_party_creative_invalid_wrapper_url
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(partners__sales_channel, partners__reseller_network_id, partners__network_id, partners__entity_source, partners__supply_source, partners__site_section_id) AS partner(sales_channel, reseller_network_id, network_id, entity_source, supply_source, site_section_id)
  WHERE
    (
      (
        COALESCE(auction.auction__integration_type, '') IN ('normal', 'pg_td', 'mkpl_partner_tag')
        AND partner.entity_source = 'auction'
      )
      AND auction.auction__is_faked_auction = FALSE
    )
    AND BITWISE_AND(COALESCE(auction.auction__auction_status, CAST(0 AS BIGINT)), 2) > 0
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
) AS tmp
LEFT JOIN db.default.d_network AS nw
  ON nw.id = network_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = dsp_id
LEFT JOIN db.default.d_network AS third_party_nw
  ON third_party_nw.id = reseller_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS prof
  ON prof.id = profile_id
LEFT JOIN db.default.d_site_section AS section
  ON site_section_id = section.id
