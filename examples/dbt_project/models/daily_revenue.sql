{{ config(materialized='table') }}

select
    day,
    region,
    sum(amount) as revenue,
    count(*) as orders
from {{ ref('raw_orders') }}
group by day, region
