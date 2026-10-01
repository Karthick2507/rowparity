-- account:    sa-presto-tier2
-- skeleton:   7ee81550f956fdfe143db522ae8faa14
-- pattern:    87751b0967c535cdf2cb77ebf335b3e0  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH delivered_users AS (
  SELECT DISTINCT
    visitor__user_id
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__audience_partner_segment_infos__audience_partner_id) AS p(a_partner_id)
  WHERE
    (
      (
        (
          ack__ack_entity_type = 'ad'
          AND CARDINALITY(FILTER(partners__audience_partner_segment_infos__max_cpm, x -> NOT x IS NULL)) > 0
        )
        AND CONTAINS(p.a_partner_id, 536344)
      )
      AND NOT visitor__user_id IS NULL
    )
    AND visitor__user_id <> ''
)
SELECT
  COUNT(*) AS total_delivered_users,
  COUNT_IF(visitor__user_id LIKE '144750:%') AS prefixed_144750,
  COUNT_IF(visitor__user_id LIKE '394492:%') AS prefixed_394492,
  COUNT_IF(
    NOT visitor__user_id LIKE '144750:%'
    AND NOT visitor__user_id LIKE '394492:%'
    AND NOT visitor__user_id LIKE '%-%-%-%-%'
    AND NOT visitor__user_id LIKE 'l%'
    AND NOT visitor__user_id LIKE 'v%'
    AND NOT visitor__user_id LIKE 'g%'
    AND NOT REGEXP_LIKE(visitor__user_id, '^[0-9]+$')
    AND LENGTH(visitor__user_id) < 65
  ) AS base64_or_short_hex_format_users
FROM delivered_users
