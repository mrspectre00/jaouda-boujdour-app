-- Create a function to allow administrators to reset user passwords
CREATE OR REPLACE FUNCTION admin_reset_password(user_id_param UUID, new_password_param TEXT)
RETURNS VOID AS $$
DECLARE
  calling_user_id UUID;
  is_admin BOOLEAN;
BEGIN
  -- Get the ID of the calling user
  calling_user_id := auth.uid();
  
  -- Check if the calling user is an admin
  SELECT is_management INTO is_admin
  FROM public.vendors
  WHERE user_id = calling_user_id;
  
  IF NOT is_admin THEN
    RAISE EXCEPTION 'Only administrators can reset passwords';
  END IF;
  
  -- Update the user's password
  UPDATE auth.users
  SET encrypted_password = crypt(new_password_param, gen_salt('bf')),
      raw_app_meta_data = jsonb_set(
        COALESCE(raw_app_meta_data, '{}'::jsonb),
        '{must_change_password}',
        'true'
      ),
      updated_at = now()
  WHERE id = user_id_param;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 