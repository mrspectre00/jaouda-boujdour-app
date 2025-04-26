-- Supabase Schema for Jaouda Boujdour App

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- Drop all existing tables (if any)
DROP TABLE IF EXISTS market_visit_status CASCADE;
DROP TABLE IF EXISTS sales_items CASCADE;
DROP TABLE IF EXISTS sales_records CASCADE;
DROP TABLE IF EXISTS vendor_inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS markets CASCADE;
DROP TABLE IF EXISTS vendors CASCADE;
DROP TABLE IF EXISTS regions CASCADE;

-- Create regions table
CREATE TABLE regions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create vendors table
CREATE TABLE vendors (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  region_id UUID REFERENCES regions(id),
  phone TEXT,
  address TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create markets table
CREATE TABLE markets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  gps_location GEOGRAPHY(POINT) NOT NULL,
  region_id UUID REFERENCES regions(id),
  added_by UUID REFERENCES vendors(id),
  status TEXT CHECK (status IN ('active', 'inactive', 'pending_review')) DEFAULT 'pending_review',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create products table
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  image TEXT,
  price DECIMAL(10, 2) NOT NULL,
  category TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create vendor_inventory table
CREATE TABLE vendor_inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vendor_id, product_id)
);

-- Create sales_records table
CREATE TABLE sales_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  market_id UUID NOT NULL REFERENCES markets(id),
  total_amount DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create sales_items table
CREATE TABLE sales_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sales_record_id UUID NOT NULL REFERENCES sales_records(id),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL,
  unit_price DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create market_visit_status table
CREATE TABLE market_visit_status (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  market_id UUID NOT NULL REFERENCES markets(id),
  status TEXT NOT NULL,
  visit_date DATE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vendor_id, market_id, visit_date)
);

-- Create stock table
CREATE TABLE stock (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INT NOT NULL CHECK (quantity >= 0),
  date_assigned TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (vendor_id, product_id)
);

-- Create promotions table
CREATE TABLE promotions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID REFERENCES products(id),
  description TEXT NOT NULL,
  remise_value DECIMAL(5, 2) NOT NULL,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (end_date > start_date)
);

-- Create sales table
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  market_id UUID NOT NULL REFERENCES markets(id),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10, 2) NOT NULL,
  remise_applied DECIMAL(5, 2) DEFAULT 0,
  total DECIMAL(10, 2) NOT NULL,
  date TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create spoiled stock table
CREATE TABLE spoiled_stock (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INT NOT NULL CHECK (quantity > 0),
  market_id UUID REFERENCES markets(id),
  reason TEXT,
  date TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create RLS policies
-- Enable Row Level Security
ALTER TABLE regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE markets ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_visit_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE spoiled_stock ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Vendors can read all vendors but only update their own
CREATE POLICY "Vendors can view all vendors" ON vendors FOR SELECT USING (true);
CREATE POLICY "Vendors can update own profile" ON vendors FOR UPDATE USING (auth.uid() = id);

-- Admin policies for vendors table
CREATE POLICY "Admins can manage all vendors" ON vendors FOR ALL USING (auth.role() = 'authenticated');

-- Markets policies
CREATE POLICY "Markets are viewable by all" ON markets FOR SELECT USING (true);
CREATE POLICY "Vendors can insert markets" ON markets FOR INSERT WITH CHECK (auth.uid()::text = added_by::text);
CREATE POLICY "Vendors can update their markets" ON markets FOR UPDATE USING (auth.uid()::text = added_by::text);

-- Products are viewable by all
CREATE POLICY "Products are viewable by all" ON products FOR SELECT USING (true);

-- Vendor inventory policies
CREATE POLICY "Vendors can view their inventory" ON vendor_inventory FOR SELECT USING (auth.uid()::text = vendor_id::text);
CREATE POLICY "Vendors can update their inventory" ON vendor_inventory FOR ALL USING (auth.uid()::text = vendor_id::text);

-- Sales records policies
CREATE POLICY "Vendors can view their sales" ON sales_records FOR SELECT USING (auth.uid()::text = vendor_id::text);
CREATE POLICY "Vendors can insert their sales" ON sales_records FOR INSERT WITH CHECK (auth.uid()::text = vendor_id::text);

-- Sales items policies
CREATE POLICY "Vendors can view their sales items" ON sales_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM sales_records WHERE sales_records.id = sales_items.sales_record_id AND sales_records.vendor_id::text = auth.uid()::text)
);
CREATE POLICY "Vendors can insert their sales items" ON sales_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM sales_records WHERE sales_records.id = sales_items.sales_record_id AND sales_records.vendor_id::text = auth.uid()::text)
);

-- Market visit status policies
CREATE POLICY "Vendors can view their market visits" ON market_visit_status FOR SELECT USING (auth.uid()::text = vendor_id::text);
CREATE POLICY "Vendors can update their market visits" ON market_visit_status FOR ALL USING (auth.uid()::text = vendor_id::text);

-- Stock policies
CREATE POLICY "Vendors can view their stock" ON stock FOR SELECT USING (auth.uid()::text = vendor_id::text);
CREATE POLICY "Vendors can update their stock" ON stock FOR ALL USING (auth.uid()::text = vendor_id::text);

-- Promotions policies
CREATE POLICY "Vendors can view their promotions" ON promotions FOR SELECT USING (
  active = true AND
  current_timestamp BETWEEN start_date AND end_date
);

-- Sales policies
CREATE POLICY "Vendors can insert their sales" ON sales FOR INSERT WITH CHECK (auth.uid()::text = vendor_id::text);
CREATE POLICY "Vendors can view their sales" ON sales FOR SELECT USING (auth.uid()::text = vendor_id::text);

-- Spoiled stock policies
CREATE POLICY "Vendors can insert spoiled stock" ON spoiled_stock FOR INSERT WITH CHECK (auth.uid()::text = vendor_id::text);
CREATE POLICY "Vendors can view their spoiled stock" ON spoiled_stock FOR SELECT USING (auth.uid()::text = vendor_id::text);

-- Functions and Triggers
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to all tables
CREATE TRIGGER update_vendors_timestamp BEFORE UPDATE ON vendors
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_regions_timestamp BEFORE UPDATE ON regions
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_markets_timestamp BEFORE UPDATE ON markets
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_products_timestamp BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_stock_timestamp BEFORE UPDATE ON stock
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_promotions_timestamp BEFORE UPDATE ON promotions
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_sales_timestamp BEFORE UPDATE ON sales
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_spoiled_stock_timestamp BEFORE UPDATE ON spoiled_stock
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

-- Function to automatically deduct stock when sale is recorded
CREATE OR REPLACE FUNCTION deduct_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if we have sufficient stock
  IF NOT EXISTS (
    SELECT 1 FROM stock 
    WHERE vendor_id = NEW.vendor_id 
      AND product_id = NEW.product_id 
      AND quantity >= NEW.quantity
  ) THEN
    RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
  END IF;
  
  -- Deduct the stock
  UPDATE stock 
  SET quantity = quantity - NEW.quantity 
  WHERE vendor_id = NEW.vendor_id AND product_id = NEW.product_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to deduct stock on sale
CREATE TRIGGER deduct_stock_on_sale_trigger
AFTER INSERT ON sales
FOR EACH ROW EXECUTE PROCEDURE deduct_stock_on_sale();

-- Function to deduct stock when spoiled stock is recorded
CREATE OR REPLACE FUNCTION deduct_stock_on_spoiled()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if we have sufficient stock
  IF NOT EXISTS (
    SELECT 1 FROM stock 
    WHERE vendor_id = NEW.vendor_id 
      AND product_id = NEW.product_id 
      AND quantity >= NEW.quantity
  ) THEN
    RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
  END IF;
  
  -- Deduct the stock
  UPDATE stock 
  SET quantity = quantity - NEW.quantity 
  WHERE vendor_id = NEW.vendor_id AND product_id = NEW.product_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to deduct stock on spoiled stock recording
CREATE TRIGGER deduct_stock_on_spoiled_trigger
AFTER INSERT ON spoiled_stock
FOR EACH ROW EXECUTE PROCEDURE deduct_stock_on_spoiled();