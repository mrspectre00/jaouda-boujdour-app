# Jaouda Boujdour App

A Flutter mobile application for managing sales and markets for Jaouda Boujdour vendors.

## Features

- Vendor authentication with Supabase
- Dashboard with sales summary and quick actions
- Interactive map to locate and manage markets
- Market management (add, view, update markets)
- Sales tracking and recording
- Offline support for data collection
- Reports and analytics

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- A Supabase account and project

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/jaouda_boujdour_app.git
   cd jaouda_boujdour_app
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Supabase credentials are already configured in the app:
   - URL: `https://hvxgdyxqmkpmhejpumlc.supabase.co`
   - Anonymous Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2eGdkeXhxbWtwbWhlanB1bWxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ0Nzk2OTMsImV4cCI6MjA2MDA1NTY5M30.JfS42uMEMgqNiKKfF17OKjMa6QRq6LUaJkESdAdLmdA`
   
   If you need to change these credentials, update them in `lib/config/environment.dart`

4. Set up the Supabase database by running the SQL script in `database/setup.sql` in your Supabase SQL editor.

5. Run the app
   ```bash
   flutter run
   ```

## Database Structure

The app uses Supabase as its backend and requires the following tables (created by the setup script):

### vendors
- id (UUID)
- name (text)
- email (text)
- phone (text)
- created_at (timestamp)
- updated_at (timestamp)

### markets
- id (UUID)
- name (text)
- address (text)
- location (json: {latitude: float, longitude: float})
- status (text: 'active', 'inactive', 'pending', 'archived')
- notes (text)
- vendor_id (UUID, foreign key to vendors.id)
- created_at (timestamp)
- updated_at (timestamp)

### sales
- id (UUID)
- vendor_id (UUID, foreign key to vendors.id)
- market_id (UUID, foreign key to markets.id)
- market_name (text)
- product_name (text)
- quantity (float)
- unit_price (float)
- total_amount (float)
- discount (float)
- notes (text)
- created_at (timestamp)

### products
- id (UUID)
- name (text)
- description (text)
- price (float)
- image_url (text)
- vendor_id (UUID, foreign key to vendors.id)
- created_at (timestamp)
- updated_at (timestamp)
- is_active (boolean)

## Project Structure

```
lib/
├── config/
│   └── environment.dart   # Contains Supabase credentials
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   └── providers/
│   ├── dashboard/
│   │   ├── screens/
│   │   └── providers/
│   ├── maps/
│   │   ├── screens/
│   │   └── providers/
│   ├── markets/
│   │   ├── screens/
│   │   └── providers/
│   └── sales/
│       ├── screens/
│       └── providers/
├── models/
├── services/
├── widgets/
└── main.dart
```

## Database Setup

The application comes with a pre-configured SQL script to set up all required tables, indexes, and Row Level Security (RLS) policies in Supabase:

1. Go to your Supabase project dashboard
2. Navigate to the SQL Editor
3. Copy the contents of `database/setup.sql` 
4. Run the script to create all tables with proper security policies

The script will:
- Create all required tables (vendors, markets, products, sales)
- Set up appropriate relationships between tables
- Configure Row Level Security to control data access
- Create triggers for automatic timestamp updates
- Add indexes for optimized queries

## Architecture

This app follows a feature-first architecture with Riverpod for state management. Key components include:

- **Features**: Self-contained modules with their own screens and providers
- **Models**: Data classes that represent domain entities
- **Services**: Cross-cutting concerns like authentication and API communication
- **Widgets**: Reusable UI components
- **Providers**: State management using Riverpod

## License

This project is licensed under the MIT License - see the LICENSE file for details.
