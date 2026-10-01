-- account:    sa-presto-tier2
-- skeleton:   2dc2229490dcc452e6f39d8fc0cffa70
-- pattern:    da8c4f22c68cfbfeb6be3b2638f1f5fb  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad, candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   c.request__timestamp < CAST(? AS TIMESTAMP)
--   c.request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(c.request__timestamp, '%y-%m-%d') AS event_day,
  c.candidate__internal_deal_id AS deal_id,
  fr_error,
  ELEMENT_AT(
    a.partners__sales_channel,
    ARRAY_POSITION(a.partners__network_id, CAST('393759' AS BIGINT))
  ) AS winning_sales_channel,
  COUNT(*) AS occurrences
FROM ${bcv_candidate} AS c
CROSS JOIN UNNEST(c.candidate__filter_reason__error) AS t(fr_error)
JOIN ${bcv_ad} AS a
  ON a.request__transaction_id = c.request__transaction_id
  AND a.request__timestamp = c.request__timestamp
WHERE
  (
    (
      c.request__context__network_id = 393759
      AND c.candidate__internal_deal_id IN (667139, 667140, 670539, 670542)
    )
    AND fr_error = 'exceed_max_num_advertisements'
  )
  AND NOT a.advertisement__ad_id IS NULL
GROUP BY
  1,
  2,
  3,
  4
