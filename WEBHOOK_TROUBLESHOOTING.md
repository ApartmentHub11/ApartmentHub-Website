# Webhook Troubleshooting Guide

If webhooks are not appearing in n8n, follow these steps:

## Common Issues and Solutions

### 1. Webhook URLs Not Active in n8n

**Problem:** Webhooks exist but are not receiving requests.

**Solution:**
- Go to your n8n workflow
- Make sure the webhook node is **Active** (not just saved)
- Check if the workflow itself is **Active**
- Verify the webhook URL matches exactly:
  - `https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link`
  - `https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active`

### 2. Webhook URLs Incorrect

**Problem:** Requests are being sent to wrong URLs.

**Check:**
```sql
-- Check webhook URLs in trigger functions
SELECT 
    routine_name,
    prosrc -- This shows the function source code
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname LIKE '%webhook%';
```

**Fix:** Update the URLs in the migration files if they're incorrect.

### 3. pg_net Extension Not Working

**Problem:** pg_net extension is not properly configured.

**Check:**
```sql
SELECT * FROM pg_extension WHERE extname = 'pg_net';
```

**Solution:**
- Enable pg_net in Supabase Dashboard → Database → Extensions
- Or use Supabase Edge Functions as an alternative

### 4. Network/Firewall Issues

**Problem:** Supabase cannot reach n8n webhook endpoints.

**Test:**
Run the diagnostic script to see if requests are being sent:
```sql
\i diagnose-webhooks.sql
```

**Solution:**
- Check Supabase project settings for network restrictions
- Verify n8n webhook endpoints are publicly accessible
- Test webhook URLs manually with curl:
  ```bash
  curl -X POST https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link \
    -H "Content-Type: application/json" \
    -d '{"test": true}'
  ```

### 5. Webhook Endpoints Not Listening

**Problem:** n8n webhooks are not configured to receive POST requests.

**Solution:**
- In n8n, check webhook node settings:
  - HTTP Method should be `POST`
  - Path should match: `/webhook/trigger-status-change-create-link` or `/webhook/trigger-status-change-active`
  - Response Mode should be set appropriately

### 6. Silent Failures

**Problem:** Webhooks fail silently without errors.

**Check:**
- Look at Supabase logs for warnings:
  ```sql
  -- Check for webhook warnings in logs
  -- (This depends on your Supabase plan and logging setup)
  ```
- Check n8n execution logs for failed requests
- Verify webhook payload structure matches what n8n expects

## Step-by-Step Verification

### Step 1: Verify Webhook URLs in n8n

1. Open your n8n workflow
2. Click on the webhook node
3. Copy the webhook URL
4. Compare with:
   - `https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link`
   - `https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active`

### Step 2: Test Webhook Manually

Use curl or Postman to test the webhook directly:

```bash
curl -X POST \
  https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link \
  -H "Content-Type: application/json" \
  -d '{
    "test": true,
    "timestamp": "2026-02-18T12:00:00Z"
  }'
```

If this works, the webhook endpoint is fine, and the issue is with Supabase → n8n communication.

### Step 3: Check Supabase Logs

1. Go to Supabase Dashboard → Logs
2. Look for webhook-related errors or warnings
3. Check for "Webhook call failed" messages

### Step 4: Verify Trigger Functions

Run this query to see the actual webhook URLs in your functions:

```sql
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname LIKE '%webhook%';
```

Look for the webhook URLs in the function definitions.

### Step 5: Test with Diagnostic Script

Run the diagnostic script:

```sql
\i diagnose-webhooks.sql
```

This will:
- Check pg_net status
- Test webhook endpoints directly
- Trigger database triggers manually
- Show request history (if available)

## Alternative: Use Supabase Edge Functions

If pg_net continues to have issues, you can use Supabase Edge Functions:

1. Create an Edge Function that calls the webhook
2. Call the Edge Function from the database trigger
3. Edge Functions have better network access and error handling

## Quick Test Commands

### Test Webhook Endpoint Directly:
```sql
SELECT net.http_post(
    url := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{"test": true}'::text
);
```

### Trigger Accounts Tags Webhook:
```sql
UPDATE public.accounts
SET tags = ARRAY['test-tag']
WHERE id = (SELECT id FROM public.accounts LIMIT 1);
```

### Trigger Apartment CreateLink Webhook:
```sql
UPDATE public.apartments
SET status = 'CreateLink'
WHERE id = (SELECT id FROM public.apartments LIMIT 1);
```

### Trigger Apartment Active Webhook:
```sql
UPDATE public.apartments
SET status = 'Active'
WHERE id = (SELECT id FROM public.apartments LIMIT 1);
```

## Still Not Working?

1. **Check n8n webhook node settings:**
   - Is it set to "Listen for Webhooks"?
   - Is the workflow Active?
   - Is the webhook path correct?

2. **Check Supabase project settings:**
   - Are there any network restrictions?
   - Is pg_net extension enabled?
   - Check project logs for errors

3. **Contact Support:**
   - Supabase support for database/webhook issues
   - n8n support for webhook endpoint issues
