-- Jaouda Boujdour App - Data Seeder
-- This script adds test data to your database for development and testing

-- Clear existing data if needed (uncomment if you want to start fresh)
-- DELETE FROM public.sales;
-- DELETE FROM public.markets WHERE id != '00000000-0000-0000-0000-000000000001';
-- DELETE FROM public.products;
-- DELETE FROM public.promotions;
-- DELETE FROM public.vendors WHERE is_management != true;
-- DELETE FROM public.regions WHERE id != '00000000-0000-0000-0000-000000000001';

-- Add regions
INSERT INTO public.regions (id, name, country)
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Test Region', 'Morocco'),
  ('00000000-0000-0000-0000-000000000002', 'Boujdour', 'Morocco'),
  ('00000000-0000-0000-0000-000000000003', 'Laayoune', 'Morocco'),
  ('00000000-0000-0000-0000-000000000004', 'Dakhla', 'Morocco')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  country = EXCLUDED.country;

-- Add test vendor if not exists (assuming there's a test user in auth.users)
-- Note: Replace 'auth-user-id-here' with an actual user ID from your auth.users table
DO $$
DECLARE
  user_id UUID;
BEGIN
  -- Try to get a user ID from auth.users
  BEGIN
    SELECT id INTO user_id FROM auth.users LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    user_id := NULL;
  END;

  -- Insert test vendor if we have a user ID
  IF user_id IS NOT NULL THEN
    INSERT INTO public.vendors (id, name, email, region_id, user_id, is_management)
    VALUES (
      '00000000-0000-0000-0000-000000000001',
      'Test Vendor',
      'testvendor@jaouda.com',
      '00000000-0000-0000-0000-000000000001',
      user_id,
      true
    )
    ON CONFLICT (email) DO NOTHING;
  END IF;
END $$;

-- Add test products
INSERT INTO public.products (id, name, description, price, stock_quantity, category, status)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Milk', 'Fresh cow milk', 10.50, 100, 'Dairy', 'active'),
  ('00000000-0000-0000-0000-000000000002', 'Yogurt', 'Natural yogurt', 5.25, 200, 'Dairy', 'active'),
  ('00000000-0000-0000-0000-000000000003', 'Cheese', 'Gouda cheese', 25.00, 50, 'Dairy', 'active'),
  ('00000000-0000-0000-0000-000000000004', 'Butter', 'Salted butter', 15.75, 75, 'Dairy', 'active')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  stock_quantity = EXCLUDED.stock_quantity,
  category = EXCLUDED.category,
  status = EXCLUDED.status;

-- Add promotions
INSERT INTO public.promotions (id, name, description, discount_percentage, start_date, end_date, product_id, is_active)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Summer Sale', 'Summer discount on milk', 10.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days', '00000000-0000-0000-0000-000000000001', true),
  ('00000000-0000-0000-0000-000000000002', 'Yogurt Special', 'Special discount on yogurt', 15.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '15 days', '00000000-0000-0000-0000-000000000002', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  discount_percentage = EXCLUDED.discount_percentage,
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  product_id = EXCLUDED.product_id,
  is_active = EXCLUDED.is_active;

-- Add test markets
INSERT INTO public.markets (id, name, address, gps_location, region_id, status, notes)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Central Market', '123 Main St, Boujdour', ST_SetSRID(ST_MakePoint(-14.4956, 26.1224), 4326), '00000000-0000-0000-0000-000000000002', 'active', 'Main market in Boujdour'),
  ('00000000-0000-0000-0000-000000000002', 'Corner Shop', '45 Side St, Boujdour', ST_SetSRID(ST_MakePoint(-14.4876, 26.1192), 4326), '00000000-0000-0000-0000-000000000002', 'active', 'Small corner shop'),
  ('00000000-0000-0000-0000-000000000003', 'Laayoune Market', '78 Center Ave, Laayoune', ST_SetSRID(ST_MakePoint(-13.2033, 27.1544), 4326), '00000000-0000-0000-0000-000000000003', 'active', 'Main market in Laayoune')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  address = EXCLUDED.address,
  gps_location = EXCLUDED.gps_location,
  region_id = EXCLUDED.region_id,
  status = EXCLUDED.status,
  notes = EXCLUDED.notes;

-- Add sales data (only if there's at least one vendor)
DO $$
DECLARE
  vendor_id UUID;
BEGIN
  -- Try to get a vendor ID
  SELECT id INTO vendor_id FROM public.vendors LIMIT 1;
  
  -- Only proceed if we have a vendor
  IF vendor_id IS NOT NULL THEN
    -- Insert sales for today
    INSERT INTO public.sales (
      id, market_id, product_id, vendor_id, quantity, unit_price, total, discount, promotion_id, payment_method, notes
    )
    VALUES
      ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', vendor_id, 5, 10.50, 52.50, 0, NULL, 'cash', 'Morning sale'),
      ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', vendor_id, 10, 5.25, 52.50, 0, NULL, 'cash', NULL),
      ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', vendor_id, 2, 25.00, 50.00, 0, NULL, 'cash', NULL),
      ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', vendor_id, 8, 10.50, 84.00, 0, NULL, 'cash', 'Bulk purchase')
    ON CONFLICT (id) DO NOTHING;
    
    -- Insert sales for yesterday
    INSERT INTO public.sales (
      id, market_id, product_id, vendor_id, quantity, unit_price, total, discount, promotion_id, payment_method, notes, created_at
    )
    VALUES
      ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', vendor_id, 3, 10.50, 31.50, 0, NULL, 'cash', NULL, CURRENT_TIMESTAMP - INTERVAL '1 day'),
      ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', vendor_id, 4, 15.75, 63.00, 0, NULL, 'cash', NULL, CURRENT_TIMESTAMP - INTERVAL '1 day')
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$; 