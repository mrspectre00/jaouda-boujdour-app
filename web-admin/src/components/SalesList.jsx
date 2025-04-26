import { useState, useEffect } from 'react';
import { DataGrid } from '@mui/x-data-grid';
import { Box, Button, Typography, MenuItem, Select, FormControl, InputLabel } from '@mui/material';
import { supabase } from '../lib/supabase';

const columns = [
  { field: 'id', headerName: 'ID', width: 90 },
  { 
    field: 'vendor_name', 
    headerName: 'Vendor', 
    width: 150,
    valueGetter: (params) => params.row.vendors?.full_name || 'Unknown',
  },
  { 
    field: 'market_name', 
    headerName: 'Market', 
    width: 150,
    valueGetter: (params) => params.row.markets?.name || 'Unknown',
  },
  { 
    field: 'total_amount', 
    headerName: 'Amount', 
    width: 120,
    valueFormatter: (params) => {
      if (params.value == null) return '';
      return `$${params.value.toFixed(2)}`;
    },
  },
  { field: 'status', headerName: 'Status', width: 130 },
  { 
    field: 'created_at', 
    headerName: 'Date', 
    width: 180,
    valueFormatter: (params) => {
      if (!params.value) return '';
      return new Date(params.value).toLocaleString();
    },
  },
];

export default function SalesList() {
  const [sales, setSales] = useState([]);
  const [loading, setLoading] = useState(true);
  const [timePeriod, setTimePeriod] = useState('all');
  const [selectedSale, setSelectedSale] = useState(null);
  const [saleItems, setSaleItems] = useState([]);
  const [viewingDetails, setViewingDetails] = useState(false);

  useEffect(() => {
    fetchSales();
  }, [timePeriod]);

  const fetchSales = async () => {
    try {
      setLoading(true);
      
      // Determine date range based on selected period
      let startDate;
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      
      switch (timePeriod) {
        case 'today':
          startDate = today.toISOString();
          break;
        case 'week':
          const weekStart = new Date(today);
          weekStart.setDate(today.getDate() - today.getDay());
          startDate = weekStart.toISOString();
          break;
        case 'month':
          const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
          startDate = monthStart.toISOString();
          break;
        case 'all':
        default:
          startDate = null;
          break;
      }
      
      let query = supabase
        .from('sales_records')
        .select(`
          *,
          vendors:vendor_id(id, full_name),
          markets:market_id(id, name)
        `)
        .order('created_at', { ascending: false });
      
      if (startDate) {
        query = query.gte('created_at', startDate);
      }

      const { data, error } = await query;

      if (error) throw error;
      setSales(data || []);
    } catch (error) {
      console.error('Error fetching sales:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRowClick = async (params) => {
    try {
      setSelectedSale(params.row);
      setViewingDetails(true);
      
      // Fetch sale items
      const { data, error } = await supabase
        .from('sales_items')
        .select(`
          *,
          products:product_id(id, name, price)
        `)
        .eq('sales_record_id', params.row.id);
      
      if (error) throw error;
      setSaleItems(data || []);
    } catch (error) {
      console.error('Error fetching sale items:', error);
    }
  };

  const handleBackToList = () => {
    setViewingDetails(false);
    setSelectedSale(null);
    setSaleItems([]);
  };

  const renderSaleDetails = () => {
    if (!selectedSale) return null;
    
    return (
      <Box>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
          <Button variant="outlined" onClick={handleBackToList} sx={{ mr: 2 }}>
            Back to List
          </Button>
          <Typography variant="h6">
            Sale Details - {new Date(selectedSale.created_at).toLocaleString()}
          </Typography>
        </Box>
        
        <Box sx={{ mb: 3 }}>
          <Typography variant="subtitle1">Sale Information</Typography>
          <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
            <Box>
              <Typography variant="body2" color="text.secondary">Vendor</Typography>
              <Typography variant="body1">{selectedSale.vendors?.full_name || 'Unknown'}</Typography>
            </Box>
            <Box>
              <Typography variant="body2" color="text.secondary">Market</Typography>
              <Typography variant="body1">{selectedSale.markets?.name || 'Unknown'}</Typography>
            </Box>
            <Box>
              <Typography variant="body2" color="text.secondary">Total Amount</Typography>
              <Typography variant="body1">${selectedSale.total_amount.toFixed(2)}</Typography>
            </Box>
            <Box>
              <Typography variant="body2" color="text.secondary">Status</Typography>
              <Typography variant="body1">{selectedSale.status}</Typography>
            </Box>
          </Box>
        </Box>
        
        <Typography variant="subtitle1" sx={{ mb: 1 }}>Items</Typography>
        <Box sx={{ height: 400, width: '100%' }}>
          <DataGrid
            rows={saleItems}
            columns={[
              { field: 'id', headerName: 'ID', width: 90 },
              { 
                field: 'product_name', 
                headerName: 'Product', 
                width: 200,
                valueGetter: (params) => params.row.products?.name || 'Unknown',
              },
              { field: 'quantity', headerName: 'Quantity', width: 120 },
              { 
                field: 'unit_price', 
                headerName: 'Unit Price', 
                width: 120,
                valueFormatter: (params) => {
                  if (params.value == null) return '';
                  return `$${params.value.toFixed(2)}`;
                },
              },
              { 
                field: 'total', 
                headerName: 'Total', 
                width: 120,
                valueGetter: (params) => params.row.quantity * params.row.unit_price,
                valueFormatter: (params) => {
                  if (params.value == null) return '';
                  return `$${params.value.toFixed(2)}`;
                },
              },
            ]}
            pageSize={5}
            rowsPerPageOptions={[5]}
            disableSelectionOnClick
          />
        </Box>
      </Box>
    );
  };

  const renderSalesList = () => {
    return (
      <>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
          <Typography variant="h5" component="h2">
            Sales Records
          </Typography>
          <FormControl sx={{ minWidth: 120 }}>
            <InputLabel id="time-period-label">Time Period</InputLabel>
            <Select
              labelId="time-period-label"
              value={timePeriod}
              label="Time Period"
              onChange={(e) => setTimePeriod(e.target.value)}
            >
              <MenuItem value="all">All Time</MenuItem>
              <MenuItem value="today">Today</MenuItem>
              <MenuItem value="week">This Week</MenuItem>
              <MenuItem value="month">This Month</MenuItem>
            </Select>
          </FormControl>
        </Box>

        <DataGrid
          rows={sales}
          columns={columns}
          pageSize={10}
          rowsPerPageOptions={[10]}
          loading={loading}
          disableSelectionOnClick
          onRowClick={handleRowClick}
          sx={{ height: 600 }}
        />
      </>
    );
  };

  return (
    <Box sx={{ width: '100%' }}>
      {viewingDetails ? renderSaleDetails() : renderSalesList()}
    </Box>
  );
}