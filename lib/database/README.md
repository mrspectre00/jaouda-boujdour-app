# Database Management

This directory contains files for setting up and managing the database for the Jaouda Boujdour App.

## Files

- **schema.sql**: Complete database schema definition with all tables, relationships, indexes, and RLS policies.
- **data_seeder.sql**: Script to populate the database with test data for development and testing.
- **setup_instructions.md**: Detailed instructions on how to set up the database in Supabase.

## Database Structure

The Jaouda Boujdour App uses a PostgreSQL database hosted on Supabase with the following structure:

### Tables

1. **regions**
   - Stores geographical regions where markets and vendors operate
   - Fields: id, name, country, created_at, updated_at

2. **vendors**
   - Stores information about vendors linked to auth users
   - Fields: id, name, email, region_id, user_id, is_management, created_at, updated_at

3. **markets**
   - Stores market information with geographical locations
   - Uses PostGIS for location data
   - Fields: id, name, address, gps_location, region_id, vendor_id, status, notes, created_at, updated_at

4. **products**
   - Stores product information
   - Fields: id, name, description, price, stock_quantity, category, status, created_at, updated_at

5. **promotions**
   - Stores information about product promotions and discounts
   - Fields: id, name, description, discount_percentage, start_date, end_date, product_id, is_active, created_at, updated_at

6. **sales**
   - Stores sales transaction records
   - Fields: id, market_id, product_id, vendor_id, quantity, unit_price, total, discount, promotion_id, payment_method, notes, created_at, updated_at

### Relationships

- A vendor belongs to a region
- A market belongs to a region and optionally to a vendor
- A sale belongs to a market, product, and vendor
- A promotion applies to a product

### Security

Row Level Security (RLS) policies are implemented for all tables to ensure:
- Vendors can only access and modify their own data
- Management users have broader access privileges
- Authenticated users have appropriate read access

## Setup Instructions

Please refer to the `setup_instructions.md` file for detailed instructions on setting up the database in Supabase.

## Adding Test Data

For development and testing purposes, you can use the `data_seeder.sql` script to populate your database with test data. The script includes:

- Test regions
- Test vendors
- Test products and promotions
- Test markets with geographical coordinates
- Sample sales data

## Troubleshooting

If you encounter database-related errors in the app, check the `setup_instructions.md` file for common issues and their solutions.

## Development Notes

- The database uses UUID for primary keys
- Timestamps are stored with timezone information
- Geographical data uses the PostGIS extension and is stored in EPSG:4326 format
- Row Level Security is used to enforce access control at the database level 