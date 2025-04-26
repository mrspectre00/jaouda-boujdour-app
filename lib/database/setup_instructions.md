# Database Setup Instructions for Jaouda Boujdour App

This document provides instructions on how to set up the database schema for the Jaouda Boujdour App in Supabase.

## Prerequisites

1. A Supabase account and project
2. Access to the SQL Editor in the Supabase Dashboard

## Setup Steps

### 1. Enable PostGIS Extension

Before running the schema script, you need to enable the PostGIS extension for handling geographical data:

1. Log in to your Supabase dashboard
2. Navigate to the SQL Editor
3. Run the following SQL command:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### 2. Execute the Schema SQL Script

1. Open the SQL Editor in the Supabase Dashboard
2. Copy the entire contents of the `schema.sql` file
3. Paste it into the SQL Editor
4. Click "Run" to execute the SQL script

The script will:
- Create all required tables if they don't exist
- Set up relationships between tables
- Configure Row Level Security (RLS) policies
- Create an initial test region
- Create helper functions

### 3. Verify the Setup

After running the script, verify that all tables were created successfully:

1. Navigate to the "Table Editor" in the Supabase Dashboard
2. You should see the following tables:
   - regions
   - vendors
   - markets
   - products
   - promotions
   - sales

### 4. Database Structure

The database has the following structure:

- **regions**: Stores geographical regions
- **vendors**: Stores vendor information, linked to auth.users
- **markets**: Stores market information with geographical location
- **products**: Stores product information
- **promotions**: Stores product promotions and discounts
- **sales**: Stores sales records

### 5. Fixing Common Issues

If you encounter the following errors in your app:

#### Missing gps_location column

Error: `column markets.gps_location does not exist`

Solution: Make sure you've enabled the PostGIS extension and created the markets table with the gps_location field as GEOMETRY type.

#### Missing regions table

Error: `relation "public.regions" does not exist`

Solution: Run the schema.sql script which creates the regions table.

### 6. Initial Data

The schema script includes an INSERT statement to create an initial test region with ID '00000000-0000-0000-0000-000000000001'. You can add more initial data as needed.

### 7. Update Environment Variables

Make sure your app's `.env` file or environment configuration contains the correct Supabase URL and anonymous key:

```
SUPABASE_URL=https://your-project-url.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

## Testing the Setup

After completing the setup, you can test it by running your Flutter app. The database errors related to missing tables and columns should be resolved. 