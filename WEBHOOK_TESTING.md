# Webhook Testing Guide

This guide explains how to test the webhook triggers that have been set up.

## Webhooks Created

1. **Accounts Tags Webhook**
   - Triggers when `accounts.tags` column changes
   - URL: `https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link`

2. **Apartment CreateLink Webhook**
   - Triggers when apartment `status` changes to `'CreateLink'`
   - URL: `https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link`
   - Sends: All apartment table data

3. **Apartment Active Webhook**
   - Triggers when apartment `status` changes to `'Active'`
   - URL: `https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active`
   - Sends: All apartment data + matched tenants based on tags

## Prerequisites

1. Ensure all migrations have been applied:
   - `20260218130000_update_accounts_documentation_status.sql`
   - `20260218140000_accounts_tags_webhook.sql`
   - `20260218150000_apartment_status_active_webhook.sql` (CreateLink)
   - `20260218160000_apartment_status_active_webhook.sql` (Active)

2. Verify `pg_net` extension is enabled:
   ```sql
   SELECT * FROM pg_extension WHERE extname = 'pg_net';
   ```

3. If `pg_net` is not available, enable it in Supabase Dashboard:
   - Go to Database → Extensions
   - Search for "pg_net"
   - Enable it

## Testing Methods

### Method 1: Using SQL Test Script

Run the test script in Supabase SQL Editor:

```bash
# Run the comprehensive test script
psql -f supabase/migrations/test_webhooks.sql

# Or run the simple test script
psql -f test-webhooks-simple.sql
```

### Method 2: Manual Testing via Supabase SQL Editor

#### Test Accounts Tags Webhook:

```sql
-- Update tags on an existing account
UPDATE public.accounts
SET tags = ARRAY['test-tag-1', 'test-tag-2']
WHERE id = 'your-account-id-here'
RETURNING id, tenant_name, tags;
```

#### Test Apartment CreateLink Webhook:

```sql
-- Change apartment status to CreateLink
UPDATE public.apartments
SET status = 'CreateLink'
WHERE id = 'your-apartment-id-here'
RETURNING id, name, status;
```

#### Test Apartment Active Webhook:

```sql
-- First, ensure tags match between apartment and accounts
UPDATE public.apartments
SET tags = ARRAY['matching-tag']
WHERE id = 'your-apartment-id-here';

UPDATE public.accounts
SET tags = ARRAY['matching-tag']
WHERE id = 'your-account-id-here';

-- Then change status to Active
UPDATE public.apartments
SET status = 'Active'
WHERE id = 'your-apartment-id-here'
RETURNING id, name, status, tags;
```

### Method 3: Using Supabase Dashboard

1. Go to Supabase Dashboard → Table Editor
2. Select the `accounts` or `apartments` table
3. Update a record:
   - For accounts: Change the `tags` column
   - For apartments: Change the `status` column to `'CreateLink'` or `'Active'`
4. Check your webhook endpoint to see if it received the request

## Verifying Webhook Calls

### Check Trigger Status

```sql
SELECT 
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE trigger_name LIKE '%webhook%'
ORDER BY trigger_name;
```

### Check Function Status

```sql
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%webhook%'
ORDER BY routine_name;
```

### Check pg_net Request History (if available)

```sql
SELECT 
    id,
    url,
    method,
    status_code,
    created_at
FROM net.http_request_queue
ORDER BY created_at DESC
LIMIT 10;
```

## Troubleshooting

### Webhooks Not Triggering

1. **Check if triggers exist:**
   ```sql
   SELECT * FROM information_schema.triggers 
   WHERE trigger_name LIKE '%webhook%';
   ```

2. **Check if pg_net extension is enabled:**
   ```sql
   SELECT * FROM pg_extension WHERE extname = 'pg_net';
   ```

3. **Check function errors:**
   - Look for warnings in Supabase logs
   - Check if webhook URL is accessible
   - Verify network/firewall allows outbound HTTP requests

4. **Test webhook function manually:**
   ```sql
   -- Test the webhook function directly
   SELECT net.http_post(
       url := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link',
       headers := jsonb_build_object('Content-Type', 'application/json'),
       body := '{"test": "data"}'::text
   );
   ```

### Webhooks Triggering But Not Receiving Data

1. Check webhook endpoint logs in n8n
2. Verify the payload structure matches what your endpoint expects
3. Check if webhook endpoint is publicly accessible
4. Verify Content-Type headers are correct

### pg_net Extension Not Available

If `pg_net` is not available in your Supabase instance:

1. **Option 1:** Enable it via Supabase Dashboard
   - Database → Extensions → Search "pg_net" → Enable

2. **Option 2:** Use Supabase Edge Functions
   - Create an Edge Function that calls the webhook
   - Call the Edge Function from the trigger using `pg_net` or `http` extension

3. **Option 3:** Use `http` extension (if available)
   - Modify the trigger functions to use `http` extension instead

## Expected Payloads

### Accounts Tags Webhook Payload:

```json
{
  "event_type": "UPDATE",
  "account_id": "uuid",
  "tenant_name": "John Doe",
  "whatsapp_number": "+31612345678",
  "email": "john@example.com",
  "tags": ["tag1", "tag2"],
  "old_tags": ["old-tag1"],
  "timestamp": "2026-02-18T...",
  "salesforce_account_id": "..."
}
```

### Apartment CreateLink Webhook Payload:

```json
{
  "id": "uuid",
  "name": "Apartment Name",
  "street": "...",
  "area": "...",
  "full_address": "...",
  "zip_code": "...",
  "rental_price": 1500,
  "bedrooms": "2",
  "square_meters": 75,
  "tags": ["tag1", "tag2"],
  "status": "CreateLink",
  "event_link": "...",
  "booking_details": {},
  "slot_dates": [],
  "salesforce_id": "...",
  "additional_notes": "...",
  "real_estate_agent_id": "uuid",
  "real_estate_agent": {...},
  "viewing_participants": [],
  "viewing_cancellations": [],
  "booking_reschedules": [],
  "apartmenthub_agents": [],
  "people_making_offer": [],
  "offers_in": [],
  "offers_sent": [],
  "created_at": "...",
  "updated_at": "...",
  "timestamp": "..."
}
```

### Apartment Active Webhook Payload:

```json
{
  "event_type": "apartment_status_active",
  "apartment": {
    "id": "uuid",
    "name": "Apartment Name",
    "tags": ["tag1", "tag2"],
    ...
  },
  "matched_tenants": [
    {
      "account_id": "uuid",
      "tenant_name": "John Doe",
      "tags": ["tag1"],
      "whatsapp_number": "+31612345678",
      ...
    }
  ],
  "matched_tenants_count": 1,
  "timestamp": "..."
}
```

## Next Steps

After testing:

1. Monitor webhook endpoints in n8n for incoming requests
2. Verify payload structure matches expectations
3. Check for any errors in webhook processing
4. Set up monitoring/alerting for webhook failures
