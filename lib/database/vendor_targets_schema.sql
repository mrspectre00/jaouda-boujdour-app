-- Vendor Targets and Quotas Schema
-- Add this to your Supabase SQL Editor to create the necessary tables

-- Vendor Targets Table
CREATE TABLE IF NOT EXISTS public.vendor_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id),
    target_name TEXT NOT NULL,
    target_description TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    target_type TEXT NOT NULL CHECK (target_type IN ('units', 'revenue')),
    target_value DECIMAL(10, 2) NOT NULL, -- Either units or currency value
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Optional product-specific target
    product_id UUID REFERENCES public.products(id)
);

-- Create index on vendor_id for faster querying
CREATE INDEX IF NOT EXISTS vendor_targets_vendor_id_idx ON public.vendor_targets (vendor_id);

-- Add RLS policies for vendor_targets
ALTER TABLE public.vendor_targets ENABLE ROW LEVEL SECURITY;

-- Allow vendors to read their own targets
CREATE POLICY "Allow vendors to view their own targets" ON public.vendor_targets
    FOR SELECT TO authenticated USING (
        vendor_id = (SELECT id FROM public.vendors WHERE user_id = auth.uid())
    );

-- Allow management to read all targets
CREATE POLICY "Allow management to view all targets" ON public.vendor_targets
    FOR SELECT TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Allow management to create targets
CREATE POLICY "Allow management to create targets" ON public.vendor_targets
    FOR INSERT TO authenticated WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Allow management to update targets
CREATE POLICY "Allow management to update targets" ON public.vendor_targets
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Allow management to delete targets
CREATE POLICY "Allow management to delete targets" ON public.vendor_targets
    FOR DELETE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Target Achievement Tracking Table
CREATE TABLE IF NOT EXISTS public.target_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_id UUID NOT NULL REFERENCES public.vendor_targets(id),
    date DATE NOT NULL,
    achieved_value DECIMAL(10, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index on target_id for faster querying
CREATE INDEX IF NOT EXISTS target_achievements_target_id_idx ON public.target_achievements (target_id);

-- Add RLS policies for target_achievements
ALTER TABLE public.target_achievements ENABLE ROW LEVEL SECURITY;

-- Allow vendors to view their own achievements
CREATE POLICY "Allow vendors to view their own achievements" ON public.target_achievements
    FOR SELECT TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendor_targets 
            WHERE id = target_id AND vendor_id = (SELECT id FROM public.vendors WHERE user_id = auth.uid())
        )
    );

-- Allow management to view all achievements
CREATE POLICY "Allow management to view all achievements" ON public.target_achievements
    FOR SELECT TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Allow management to create achievements
CREATE POLICY "Allow management to create achievements" ON public.target_achievements
    FOR INSERT TO authenticated WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Allow management to update achievements
CREATE POLICY "Allow management to update achievements" ON public.target_achievements
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.vendors 
            WHERE user_id = auth.uid() AND is_management = true
        )
    );

-- Create a function to calculate target progress
CREATE OR REPLACE FUNCTION get_target_progress(
    target_uuid UUID
)
RETURNS TABLE (
    target_id UUID,
    target_value DECIMAL(10, 2),
    achieved_value DECIMAL(10, 2),
    progress_percentage DECIMAL(5, 2)
)
LANGUAGE SQL
AS $$
    WITH target_data AS (
        SELECT 
            id,
            target_value
        FROM public.vendor_targets
        WHERE id = target_uuid
    ),
    achievement_data AS (
        SELECT 
            COALESCE(SUM(achieved_value), 0) as total_achieved
        FROM public.target_achievements
        WHERE target_id = target_uuid
    )
    SELECT 
        td.id as target_id,
        td.target_value,
        ad.total_achieved as achieved_value,
        CASE 
            WHEN td.target_value = 0 THEN 0
            ELSE (ad.total_achieved / td.target_value) * 100
        END as progress_percentage
    FROM target_data td
    CROSS JOIN achievement_data ad;
$$;

-- Create a function to automatically update target achievements based on sales
CREATE OR REPLACE FUNCTION update_target_achievements_from_sales()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_id UUID;
    v_product_id UUID;
    v_sale_date DATE;
    v_sale_amount DECIMAL(10, 2);
    v_sale_units INTEGER;
    target_record RECORD;
BEGIN
    -- Extract values from the new sale
    v_vendor_id := NEW.vendor_id;
    v_product_id := NEW.product_id;
    v_sale_date := NEW.created_at::DATE;
    v_sale_amount := NEW.total;
    v_sale_units := NEW.quantity;
    
    -- Find all active targets for this vendor on this date
    FOR target_record IN 
        SELECT id, target_type, product_id
        FROM public.vendor_targets
        WHERE vendor_id = v_vendor_id
        AND v_sale_date BETWEEN start_date AND end_date
        AND is_active = true
        AND (product_id IS NULL OR product_id = v_product_id)
    LOOP
        -- For each target, update or create a achievement record
        IF target_record.target_type = 'units' THEN
            -- For unit-based targets, we add the units sold
            INSERT INTO public.target_achievements (
                target_id, date, achieved_value, notes
            ) VALUES (
                target_record.id, 
                v_sale_date, 
                v_sale_units,
                'Auto-generated from sale ' || NEW.id
            )
            ON CONFLICT (target_id, date) DO UPDATE
            SET achieved_value = target_achievements.achieved_value + v_sale_units,
                updated_at = now();
        ELSE
            -- For revenue-based targets, we add the sale amount
            INSERT INTO public.target_achievements (
                target_id, date, achieved_value, notes
            ) VALUES (
                target_record.id, 
                v_sale_date, 
                v_sale_amount,
                'Auto-generated from sale ' || NEW.id
            )
            ON CONFLICT (target_id, date) DO UPDATE
            SET achieved_value = target_achievements.achieved_value + v_sale_amount,
                updated_at = now();
        END IF;
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to update target achievements when a sale is recorded
CREATE TRIGGER trigger_update_target_achievements
AFTER INSERT ON public.sales
FOR EACH ROW
EXECUTE FUNCTION update_target_achievements_from_sales();

-- Add unique constraint to prevent duplicate achievement entries per day
ALTER TABLE public.target_achievements 
ADD CONSTRAINT unique_target_date UNIQUE (target_id, date); 