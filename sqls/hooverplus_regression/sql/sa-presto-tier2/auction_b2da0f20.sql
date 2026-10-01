-- account:    sa-presto-tier2
-- skeleton:   a28f7a7a41a7efdf6370c1b4f52de28a
-- pattern:    b2da0f209f33133b4b7af3542514dc25  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  ROUND(100.0 * COUNT_IF(NOT auction__application_type IS NULL) / COUNT(*), 1) AS pct_app_type,
  ROUND(100.0 * COUNT_IF(NOT auction__device_type IS NULL) / COUNT(*), 1) AS pct_device_type,
  ROUND(
    100.0 * COUNT_IF(NOT auction__site_domain IS NULL AND auction__site_domain <> '') / COUNT(*),
    1
  ) AS pct_site_domain,
  ROUND(
    AVG(
      IF(
        NOT auction__site_domain IS NULL AND auction__site_domain <> '',
        LENGTH(auction__site_domain),
        NULL
      )
    ),
    1
  ) AS avg_site_domain_bytes,
  ROUND(
    100.0 * COUNT_IF(NOT auction__app_bundle IS NULL AND auction__app_bundle <> '') / COUNT(*),
    1
  ) AS pct_app_bundle,
  ROUND(
    AVG(
      IF(
        NOT auction__app_bundle IS NULL AND auction__app_bundle <> '',
        LENGTH(auction__app_bundle),
        NULL
      )
    ),
    1
  ) AS avg_app_bundle_bytes,
  ROUND(
    100.0 * COUNT_IF(NOT auction__app_storeurl IS NULL AND auction__app_storeurl <> '') / COUNT(*),
    1
  ) AS pct_storeurl,
  ROUND(
    AVG(
      IF(
        NOT auction__app_storeurl IS NULL AND auction__app_storeurl <> '',
        LENGTH(auction__app_storeurl),
        NULL
      )
    ),
    1
  ) AS avg_storeurl_bytes,
  ROUND(
    100.0 * COUNT_IF(NOT auction__publisher_id IS NULL AND auction__publisher_id <> '') / COUNT(*),
    1
  ) AS pct_publisher_id,
  ROUND(
    AVG(
      IF(
        NOT auction__publisher_id IS NULL AND auction__publisher_id <> '',
        LENGTH(auction__publisher_id),
        NULL
      )
    ),
    1
  ) AS avg_publisher_id_bytes,
  ROUND(100.0 * COUNT_IF(NOT auction__width IS NULL) / COUNT(*), 1) AS pct_width,
  ROUND(
    100.0 * COUNT_IF(
      NOT auction__auction_network_to_usd_exchange_rate IS NULL
      AND auction__auction_network_to_usd_exchange_rate <> 0
    ) / COUNT(*),
    1
  ) AS pct_usd_rate,
  COUNT(*) AS sampled_rows
FROM (
  SELECT
    auction__application_type,
    auction__device_type,
    auction__site_domain,
    auction__app_bundle,
    auction__app_storeurl,
    auction__publisher_id,
    auction__width,
    auction__auction_network_to_usd_exchange_rate
  FROM ${bcv_auction}
  WHERE
    NOT auction__dsp_id IS NULL
  
)
