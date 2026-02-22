-- Fix: Alter current_bookings from text[] to jsonb
-- Run this in Supabase SQL Editor if you get "column is of type text[] but expression is of type jsonb"

ALTER TABLE public.accounts
ALTER COLUMN current_bookings TYPE jsonb USING '[]'::jsonb;

ALTER TABLE public.accounts
ALTER COLUMN current_bookings SET DEFAULT '[]'::jsonb;
