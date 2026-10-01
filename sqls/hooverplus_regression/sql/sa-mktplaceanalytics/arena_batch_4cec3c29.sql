-- account:    sa-mktplaceanalytics
-- skeleton:   1efb951a175dbeca9f07fc5582ecdf93
-- pattern:    4cec3c29b5b0410c408789d38d50a658  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_TRUNC(?, CAST(? AS TIMESTAMP))
--   request__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))

SELECT
  *,
  request_date AS _arena_partition_request_date
FROM (
  SELECT
    DATE_TRUNC('DAY', request__timestamp) AS request_date,
    partners__network_id,
    partners__priority_type,
    partners__sales_channel,
    partners__network_is_ad_owner,
    partners__network_is_extra_item_owner,
    ack__is_private_impression,
    candidate__internal_deal_id AS internal_deal_id,
    candidate__deal_type AS deal_type,
    visitor__universal_hhid AS imp_hhid,
    visitor__user_id AS imp_user_id,
    SUM(ack__metrics__ad_impression) AS ad_impressions
  FROM ${bcv_ack}
  WHERE
    (
      (
        NOT ack__metrics__ad_impression IS NULL AND ack__traffic_type = 0
      )
      AND ack__ack_entity_type = 'ad'
    )
    AND advertisement__is_bumper = FALSE
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
    11
) AS arena_tmp
