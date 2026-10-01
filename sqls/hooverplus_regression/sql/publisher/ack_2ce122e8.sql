-- account:    publisher
-- skeleton:   0aa2e862cd6341acbf63590899cef3ac
-- pattern:    2ce122e8c99a79ac879d74bc86ffe178  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)
--   process_batch_id <= ?
--   process_batch_id >= ?

SELECT
  fact.eventdate AS eventdate,
  fact.trustid AS trustid,
  fact.dealexternalid AS dealexternalid,
  fact.dealname AS dealname,
  fact.openexchangeruleid AS openexchangeruleid,
  fact.openexchangerulename AS openexchangerulename,
  fact.sitesectionid AS sitesectionid,
  fact.advertisername AS advertisername,
  fact.creativeexternalid AS creativeexternalid,
  SUM(fact.netcountedads) AS netcountedads,
  CAST(SUM(fact.revenue) AS DECIMAL(10, 2)) AS revenue,
  IF(
    SUM(fact.netcountedads) > 0,
    SUM(fact.completion) * 100.00 / (
      SUM(fact.netcountedads)
    ),
    0
  ) AS completionrate
FROM (
  SELECT
    DATE_FORMAT((
      AT_TIMEZONE(ack__timestamp, 'cet')
    ), '%y-%m-%d') AS eventdate,
    SUBSTR(candidate__trust_id, 1, 255) AS trustid,
    COALESCE(deal.external_id, '') AS dealexternalid,
    COALESCE(deal.name, 'n/a') AS dealname,
    COALESCE(candidate__buyer_group_id, -1) AS openexchangeruleid,
    COALESCE(bg.name, 'n/a') AS openexchangerulename,
    COALESCE(candidate__site_section_id, -1) AS sitesectionid,
    COALESCE(advertiser.name, 'n/a') AS advertisername,
    COALESCE(candidate__external_ad_id, 'n/a') AS creativeexternalid,
    COALESCE(SUM(ack__metrics__ad_impression), 0) AS netcountedads,
    SUM(candidate__clearing_price * 0.001 * COALESCE(ack__metrics__ad_impression, 0)) AS revenue,
    COALESCE(SUM(ack__metrics__complete_quartile), 0) AS completion
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(IF(
    CARDINALITY(candidate__global_advertiser_ids) = 0,
    ARRAY[-1],
    candidate__global_advertiser_ids
  )) AS global_advertiser(id)
  LEFT JOIN db.default.d_ssp_deal_metadata AS deal
    ON deal.id = candidate__internal_deal_id
  LEFT JOIN db.default.d_ssp_buyer_group AS bg
    ON bg.id = candidate__buyer_group_id
  LEFT JOIN db.default.d_global_brand_advertiser AS advertiser
    ON advertiser.id = global_advertiser.id
  WHERE
    (
      (
        (
          BITWISE_AND(ack__flags, 1048576) > 0
          AND BITWISE_AND(COALESCE(ack__flags, 0), 67108864) = 0
        )
        AND request__is_filtered = FALSE
      )
      AND (
        COALESCE(ack__metrics__ad_impression, 0) <> 0
        OR COALESCE(ack__metrics__complete_quartile, 0) <> 0
      )
    )
    AND auction__network_id = 511351
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9
) AS fact
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9
