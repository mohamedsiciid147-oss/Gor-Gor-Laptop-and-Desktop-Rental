-- Run this migration in the Supabase SQL editor before deploying the update.
-- It makes the final availability check atomic, so simultaneous booking requests
-- cannot reserve the same item and dates.

-- Existing records are preserved.  NOT VALID means this rule applies to every
-- new or edited booking without failing because of any old, malformed data.
alter table public.bookings
  drop constraint if exists bookings_dates_in_order;

alter table public.bookings
  add constraint bookings_dates_in_order
  check ("startDate"::date <= "endDate"::date) not valid;

-- Keeps the availability lookup and the overlap trigger fast as bookings grow.
create index if not exists bookings_item_dates_idx
  on public.bookings ("itemId", "startDate", "endDate");

create or replace function public.prevent_overlapping_bookings()
returns trigger
language plpgsql
as $$
begin
  if lower(coalesce(new."status", 'pending')) in ('pending', 'confirmed') and exists (
    select 1
    from public.bookings existing
    where existing."itemId" = new."itemId"
      and existing.id is distinct from new.id
      and lower(coalesce(existing."status", 'pending')) in ('pending', 'confirmed')
      and daterange(
        existing."startDate"::date,
        existing."endDate"::date,
        '[]'
      ) && daterange(new."startDate"::date, new."endDate"::date, '[]')
  ) then
    raise exception 'This item is already booked for one or more selected dates';
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_prevent_overlap on public.bookings;

create trigger bookings_prevent_overlap
before insert or update of "itemId", "startDate", "endDate", "status"
on public.bookings
for each row
execute function public.prevent_overlapping_bookings();

comment on function public.prevent_overlapping_bookings() is
  'Rejects overlapping Pending or Confirmed rentals for the same item.';
