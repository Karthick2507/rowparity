-- account:    sa-presto-tier2
-- skeleton:   213a37aef046ec66f8ec001e0059c284
-- pattern:    8d995468bb821248a15f4b11096cccab  (1 execution(s))
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
), optout_ids AS (
  SELECT
    uid
  FROM (VALUES
    ('mjm3nzu3nze5odg3mzmxnzuz'),
    ('ndkymjyynzg0nzqymjg1ndc2nq=='),
    ('odmznjmxnzuzmjkymdq3mdi2ma=='),
    ('41cadf661680cecb5df62e06a1fb79e69fd7aa89'),
    ('njm5njyymzi3mda0ndm0odcxnq=='),
    ('244f7b3d2c414ec593448190fc5c4991617a2bb4'),
    ('53054253452a097893b35e5fbb4b338ad5e1d627'),
    ('bc913285e92d610f07f2cc00b38c9a73c8fa9740'),
    ('e81d2bc9182a570b7dbaa786dd6b371fa9aeb19e'),
    ('634ea54dfc57a6b86b0e990aed79f2d2839557f6'),
    ('160856ac256560e6c869be1615d99e5e946c6937'),
    ('ac9ddc924dbc0efa47053ae6c159b1361bb1130d'),
    ('5a1cab1cf6e792bb107e232da418e758dc8b476f'),
    ('143575a6a1ba6ec1214fafa4028f887773772127'),
    ('330b1cb65aae2fd46a973ef92ec7a3af582ab293'),
    ('c398f1f1860b1e3630fdeb2e1c4cadc5f01042ab'),
    ('84a22c7c857bf3e627337807726167d7abeeae8e'),
    ('0c6544c7a0b1a8f8fe919f15ef71a42ae7df9f37'),
    ('505d6f571b0e1b741ed3146e1396993da5a2cd66'),
    ('eb9a39d6b35bd6cd5d75f1b3d572e4609331170a')) AS t(uid)
)
SELECT
  'plain_match' AS match_type,
  COUNT(*) AS matched_opted_out_users
FROM delivered_users AS d
INNER JOIN optout_ids AS o
  ON d.visitor__user_id = o.uid
UNION ALL
SELECT
  'prefixed_144750_match' AS match_type,
  COUNT(*) AS matched_opted_out_users
FROM delivered_users AS d
INNER JOIN optout_ids AS o
  ON d.visitor__user_id = CONCAT('144750:', o.uid)
