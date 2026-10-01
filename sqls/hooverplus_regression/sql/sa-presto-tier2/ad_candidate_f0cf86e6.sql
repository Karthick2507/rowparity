-- account:    sa-presto-tier2
-- skeleton:   2b9c2a1d47fe8da61f264dfbb9c5b97b
-- pattern:    f0cf86e6ec6a84076b7b7b651dc1190e  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad, candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   c.request__timestamp < CAST(? AS TIMESTAMP)
--   c.request__timestamp >= CAST(? AS TIMESTAMP)

WITH jul31 AS (
  SELECT
    c.candidate__internal_deal_id AS deal_id,
    ELEMENT_AT(
      a.partners__sales_channel,
      ARRAY_POSITION(a.partners__network_id, CAST('393759' AS BIGINT))
    ) AS winning_sc,
    COUNT(*) AS cnt
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
    2
), aug1 AS (
  SELECT
    c.candidate__internal_deal_id AS deal_id,
    ELEMENT_AT(
      a.partners__sales_channel,
      ARRAY_POSITION(a.partners__network_id, CAST('393759' AS BIGINT))
    ) AS winning_sc,
    COUNT(*) AS cnt
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
    2
)
SELECT
  'jul 31 12:00-13:00' AS period,
  CASE winning_sc
    WHEN 2
    THEN 'direct sold (sc=2)'
    WHEN 4
    THEN 'programmatic module (sc=4)'
    ELSE 'other'
  END AS winning_channel,
  SUM(cnt) AS total_failures,
  ROUND(100.0 * SUM(cnt) / SUM(SUM(cnt)) OVER (), 1) AS pct_of_failures
FROM jul31
GROUP BY
  1,
  2
UNION ALL
SELECT
  'aug 1 12:00-13:00' AS period,
  CASE winning_sc
    WHEN 2
    THEN 'direct sold (sc=2)'
    WHEN 4
    THEN 'programmatic module (sc=4)'
    ELSE 'other'
  END AS winning_channel,
  SUM(cnt) AS total_failures,
  ROUND(100.0 * SUM(cnt) / SUM(SUM(cnt)) OVER (), 1) AS pct_of_failures
FROM aug1
GROUP BY
  1,
  2
ORDER BY
  1,
  3 DESC
