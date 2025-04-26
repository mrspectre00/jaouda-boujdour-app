-- Create a secure function to delete vendors
-- This function has higher privileges than regular RLS (security definer)
-- and can bypass some constraints

create or replace function delete_vendor(vendor_id uuid)
returns void 
language sql 
security definer  -- Runs with privileges of the function creator (DB admin)
as $$
  -- First reassign any related data to the system account
  UPDATE markets SET vendor_id = '00000000-0000-0000-0000-000000000001'
  WHERE vendor_id = vendor_id;
  
  UPDATE sales SET vendor_id = '00000000-0000-0000-0000-000000000001'
  WHERE vendor_id = vendor_id;
  
  -- Then delete the vendor
  DELETE FROM vendors WHERE id = vendor_id;
$$; 