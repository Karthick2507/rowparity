-- account:    sa-presto-tier2
-- skeleton:   718ffa7381ab15578591e7caacb91981
-- pattern:    2e437e1e72668f22151b1d48a7fd6af0  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  visitor__user_id,
  SUM(ack__metrics__raw_ad_impression) AS raw_impressions,
  SUM(IF(ack__traffic_type = 0, ack__metrics__raw_ad_impression, 0)) AS net_impressions,
  COUNT(DISTINCT request__transaction_id) AS transactions
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__audience_partner_segment_infos__audience_partner_id) AS p(a_partner_id)
WHERE
  (
    (
      ack__ack_entity_type = 'ad'
      AND CARDINALITY(FILTER(partners__audience_partner_segment_infos__max_cpm, x -> NOT x IS NULL)) > 0
    )
    AND CONTAINS(p.a_partner_id, 536344)
  )
  AND visitor__user_id IN (
    'mjm3nzu3nze5odg3mzmxnzuz',
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
    'mzmxmtk2ntixodiynzi1mtayma==',
    'ltcwndixnta5odi4nzaznzeymza=',
    'nzaymtq0mdi1mzawmtq4nzkyng==',
    'ltc4nza1nzmymtgxnzawmtg2ntg=',
    'ndg0njq4otc0ntuxntg2otuznw==',
    '492ab31ba2de0dc96ad89e113550d3f024f6a1be',
    'c398f1f1860b1e3630fdeb2e1c4cadc5f01042ab',
    '84a22c7c857bf3e627337807726167d7abeeae8e',
    'ntczmtu1nzqwotuznjawmde2nw==',
    'ltm1njawnzuymji1otq5mze4odm=',
    'ltu0mzq3ndgxmjmymju4mjq3nzi=',
    'ntuyotaxotk0mzqyotkwnjmymg==',
    'oduxmju2ntg4mte1mtuxotuzna==',
    'mte5ndyzntgymdg1mzaxodg4',
    'ltcwndc5mzy5mty5mjk1ode4mzm=',
    'e81d2bc9182a570b7dbaa786dd6b371fa9aeb19e',
    '634ea54dfc57a6b86b0e990aed79f2d2839557f6',
    '160856ac256560e6c869be1615d99e5e946c6937',
    'ac9ddc924dbc0efa47053ae6c159b1361bb1130d',
    '5a1cab1cf6e792bb107e232da418e758dc8b476f',
    '47fd1e9b95ea8f8fa1e2defb321dc0f487fafdb2',
    '9ce8687ea0cb6f118d1fe247f9baf770191cdfb4',
    'ltu0ndk0mjqxmzu2ndk2nza4mta=',
    'njixodawmte4njazmda4ndkyoq==',
    'ntyzmzuymdk5mjmymtuxmzcwoa==',
    'ltu1mdcwodg5mdc2ote2otkwndc=',
    '0c6544c7a0b1a8f8fe919f15ef71a42ae7df9f37',
    'ntg5mjixmzqymzg1nduzmtu3mq==',
    'mzayndiwnju0nzgxntm2nzg1mw==',
    'eb9a39d6b35bd6cd5d75f1b3d572e4609331170a',
    '505d6f571b0e1b741ed3146e1396993da5a2cd66',
    'njqwnjm3mja5mzqyntaznjk2nq==',
    'ltqzmdyzmtqwmdgwmti3mzy5odi=',
    'mte1ntq1mjc1ntg3mzg4odywoq==',
    'ltqymtgynzg1mjk4mdc1nda3otg=',
    'nde0odu5ntq1ntmymdgxntywoa==',
    'ltexodm0mjaynzcznzkxnjgwnjc=',
    'lte2ndu0mzkznjy4nzi4mda0njq='
  )
GROUP BY
  1
ORDER BY
  net_impressions DESC
