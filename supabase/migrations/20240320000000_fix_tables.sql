-- Add discount_type column to promotions table
ALTER TABLE promotions ADD COLUMN IF NOT EXISTS discount_type TEXT NOT NULL DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'fixed'));

-- Ensure stock table exists with correct structure
CREATE TABLE IF NOT EXISTS stock (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INT NOT NULL CHECK (quantity >= 0),
  date_assigned TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (vendor_id, product_id)
);

-- Create or replace the update_modified_column function
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add RLS policy for stock table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'stock' AND policyname = 'Vendors can manage their stock'
  ) THEN
    CREATE POLICY "Vendors can manage their stock" ON stock
      FOR ALL USING (auth.uid()::text = vendor_id::text);
  END IF;
END $$;

-- Add trigger for stock table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'update_stock_timestamp'
  ) THEN
    CREATE TRIGGER update_stock_timestamp
      BEFORE UPDATE ON stock
      FOR EACH ROW
      EXECUTE PROCEDURE update_modified_column();
  END IF;
END $$; 