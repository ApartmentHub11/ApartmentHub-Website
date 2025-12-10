# Supabase Integration Setup Guide

## Current Status: ✅ Connection Verified, ⚠️ Table Missing

### Test Results

**✅ Successful Tests:**
- Environment variables are correctly configured
- Supabase client initializes successfully
- Database connection is working

**⚠️ Issues Found:**
- The `rental_leads` table does not exist in your Supabase database

---

## Setup Instructions

### Step 1: Create the Database Table

You need to run the SQL schema in your Supabase dashboard:

1. Open your Supabase dashboard: [https://vordjtqtqrzvqvuzogop.supabase.co/project/_/editor](https://vordjtqtqrzvqvuzogop.supabase.co/project/_/editor)

2. Navigate to **SQL Editor** in the left sidebar

3. Click **New Query**

4. Copy the contents of `supabase-schema.sql` and paste it into the query editor

5. Click **Run** to execute the SQL

### Step 2: Verify Table Creation

After running the SQL, you should see:
- A new table called `rental_leads` in your database
- Row Level Security (RLS) policies that allow:
  - Anonymous users to INSERT new leads (for the public form)
  - Authenticated users to READ and UPDATE leads (for CRM access)

### Step 3: Re-run Tests

Once the table is created, run the test script again:

```bash
node test-supabase.js
```

All tests should now pass! ✅

---

## What the Schema Includes

### Table: `rental_leads`

**Columns:**
- `id` - UUID primary key (auto-generated)
- `created_at` - Timestamp when the lead was created
- `updated_at` - Timestamp when the lead was last updated (auto-updated)
- `address` - Property address
- `postal_code` - Postal code
- `square_meters` - Property size in m²
- `rooms` - Number of rooms
- `interior` - Interior condition (shell, unfurnished, partlyFurnished, furnished)
- `condition` - Property condition (brandNew, average, belowAverage)
- `full_name` - Contact full name
- `email` - Contact email address
- `phone` - Contact phone number
- `estimated_rent` - Calculated rental price (EUR/month)
- `status` - Lead status for CRM (new, contacted, qualified, converted, closed)
- `notes` - Additional notes

**Features:**
- ✨ Automatic UUID generation for IDs
- ✨ Automatic timestamp management
- ✨ Data validation with CHECK constraints
- ✨ Optimized indexes for fast queries
- ✨ Row Level Security for data protection
- ✨ Anonymous insert capability for public forms

---

## Testing the Integration

### Automated Test
Run the test script to verify all components:
```bash
node test-supabase.js
```

### Manual Test via UI
1. Navigate to [http://localhost:5173](http://localhost:5173)
2. Fill out the Rental Calculator form
3. Submit the form
4. Check your Supabase dashboard → Table Editor → `rental_leads`
5. You should see the new entry!

---

## Next Steps

After the table is created:
1. ✅ Test the form submission on your website
2. ✅ Verify data appears in Supabase dashboard
3. ✅ Set up email notifications (optional)
4. ✅ Connect to your CRM system (optional)

---

## Troubleshooting

### Issue: "Permission denied" errors
**Solution:** Make sure RLS policies are set up correctly. The SQL script creates policies that allow anonymous inserts.

### Issue: "Table not found" errors
**Solution:** Run the `supabase-schema.sql` script in your Supabase SQL Editor.

### Issue: Form submits but data doesn't save
**Solution:** Check browser console for errors and verify environment variables are set correctly.

---

## Files Created
- `test-supabase.js` - Automated test script
- `supabase-schema.sql` - Database schema and setup
- This guide - Setup instructions
