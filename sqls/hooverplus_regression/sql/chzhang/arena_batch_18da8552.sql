-- account:    chzhang
-- skeleton:   511cf0a2701c09e7cfbb9125ff6bb9d0
-- pattern:    18da85527eda8928ad0880c66d3f612c  (115 execution(s))
-- in suite:   daily commitment
-- hoover:     candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? HOUR

SELECT
  f.eventtime AS __time,
  f.externalid,
  CAST(f.sellernetworkid AS VARCHAR) AS sellernetworkid
FROM (
  SELECT
    MIN(request__timestamp) AS eventtime,
    candidate__external_ad_id AS externalid,
    approval.network_id AS sellernetworkid
  FROM ${bcv_candidate}
  CROSS JOIN UNNEST(candidate__creative_approval_request__network_id, candidate__creative_approval_request__approval_type, candidate__creative_approval_request__approval_scope) AS approval(network_id, approval_type, approval_scope)
  WHERE
    (
      approval_type = 'global_approval' AND approval_scope = 'exchange'
    )
    AND CARDINALITY(candidate__creative_approval_request) > 0
  GROUP BY
    2,
    3
) AS f
