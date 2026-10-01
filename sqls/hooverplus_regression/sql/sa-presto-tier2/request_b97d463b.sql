-- account:    sa-presto-tier2
-- skeleton:   920359374e3f61a9edc2c937c115d750
-- pattern:    b97d463b8aa53371f8f8f57cab43adcb  (1 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request_event_date >= DATE_ADD(?, -?, CURRENT_DATE)

SELECT
  DATE_TRUNC('DAY', FROM_UNIXTIME(request_time)) AS day,
  COUNT(*) AS total_requests,
  SUM(CASE WHEN ad_delivery_status = 'filled' THEN 1 ELSE 0 END) AS filled,
  SUM(CASE WHEN ad_delivery_status <> 'filled' THEN 1 ELSE 0 END) AS unfilled,
  ROUND(
    100.0 * SUM(CASE WHEN ad_delivery_status = 'filled' THEN 1 ELSE 0 END) / COUNT(*),
    2
  ) AS fill_rate_pct
FROM ${bcv_request}
WHERE
  network_id = 530362
GROUP BY
  1
