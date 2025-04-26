-- Create daily_stock table
CREATE TABLE IF NOT EXISTS daily_stock (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  product_id UUID NOT NULL REFERENCES products(id),
  date DATE NOT NULL,
  quantity_assigned INTEGER NOT NULL DEFAULT 0,
  quantity_sold INTEGER NOT NULL DEFAULT 0,
  quantity_returned INTEGER NOT NULL DEFAULT 0,
  quantity_damaged INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (vendor_id, product_id, date)
);

-- Add RLS policies for daily_stock
ALTER TABLE daily_stock ENABLE ROW LEVEL SECURITY;

-- Vendors can view their daily stock
CREATE POLICY "Vendors can view their daily stock" ON daily_stock
  FOR SELECT USING (auth.uid()::text = vendor_id::text);

-- Vendors can update their daily stock (for returns and damaged items)
CREATE POLICY "Vendors can update their daily stock" ON daily_stock
  FOR UPDATE USING (auth.uid()::text = vendor_id::text);

-- Management can manage all daily stock
CREATE POLICY "Management can manage all daily stock" ON daily_stock
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM vendors 
      WHERE user_id = auth.uid() AND is_management = true
    )
  );

-- Function to calculate remaining quantity
CREATE OR REPLACE FUNCTION calculate_remaining_quantity()
RETURNS TRIGGER AS $$
BEGIN
  NEW.quantity_remaining = NEW.quantity_assigned - 
    (NEW.quantity_sold + NEW.quantity_returned + NEW.quantity_damaged);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update remaining quantity
CREATE TRIGGER update_remaining_quantity
  BEFORE INSERT OR UPDATE ON daily_stock
  FOR EACH ROW
  EXECUTE PROCEDURE update_modified_column();

-- Function to validate stock updates
CREATE OR REPLACE FUNCTION validate_stock_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Ensure quantities don't exceed assigned amount
  IF NEW.quantity_sold + NEW.quantity_returned + NEW.quantity_damaged > NEW.quantity_assigned THEN
    RAISE EXCEPTION 'Total quantities cannot exceed assigned amount';
  END IF;
  
  -- Ensure quantities are not negative
  IF NEW.quantity_sold < 0 OR NEW.quantity_returned < 0 OR NEW.quantity_damaged < 0 THEN
    RAISE EXCEPTION 'Quantities cannot be negative';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate stock updates
CREATE TRIGGER validate_stock_update_trigger
  BEFORE INSERT OR UPDATE ON daily_stock
  FOR EACH ROW
  EXECUTE PROCEDURE validate_stock_update();

-- Function to update stock on sale
CREATE OR REPLACE FUNCTION update_daily_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
  -- Find the daily stock record for this vendor and product
  UPDATE daily_stock
  SET quantity_sold = quantity_sold + NEW.quantity
  WHERE vendor_id = NEW.vendor_id
    AND product_id = NEW.product_id
    AND date = CURRENT_DATE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update daily stock on sale
CREATE TRIGGER update_daily_stock_on_sale_trigger
  AFTER INSERT ON sales
  FOR EACH ROW
  EXECUTE PROCEDURE update_daily_stock_on_sale();

-- Function to update stock on return
CREATE OR REPLACE FUNCTION update_daily_stock_on_return()
RETURNS TRIGGER AS $$
BEGIN
  -- Find the daily stock record for this vendor and product
  UPDATE daily_stock
  SET quantity_returned = quantity_returned + NEW.quantity
  WHERE vendor_id = NEW.vendor_id
    AND product_id = NEW.product_id
    AND date = CURRENT_DATE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update daily stock on return
CREATE TRIGGER update_daily_stock_on_return_trigger
  AFTER INSERT ON returns
  FOR EACH ROW
  EXECUTE PROCEDURE update_daily_stock_on_return();

-- Function to update stock on damage
CREATE OR REPLACE FUNCTION update_daily_stock_on_damage()
RETURNS TRIGGER AS $$
BEGIN
  -- Find the daily stock record for this vendor and product
  UPDATE daily_stock
  SET quantity_damaged = quantity_damaged + NEW.quantity
  WHERE vendor_id = NEW.vendor_id
    AND product_id = NEW.product_id
    AND date = CURRENT_DATE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update daily stock on damage
CREATE TRIGGER update_daily_stock_on_damage_trigger
  AFTER INSERT ON damaged_items
  FOR EACH ROW
  EXECUTE PROCEDURE update_daily_stock_on_damage(); 