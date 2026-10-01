-- account:    sa-presto-tier2
-- skeleton:   f10defd9e35db690763544c703df2e47
-- pattern:    3877702888603ee711790297eabc3523  (1 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__site_section_id,
  COUNT_IF(request__is_first_request) AS requests,
  COUNT_IF(BITWISE_AND(request__extra_flags, 1024) > 0) AS linear_requests,
  COUNT_IF(BITWISE_AND(request__extra_flags, 33554432) > 0) AS stb_requests,
  COUNT_IF(BITWISE_AND(request__extra_flags, 67108864) > 0) AS ip_player_requests,
  COUNT_IF(NOT request__ifa_type IS NULL) AS has_ifa,
  COUNT_IF(NOT request__bidding_context__bid_request__device__ifa IS NULL) AS has_device_ifa
FROM ${bcv_request}
WHERE
  request__context__site_section_id IN (9437036, 15367719, 17489472, 22720033)
GROUP BY
  1
