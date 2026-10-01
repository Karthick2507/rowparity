-- account:    sa-mktplaceanalytics
-- skeleton:   4a232a6966fa17d6bdcbf63ff019310a
-- pattern:    c2550a924e1c105e42d7464d69e2f812  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < DATE_ADD(?, ?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))
--   ack__timestamp >= DATE_ADD(?, ?, DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP))))

SELECT
  *,
  event_date AS _arena_partition_event_date
FROM (
  SELECT
    DATE_FORMAT(DATE_TRUNC('DAY', AT_TIMEZONE(ack__timestamp, 'america/new_york')), '%y-%m-%d') AS event_date,
    visitor__user_agent AS user_agent,
    request__context__site_section_cro_asset_id AS site_section_id,
    dss.name AS site_section_name,
    candidate__internal_deal_id AS deal_id,
    g.name AS deal_name,
    g.public_id AS public_deal_id,
    candidate__dsp_id AS dsp_id,
    f.name AS dsp_name,
    network.network_id,
    dd.name AS network_name,
    request__context__video_cro_network_id AS content_owner_id,
    d.name AS content_owner_name,
    SUM(ack__metrics__raw_ad_impression) AS net_tracked_ad_views,
    SUM(ack__metrics__complete_quartile) AS complete_quartile,
    SUM(
      IF(ack__traffic_type = 0, network.revenue, 0.0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0) * auction__auction_network_to_usd_exchange_rate
    ) AS measured_revenue_corp_usd
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__revenue, partners__sales_channel, partners__supply_source, partners__network_id) AS network(revenue, sales_channel, supply_source, network_id)
  LEFT JOIN db.default.d_lu_dma AS dld
    ON dld.code = visitor__dma_code
  LEFT JOIN db.default.d_site_section AS dss
    ON dss.id = request__context__site_section_cro_asset_id
  LEFT JOIN db.default.d_network AS d
    ON request__context__video_cro_network_id = d.id
  LEFT JOIN db.default.d_network AS dd
    ON network.network_id = dd.id
  LEFT JOIN db.default.d_ssp_demand_side_platform AS f
    ON candidate__dsp_id = f.id
  LEFT JOIN db.default.d_ssp_deal AS g
    ON candidate__internal_deal_id = g.id
  WHERE
    (
      ack__traffic_type = 0
      AND (
        network.sales_channel = 4 OR BITWISE_AND(ack__bit_flags, 32) = 32
      )
    )
    AND network.supply_source <> 4
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
    13
) AS arena_tmp
