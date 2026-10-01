-- account:    sa-presto-af-etl
-- skeleton:   4b4fa9507dfcaa9a47e7844637b1861c
-- pattern:    f740658b00c59aff4c4b9cecf567a9b1  (3 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < ?
--   process_batch_id >= ?

SELECT
  *
FROM (
  SELECT
    DATE_FORMAT(request__timestamp, '%y%m%d') AS request_date,
    request__context__video_cro_network_id AS cro_network_id,
    COALESCE(network_content_owner_network_id, CAST(-1 AS BIGINT)) AS content_owner_id,
    COALESCE(network_inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
    request__context__site_section_cro_asset_id AS site_section_id,
    CAST(SUM(COALESCE(ack__metrics__ad_impression, 0)) AS BIGINT) AS ad_views,
    0 AS total_avails
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
    4,
    5
)
UNION ALL
(
  SELECT
    DATE_FORMAT(request__timestamp, '%y%m%d') AS request_date,
    request__context__video_cro_network_id AS cro_network_id,
    COALESCE(network_content_owner_network_id, CAST(-1 AS BIGINT)) AS content_owner_id,
    COALESCE(network_inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
    request__context__site_section_cro_asset_id AS site_section_id,
    0 AS ad_views,
    CAST(SUM(
      COALESCE(network_avails_category_total_avails_in_played_slot, 0) * (
        COALESCE(ack__metrics__slot_impression, 0)
      )
    ) AS BIGINT) AS total_avails
  FROM ${bcv_ack} AS ack
  CROSS JOIN UNNEST(partners__avails_category__total_avails_in_played_slot, partners__content_owner_network_id, partners__inbound_order_id, partners__network_id, partners__avails_category__unconstrained_avails_in_played_slot, partners__avails_category__unfilled_avails_in_played_slot, partners__avails_category__market_avails_in_played_slot, partners__avails_category__ssp_avails_in_played_slot, partners__avails_category__total_unfilled_avails_in_played_slot, partners__avails_category__opportunity_in_played_slot, partners__site_section_id) AS t(network_avails_category_total_avails_in_played_slot, network_content_owner_network_id, network_inbound_order_id, network_network_id, network_avails_category_unconstrained_avails_in_played_slot, network_avails_category_unfilled_avails_in_played_slot, network_avails_category_ssp_avails_in_played_slot, network_avails_category_market_avails_in_played_slot, network_avails_category_total_unfilled_avails_in_played_slot, network_avails_category_opportunity_in_played_slot, network_site_section_id)
  WHERE
    (
      (
        COALESCE(network_network_id, CAST(-1 AS BIGINT)) = 376521
        AND ack__ack_entity_type = 'slot'
      )
      AND BITWISE_AND(COALESCE(slot__flags, CAST(0 AS BIGINT)), 64) = 0
    )
    AND (
      (
        COALESCE(ack__metrics__avails_event_count, CAST(0 AS INTEGER)) <> 0
        AND (
          COALESCE(network_avails_category_total_avails_in_played_slot, CAST(0 AS INTEGER)) <> 0
          OR COALESCE(network_avails_category_unconstrained_avails_in_played_slot, CAST(0 AS INTEGER)) <> 0
          OR COALESCE(network_avails_category_unfilled_avails_in_played_slot, CAST(0 AS INTEGER)) <> 0
          OR COALESCE(network_avails_category_market_avails_in_played_slot, CAST(0 AS INTEGER)) <> 0
          OR COALESCE(network_avails_category_ssp_avails_in_played_slot, CAST(0 AS INTEGER)) <> 0
        )
      )
      OR (
        COALESCE(ack__metrics__slot_impression, CAST(0 AS BIGINT)) <> 0
        AND (
          COALESCE(network_avails_category_total_avails_in_played_slot, CAST(0 AS INTEGER)) <> 0
          OR COALESCE(network_avails_category_total_unfilled_avails_in_played_slot, CAST(0 AS INTEGER)) <> 0
          OR COALESCE(network_avails_category_opportunity_in_played_slot, CAST(0 AS INTEGER)) <> 0
        )
      )
    )
  GROUP BY
    1,
    2,
    3,
    4,
    5
)
