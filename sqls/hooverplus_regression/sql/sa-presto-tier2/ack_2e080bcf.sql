-- account:    sa-presto-tier2
-- skeleton:   a7c762b13a32e21bd48337956fa0ea6c
-- pattern:    2e080bcf87c22bdb37be67c81f80c7e2  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COUNT_IF(request__is_first_request) AS first_requests,
  SUM(ack__metrics__ad_impression) AS impressions
FROM ${bcv_ack}
WHERE
  request__context__video_cro_network_id = 144750
  AND CARDINALITY(
    ARRAY_INTERSECT(
      IF(
        CARDINALITY(request__audience_item__audience_item_id) > 0,
        request__audience_item__audience_item_id,
        FLATTEN(
          CONCAT(
            request__network_audience_items__tracked_audience_item_ids,
            request__network_audience_items__non_tracked_audience_item_ids
          )
        )
      ),
      ARRAY[CAST('1416990' AS BIGINT)]
    )
  ) > 0
