-- account:    sa-mktplaceanalytics
-- skeleton:   f0fb18104fc7ee903fd27934e2712d78
-- pattern:    85b14d3a1e0ce2eb56be40121dacb5f1  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   DATE_TRUNC(?, auction.request__timestamp) = DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))

SELECT
  auction.event_date,
  auction.event_date_raw,
  auction.auction__publisher_id,
  content_owner_network_id,
  supply_source,
  sales_channel,
  dsp_id,
  auction__network_id AS network_id,
  SUM(bid_requests) AS bid_requests,
  SUM(responses_with_bids) AS responses_with_bids,
  app_bundle,
  standard_app_bundle_id,
  standard_app_id,
  internal_deal_ids
FROM (
  SELECT
    CAST(DATE_TRUNC('DAY', AT_TIMEZONE(auction.request__timestamp, 'america/new_york')) AS DATE) AS event_date,
    CAST(DATE_TRUNC('DAY', auction.request__timestamp) AS DATE) AS event_date_raw,
    auction.auction__publisher_id,
    content_owner_network_id,
    supply_source,
    sales_channel,
    auction__dsp_id AS dsp_id,
    auction__network_id,
    SUM(
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
    ) AS bid_requests,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 8) > 0,
        1 * COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS responses_with_bids,
    auction__app_bundle AS app_bundle,
    request__context__standard_app_bundle_id AS standard_app_bundle_id,
    request__context__standard_app_id AS standard_app_id,
    internal_deal_ids
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(partners__content_owner_network_id, partners__supply_source, partners__sales_channel, partners__entity_source, partners__internal_deal_ids) AS t(content_owner_network_id, supply_source, sales_channel, partners__entity_source, internal_deal_ids)
  WHERE
    (
      (
        (
          1 = 1 AND (
            BITWISE_AND(auction__auction_status, 2) > 0
          )
        )
        AND (
          auction__integration_type IN ('normal', 'pg_td')
        )
      )
      AND (
        t.partners__entity_source = 'auction'
      )
    )
    AND (
      auction__is_faked_auction = FALSE
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
    11,
    12,
    13,
    14
) AS auction
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  11,
  12,
  13,
  14
ORDER BY
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
  14
