-- Rental handover, return, reschedule, and maintenance scheduling fields.
-- Run this migration in the Supabase SQL Editor before using the new screens.

alter table public.bookings
  add column if not exists "pickupAt" timestamptz,
  add column if not exists "returnAt" timestamptz,
  add column if not exists "checkoutNotes" text,
  add column if not exists "returnNotes" text,
  add column if not exists "returnCondition" text,
  add column if not exists "rescheduleStartDate" date,
  add column if not exists "rescheduleEndDate" date,
  add column if not exists "rescheduleReason" text,
  add column if not exists "rescheduleStatus" text,
  add column if not exists "reschedulePrice" numeric;

alter table public.items
  add column if not exists "lastMaintenanceDate" date,
  add column if not exists "nextMaintenanceDate" date,
  add column if not exists "maintenanceCost" numeric;

alter table public.bookings
  drop constraint if exists bookings_reschedule_dates_in_order;

alter table public.bookings
  add constraint bookings_reschedule_dates_in_order
  check (
    "rescheduleStartDate" is null
    or "rescheduleEndDate" is null
    or "rescheduleStartDate" <= "rescheduleEndDate"
  ) not valid;
