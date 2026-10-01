-- account:    sa-presto-af-etl
-- skeleton:   20ace51960ba1b14bcf39efe268047d7
-- pattern:    f714c1bf48ab93ea47f5d35f19fb4c10  (17 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CURRENT_DATE
--   request__timestamp >= CURRENT_DATE - INTERVAL ? DAY

SELECT
  DAY_OF_WEEK(request__timestamp) AS weekday,
  auction__network_id AS network_id,
  TRY(partners__network_id[2]) AS seller_network,
  TRY(partners__inventory_package_ids[1]) AS inventory_package_id,
  TRY(partners__outbound_listing_id[2]) AS outbound_listing_id,
  TRY(partners__inbound_order_id[1]) AS inbound_order_id,
  TRY(partners__supply_source[1]) AS supply_source,
  auction__time_position_class AS time_position_class,
  visitor__country_id AS user_country_id,
  auction__dsp_id AS dsp_id,
  visitor__state_id AS user_state_id,
  visitor__city_id AS user_city_id,
  '0' AS postal_code,
  visitor__dma_code AS user_dma_code,
  visitor__standard_device_type_ids AS standard_device_type_id,
  visitor__standard_environment_id AS standard_environment_id,
  visitor__standard_os_id AS standard_os_id,
  request__context__standard_endpoint_owner_id AS standard_endpoint_owner_id,
  request__context__standard_endpoint_id AS standard_endpoint_id,
  request__context__standard_brand_id AS standard_brand_id,
  request__context__standard_programmer_id AS standard_programmer_id,
  request__context__standard_channel_id AS standard_channel_id,
  request__context__standard_language_ids AS standard_language_ids,
  request__context__standard_genre_ids AS standard_genre_ids,
  visitor__dma_code_id AS user_dma_code_id,
  auction__app_bundle AS app_bundle,
  request__context__standard_app_id AS app_id,
  request__context__content_rating_id AS rating_id,
  request__context__stream_mode_id AS stream_mode_id,
  request__context__standard_iab_category_ids AS iab_category_ids,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS bid_requests,
  DATE_TRUNC('DAY', request__timestamp) AS event_date
FROM ${bcv_auction}
WHERE
  auction__network_id = 523319 AND request__traffic_type = 0
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
  32
