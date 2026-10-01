-- account:    publisher
-- skeleton:   aa21ead7c0b7815ebdc131f7beb18836
-- pattern:    4af544ea436f99484e05d5d248dddd62  (23 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)
--   event_date <= CAST(? AS DATE)
--   event_date >= CAST(? AS DATE)
--   process_batch_id <= ?
--   process_batch_id >= ?

WITH segment_targeting AS (
  SELECT
    placement_id,
    MAX(IF(seg.custom_id LIKE '%_fwar=%', 1, 0)) AS is_age,
    MAX(IF(seg.custom_id LIKE '%fw_d_002=%', 1, 0)) AS is_gender,
    MAX(IF(seg.custom_id LIKE '%fw_d_002=%' OR seg.custom_id LIKE '%_fwar=%', 0, 1)) AS is_other
  FROM etl.ds_billing.f_aim_audience_partner_revenue_daily AS f
  CROSS JOIN UNNEST(matched_segment_pk_ids) AS s(matched_segment_pk_id)
  LEFT JOIN etl.ds_billing.d_ds_segment AS seg
    ON seg.id_pk = s.matched_segment_pk_id
  WHERE
    (
      f.network_id = 532336 AND placement_id <> -1
    )
    AND LOWER(seg.data_provider) LIKE '%youtube%'
  GROUP BY
    1
)
SELECT
  network_owner,
  ad_server,
  content_owner_id,
  video_id,
  ad_server_video_asset_id,
  served_country_code,
  date_id,
  ad_format,
  ad_duration,
  targeting_parameters,
  campaign,
  campaign_book_date,
  IF(
    '2.2.1' = '2.2.1',
    '',
    (
      CASE
        WHEN sales_channel = 2
        THEN advertiser_name
        WHEN sales_channel = 4
        THEN global_advertiser_names
        ELSE ''
      END
    )
  ) AS advertiser_name,
  IF(
    '2.2.1' = '2.2.1',
    '',
    (
      CASE
        WHEN sales_channel = 2
        THEN advertiser_id
        WHEN sales_channel = 4
        THEN global_advertiser_ids
        ELSE ''
      END
    )
  ) AS advertiser_id,
  IF('2.2.1' = '2.2.1', '', yt_advertiser_id) AS yt_advertiser_id,
  yt_billing_params,
  impressions
FROM (
  SELECT
    reseller.name AS network_owner,
    'freewheel' AS ad_server,
    fact.content_owner_id AS content_owner_id,
    fact.distributor_custom_asset_id AS video_id,
    fact.root_asset_id AS ad_server_video_asset_id,
    d_country.name AS served_country_code,
    event_date AS date_id,
    (
      CASE
        WHEN fact.time_position_class IN ('display', 'in-player-display')
        THEN 'display'
        WHEN fact.time_position_class = 'overlay'
        THEN 'overlay'
        WHEN fact.time_position_class IN ('preroll', 'midroll', 'postroll')
        AND (
          "skip".skippable IS NULL
        )
        THEN 'instream'
        ELSE 'instream select'
      END
    ) AS ad_format,
    (
      CASE
        WHEN fact.time_position_class IN ('preroll', 'midroll', 'postroll')
        AND NOT creative.id IS NULL
        AND creative.duration > 0
        THEN creative.duration
        WHEN fact.time_position_class IN ('preroll', 'midroll', 'postroll')
        AND NOT market_creative.market_ad_id IS NULL
        AND market_creative.creative_duration > 0
        THEN market_creative.creative_duration
        ELSE 0
      END
    ) AS ad_duration,
    IF(NOT targeted.id IS NULL, targeted.bitmap, 0) + IF(fre.placement_id IS NULL, 0, 4) + IF(NOT st.placement_id IS NULL AND st.is_age = 1, 32, 0) + IF(NOT st.placement_id IS NULL AND st.is_gender = 1, 64, 0) + IF(NOT st.placement_id IS NULL AND st.is_other = 1, 128, 0) AS targeting_parameters,
    (
      CASE
        WHEN sales_channel = 2
        THEN CASE
          WHEN plc.schedule_mode = 'actual_ecpm'
          AND (
            plc.priority_type = 'sponsorship' OR plc.priority_type IS NULL
          )
          AND ad.ad_unit_price > 0
          THEN 'standard'
          WHEN plc.schedule_mode = 'actual_ecpm'
          AND (
            plc.priority_type = 'sponsorship' OR plc.priority_type IS NULL
          )
          AND (
            ad.ad_unit_price <= 0 OR ad.ad_unit_price IS NULL
          )
          THEN 'standard-zerocpm'
          ELSE 'non-standard'
        END
        WHEN sales_channel = 4
        THEN CASE
          WHEN deal.pricing_model = 'fixed price'
          THEN 'fixed price'
          WHEN deal.pricing_model = '1st price auction floor'
          THEN '1st price auction floor'
          WHEN deal.pricing_model = '2nd price auction floor'
          THEN '2nd price auction floor'
          ELSE ''
        END
        ELSE ''
      END
    ) AS campaign,
    (
      CASE
        WHEN sales_channel = 2
        THEN DATE_FORMAT(plc.first_booked_date, '%y%m%d')
        WHEN sales_channel = 4
        THEN DATE_FORMAT(deal.start_time, '%y%m%d')
        ELSE ''
      END
    ) AS campaign_book_date,
    IF(sales_channel = 2, adver.name, '') AS advertiser_name,
    IF(sales_channel = 2, CAST(adver.id AS VARCHAR(20)), '') AS advertiser_id,
    IF(sales_channel = 2, COALESCE(company.meta_data, ''), '') AS yt_advertiser_id,
    fact.billing_parameters AS yt_billing_params,
    sales_channel AS sales_channel,
    IF(
      sales_channel = 4,
      ARRAY_JOIN(
        ARRAY_DISTINCT(
          FILTER(ARRAY_AGG(global_adver.name ORDER BY global_advertiser.id), x -> NOT x IS NULL)
        ),
        ';'
      ),
      ''
    ) AS global_advertiser_names,
    IF(
      sales_channel = 4,
      ARRAY_JOIN(
        ARRAY_DISTINCT(
          FILTER(ARRAY_AGG(global_advertiser.id ORDER BY global_advertiser.id), x -> NOT x IS NULL)
        ),
        ','
      ),
      ''
    ) AS global_advertiser_ids,
    SUM(fact.ad_views) AS impressions
  FROM (
    SELECT
      DATE_FORMAT((
        AT_TIMEZONE(ack__timestamp, 'america/new_york')
      ), '%y%m%d') AS event_date,
      request__context__site_section_cro_network_id AS content_owner_id,
      COALESCE(p.network_id, -1) AS reseller_id,
      COALESCE(request__context__video_cro_asset_id, -1) AS root_asset_id,
      COALESCE(request__context__distributor_asset_id, '') AS distributor_custom_asset_id,
      COALESCE(visitor__country_id, -1) AS country_id,
      COALESCE(slot__time_position_class, 'unknown') AS time_position_class,
      IF(
        BITWISE_AND(advertisement__flags, 4194304) <> 4194304,
        CASE
          WHEN advertisement__ad_oo_network_id = request__context__site_section_cro_network_id
          THEN advertisement__ad_id
          ELSE CAST(-1 AS BIGINT)
        END,
        CAST(-1 AS BIGINT)
      ) AS ad_id,
      IF(p.sales_channel = 4, candidate__market_ad_id, CAST(-1 AS BIGINT)) AS market_ad_id,
      advertisement__global_advertiser_ids AS global_advertiser_ids,
      IF(BITWISE_AND(advertisement__flags, 4194304) = 4194304, -1, advertisement__creative_id) AS creative_id,
      COALESCE(request__context__extracted_key_value___fw_dbp, '') AS billing_parameters,
      p.sales_channel AS sales_channel,
      candidate__internal_deal_id AS deal_id,
      COALESCE(ack.ack__metrics__ad_impression, 0) AS ad_views
    FROM ${bcv_ack}
    CROSS JOIN UNNEST(partners__network_id, partners__sales_channel, partners__supply_source) AS p(network_id, sales_channel, supply_source)
    WHERE
      (
        (
          (
            (
              (
                (
                  request__context__network_id = 10613
                  AND request__context__site_section_cro_network_id = 532336
                )
                AND (
                  ack.request__is_filtered = FALSE
                )
              )
              AND advertisement__is_bumper = FALSE
            )
            AND ack__is_private_impression = FALSE
          )
          AND COALESCE(ack__metrics__ad_impression, 0) <> 0
        )
        AND COALESCE(p.sales_channel, CAST(-1 AS INTEGER)) IN (2, 4)
      )
      AND COALESCE(p.supply_source, CAST(-1 AS INTEGER)) <> 4
  ) AS fact
  LEFT JOIN UNNEST(global_advertiser_ids) AS global_advertiser(id)
    ON TRUE
  LEFT JOIN db.default.d_network AS reseller
    ON fact.reseller_id = reseller.id
  LEFT JOIN db.default.d_country
    ON fact.country_id = d_country.id
  LEFT JOIN db.default.d_ad_tree_node_rehashed AS ad
    ON fact.ad_id = ad.id AND IF(fact.ad_id = -1, RAND(100) + 1, 1) = ad.id_rehashed
  LEFT JOIN db.default.d_advertiser AS adver
    ON ad.advertiser_id = adver.id
  LEFT JOIN db.default.d_global_advertiser AS global_adver
    ON global_advertiser.id = global_adver.id
  LEFT JOIN db.default.d_company AS company
    ON adver.advertiser_company_id = company.id
  LEFT JOIN db.default.d_creative AS creative
    ON fact.creative_id = creative.id
  LEFT JOIN db.default.d_market_creative AS market_creative
    ON fact.market_ad_id = market_creative.market_ad_id
  LEFT JOIN db.default.d_placement AS plc
    ON ad.placement_id = plc.id
  LEFT JOIN db.default.d_ssp_deal_metadata AS deal
    ON deal.id = deal_id
  LEFT JOIN db.default.d_targeting_criteria_bitmap AS targeted
    ON targeted.id = plc.id
  LEFT JOIN db.default.d_ad_tree_node_skippable AS "skip"
    ON "skip".id = fact.ad_id
  LEFT JOIN (
    SELECT DISTINCT
      plc2.id AS placement_id
    FROM db.default.d_placement AS plc2
    JOIN db.default.d_ad_tree_node_frequency_cap AS atnfc
      ON atnfc.ad_tree_node_id = plc2.id
  ) AS fre
    ON fre.placement_id = plc.id
  LEFT JOIN segment_targeting AS st
    ON st.placement_id = plc.id
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
    global_advertiser_ids
)
