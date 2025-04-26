-- Add discount_type column to promotions table
ALTER TABLE promotions ADD COLUMN IF NOT EXISTS discount_type TEXT NOT NULL DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'fixed'));

-- Create a function to update market locations
CREATE OR REPLACE FUNCTION update_market_location(
  market_id UUID,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION
) RETURNS void AS $$
BEGIN
  UPDATE markets
  SET gps_location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
  WHERE id = market_id;
END;
$$ LANGUAGE plpgsql;

-- Update existing markets with test data
DO $$
BEGIN
  -- Update Central Market
  PERFORM update_market_location(
    '00000000-0000-0000-0000-000000000001'::uuid,
    27.1537,
    -13.2033
  );
  
  -- Update Corner Shop
  PERFORM update_market_location(
    '00000000-0000-0000-0000-000000000002'::uuid,
    27.1553,
    -13.2011
  );
  
  -- Update Laayoune Market
  PERFORM update_market_location(
    '00000000-0000-0000-0000-000000000003'::uuid,
    27.1571,
    -13.1989
  );
END $$; 