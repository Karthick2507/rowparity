-- account:    sa-presto-af-etl
-- skeleton:   c14cb1feae7935437f82b98120773d85
-- pattern:    2eee36c0f8c2e0ec50f703f0d706834b  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack, ad, transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < ?
--   process_batch_id >= ?

SELECT
  t2.*,
  COALESCE(t1.ad_views, 0) AS ad_views,
  COALESCE(t3.total_ad_cnt, 0) AS total_ad_cnt
FROM (
  SELECT
    DATE_FORMAT(request__timestamp, '%y%m%d') AS request_date,
    request__context__video_cro_network_id AS cro_network_id,
    request__context__site_section_cro_site_id AS site_id,
    request__context__site_section_cro_asset_id AS site_section_id,
    CAST(SUM(COALESCE(ack__metrics__ad_impression, 0)) AS BIGINT) AS ad_views
  FROM ${bcv_ack} AS ack
  CROSS JOIN UNNEST(partners__network_is_ad_owner, partners__network_is_extra_item_owner, partners__content_owner_network_id, partners__inbound_order_id, partners__network_id, partners__role, partners__site_section_id) AS t(network_network_is_ad_owner, network_network_is_extra_item_owner, network_content_owner_network_id, network_inbound_order_id, network_network_id, network_role, network_site_section_id)
  WHERE
    COALESCE(network_network_id, CAST(-1 AS BIGINT)) = 376521
    AND (
      (
        ack__ack_entity_type = 'ad'
        AND NOT advertisement__is_bumper
        AND (
          NOT ack__is_private_impression
          OR network_network_is_ad_owner
          OR network_network_is_extra_item_owner
        )
      )
      OR (
        ack__ack_entity_type = 'ad'
        AND network_network_is_ad_owner
        AND NOT advertisement__is_bumper
        AND advertisement__is_ax
        AND COALESCE(network_role, '') = 'cro'
      )
    )
  GROUP BY
    1,
    2,
    3,
    4
) AS t1
JOIN (
  SELECT
    DATE_FORMAT(request__timestamp, '%y%m%d') AS request_date,
    request__context__asset_chain__content_right_owner__network_id AS cro_network_id,
    request__context__site_section_chain__content_right_owner__site_id AS site_id,
    request__context__site_section_chain__content_right_owner__asset_id AS site_section_id,
    COUNT(*) AS request_cnt
  FROM ${bcv_transaction}
  WHERE
    request__is_first_request
  GROUP BY
    1,
    2,
    3,
    4
) AS t2
  ON t1.request_date = t2.request_date
  AND t1.cro_network_id = t2.cro_network_id
  AND t1.site_id = t2.site_id
  AND t1.site_section_id = t2.site_section_id
JOIN (
  SELECT
    DATE_FORMAT(request__timestamp, '%y%m%d') AS request_date,
    request__context__video_cro_network_id AS cro_network_id,
    request__context__site_section_cro_site_id AS site_id,
    request__context__site_section_cro_asset_id AS site_section_id,
    COUNT(*) AS total_ad_cnt
  FROM ${bcv_ad} AS t1
  JOIN oltp.fwmrm_oltp.ad_tree_node AS t2
    ON t1.advertisement__ad_id = t2.id
  WHERE
    t2.network_id = 376521
  GROUP BY
    1,
    2,
    3,
    4
) AS t3
  ON t1.request_date = t3.request_date
  AND t1.cro_network_id = t3.cro_network_id
  AND t1.site_id = t3.site_id
  AND t1.site_section_id = t3.site_section_id
