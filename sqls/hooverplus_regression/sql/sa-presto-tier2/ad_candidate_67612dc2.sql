-- account:    sa-presto-tier2
-- skeleton:   896c50a2756c574b261e2996ab2fd724
-- pattern:    67612dc24b24a1fad99d201f0a477243  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad, candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   a.request__timestamp < CAST(? AS TIMESTAMP)
--   a.request__timestamp >= CAST(? AS TIMESTAMP)
--   c.request__timestamp < CAST(? AS TIMESTAMP)
--   c.request__timestamp >= CAST(? AS TIMESTAMP)

WITH pg_deal_failures AS (
  SELECT DISTINCT
    c.request__transaction_id,
    c.candidate__filter_reason__slot_index[1] AS failed_slot_index
  FROM ${bcv_candidate} AS c
  WHERE
    (
      (
        (
          c.request__context__video_cro_network_id = 393759
          AND c.candidate__internal_deal_id = 670542
        )
        AND c.candidate__error = 'competition_failure'
      )
      AND CONTAINS(c.candidate__filter_reason__error, 'exceed_max_num_advertisements')
    )
    AND CARDINALITY(c.candidate__filter_reason__slot_index) > 0
  
), ads_in_slot AS (
  SELECT
    a.request__transaction_id,
    a.advertisement__slot_index,
    a.advertisement__position_in_slot,
    a.candidate__integration_type,
    a.candidate__internal_deal_id AS ad_deal_id,
    a.candidate__clearing_price AS ad_clearing_price,
    a.advertisement__unified_priority__priority_tier AS priority_tier,
    a.advertisement__duration,
    CASE
      WHEN BITWISE_AND(COALESCE(a.advertisement__flags, 0), 4194304) > 0
      THEN 'market_ad'
      WHEN a.candidate__integration_type IN ('openrtb_pg_td')
      THEN 'pg_programmatic'
      WHEN a.candidate__integration_type IN ('openrtb_normal')
      THEN 'programmatic'
      WHEN a.candidate__integration_type IN ('mkpl_partner_tag')
      THEN 'partner_tag'
      WHEN a.candidate__integration_type IS NULL
      THEN 'direct_sold'
      ELSE a.candidate__integration_type
    END AS ad_type,
    CASE
      WHEN BITWISE_AND(COALESCE(a.advertisement__flags, 0), 32) > 0
      THEN 'yes'
      ELSE 'no'
    END AS is_fallback
  FROM ${bcv_ad} AS a
  WHERE
    a.request__context__video_cro_network_id = 393759
)
SELECT
  a.ad_type,
  a.candidate__integration_type,
  a.priority_tier,
  a.is_fallback,
  COUNT(*) AS occurrences,
  COUNT(DISTINCT f.request__transaction_id) AS unique_transactions,
  ROUND(AVG(a.ad_clearing_price), 3) AS avg_clearing_price_cpm,
  ROUND(MIN(a.ad_clearing_price), 3) AS min_clearing_price_cpm,
  ROUND(MAX(a.ad_clearing_price), 3) AS max_clearing_price_cpm,
  ROUND(AVG(a.advertisement__duration), 1) AS avg_duration_sec
FROM pg_deal_failures AS f
JOIN ads_in_slot AS a
  ON f.request__transaction_id = a.request__transaction_id
  AND f.failed_slot_index = a.advertisement__slot_index
GROUP BY
  1,
  2,
  3,
  4
