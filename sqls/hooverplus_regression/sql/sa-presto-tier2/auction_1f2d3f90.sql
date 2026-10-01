-- account:    sa-presto-tier2
-- skeleton:   65cedf29eebfaf0f189797779db40371
-- pattern:    1f2d3f90f90a00a569354abbbe45a558  (1 execution(s))
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
  ELEMENT_AT(
    partners__inbound_order_id,
    ARRAY_POSITION(partners__network_id, CAST('384777' AS BIGINT))
  ) AS comcast_prod_inbound_order_id,
  COUNT(*) * MAX(COALESCE(request__log_sampling__magnifier, 1)) AS total_opportunities_est,
  COUNT(*) AS total_opportunities_raw,
  COUNT_IF(
    NOT visitor__address IS NULL
    AND visitor__address <> ''
    AND visitor__address <> '-2'
  ) AS opps_with_inbound_ip,
  COUNT_IF(
    NOT auction__device_ip IS NULL
    AND auction__device_ip <> ''
    AND auction__device_ip <> '-2'
  ) AS opps_with_outbound_ip,
  ROUND(
    100.0 * COUNT_IF(
      NOT visitor__address IS NULL
      AND visitor__address <> ''
      AND visitor__address <> '-2'
    ) / COUNT(*),
    2
  ) AS inbound_ip_pct,
  ROUND(
    100.0 * COUNT_IF(
      NOT auction__device_ip IS NULL
      AND auction__device_ip <> ''
      AND auction__device_ip <> '-2'
    ) / COUNT(*),
    2
  ) AS outbound_ip_pct
FROM ${bcv_auction}
WHERE
  CONTAINS(partners__network_id, CAST('384777' AS BIGINT))
  AND ELEMENT_AT(
    partners__inbound_order_id,
    ARRAY_POSITION(partners__network_id, CAST('384777' AS BIGINT))
  ) IN (
    161012,
    161014,
    161016,
    161020,
    161022,
    161024,
    161025,
    161026,
    161027,
    161029,
    161030,
    161031,
    179876,
    227373,
    227374,
    227375,
    227376,
    227377,
    227378,
    227379,
    300174,
    316128,
    329746,
    329748,
    329749,
    329750,
    329751,
    329753,
    329754,
    329755,
    464134,
    464135,
    680968,
    681221
  )
GROUP BY
  1
