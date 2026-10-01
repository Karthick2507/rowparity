-- account:    sa-presto-tier2
-- skeleton:   3524511926bc038403c0fbab320fbfc3
-- pattern:    707a3215f6e33c27af5b4b66c244152b  (1 execution(s))
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
), matched AS (
  SELECT
    d.visitor__user_id,
    CASE
      WHEN d.visitor__user_id LIKE '144750:%'
      THEN SUBSTR(d.visitor__user_id, 8)
      ELSE d.visitor__user_id
    END AS normalized_id
  FROM delivered_users AS d
  WHERE
    (
      d.visitor__user_id LIKE '144750:%'
      OR (
        NOT d.visitor__user_id LIKE '394492:%'
        AND NOT d.visitor__user_id LIKE '%-%-%-%-%'
        AND NOT d.visitor__user_id LIKE 'l%'
        AND NOT d.visitor__user_id LIKE 'v%'
        AND NOT d.visitor__user_id LIKE 'g%'
        AND NOT REGEXP_LIKE(d.visitor__user_id, '^[0-9]+$')
        AND LENGTH(d.visitor__user_id) < 65
      )
    )
)
SELECT
  COUNT(*) AS candidate_delivered_users_to_check
FROM matched
