# Vendor Deletion Fix Guide

## Problem

When attempting to delete a vendor, the system shows the error:
```
Cannot delete test vendor: this vendor has related data (sales, markets, etc.) that must be deleted first
```

However, even after implementing data reassignment to handle these dependencies, the deletion still fails with no specific error message. The DELETE query appears to be running but affecting 0 rows.

## Root Causes

After investigation, we found several potential issues:

1. **Foreign Key Constraints**: Some vendor records have foreign key relationships with other tables, preventing deletion until those references are removed.

2. **RLS Policies**: Row-Level Security policies in Supabase may be preventing the deletion of certain vendors.

3. **Auth/Database Separation**: Vendor accounts exist in both the Auth system and the database, but deletion was only targeting the database record.

4. **Special System Accounts**: Some vendors (like the default system account) should not be deletable.

## Solution

We've implemented a comprehensive solution:

1. **Data Reassignment**: Before deletion, all related data (markets, sales, etc.) is reassigned to a system default account.

2. **Special Account Protection**: Special system accounts (using UUID starting with zeros) are protected from deletion.

3. **SQL Function**: A secure database function with elevated privileges has been created to handle deletions that might be blocked by RLS policies.

4. **Improved Error Handling**: Detailed error messages now show exactly why a deletion failed, making troubleshooting easier.

5. **Fallback Mechanism**: If standard deletion fails, the app now attempts an RPC call to a specialized function.

## How to Apply the Fix

1. Run the SQL function creation script in the Supabase dashboard:
   - Go to the SQL Editor in your Supabase dashboard
   - Copy and paste the contents of `supabase/migrations/20230522000001_create_delete_vendor_function.sql`
   - Execute the query

2. The vendor deletion code in the app has already been updated to use this new function when standard deletion fails.

## For Manual Deletion

To manually delete a problematic vendor from Supabase:

1. First reassign any related data:
```sql
-- Reassign markets
UPDATE markets 
SET vendor_id = '00000000-0000-0000-0000-000000000001'
WHERE vendor_id = 'PROBLEM_VENDOR_ID';

-- Reassign sales
UPDATE sales 
SET vendor_id = '00000000-0000-0000-0000-000000000001'
WHERE vendor_id = 'PROBLEM_VENDOR_ID';
```

2. Delete the vendor using the function:
```sql
SELECT delete_vendor('PROBLEM_VENDOR_ID');
```

3. If the vendor also exists in the auth system, you'll need to delete them from there as well using the Supabase dashboard or API.

## Future Improvements

For a more robust solution in the future, consider:

1. Creating an edge function that can delete from both Auth and Database
2. Adding transaction support for all related operations
3. Implementing soft deletion instead of hard deletion
4. Adding an audit trail for all deletions 