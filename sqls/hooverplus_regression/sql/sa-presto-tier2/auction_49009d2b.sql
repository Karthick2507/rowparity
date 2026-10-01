-- account:    sa-presto-tier2
-- skeleton:   097d8f76279ace17795042af905ba50f
-- pattern:    49009d2bb362708c75fbe242e4e5f6e2  (1 execution(s))
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
  partners__inbound_order_id[ARRAY_POSITION(partners__network_id, CAST('384777' AS BIGINT))] AS comcast_prod_inbound_order_id,
  COUNT(*) AS total_opportunities,
  COUNT_IF(NOT auction__ip IS NULL AND auction__ip <> '' AND auction__ip <> '-2') AS opportunities_with_ip,
  COUNT_IF(auction__ip IS NULL OR auction__ip = '' OR auction__ip = '-2') AS opportunities_without_ip,
  ROUND(
    100.0 * COUNT_IF(NOT auction__ip IS NULL AND auction__ip <> '' AND auction__ip <> '-2') / COUNT(*),
    2
  ) AS ip_present_pct
FROM ${bcv_auction}
WHERE
  (
    CONTAINS(partners__network_id, CAST('384777' AS BIGINT))
    AND CONTAINS(partners__network_id, CAST('520024' AS BIGINT))
  )
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
