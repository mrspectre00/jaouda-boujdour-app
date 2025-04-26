
import { useState, useEffect } from 'react';
import { DataGrid } from '@mui/x-data-grid';
import { Box, Button, Typography, Dialog, DialogTitle, DialogContent, DialogActions, TextField, FormControl, InputLabel, Select, MenuItem, IconButton } from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import { supabase } from '../lib/supabase';

const columns = [
  { field: 'id', headerName: 'ID', width: 90 },
  { field: 'name', headerName: 'Name', width: 200 },
  { field: 'address', headerName: 'Address', width: 250 },
  { field: 'phone', headerName: 'Phone', width: 130 },
  { field: 'region', headerName: 'Region', width: 130 },
  { field: 'assignedVendor', headerName: 'Assigned Vendor', width: 150 },
  {
    field: 'lastVisit',
    headerName: 'Last Visit',
    width: 160,
    valueFormatter: (params) => {
      if (!params.value) return '';
      return new Date(params.value).toLocaleString();
    },
  },
  { field: 'status', headerName: 'Status', width: 130 },
];

export default function MarketList() {
  const [markets, setMarkets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [confirmDeleteDialogOpen, setConfirmDeleteDialogOpen] = useState(false);
  const [marketToDelete, setMarketToDelete] = useState(null);
  const [currentMarket, setCurrentMarket] = useState({
    id: null, // Ensure id is part of the state
    name: '',
    address: '',
    phone: '',
    region: '',
    assignedVendor: '',
    status: 'active'
  });

  useEffect(() => {
    fetchMarkets();
  }, []);

  const fetchMarkets = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('markets')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setMarkets(data || []);
    } catch (error) {
      console.error('Error fetching markets:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = (market = null) => {
    if (market) {
      // Ensure all fields exist in the state, even if null/undefined in the market object
      setCurrentMarket({
        id: market.id || null,
        name: market.name || '',
        address: market.address || '',
        phone: market.phone || '',
        region: market.region || '',
        assignedVendor: market.assignedVendor || '',
        status: market.status || 'active',
        // Add other fields if necessary, ensuring they exist in the initial state
      });
    } else {
      setCurrentMarket({
        id: null,
        name: '',
        address: '',
        phone: '',
        region: '',
        assignedVendor: '',
        status: 'active'
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setCurrentMarket({ // Reset current market on close
        id: null,
        name: '',
        address: '',
        phone: '',
        region: '',
        assignedVendor: '',
        status: 'active'
      });
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setCurrentMarket({
      ...currentMarket,
      [name]: value,
    });
  };

  const handleSaveMarket = async () => {
    try {
      // Validate required fields
      if (!currentMarket.name) {
        alert('Market name is required');
        return;
      }

      const marketData = {
        name: currentMarket.name,
        address: currentMarket.address || '',
        phone: currentMarket.phone || '',
        region: currentMarket.region || '',
        assignedVendor: currentMarket.assignedVendor || '',
        status: currentMarket.status || 'active'
      };

      let result;
      if (currentMarket.id) {
        // Update existing market
        const { id, ...updateData } = marketData; // Exclude id from update data
        result = await supabase
          .from('markets')
          .update(updateData)
          .eq('id', currentMarket.id);
      } else {
        // Create new market
        result = await supabase
          .from('markets')
          .insert([marketData]) // insert expects an array
          .select(); // Optionally select the inserted data if needed
      }

      if (result.error) {
        console.error('Error saving market:', result.error);
        alert(`Error saving market: ${result.error.message}`);
        return;
      }

      // Refresh market list
      fetchMarkets();
      handleCloseDialog();
    } catch (error) {
      console.error('Error saving market:', error);
      alert(`Error saving market: ${error.message}`);
    }
  };

  const openDeleteConfirm = (market) => {
    setMarketToDelete(market);
    setConfirmDeleteDialogOpen(true);
  };

  const closeDeleteConfirm = () => {
    setMarketToDelete(null);
    setConfirmDeleteDialogOpen(false);
  };

  const handleDeleteMarket = async () => {
    if (!marketToDelete || !marketToDelete.id) return;

    try {
      const { error } = await supabase
        .from('markets')
        .delete()
        .eq('id', marketToDelete.id);

      if (error) {
        console.error('Error deleting market:', error);
        alert(`Error deleting market: ${error.message}`);
        return;
      }

      // Refresh market list and close dialogs
      fetchMarkets();
      closeDeleteConfirm();
      handleCloseDialog(); // Close the edit/add dialog if it was open for the deleted item

    } catch (error) {
      console.error('Error deleting market:', error);
      alert(`Error deleting market: ${error.message}`);
    }
  };

  // Add action column for delete
  const actionColumn = {
    field: 'actions',
    headerName: 'Actions',
    sortable: false,
    width: 100,
    renderCell: (params) => {
      return (
        <IconButton onClick={(e) => {
          e.stopPropagation(); // prevent opening the edit dialog
          openDeleteConfirm(params.row);
        }} color="error">
          <DeleteIcon />
        </IconButton>
      );
    },
  };

  return (
    <Box sx={{ height: 600, width: '100%' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5" component="h2">
          Markets
        </Typography>
        <Button 
          variant="contained" 
          color="primary"
          onClick={() => handleOpenDialog()}
        >
          Add New Market
        </Button>
      </Box>
      <DataGrid
        rows={markets}
        columns={[...columns, actionColumn]} // Add action column here
        pageSize={10}
        rowsPerPageOptions={[10]}
        loading={loading}
        disableSelectionOnClick
        onRowClick={(params) => handleOpenDialog(params.row)}
      />

      {/* Edit/Add Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog}>
        <DialogTitle>
          {currentMarket.id ? 'Edit Market' : 'Add New Market'}
        </DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            name="name"
            label="Market Name"
            type="text"
            fullWidth
            value={currentMarket.name}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            name="address"
            label="Address"
            type="text"
            fullWidth
            value={currentMarket.address || ''}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            name="phone"
            label="Phone"
            type="text"
            fullWidth
            value={currentMarket.phone || ''}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            name="region"
            label="Region"
            type="text"
            fullWidth
            value={currentMarket.region || ''}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            name="assignedVendor"
            label="Assigned Vendor"
            type="text"
            fullWidth
            value={currentMarket.assignedVendor || ''}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <FormControl fullWidth margin="dense" sx={{ mb: 2 }}>
            <InputLabel id="status-label">Status</InputLabel>
            <Select
              labelId="status-label"
              name="status"
              value={currentMarket.status || 'active'}
              label="Status"
              onChange={handleInputChange}
            >
              <MenuItem value="active">Active</MenuItem>
              <MenuItem value="inactive">Inactive</MenuItem>
              <MenuItem value="pending">Pending</MenuItem>
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button onClick={handleSaveMarket} color="primary">
            Save
          </Button>
        </DialogActions>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={confirmDeleteDialogOpen}
        onClose={closeDeleteConfirm}
        aria-labelledby="alert-dialog-title"
        aria-describedby="alert-dialog-description"
      >
        <DialogTitle id="alert-dialog-title">{"Confirm Deletion"}</DialogTitle>
        <DialogContent>
          <Typography id="alert-dialog-description">
            Are you sure you want to delete the market "{marketToDelete?.name}"? This action cannot be undone.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={closeDeleteConfirm}>Cancel</Button>
          <Button onClick={handleDeleteMarket} color="error" autoFocus>
            Delete
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}