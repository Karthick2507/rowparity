-- account:    sa-dataapp-yield
-- skeleton:   fd2835ba183177c1cea43a65fe329323
-- pattern:    f0c36c6209cfd53f884a7fa1e6811569  (696 execution(s))
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
  COALESCE(partner.network_id, CAST(-1 AS BIGINT)) AS network_id,
  nw.name AS network_name,
  COALESCE(partner.reseller_network_id, CAST(-1 AS BIGINT)) AS third_party_partner_id,
  'network' AS third_party_partner_type,
  third_party_nw.name AS third_party_partner_name,
  CASE
    WHEN partner.supply_source = 1
    THEN 'o_o'
    WHEN partner.supply_source = 2
    THEN 'direct_io_sold'
    WHEN partner.supply_source = 3
    THEN 'mrm_rule'
    WHEN partner.supply_source = 4
    THEN 'programmatic'
    WHEN partner.supply_source = 5
    THEN 'mpp'
    WHEN partner.supply_source = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS supply_source,
  CASE
    WHEN partner.sales_channel = 2
    THEN 'direct sold'
    WHEN partner.sales_channel = 3
    THEN 'reseller tag'
    WHEN partner.sales_channel = 4
    THEN 'programmatic'
    WHEN partner.sales_channel = 5
    THEN 'partner tag'
    ELSE 'na'
  END AS sales_channel,
  'na' AS integration_type,
  'post-decision' AS selection_phase,
  IF(
    BITWISE_AND(request__extra_flags, 1073741824) = 1073741824
    AND COALESCE(partner.role, '') = 'cro',
    CAST(-3 AS BIGINT),
    request__context__profile_id
  ) AS profile_id,
  COALESCE(prof.name, 'na') AS profile_name,
  request__context__profile_type AS profile_type,
  COALESCE(partner.site_section_id, CAST(-1 AS BIGINT)) AS site_section_id,
  COALESCE(partner_ss.name, 'na') AS site_section_name,
  CAST(0 AS BIGINT) AS third_party_ad_request,
  CAST(0 AS BIGINT) AS third_party_ad_timeout,
  CAST(0 AS BIGINT) AS third_party_ad_http_error,
  CAST(0 AS BIGINT) AS third_party_ad_malformed_response,
  CAST(0 AS BIGINT) AS third_party_ad_bid_response_id_nomatch,
  CAST(0 AS BIGINT) AS third_party_ad_empty_bid_dealid,
  CAST(0 AS BIGINT) AS third_party_ad_unexpected_bid_dealid,
  CAST(0 AS BIGINT) AS third_party_ad_unknown_seat,
  CAST(0 AS BIGINT) AS third_party_ad_unexpected_external_ad_id,
  CAST(0 AS BIGINT) AS third_party_ad_bid_impression_id_nomatch,
  CAST(0 AS BIGINT) AS third_party_ad_floor_price_notmet,
  CAST(0 AS BIGINT) AS third_party_ad_inaplicable_for_https,
  CAST(0 AS BIGINT) AS third_party_ad_no_valid_price,
  CAST(0 AS BIGINT) AS third_party_ad_no_ad_markup,
  CAST(0 AS BIGINT) AS third_party_ad_no_content,
  CAST(0 AS BIGINT) AS third_party_ad_invalid_wrapper_url,
  SUM(CAST(1 AS BIGINT)) AS third_party_creative_request,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') IN ('timeout', 'wrapper_timeout'),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_timeout,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') IN ('http_error', 'wrapper_http_error'),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_http_error,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'malformed_response',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_malformed_response,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'max_wrapper_redirect',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_max_wrapper_redirect,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'inapplicable_for_https',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_inaplicable_for_https,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'no_valid_creative',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_no_valid_creative,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'no_ad_markup',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_no_ad_markup,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'no_content',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_no_content,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'external_creative_profile_check_failed',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_external_creative_profile_check_failed,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'empty_response',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_empty_response,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'competition_failure',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_competition_failure,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'no_slot_selected',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_no_slot_selected,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'jitt_rendition_required',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_jitt_rendition_required,
  SUM(
    IF(
      COALESCE(ad.advertisement__error, '') = 'invalid_wrapper_url',
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_invalid_wrapper_url
FROM ${bcv_ad}
CROSS JOIN UNNEST(partners__sales_channel, partners__reseller_network_id, partners__network_id, partners__entity_source, partners__supply_source, partners__site_section_id, partners__role, partners__network_is_ad_owner) AS partner(sales_channel, reseller_network_id, network_id, entity_source, supply_source, site_section_id, role, network_is_ad_owner)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = network_id
LEFT JOIN db.default.d_network AS third_party_nw
  ON third_party_nw.id = partner.reseller_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS prof
  ON prof.id = request__context__profile_id
LEFT JOIN db.default.d_site_section AS auction_ss
  ON auction__site_section_id = auction_ss.id
LEFT JOIN db.default.d_site_section AS partner_ss
  ON partner.site_section_id = partner_ss.id
WHERE
  (
    (
      BITWISE_AND(COALESCE(ad.advertisement__inventory_protection_flags, CAST(0 AS BIGINT)), 8) > 0
      AND COALESCE(partner.sales_channel, CAST(-1 AS INTEGER)) IN (2, 3)
    )
    AND partner.network_is_ad_owner = TRUE
  )
  AND COALESCE(ad.advertisement__has_candidate, FALSE) = FALSE
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
  15
