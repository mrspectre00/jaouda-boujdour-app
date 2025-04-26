# Supabase Implementation Guide

## Overview
This guide explains how to set up the Supabase database for the Jaouda Boujdour application and connect it to both the web admin interface and the Flutter mobile app.

## Database Setup

1. Log in to your Supabase dashboard at https://app.supabase.com
2. Navigate to your project (URL: https://hvxgdyxqmkpmhejpumlc.supabase.co)
3. Go to the SQL Editor section
4. Create a new query and paste the contents of `schema.sql`
5. Run the query to create all necessary tables and security policies

## Data Models

The database schema includes the following tables:

- **regions**: Geographic regions for organizing vendors and markets
- **vendors**: Users who sell products in markets
- **markets**: Locations where vendors sell products
- **products**: Items that vendors sell
- **vendor_inventory**: Tracks product quantities for each vendor
- **sales_records**: Records of sales transactions
- **sales_items**: Individual items included in each sale
- **market_visit_status**: Tracks vendor visits to markets

## Next Steps

### Web Admin Implementation

1. Create new components for managing each data model:
   - ProductList.jsx
   - SalesList.jsx
   - RegionList.jsx

2. Update the existing components to use Supabase instead of Firebase:
   - MarketList.jsx
   - VendorList.jsx

3. Add routes for the new components in App.jsx

### Mobile App Implementation

1. Create a new model for sales:
   ```dart
   // lib/models/sale.dart
   class Sale {
     final String id;
     final String vendorId;
     final String marketId;
     final double totalAmount;
     final String status;
     final double? latitude;
     final double? longitude;
     final DateTime createdAt;
     final DateTime updatedAt;
     final List<SaleItem>? items;

     Sale({
       required this.id,
       required this.vendorId,
       required this.marketId,
       required this.totalAmount,
       required this.status,
       this.latitude,
       this.longitude,
       required this.createdAt,
       required this.updatedAt,
       this.items,
     });

     // Add fromJson and toJson methods
   }

   class SaleItem {
     final String id;
     final String salesRecordId;
     final String productId;
     final int quantity;
     final double unitPrice;
     final DateTime createdAt;
     final DateTime updatedAt;

     SaleItem({
       required this.id,
       required this.salesRecordId,
       required this.productId,
       required this.quantity,
       required this.unitPrice,
       required this.createdAt,
       required this.updatedAt,
     });

     // Add fromJson and toJson methods
   }
   ```

2. Implement inventory management screens

3. Add sales history and reporting screens

## Authentication

Supabase provides built-in authentication that works with both the web admin and mobile app:

- Web Admin: Use the `supabase.auth` methods in the Login component
- Mobile App: Use the `Supabase.instance.client.auth` methods in the login screen

## Row Level Security

The schema includes Row Level Security (RLS) policies to ensure data access is properly controlled:

- Vendors can only access their own data
- Admins can access all data (requires additional setup)
- Public data like product listings is accessible to all authenticated users

## Testing

After implementing the database, test the following flows:

1. Vendor registration and login
2. Market creation and approval
3. Product inventory management
4. Sales recording
5. Reporting and analytics

# Supabase Database Functions

This directory contains SQL files and other Supabase-related scripts for the Jaouda Boujdour app.

## Applying SQL Functions

To apply the SQL functions in this directory:

1. Open the [Supabase Dashboard](https://app.supabase.io/)
2. Select your project
3. Go to SQL Editor
4. Create a new query
5. Copy and paste the contents of the SQL file you want to apply
6. Run the query

## Available Functions

### `delete_vendor` Function

**Purpose**: Securely delete a vendor even when there are permission issues.

**File**: `migrations/20230522000001_create_delete_vendor_function.sql`

**Usage**: 
```sql
-- Delete a vendor by ID
SELECT delete_vendor('00000000-0000-0000-0000-000000000001');
```

This function:
1. Reassigns related data to the default system account
2. Deletes the vendor record
3. Runs with elevated privileges to bypass RLS policies

## Troubleshooting

If you're experiencing issues with vendor deletion, try these steps:

1. Check if the account has RLS protection
2. Ensure the vendor ID is in the correct UUID format
3. Run the function manually in the SQL Editor
4. Check for custom triggers that might be preventing deletion