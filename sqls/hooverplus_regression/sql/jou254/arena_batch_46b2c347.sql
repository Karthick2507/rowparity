-- account:    jou254
-- skeleton:   8f822436909153d8413e3ebabfc865ab
-- pattern:    46b2c347f95c62f22f2dc6d569e6d9a5  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE(CURRENT_TIMESTAMP)
--   request__timestamp >= DATE(DATE_ADD(?, -?, CURRENT_TIMESTAMP))

WITH req AS (
  SELECT
    request__context__network_id,
    request__timestamp,
    request__traffic_type,
    CASE WHEN request__context__standard_brand_id IS NULL THEN 0 ELSE 1 END AS brand_detected_by_ads,
    CASE WHEN request__context__standard_channel_id IS NULL THEN 0 ELSE 1 END AS channel_detected_by_ads,
    CAST(JSON_PARSE(r.request_info) AS ROW(raw_brands ARRAY(VARCHAR), raw_channels ARRAY(VARCHAR))) AS ri
  FROM ${bcv_request} AS r
)
SELECT
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS event_date,
  COALESCE(request__context__network_id, -1) AS network_id,
  CASE
    WHEN pos_idx = 1
    THEN 'standard_content_brand'
    WHEN pos_idx = 2
    THEN 'standard_content_channel'
  END AS attribute_type,
  brand_channel AS attribute_name,
  COUNT(*) AS request_count
FROM req
CROSS JOIN UNNEST(ARRAY[ri.raw_brands, ri.raw_channels]) WITH ORDINALITY AS t(brands_channels, pos_idx)
CROSS JOIN UNNEST(brands_channels) AS u(brand_channel)
WHERE
  (
    (
      (
        request__traffic_type = 0 AND NOT request__context__network_id IN (524006)
      )
      AND NOT ri.raw_brands IS NULL
    )
    AND NOT ri.raw_channels IS NULL
  )
  AND (
    (
      pos_idx = 1 AND brand_detected_by_ads = 0
    )
    OR (
      pos_idx = 2 AND channel_detected_by_ads = 0
    )
  )
GROUP BY
  1,
  2,
  3,
  4
HAVING
  COUNT(*) > 100
