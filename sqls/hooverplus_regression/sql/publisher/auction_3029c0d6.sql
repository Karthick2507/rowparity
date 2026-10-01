-- account:    publisher
-- skeleton:   42a93dfee9347caa585c6e3af2d07897
-- pattern:    3029c0d69fac3e15e27e795e0b56bc87  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_ADD(?, ?, CAST(? AS TIMESTAMP))
--   request__timestamp < NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)
--   request__timestamp >= DATE_ADD(?, -?, CAST(? AS TIMESTAMP))
--   request__timestamp >= NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)

SELECT
  DATE_FORMAT(UTC_TO_NETWORKLOCAL(request__timestamp, 529832), '%y-%m-%d') AS "date",
  COALESCE(auction__network_id, -1) AS "auction network id",
  COALESCE(nw.name, 'unknown network') AS "auction network name",
  IF(auction__integration_type = 'mkpl_partner_tag', 'partner tags', 'programmatic') AS "demand type",
  COALESCE(
    IF(
      auction__integration_type = 'mkpl_partner_tag',
      partner.reseller_network_id,
      auction__dsp_id
    ),
    -1
  ) AS "partner id",
  COALESCE(
    IF(auction__integration_type = 'mkpl_partner_tag', mkpl_partner.name, dsp.name),
    'unknown partner'
  ) AS "partner name",
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
  ) AS "ifa%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(auction__flags, 67108864) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "content.id%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(auction__flags, 134217728) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "content.title%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(auction__flags, 268435456) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "geo.zip%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(COALESCE(auction__privacy_flags, 0), 1) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "lat%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(COALESCE(auction__privacy_flags, 0), 2) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "gdpr%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(COALESCE(auction__privacy_flags, 0), 4) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "coppa%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(COALESCE(auction__privacy_flags, 0), 8) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "ccpa%",
  ROUND(
    CAST(SUM(
      IF(
        BITWISE_AND(COALESCE(auction__privacy_flags, 0), 16) > 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS DOUBLE) / SUM(COALESCE(request__log_sampling__magnifier, 1)),
    4
  ) AS "gpp%"
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
