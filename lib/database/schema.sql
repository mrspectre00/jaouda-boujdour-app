-- Jaouda Boujdour App Database Schema
-- This file contains the complete database schema definition
-- Execute this in your Supabase SQL Editor to create all required tables

-- Enable PostGIS extension for geographical data
CREATE EXTENSION IF NOT EXISTS postgis;

-- Regions Table
CREATE TABLE IF NOT EXISTS public.regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'Morocco',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add RLS policies for regions
ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON public.regions
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert" ON public.regions
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update" ON public.regions
    FOR UPDATE TO authenticated USING (true);

-- Vendors Table
CREATE TABLE IF NOT EXISTS public.vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    region_id UUID REFERENCES public.regions(id),
    user_id UUID REFERENCES auth.users(id),
    is_management BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add RLS policies for vendors
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read access" ON public.vendors
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow users to insert vendors" ON public.vendors
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to update own vendor" ON public.vendors
    FOR UPDATE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Allow management to update any vendor" ON public.vendors
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Markets Table
CREATE TABLE IF NOT EXISTS public.markets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    gps_location GEOMETRY(POINT, 4326) NOT NULL,
    region_id UUID REFERENCES public.regions(id),
    vendor_id UUID REFERENCES public.vendors(id),
    status TEXT NOT NULL DEFAULT 'pending_review',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index on gps_location
CREATE INDEX IF NOT EXISTS markets_gps_location_idx ON public.markets USING GIST (gps_location);

-- Add RLS policies for markets
ALTER TABLE public.markets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read access" ON public.markets
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated insert" ON public.markets
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow vendors to update their markets" ON public.markets
    FOR UPDATE TO authenticated USING (
        vendor_id = (SELECT id FROM public.vendors WHERE user_id = auth.uid())
    );

CREATE POLICY "Allow management to update any market" ON public.markets
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Products Table
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    category TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add RLS policies for products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read access" ON public.products
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow management to insert" ON public.products
    FOR INSERT TO authenticated WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

CREATE POLICY "Allow management to update" ON public.products
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

CREATE POLICY "Allow management to delete" ON public.products
    FOR DELETE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Promotions Table
CREATE TABLE IF NOT EXISTS public.promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    discount_percentage DECIMAL(5, 2) NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    product_id UUID REFERENCES public.products(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add RLS policies for promotions
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read access" ON public.promotions
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow management to insert" ON public.promotions
    FOR INSERT TO authenticated WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

CREATE POLICY "Allow management to update" ON public.promotions
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

CREATE POLICY "Allow management to delete" ON public.promotions
    FOR DELETE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Sales Table
CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    market_id UUID NOT NULL REFERENCES public.markets(id),
    product_id UUID NOT NULL REFERENCES public.products(id),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total DECIMAL(10, 2) NOT NULL,
    discount DECIMAL(10, 2) DEFAULT 0,
    promotion_id UUID REFERENCES public.promotions(id),
    payment_method TEXT DEFAULT 'cash',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add RLS policies for sales
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read access" ON public.sales
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow vendors to insert own sales" ON public.sales
    FOR INSERT TO authenticated WITH CHECK (
        vendor_id = (SELECT id FROM public.vendors WHERE user_id = auth.uid())
    );

CREATE POLICY "Allow vendors to update own sales" ON public.sales
    FOR UPDATE TO authenticated USING (
        vendor_id = (SELECT id FROM public.vendors WHERE user_id = auth.uid())
    );

CREATE POLICY "Allow management to update any sale" ON public.sales
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Create initial test region if needed
INSERT INTO public.regions (id, name, country)
VALUES ('00000000-0000-0000-0000-000000000001', 'Test Region', 'Morocco')
ON CONFLICT (id) DO NOTHING;

-- Create function to get sales by date range
CREATE OR REPLACE FUNCTION get_sales_by_date_range(
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    vendor_uuid UUID DEFAULT NULL
)
RETURNS TABLE (
    sale_id UUID,
    market_name TEXT,
    product_name TEXT,
    quantity INTEGER,
    unit_price DECIMAL(10, 2),
    total DECIMAL(10, 2),
    sale_date TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL
AS $$
    SELECT 
        s.id as sale_id,
        m.name as market_name,
        p.name as product_name,
        s.quantity,
        s.unit_price,
        s.total,
        s.created_at as sale_date
    FROM 
        public.sales s
    JOIN 
        public.markets m ON s.market_id = m.id
    JOIN 
        public.products p ON s.product_id = p.id
    WHERE 
        s.created_at BETWEEN start_date AND end_date
        AND (vendor_uuid IS NULL OR s.vendor_id = vendor_uuid)
    ORDER BY 
        s.created_at DESC;
$$; 