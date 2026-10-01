-- account:    sa-presto-tier2
-- skeleton:   1d8c1bd4fc675a21b5efc43dc72bc859
-- pattern:    f6cc5a280d9034d44a7d50ce90a6b896  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH transaction_ads AS (
  SELECT
    ack__transaction_id AS txn_id,
    DATE_TRUNC('DAY', request__timestamp) AS event_date,
    MAX(CASE WHEN ack__advertisement__ad_id = 92683573 THEN 1 ELSE 0 END) AS has_blipvert,
    MAX(
      CASE
        WHEN ack__advertisement__network_id = 144750 AND ack__advertisement__ad_id <> 92683573
        THEN 1
        ELSE 0
      END
    ) AS has_sky_priority,
    MAX(CASE WHEN ack__advertisement__network_id IN (191701, 386345) THEN 1 ELSE 0 END) AS has_passback
  FROM ${bcv_ack}
  WHERE
    (
      (
        request__context__video_cro_network_id = 386345
        AND request__context__standard_endpoint_id = 629
      )
      AND request__is_first_request = TRUE
    )
    AND ack__ack_entity_type = 'ad'
  GROUP BY
    ack__transaction_id,
    event_date
), categorized AS (
  SELECT
    event_date,
    CASE
      WHEN has_blipvert = 1 AND has_sky_priority = 0 AND has_passback = 0
      THEN 'q1: only blipverts delivered'
      WHEN has_blipvert = 1 AND has_sky_priority = 1
      THEN 'q2: sky priority ads + blipverts'
      WHEN has_blipvert = 0 AND has_sky_priority = 0 AND has_passback = 1
      THEN 'q3: passback only (no blipvert, no sky priority)'
      ELSE 'other'
    END AS delivery_scenario,
    txn_id
  FROM transaction_ads
)
SELECT
  event_date,
  delivery_scenario,
  COUNT(DISTINCT txn_id) AS total_ad_requests
FROM categorized
WHERE
  delivery_scenario IN (
    'q1: only blipverts delivered',
    'q2: sky priority ads + blipverts',
    'q3: passback only (no blipvert, no sky priority)'
  )
GROUP BY
  event_date,
  delivery_scenario
ORDER BY
  event_date DESC,
  delivery_scenario
