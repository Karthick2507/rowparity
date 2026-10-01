-- account:    sa-presto-tier2
-- skeleton:   f2e3b72821f5d6a851f165d70be47a61
-- pattern:    78f5e908b697f1c67e16fe0427052189  (1 execution(s))
-- in suite:   column coverage
-- hoover:     slot
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  inbound_order_id AS comcast_prod_inbound_order_id,
  COUNT(*) AS total_slot_opps,
  COUNT_IF(
    NOT visitor__address IS NULL
    AND visitor__address <> ''
    AND visitor__address <> '-2'
  ) AS opps_with_ip,
  ROUND(
    100.0 * COUNT_IF(
      NOT visitor__address IS NULL
      AND visitor__address <> ''
      AND visitor__address <> '-2'
    ) / COUNT(*),
    2
  ) AS ip_present_pct
FROM ${bcv_slot}
CROSS JOIN UNNEST(partners__network_id, partners__inbound_order_id) AS t(partner_nw, inbound_order_id)
WHERE
  (
    request__context__video_cro_network_id = 384777 AND partner_nw = 384777
  )
  AND inbound_order_id IN (
    161012,
    161014,
    161016,
    161020,
    161022,
    161024,
    161025,
    161026,
    161027,
    161029,
    161030,
    161031,
    179876,
    227373,
    227374,
    227375,
    227376,
    227377,
    227378,
    227379,
    300174,
    316128,
    329746,
    329748,
    329749,
    329750,
    329751,
    329753,
    329754,
    329755,
    464134,
    464135,
    680968,
    681221
  )
GROUP BY
  1
