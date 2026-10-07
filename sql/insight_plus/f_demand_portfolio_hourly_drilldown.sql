/* Drilldown query for f_demand_portfolio_hourly case */
/* Investigates a specific ad_id across batch and detailed ad data */

select
    ad_id,
    event_date,
    process_batch_id,
    process_stage,
    market_ad_id,
    creative_id,
    placement_id,
    deal_id,
    dsp_id,
    buyer_group_id,
    network_id,
    content_owner_id,
    distributor_id,
    reseller_id,
    supply_source,
    sales_channel,
    slot_user_drop_off,
    request_fill_status,
    slot_fill_status,
    inbound_order_id,
    outbound_order_id,
    request_traffic_type,
    ack_traffic_type,
    partition_key,
    count(*) as row_count,
    sum(coalesce(requests_count, 0)) as total_requests,
    sum(coalesce(impressions_count, 0)) as total_impressions
from ${facts}.ad_detail
where
    ad_id = ${bind}
    and event_date = cast(${time.param} as date)
    and process_batch_id = ${time.param}
    and (${sampling_filter})
group by
    ad_id,
    event_date,
    process_batch_id,
    process_stage,
    market_ad_id,
    creative_id,
    placement_id,
    deal_id,
    dsp_id,
    buyer_group_id,
    network_id,
    content_owner_id,
    distributor_id,
    reseller_id,
    supply_source,
    sales_channel,
    slot_user_drop_off,
    request_fill_status,
    slot_fill_status,
    inbound_order_id,
    outbound_order_id,
    request_traffic_type,
    ack_traffic_type,
    partition_key
order by
    process_batch_id desc,
    process_stage,
    event_date desc
