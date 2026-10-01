-- account:    sa-pqm
-- skeleton:   6c22b919436bcc6f496599ee1a90a229
-- pattern:    744bfcc8457664e6b7fc6a3146b4d4a0  (58 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_TRUNC(?, CAST(? AS TIMESTAMP))
--   request__timestamp >= DATE_TRUNC(?, CAST(? AS TIMESTAMP)) - INTERVAL ? DAY

SELECT
  CAST(costs AS DOUBLE) AS usage,
  product_line AS product,
  CAST(network_id AS VARCHAR) AS network,
  CAST(vcro_network_id AS VARCHAR) AS cro_network,
  '' AS custom_col,
  CAST(request_time AS DATE) AS time,
  'ads network' AS component
FROM (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d') AS request_time,
    auction__network_id AS network_id,
    CASE
      WHEN auction__integration_type = 'mkpl_partner_tag'
      THEN 'partner_tag'
      WHEN auction__integration_type <> 'mkpl_partner_tag'
      THEN 'prog_mod'
    END AS product_line,
    request__context__video_cro_network_id AS vcro_network_id,
    COUNT(*) AS costs
  FROM ${bcv_auction}
  GROUP BY
    1,
    2,
    3,
    4
)
