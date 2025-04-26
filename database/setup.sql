-- Create the vendors table
CREATE TABLE IF NOT EXISTS vendors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create RLS policies for vendors
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Vendors can view their own profile" 
  ON vendors FOR SELECT 
  USING (auth.uid() = id);
  
CREATE POLICY "Vendors can update their own profile" 
  ON vendors FOR UPDATE 
  USING (auth.uid() = id);

-- Create the markets table
CREATE TABLE IF NOT EXISTS markets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  location JSONB, -- {latitude: float, longitude: float}
  status TEXT CHECK (status IN ('active', 'inactive', 'pending', 'archived')) DEFAULT 'pending',
  notes TEXT,
  vendor_id UUID REFERENCES vendors(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create RLS policies for markets
ALTER TABLE markets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Vendors can view all markets" 
  ON markets FOR SELECT 
  USING (true);
  
CREATE POLICY "Vendors can insert their own markets" 
  ON markets FOR INSERT 
  WITH CHECK (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can update their own markets" 
  ON markets FOR UPDATE 
  USING (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can delete their own markets" 
  ON markets FOR DELETE 
  USING (auth.uid() = vendor_id);

-- Create the products table
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10, 2) NOT NULL,
  image_url TEXT,
  vendor_id UUID REFERENCES vendors(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);

-- Create RLS policies for products
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Vendors can view their own products" 
  ON products FOR SELECT 
  USING (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can insert their own products" 
  ON products FOR INSERT 
  WITH CHECK (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can update their own products" 
  ON products FOR UPDATE 
  USING (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can delete their own products" 
  ON products FOR DELETE 
  USING (auth.uid() = vendor_id);

-- Create the sales table
CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES vendors(id) NOT NULL,
  market_id UUID REFERENCES markets(id) NOT NULL,
  market_name TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity DECIMAL(10, 2) NOT NULL,
  unit_price DECIMAL(10, 2) NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  discount DECIMAL(10, 2),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create RLS policies for sales
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Vendors can view their own sales" 
  ON sales FOR SELECT 
  USING (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can insert their own sales" 
  ON sales FOR INSERT 
  WITH CHECK (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can update their own sales" 
  ON sales FOR UPDATE 
  USING (auth.uid() = vendor_id);
  
CREATE POLICY "Vendors can delete their own sales" 
  ON sales FOR DELETE 
  USING (auth.uid() = vendor_id);

-- Create trigger to automatically update the updated_at column
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to tables with updated_at columns
CREATE TRIGGER set_timestamp_vendors
BEFORE UPDATE ON vendors
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_markets
BEFORE UPDATE ON markets
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_products
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Create indexes for performance
CREATE INDEX idx_markets_vendor_id ON markets(vendor_id);
CREATE INDEX idx_products_vendor_id ON products(vendor_id);
CREATE INDEX idx_sales_vendor_id ON sales(vendor_id);
CREATE INDEX idx_sales_market_id ON sales(market_id);
CREATE INDEX idx_sales_created_at ON sales(created_at); 