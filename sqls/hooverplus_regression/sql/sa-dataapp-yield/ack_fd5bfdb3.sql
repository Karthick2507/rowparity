-- account:    sa-dataapp-yield
-- skeleton:   d7da4dddab7862a5858b513b91f6ea49
-- pattern:    fd5bfdb358a74a7f1a400097ee1965c7  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(ack__timestamp, '%y-%m-%d %h:00:00') AS timestamp,
  COALESCE(advertisement__replaced_ad_network_id, advertisement__ad_oo_network_id) AS publisher_network_id,
  d_network.name AS publisher_network_name,
  CASE
    WHEN candidate__integration_type = 'openrtb_pg_td'
    THEN 'fullstack_pg'
    WHEN candidate__integration_type = 'openrtb_normal'
    THEN 'fullstack_non_pg'
    WHEN candidate__integration_type = 'openrtb_sfx'
    THEN 'sfx_openrtb'
    WHEN candidate__integration_type = 'reseller_tag'
    AND advertisement__external_reseller__network_id = 127719
    THEN 'sfx_tag'
    WHEN candidate__integration_type = 'reseller_tag'
    THEN 'ssp_others'
    WHEN candidate__integration_type = 'mkpl_partner_tag'
    THEN 'mkpl_partner_tag'
    WHEN NOT advertisement__external_reseller__network_id IS NULL
    THEN 'reseller_tag'
    ELSE 'na'
  END AS market_integration_type,
  CASE WHEN NOT candidate__integration_type IS NULL THEN 'true' ELSE 'false' END AS is_mrm_market_traffic,
  IF(
    advertisement__external_reseller__network_id = 127719
    OR candidate__integration_type IN ('openrtb_pg_td', 'openrtb_normal', 'openrtb_sfx')
    OR (
      NOT d_rendition.creative_rendition_wrapper_url IS NULL
      AND CARDINALITY(SPLIT(d_rendition.creative_rendition_wrapper_url, '/')) > 2
      AND ARRAY_JOIN(
        REVERSE(
          SLICE(REVERSE(SPLIT(SPLIT(d_rendition.creative_rendition_wrapper_url, '/')[3], '.')), 1, 2)
        ),
        '.'
      ) = 'stickyadstv.com'
    ),
    'mrm',
    IF(
      candidate__integration_type IN ('mkpl_partner_tag'),
      COALESCE(
        ARRAY_JOIN(
          REVERSE(SLICE(REVERSE(SPLIT(SPLIT(partner_tag.url_template, '/')[3], '.')), 1, 2)),
          '.'
        ),
        'na'
      ),
      COALESCE(
        ARRAY_JOIN(
          REVERSE(
            SLICE(REVERSE(SPLIT(SPLIT(d_rendition.creative_rendition_wrapper_url, '/')[3], '.')), 1, 2)
          ),
          '.'
        ),
        'na'
      )
    )
  ) AS ssp,
  IF(
    NOT candidate__internal_deal_id IS NULL
    AND d_ssp_deal_metadata.deal_type_oltp IN ('programmatic_guaranteed_trading_desk_deal', 'biddable_guaranteed_deal'),
    'guaranteed deal',
    IF(
      NOT d_mrm_access_rule.priority_setting IS NULL,
      d_mrm_access_rule.priority_setting,
      d_placement.gurantee_mode
    )
  ) AS priority_bucket,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS ad_views,
  SUM(
    IF(
      (
        ack.slot__time_position_class IN ('preroll', 'midroll', 'postroll', 'overlay')
      )
      AND NOT (
        BITWISE_AND((
          COALESCE(ack.ack__flags, 0)
        ), 20760) <> 0
      )
      AND ack.ack__event_type = 'i'
      AND ack.ack__event_name = 'resellernoad',
      1 * (
        COALESCE(ack.request__magnifier, 1)
      ) * (
        COALESCE(ack.ack__multiplier, 1)
      ),
      0
    )
  ) AS no_ad_views,
  SUM(
    IF(
      BITWISE_AND(COALESCE(advertisement__flags, 0), 32) = 0
      AND BITWISE_AND(COALESCE(ack__flags, 0), 67108864) = 0,
      COALESCE(ack__metrics__ad_impression, 0),
      0
    )
  ) AS primary_ad_views,
  SUM(
    IF(
      BITWISE_AND(COALESCE(advertisement__flags, 0), 32) = 32
      AND BITWISE_AND(COALESCE(ack__flags, 0), 67108864) = 0,
      COALESCE(ack__metrics__ad_impression, 0),
      0
    )
  ) AS fallback_ad_views,
  SUM(
    ROUND(
      IF(
        (
          ack.ack__event_type = 'i'
          AND ack.ack__event_name = 'defaultimpression'
          AND BITWISE_AND(COALESCE(ack__flags, 0), 67108864) = 0
          AND BITWISE_AND((
            COALESCE(ack.ack__flags, 0)
          ), 1) <> 0
        )
        AND NOT (
          (
            BITWISE_AND((
              COALESCE(ack.advertisement__entity_flags, 0)
            ), 8) <> 0
          )
          AND NOT (
            BITWISE_AND((
              COALESCE(ack.advertisement__entity_flags, 0)
            ), 32) <> 0
          )
        ),
        IF(
          BITWISE_AND(ack.ack__flags, 16) = 0,
          COALESCE(network.revenue, 0) * COALESCE(ack.request__magnifier, 1) * COALESCE(ack.ack__multiplier, 1),
          0.0
        ),
        0.0
      ),
      5
    )
  ) AS revenue
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_is_ad_owner, partners__rule_id, partners__revenue) AS network(network_is_ad_owner, rule_id, revenue)
INNER JOIN db.default.d_network AS d_network
  ON COALESCE(advertisement__replaced_ad_network_id, advertisement__ad_oo_network_id) = d_network.id
LEFT JOIN db.default.d_creative_rendition AS d_rendition
  ON advertisement__rendition_id = d_rendition.id
LEFT JOIN db.default.d_mrm_access_rule AS d_mrm_access_rule
  ON d_mrm_access_rule.id = network.rule_id
LEFT JOIN db.default.d_ssp_deal_metadata AS d_ssp_deal_metadata
  ON d_ssp_deal_metadata.id = candidate__internal_deal_id
LEFT JOIN db.default.d_placement AS d_placement
  ON advertisement__placement_id = d_placement.id
LEFT JOIN db.default.d_mkpl_order AS d_mkpl_order
  ON candidate__order_id = d_mkpl_order.id
LEFT JOIN oltp.fwmrm_oltp.mkpl_order_partner_tag_assignment AS order_partner_tag_assignment
  ON order_partner_tag_assignment.mkpl_order_id = d_mkpl_order.id
LEFT JOIN oltp.fwmrm_oltp.mkpl_partner_tag AS partner_tag
  ON partner_tag.id = order_partner_tag_assignment.mkpl_partner_tag_id
WHERE
  (
    (
      network.network_is_ad_owner AND ack__traffic_type = 0
    )
    AND NOT advertisement__ad_id IS NULL
  )
  AND (
    NOT candidate__integration_type IS NULL
    OR (
      IF(
        candidate__integration_type IN ('mkpl_partner_tag'),
        ARRAY_JOIN(
          REVERSE(SLICE(REVERSE(SPLIT(SPLIT(partner_tag.url_template, '/')[3], '.')), 1, 2)),
          '.'
        ) IN (
          'spotxchange.com',
          'smartclip.net',
          'tremorhub.com',
          'scanscout.com',
          'adnxs.com',
          'amazon-adsystem.com',
          'bfmio.com',
          'googlesyndication.com',
          'appspot.com',
          'adap.tv',
          'advertising.com',
          'rubiconproject.com',
          'facebook.com',
          'everesttech.net',
          'tubemogul.com',
          'adsrvr.org',
          'tidaltv.com',
          'springserve.com',
          'ravm.tv',
          'yieldlab.net',
          'lkqd.net',
          'smartadserver.com',
          'torrenti.al',
          'mdhv.io',
          'truex.com',
          'stickyadstv.com',
          'mtvnservices.com',
          'indexww.com',
          'getpublica.com',
          '3lift.com',
          '1rx.io',
          'mediation.com'
        ),
        (
          NOT d_rendition.creative_rendition_wrapper_url IS NULL
          AND CARDINALITY(SPLIT(d_rendition.creative_rendition_wrapper_url, '/')) > 2
          AND ARRAY_JOIN(
            REVERSE(
              SLICE(REVERSE(SPLIT(SPLIT(d_rendition.creative_rendition_wrapper_url, '/')[3], '.')), 1, 2)
            ),
            '.'
          ) IN (
            'spotxchange.com',
            'smartclip.net',
            'tremorhub.com',
            'scanscout.com',
            'adnxs.com',
            'amazon-adsystem.com',
            'bfmio.com',
            'googlesyndication.com',
            'appspot.com',
            'adap.tv',
            'advertising.com',
            'rubiconproject.com',
            'facebook.com',
            'everesttech.net',
            'tubemogul.com',
            'adsrvr.org',
            'tidaltv.com',
            'springserve.com',
            'ravm.tv',
            'yieldlab.net',
            'lkqd.net',
            'smartadserver.com',
            'torrenti.al',
            'mdhv.io',
            'truex.com',
            'stickyadstv.com',
            'mtvnservices.com',
            'indexww.com',
            'getpublica.com',
            '3lift.com',
            '1rx.io',
            'mediation.com'
          )
        )
      )
    )
  )
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7
