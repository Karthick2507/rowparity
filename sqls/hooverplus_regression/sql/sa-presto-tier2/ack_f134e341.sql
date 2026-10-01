-- account:    sa-presto-tier2
-- skeleton:   c996fec78e354bd270963fdf1b8dff22
-- pattern:    f134e34113ad373b2dfa315ec56e35c7  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  visitor__user_id AS user_id,
  advertisement__active_aim_audience_ids AS active_aim_audience_ids,
  advertisement__ad_id AS ad_id,
  advertisement__placement_id AS placement_id,
  COUNT(*) AS impression_count
FROM ${bcv_ack}
WHERE
  (
    (
      (
        ack__metrics__ad_impression = 1 AND NOT partners__network_id IS NULL
      )
      AND CONTAINS(partners__network_id, CAST('144750' AS BIGINT))
    )
    AND CARDINALITY(advertisement__active_aim_audience_ids) > 0
  )
  AND visitor__user_id IN (
    'ndkymjyynzg0nzqymjg1ndc2nq==',
    'odmznjmxnzuzmjkymdq3mdi2ma==',
    '41cadf661680cecb5df62e06a1fb79e69fd7aa89',
    'njm5njyymzi3mda0ndm0odcxnq==',
    '244f7b3d2c414ec593448190fc5c4991617a2bb4',
    '53054253452a097893b35e5fbb4b338ad5e1d627',
    'bc913285e92d610f07f2cc00b38c9a73c8fa9740',
    'ltg4mdm5ntu5njm5ndc3njm4mzu=',
    'nzm2ndg4ndk4mtazndc3ntq0mw==',
    'mtexndcxmtezndc2njg2odi3oa==',
    'ltm0oda1odiynzy3odiymde1ng==',
    'nzmxmtk2ntixodiynzi1mtayma==',
    'ltcwndixnta5odi4nzaznzeymza=',
    'nzaymtq0mdi1mzawmtq4nzkyng==',
    'ltc4nza1nzmymymtgxnzawmtg2ntg=',
    'ndg0njq4otc0ntuxntg2otuznw=='
  )
GROUP BY
  1,
  2,
  3,
  4
