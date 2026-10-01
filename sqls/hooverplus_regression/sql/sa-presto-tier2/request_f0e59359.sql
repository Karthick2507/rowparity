-- account:    sa-presto-tier2
-- skeleton:   38ea9ffe114949f34660fba5c0988804
-- pattern:    f0e59359d58386e5c87bccbee0612eb0  (3 execution(s))
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
  request__timestamp,
  CONCAT('t', request__transaction_id) AS transaction_id,
  request__context__network_id,
  request__bid_request__app_bundle,
  request__context__site_section_id,
  visitor__app_bundle_id,
  nt.name AS network_name,
  request__context__profile_id,
  prof.name AS profile_name,
  visitor__user_agent,
  visitor__device_type,
  visitor__user_agent_device_type,
  visitor__address,
  visitor__peer_address,
  visitor__referrer,
  visitor__filtration_reason,
  request__prebid_sivt__inhouse__is_whitelisted,
  request__prebid_sivt__inhouse__traffic_valid,
  request__prebid_sivt__inhouse__invalid_reason,
  request__prebid_sivt__whiteops__traffic_valid,
  request__prebid_sivt__whiteops__invalid_reason,
  COUNT(1) AS number_of_req
FROM ${bcv_request} AS r
LEFT JOIN oltp.fwmrm_oltp.network AS nt
  ON nt.id = request__context__network_id
LEFT JOIN oltp.fwmrm_oltp.ad_environment_compound_profile AS prof
  ON prof.id = request__context__profile_id
WHERE
  request__context__network_id IN (372496)
  AND request__context__site_section_id IN (23720059)
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21
