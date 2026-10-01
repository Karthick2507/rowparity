-- account:    sa-dataapp-yield
-- skeleton:   ae0841afdb383e6e07cb893baca67d6d
-- pattern:    faaa5944c90d238f0e84c3f263240950  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP) + INTERVAL ? HOUR
--   ack__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? HOUR

SELECT
  DATE_TRUNC('DAY', UTC_TIMESTAMP_TO_LOCAL(ack__timestamp, TIMEZONE_OF_NETWORK(n_id))) AS eventdate,
  COALESCE(n_id, -1) AS network_id,
  COALESCE(d_network.name, 'unknown') AS network,
  COALESCE(visitor__user_agent_device_type, 'unknown') AS device,
  CASE
    WHEN COALESCE(sales_channel, -1) = 2
    THEN 'direct sold'
    WHEN network_is_extra_item_owner
    AND candidate__integration_type IN ('mkpl_partner_tag')
    THEN 'partner tag'
    WHEN network_is_extra_item_owner
    AND candidate__integration_type IN ('openrtb_sfx', 'reseller_tag')
    THEN 'market: mrm+sfx'
    WHEN network_is_extra_item_owner
    AND candidate__integration_type IN ('openrtb_normal', 'openrtb_pg_td')
    THEN 'market: full stack'
    WHEN network_is_extra_item_owner AND sales_channel = 3
    THEN 'reseller sold - reseller tag'
    WHEN COALESCE(sales_channel, -1) = 3
    THEN 'reseller sold - mrm rule'
    WHEN COALESCE(sales_channel, -1) = 5
    THEN 'partner trading'
    WHEN COALESCE(sales_channel, -1) = 6
    THEN 'marketplace platform exchange'
    ELSE 'unknown'
  END AS sales_channel,
  IF(NOT nf.function_id IS NULL, 'true', 'false') AS is_report,
  COALESCE(SUM(ack__metrics__ad_impression), 0) AS impressions
FROM ${bcv_ack} AS ack
CROSS JOIN UNNEST(partners__network_id, partners__reseller_network_id, partners__role, partners__network_is_ad_owner, partners__network_is_extra_item_owner, partners__sales_channel, partners__supply_source) AS networks(n_id, r_id, t_type, network_is_ad_owner, network_is_extra_item_owner, sales_channel, supply_source)
LEFT JOIN db.default.d_network AS d_network
  ON n_id = d_network.id
LEFT JOIN db.default.d_network_function AS nf
  ON nf.network_id = n_id AND nf.function_id = 1021
WHERE
  (
    (
      (
        (
          (
            (
              t_type IN ('cro', 'r') AND ack__ack_entity_type = 'ad'
            )
            AND advertisement__is_bumper = FALSE
          )
          AND (
            NOT ack__is_private_impression
            OR networks.network_is_ad_owner
            OR networks.network_is_extra_item_owner
          )
        )
        AND COALESCE(supply_source, -1) <> 4
      )
      AND COALESCE(sales_channel, -1) > 0
    )
    AND UTC_TIMESTAMP_TO_LOCAL(ack__timestamp, TIMEZONE_OF_NETWORK(n_id)) >= CAST('2026-07-23 00:00:00' AS TIMESTAMP)
  )
  AND UTC_TIMESTAMP_TO_LOCAL(ack__timestamp, TIMEZONE_OF_NETWORK(n_id)) < CAST('2026-07-24 00:00:00' AS TIMESTAMP)
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
