-- account:    sa-presto-tier2
-- skeleton:   6e02bb21f1fabd91832206b6063a0195
-- pattern:    a18d510fac9f045326e177b426ba5618  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COUNT_IF(request__is_first_request) AS first_requests_with_audience_1416990
FROM ${bcv_transaction}
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
