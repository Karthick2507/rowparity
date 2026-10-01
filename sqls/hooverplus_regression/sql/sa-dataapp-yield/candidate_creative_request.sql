-- account:    sa-dataapp-yield
-- skeleton:   ef6ef08c7f76f36389ee05b2fff66471
-- pattern:    0adb13867ca448a9a780101de007658e  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     candidate
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
  IF(
    COALESCE(partner.sales_channel, CAST(-1 AS INTEGER)) = 4,
    COALESCE(candidate.candidate__dsp_id, CAST(-1 AS BIGINT)),
    COALESCE(partner.reseller_network_id, CAST(-1 AS BIGINT))
  ) AS third_party_partner_id,
  IF(COALESCE(partner.sales_channel, CAST(-1 AS INTEGER)) = 4, 'dsp', 'network') AS third_party_partner_type,
  CASE
    WHEN COALESCE(partner.sales_channel, CAST(-1 AS INTEGER)) = 4
    THEN dsp.name
    ELSE third_party_nw.name
  END AS third_party_partner_name,
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
  CASE
    WHEN candidate__integration_type = 'openrtb_normal'
    THEN 'fullstack_non_pg'
    WHEN candidate__integration_type = 'openrtb_pg_td'
    THEN 'fullstack_pg'
    WHEN candidate__integration_type = 'mkpl_partner_tag'
    THEN 'mkpl_partner_tag'
    ELSE 'unknown'
  END AS integration_type,
  CASE
    WHEN BITWISE_AND(COALESCE(candidate.candidate__flags, 0), 262144) > 0
    THEN 'pre-decision'
    WHEN BITWISE_AND(COALESCE(candidate.candidate__flags, 0), 524288) > 0
    THEN 'post-decision'
    ELSE ''
  END AS selection_phase,
  IF(
    BITWISE_AND(request__extra_flags, 1073741824) = 1073741824
    AND COALESCE(partner.supply_source, CAST(-1 AS INTEGER)) = 1,
    CAST(-3 AS BIGINT),
    request__context__profile_id
  ) AS profile_id,
  COALESCE(prof.name, 'na') AS profile_name,
  request__context__profile_type AS profile_type,
  IF(
    COALESCE(partner.sales_channel, CAST(-1 AS INTEGER)) = 4,
    auction__site_section_id,
    COALESCE(partner.site_section_id, CAST(-1 AS BIGINT))
  ) AS site_section_id,
  IF(
    COALESCE(partner.sales_channel, CAST(-1 AS INTEGER)) = 4,
    COALESCE(auction_ss.name, 'na'),
    COALESCE(partner_ss.name, 'na')
  ) AS site_section_name,
  CAST(0 AS BIGINT) AS third_party_ad_request,
  CAST(0 AS BIGINT) AS third_party_ad_timeout,
  CAST(0 AS BIGINT) AS third_party_ad_http_error,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'malformed_response'
      AND candidate__bid_status IN (1, 3, 5, 7)
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) = 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_malformed_response,
  CAST(0 AS BIGINT) AS third_party_ad_bid_response_id_nomatch,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'unknown_seat'
      AND candidate__bid_status IN (1, 3, 5, 7),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_unknown_seat,
  CAST(0 AS BIGINT) AS third_party_ad_unexpected_bid_dealid,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'empty_bid_dealid'
      AND candidate__bid_status IN (1, 3, 5, 7),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_empty_bid_dealid,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'unexpected_external_ad_id'
      AND candidate__bid_status IN (1, 3, 5, 7)
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) = 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_unexpected_external_ad_id,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'bid_impression_id_nomatch'
      AND candidate__bid_status IN (1, 3, 5, 7),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_bid_impression_id_nomatch,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'floor_price_notmet'
      AND candidate__bid_status IN (1, 3, 5, 7),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_floor_price_notmet,
  CAST(0 AS BIGINT) AS third_party_ad_inaplicable_for_https,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'no_valid_price'
      AND candidate__bid_status IN (1, 3, 5, 7),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_no_valid_price,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'no_ad_markup'
      AND candidate__bid_status IN (1, 3, 5, 7),
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_ad_no_ad_markup,
  CAST(0 AS BIGINT) AS third_party_ad_no_content,
  CAST(0 AS BIGINT) AS third_party_ad_invalid_wrapper_url,
  SUM(IF(COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0, 1, 0)) AS third_party_creative_request,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'wrapper_timeout'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_timeout,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'wrapper_http_error'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_http_error,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'malformed_response'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_malformed_response,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'max_wrapper_redirect'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_max_wrapper_redirect,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'inapplicable_for_https'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_inaplicable_for_https,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'no_valid_creative'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_no_valid_creative,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'external_creative_profile_check_failed'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_external_creative_profile_check_failed,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'empty_response'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_empty_response,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'competition_failure'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_competition_failure,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'no_slot_selected'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_no_slot_selected,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'jitt_rendition_required'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_jitt_rendition_required,
  CAST(0 AS BIGINT) AS third_party_creative_no_ad_markup,
  CAST(0 AS BIGINT) AS third_party_creative_no_content,
  SUM(
    IF(
      COALESCE(candidate.candidate__error, '') = 'invalid_wrapper_url'
      AND COALESCE(candidate.candidate__redirect_count, CAST(0 AS INTEGER)) > 0,
      CAST(1 AS BIGINT),
      CAST(0 AS BIGINT)
    )
  ) AS third_party_creative_invalid_wrapper_url
FROM ${bcv_candidate}
CROSS JOIN UNNEST(partners__network_id, partners__sales_channel, partners__reseller_network_id, partners__supply_source, partners__site_section_id, partners__entity_source) AS partner(network_id, sales_channel, reseller_network_id, supply_source, site_section_id, entity_source)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = network_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = auction__dsp_id
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
    COALESCE(candidate.candidate__integration_type, '') IN ('openrtb_normal', 'openrtb_pg_td', 'mkpl_partner_tag')
    AND partner.entity_source = 'auction'
  )
  AND BITWISE_AND(COALESCE(candidate.candidate__flags, 0), 131072) = 0
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
