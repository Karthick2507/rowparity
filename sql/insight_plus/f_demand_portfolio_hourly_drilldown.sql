-- Drill-down: which request__transaction_id sit behind one differing row.
--
-- The parity query is a GROUP BY over 83 dimensions, so every per-request
-- identifier is collapsed by the aggregation -- one output row summarises many
-- requests, and there is no single transaction id to report. This is the query
-- that recovers them, run once per side for one differing row.
--
-- Three placeholders, filled in by rowparity:
--
--   facts        the side's catalog+schema, from that side's vars:
--   row_filter   the differing row's predicate (creative_id only, by
--                decision -- see the case file)
--   time_filter  the side's time/batch window
--
-- (Named without the dollar-brace above on purpose: params.py substitutes
-- text, not SQL, so a placeholder written out inside a comment is a real
-- substitution site. Documenting one that way silently rewrites the comment.)
--
-- The time filter is deliberately ASYMMETRIC and that is the point. Hoover++ is
-- pinned to the one hour the parity row claims; Hoover is searched over a
-- wider window, because "the event_date shifted between the two layouts" is
-- the hypothesis under test. Pinning both sides to the same hour would assume
-- the answer and return nothing.
--
-- The sampling filter is NOT applied here. This query is looking for specific
-- transactions behind one already-identified row; excluding 511/512 of them
-- would usually return nothing and read as "the row does not exist".

select
    request__transaction_id,
    nw.nw_id                                                              as network_id,
    nw.reseller_id                                                        as reseller_id,
    nw.site_id                                                            as site_id,
    coalesce(visitor__country_id, -1)                                     as user_country_id,
    if(deal_awareability, coalesce(candidate__internal_deal_id, -1), -1)  as deal_id,
    if(network_is_ad_owner, coalesce(advertisement__ad_id, -1), -1)       as ad_id,
    if(network_is_ad_owner, coalesce(advertisement__creative_id, -1), -1) as creative_id,
    date_trunc('HOUR', cast(ack__timestamp as timestamp))                 as event_date,
    process_batch_id,
    count(*)                                                              as n
from ${facts}.ack
cross join unnest (
    partners__network_id,
    partners__site_id,
    partners__site_section_id,
    partners__distributor_network_id,
    partners__content_owner_network_id,
    partners__reseller_network_id,
    partners__sales_channel,
    partners__role,
    partners__supply_source,
    partners__geo_country_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate,
    partners__standard_channel_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__content_form_visibility__report_aggregate,
    partners__global_currency_id,
    partners__network_is_extra_item_owner,
    partners__demand_dim_awareability,
    partners__deal_awareability,
    partners__outbound_order_id,
    partners__outbound_exchange_order_id,
    partners__outbound_listing_id,
    partners__inbound_order_id,
    partners__inbound_order_type,
    partners__inbound_order_transaction_type,
    partners__unified_outbound_order_priority__priority_tier,
    partners__unified_outbound_order_priority__sub_priority_value,
    partners__outbound_order_priority_type,
    partners__unified_rule_priority__priority_tier,
    partners__unified_rule_priority__sub_priority_value,
    partners__rule_type_priority,
    partners__network_is_ad_owner,
    partners__revenue,
    partners__content_owner_revenue,
    partners__reseller_revenue,
    partners__distributor_revenue,
    partners__bit_flags
) as nw (
    nw_id,
    site_id,
    site_section_id,
    distributor_id,
    co_id,
    reseller_id,
    sales_channel,
    nw_role,
    supply_source,
    country_visibility,
    sa_brand_visibility,
    sa_channel_visibility,
    sa_programmer_visibility,
    sa_endpoint_visibility,
    sa_endpoint_owner_visibility,
    user_agent_visibility,
    content_form_visibility,
    global_currency_id,
    is_extra_item_owner,
    demand_dim_awareability,
    deal_awareability,
    outbound_order_id,
    outbound_exchange_order_id,
    outbound_listing_id,
    inbound_order_id,
    inbound_order_type,
    inbound_order_transaction_type,
    order_priority_tier,
    outbound_order_priority_value,
    order_priority,
    rule_priority_tier,
    rule_priority_value,
    rule_priority,
    network_is_ad_owner,
    revenue,
    content_owner_revenue,
    reseller_revenue,
    distributor_revenue,
    bit_flag
)
left join db.default.d_network reseller on reseller.id = coalesce(nw.reseller_id, -1)
where
    ${time_filter}
    -- The differing row. Only creative_id is bound, by decision: adding the
    -- other dimensions narrows the result but risks excluding the very rows
    -- whose dimensions drifted, which is what is being looked for.
    and ${row_filter}
    -- Below: the branch predicates, copied verbatim from the parity query.
    -- They must stay identical or this looks at a different population than
    -- the row it is supposed to explain.
    and bitwise_and(slot__flags, 64) = 0                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')
    and coalesce(advertisement__is_bumper, false) = false                   -- Remove Bumper Ad
    and supply_source != 4                                                  -- filter out DSP shell networks
    and not(bitwise_and(coalesce(request__extra_flags2, 0), 8) > 0 and coalesce(nw.nw_role, '') = 'CRO')  -- filter out SSP shell networks
    and bitwise_and(bit_flag, bitwise_shift_left(1, 41, 64)) = 0            -- filter out partner tag buyer
    and (coalesce(ack__ack_entity_type, '') = 'ad'
        or (ack__event_type = 'e' and ack__event_category in ('ad_manager_error', 'vast_error')))
    and (ack__is_private_impression = false or network_is_ad_owner = true or is_extra_item_owner = true)
group by 1,2,3,4,5,6,7,8,9,10
order by 1
