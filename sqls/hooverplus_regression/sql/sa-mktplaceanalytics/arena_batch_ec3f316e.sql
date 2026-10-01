-- account:    sa-mktplaceanalytics
-- skeleton:   9d6b8374a0836a45d95176a9dfc706fa
-- pattern:    ec3f316ea805059e754d4be783cdbb22  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_TRUNC(?, AT_TIMEZONE(CAST(? AS TIMESTAMP), ?))
--   request__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, AT_TIMEZONE(CAST(? AS TIMESTAMP), ?)))

SELECT
  *,
  date AS _arena_partition_date
FROM (
  SELECT
    DATE_FORMAT(UTC_TO_NETWORKLOCAL(request__timestamp, 529832), '%y-%m-%d') AS date,
    COALESCE(auction__network_id, -1) AS auction_network_id,
    COALESCE(nw.name, 'unknown network') AS auction_network_name,
    IF(auction__integration_type = 'mkpl_partner_tag', 'partner tags', 'programmatic') AS demand_type,
    COALESCE(
      IF(
        auction__integration_type = 'mkpl_partner_tag',
        partner.reseller_network_id,
        auction__dsp_id
      ),
      -1
    ) AS partner_id,
    COALESCE(
      IF(auction__integration_type = 'mkpl_partner_tag', mkpl_partner.name, dsp.name),
      'unknown partner'
    ) AS partner_name,
    COALESCE(auction__app_bundle, '') AS "appbundle",
    ROUND(
      CAST(SUM(
        IF(
          BITWISE_AND(auction__flags, 16777216) > 0,
          COALESCE(request__log_sampling__magnifier, 1),
          0
        )
      ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
      4
    ) AS ifa_percent,
    ROUND(
      CAST(SUM(
        IF(
          BITWISE_AND(auction__flags, 67108864) > 0,
          COALESCE(request__log_sampling__magnifier, 1),
          0
        )
      ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
      4
    ) AS content_id_percent,
    ROUND(
      CAST(SUM(
        IF(
          BITWISE_AND(auction__flags, 134217728) > 0,
          COALESCE(request__log_sampling__magnifier, 1),
          0
        )
      ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
      4
    ) AS content_title_percent,
    ROUND(
      CAST(SUM(
        IF(
          BITWISE_AND(auction__flags, 268435456) > 0,
          COALESCE(request__log_sampling__magnifier, 1),
          0
        )
      ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
      4
    ) AS geo_zip_percent
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(partners__reseller_network_id, partners__entity_source) AS partner(reseller_network_id, entity_source)
  LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
    ON dsp.id = auction__dsp_id
  LEFT JOIN db.default.d_network AS nw
    ON nw.id = auction__network_id
  LEFT JOIN db.default.d_lu_mkpl_partner_name AS mkpl_partner
    ON mkpl_partner.network_id = partner.reseller_network_id
  WHERE
    (
      (
        (
          COALESCE(auction__integration_type, '') IN ('normal', 'pg_td', 'mkpl_partner_tag')
          AND auction__is_faked_auction = FALSE
        )
        AND partner.entity_source IN ('auction')
      )
      AND BITWISE_AND(auction__auction_status, 2) > 0
    )
    AND request__context__network_id = 529832
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7
) AS arena_tmp
