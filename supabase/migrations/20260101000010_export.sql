-- =============================================================================
-- 010 — Export read models  (slice step 7)
--
-- Inmore's current report is three columns: customer, item, price - one row per
-- ITEM, not per request. That shape is also the one Excel can pivot (product
-- demand, revenue per customer, items per supervisor), so the export widens it
-- rather than replacing it.
--
-- Two views for two sheets. Request-level money is deliberately NOT repeated
-- onto item rows: three items carrying the same request total means anyone who
-- sums that column gets triple the real figure, which is worse than no figure.
-- Line totals sum correctly on the Items sheet; request totals sum correctly on
-- the Requests sheet.
--
-- Both are money-bearing, so both are gated to OWNER / SUPERVISOR.
-- =============================================================================

-- Sheet 1: Items ---------------------------------------------------------------
create view v_export_items with (security_invoker = on) as
select r.number                      as request_number,
       r.created_at                  as request_date,
       c.name                        as customer,
       c.company                     as company,
       c.phone                       as phone,          -- export as TEXT: keeps the leading zero
       i.name                        as item,
       i.quantity                    as qty,
       i.unit                        as unit,
       i.specs                       as spec,
       ql.unit_price                 as unit_price,
       ql.line_total                 as line_total,
       i.status                      as item_status,
       r.status                      as request_status,
       r.waiting_on                  as waiting_on,
       e.full_name                   as supervisor,
       r.needed_by                   as needed_by,
       r.completed_at                as completed,
       -- not for the sheet; for filtering before export
       r.id                          as request_id,
       i.id                          as request_item_id,
       i.position                    as item_position
from request_items i
join requests  r on r.id = i.request_id
join customers c on c.id = r.customer_id
left join employees e on e.id = r.supervisor_id
-- the price from the approved quotation, if the item has been priced and agreed
left join lateral (
  select ql.unit_price, ql.line_total
    from quotation_lines ql
    join quotations q on q.id = ql.quotation_id
   where ql.request_item_id = i.id
     and q.status = 'APPROVED'
   order by q.version desc
   limit 1
) ql on true
where can_see_money();

comment on view v_export_items is
  'Excel sheet 1, one row per item. unit_price and line_total are null until an '
  'approved quotation covers the item - that is the honest state, not a zero.';

-- Sheet 2: Requests ------------------------------------------------------------
create view v_export_requests with (security_invoker = on) as
select r.number          as request_number,
       r.created_at      as request_date,
       c.name            as customer,
       e.full_name       as supervisor,
       r.status          as status,
       r.waiting_on      as waiting_on,
       (select count(*) from request_items i where i.request_id = r.id) as items,
       f.approved_total  as approved_total,
       f.paid_total      as paid,
       f.balance         as balance,
       f.approved_quotation_count,
       r.needed_by       as needed_by,
       r.completed_at    as completed,
       r.id              as request_id
from requests r
join customers c on c.id = r.customer_id
left join employees e on e.id = r.supervisor_id
left join v_request_financials f on f.request_id = r.id
where can_see_money();

comment on view v_export_requests is
  'Excel sheet 2, one row per request. This is where the money totals live, so '
  'that summing a column gives the real figure.';

grant select on v_export_items    to authenticated;
grant select on v_export_requests to authenticated;
