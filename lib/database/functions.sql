-- Jaouda Boujdour App - Database Functions
-- This file contains SQL functions used by the application

-- Enable PostGIS extension if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- Function to get all markets with coordinates
CREATE OR REPLACE FUNCTION get_all_markets_with_coords()
RETURNS TABLE (
  id UUID,
  name TEXT,
  address TEXT,
  gps_location_text TEXT,
  region_id UUID,
  vendor_id UUID,
  status TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL
AS $$
  SELECT 
    id, name, address, 
    ST_AsText(gps_location) as gps_location_text,
    region_id, vendor_id, status, notes, 
    created_at, updated_at
  FROM 
    markets
  ORDER BY
    name;
$$;

-- Function to get markets in a specific region with coordinates
CREATE OR REPLACE FUNCTION get_region_markets_with_coords(region_uuid UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  address TEXT,
  gps_location_text TEXT,
  region_id UUID,
  vendor_id UUID,
  status TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL
AS $$
  SELECT 
    id, name, address, 
    ST_AsText(gps_location) as gps_location_text,
    region_id, vendor_id, status, notes, 
    created_at, updated_at
  FROM 
    markets
  WHERE
    region_id = region_uuid
  ORDER BY
    name;
$$;

-- Function to get a specific market with coordinates
CREATE OR REPLACE FUNCTION get_market_with_coords(market_uuid UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  address TEXT,
  gps_location_text TEXT,
  region_id UUID,
  vendor_id UUID,
  status TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL
AS $$
  SELECT 
    id, name, address, 
    ST_AsText(gps_location) as gps_location_text,
    region_id, vendor_id, status, notes, 
    created_at, updated_at
  FROM 
    markets
  WHERE
    id = market_uuid;
$$;

-- Function to insert a market with location
CREATE OR REPLACE FUNCTION insert_market_with_location(
  market_id UUID,
  market_name TEXT,
  market_address TEXT,
  longitude FLOAT,
  latitude FLOAT,
  region_id UUID,
  vendor_id UUID DEFAULT NULL,
  status TEXT DEFAULT 'pending_review',
  notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  inserted_id UUID;
BEGIN
  INSERT INTO markets (
    id, name, address, gps_location, region_id, vendor_id, status, notes
  )
  VALUES (
    market_id,
    market_name,
    market_address,
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326),
    region_id,
    vendor_id,
    status,
    notes
  )
  RETURNING id INTO inserted_id;
  
  RETURN inserted_id;
END;
$$;

-- Function to find markets within a radius
CREATE OR REPLACE FUNCTION find_markets_within_radius(
  latitude FLOAT,
  longitude FLOAT,
  radius_meters FLOAT
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  address TEXT,
  distance_meters FLOAT,
  region_id UUID,
  status TEXT
)
LANGUAGE SQL
AS $$
  SELECT 
    m.id, 
    m.name, 
    m.address,
    ST_Distance(
      m.gps_location::geography,
      ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
    ) as distance_meters,
    m.region_id,
    m.status
  FROM 
    markets m
  WHERE 
    ST_DWithin(
      m.gps_location::geography,
      ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
      radius_meters
    )
  ORDER BY 
    distance_meters ASC;
$$;

-- Function to get sales statistics by region
CREATE OR REPLACE FUNCTION get_sales_stats_by_region(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
  region_id UUID,
  region_name TEXT,
  total_sales BIGINT,
  total_revenue DECIMAL
)
LANGUAGE SQL
AS $$
  SELECT 
    r.id as region_id,
    r.name as region_name,
    COUNT(s.id) as total_sales,
    COALESCE(SUM(s.total), 0) as total_revenue
  FROM 
    regions r
  LEFT JOIN 
    markets m ON r.id = m.region_id
  LEFT JOIN 
    sales s ON m.id = s.market_id AND s.created_at BETWEEN start_date AND end_date
  GROUP BY 
    r.id, r.name
  ORDER BY 
    total_revenue DESC;
$$;

-- Function to get dashboard data for a vendor
CREATE OR REPLACE FUNCTION get_vendor_dashboard_data(
  vendor_uuid UUID,
  today_start TIMESTAMP WITH TIME ZONE,
  today_end TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
  today_sales_count BIGINT,
  today_total_revenue DECIMAL,
  active_markets_count BIGINT,
  products_in_stock_count BIGINT
)
LANGUAGE SQL
AS $$
  SELECT
    -- Today's sales count
    (SELECT COUNT(*) FROM sales 
     WHERE vendor_id = vendor_uuid 
     AND created_at BETWEEN today_start AND today_end) as today_sales_count,
    
    -- Today's total revenue
    (SELECT COALESCE(SUM(total), 0) FROM sales 
     WHERE vendor_id = vendor_uuid 
     AND created_at BETWEEN today_start AND today_end) as today_total_revenue,
    
    -- Active markets count
    (SELECT COUNT(*) FROM markets 
     WHERE status = 'active' 
     AND (vendor_id = vendor_uuid OR vendor_id IS NULL)) as active_markets_count,
    
    -- Products in stock count
    (SELECT COUNT(*) FROM products 
     WHERE stock_quantity > 0 
     AND status = 'active') as products_in_stock_count;
$$;

-- Helper function to create a default test region if needed
CREATE OR REPLACE FUNCTION create_test_region_if_needed()
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  region_id UUID;
BEGIN
  -- Check if test region exists
  SELECT id INTO region_id FROM regions 
  WHERE name = 'Test Region' LIMIT 1;
  
  -- If not, create it
  IF region_id IS NULL THEN
    INSERT INTO regions (name, country)
    VALUES ('Test Region', 'Morocco')
    RETURNING id INTO region_id;
  END IF;
  
  RETURN region_id;
END;
$$; 