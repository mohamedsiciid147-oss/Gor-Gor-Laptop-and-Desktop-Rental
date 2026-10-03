-- Run this after the booking migration in Supabase SQL Editor.
alter table public.items add column if not exists "serialNumber" text;
alter table public.items add column if not exists "operationalStatus" text not null default 'Available';
alter table public.items add column if not exists "maintenanceNotes" text;

alter table public.items drop constraint if exists items_operational_status_valid;
alter table public.items add constraint items_operational_status_valid
  check ("operationalStatus" in ('Available', 'Maintenance', 'Damaged', 'Retired')) not valid;

create unique index if not exists items_serial_number_unique
  on public.items ("serialNumber") where "serialNumber" is not null and "serialNumber" <> '';
