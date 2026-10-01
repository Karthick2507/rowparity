-- account:    chzhang
-- skeleton:   3ca4335280966b7f0fa12bac7e855c06
-- pattern:    84617b29fb317a127139d5916b63aa9c  (115 execution(s))
-- in suite:   daily commitment
-- hoover:     candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? HOUR

SELECT
  f.eventtime AS __time,
  CAST(f.networkid AS VARCHAR) AS networkid,
  f.marketadid,
  f.mrmbiddingbuyerid,
  f.entitytype,
  f.entityid
FROM (
  SELECT
    MIN(request__timestamp) AS eventtime,
    COALESCE(auction__network_id, -1) AS networkid,
    COALESCE(candidate__market_ad_id, -1) AS marketadid,
    -1 AS mrmbiddingbuyerid,
    'mkplorder' AS entitytype,
    COALESCE(candidate__order_id, -1) AS entityid
  FROM ${bcv_candidate}
  WHERE
    (
      NOT candidate__external_ad_id IS NULL
      AND candidate__integration_type = 'mkpl_partner_tag'
    )
    AND BITWISE_AND(auction__flags, 8) = 0
  GROUP BY
    2,
    3,
    4,
    5,
    6
) AS f
JOIN (
  SELECT
    *
  FROM oltp.fwmrm_oltp.network_function
  WHERE
    function_id = 1537
) AS nf1
  ON f.networkid = nf1.network_id
JOIN (
  SELECT
    *
  FROM oltp.fwmrm_oltp.network_function
  WHERE
    function_id = 1381 AND parameter IN ('1', '3')
) AS nf2
  ON f.networkid = nf2.network_id
LEFT JOIN (
  SELECT
    client_market_ad.market_ad_id,
    client_market_ad.network_id,
    client_market_ad_entity_assignment.entity_id
  FROM oltp.fwmrm_oltp.client_market_ad_entity_assignment
  JOIN oltp.fwmrm_oltp.client_market_ad
    ON client_market_ad_entity_assignment.client_market_ad_id = client_market_ad.id
  WHERE
    client_market_ad_entity_assignment.entity_type = 'mkpl_order'
    AND client_market_ad.mkpl_type = 'mkpl_partner_tag'
) AS cmaea
  ON f.marketadid = cmaea.market_ad_id
  AND f.networkid = cmaea.network_id
  AND f.entityid = cmaea.entity_id
WHERE
  cmaea.market_ad_id IS NULL AND f.marketadid <> -1
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
