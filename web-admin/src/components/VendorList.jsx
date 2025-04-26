import { useState, useEffect } from 'react';
import { Box, Button, Typography, Dialog, DialogTitle, DialogContent, DialogActions, TextField, FormControl, InputLabel, Select, MenuItem, Checkbox, Card, CardContent, CardActions, Grid } from '@mui/material';
import { supabase } from '../lib/supabase';

const columns = [
  { field: 'id', headerName: 'ID', width: 90 },
  { field: 'email', headerName: 'Email', width: 200 },
  { field: 'full_name', headerName: 'Full Name', width: 200 },
  { field: 'phone', headerName: 'Phone', width: 130 },
  { 
    field: 'region_id', 
    headerName: 'Region', 
    width: 130,
    valueGetter: (params) => params.row.region?.name || 'Unknown',
  },
  {
    field: 'created_at',
    headerName: 'Created At',
    width: 160,
    valueFormatter: (params) => {
      if (!params.value) return '';
      return new Date(params.value).toLocaleString();
    },
  },
  {
    field: 'actions',
    headerName: 'Actions',
    width: 250,
    renderCell: (params) => (
      <Box sx={{ display: 'flex', gap: 1 }}>
        <Button
          variant="contained"
          size="small"
          onClick={(e) => {
            e.stopPropagation();
            handleViewProfile(params.row);
          }}
        >
          Profile
        </Button>
        <Button
          variant="contained"
          color="secondary"
          size="small"
          onClick={(e) => {
            e.stopPropagation();
            handleCreateVendorAccount(params.row.id);
          }}
        >
          Account
        </Button>
        <Button
          variant="contained"
          color="error"
          size="small"
          onClick={(e) => {
            e.stopPropagation();
            handleDeleteVendor(params.row.id);
          }}
        >
          Delete
        </Button>
      </Box>
    ),
  },
];

export default function VendorList() {
  const [vendors, setVendors] = useState([]);
  const [regions, setRegions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [profileDialog, setProfileDialog] = useState(false);
  const [selectedVendor, setSelectedVendor] = useState(null);
  const [currentVendor, setCurrentVendor] = useState({
    email: '',
    full_name: '',
    phone: '',
    region_id: null
  });
  const [createAccount, setCreateAccount] = useState(false);
  const [password, setPassword] = useState('');

  useEffect(() => {
    fetchVendors();
    fetchRegions();
  }, []);

  const fetchVendors = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('vendors')
        .select('*, region:region_id(id, name)')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setVendors(data || []);
    } catch (error) {
      console.error('Error fetching vendors:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchRegions = async () => {
    try {
      const { data, error } = await supabase
        .from('regions')
        .select('id, name')
        .order('name');

      if (error) throw error;
      setRegions(data || []);
    } catch (error) {
      console.error('Error fetching regions:', error);
    }
  };

  const handleOpenDialog = (vendor = null) => {
    if (vendor) {
      setCurrentVendor({
        ...vendor,
        region_id: vendor.region_id || null
      });
      setCreateAccount(false); // Don't create account for existing vendors through this dialog
    } else {
      setCurrentVendor({
        email: '',
        full_name: '',
        phone: '',
        region_id: null
      });
      setCreateAccount(false); // Reset create account checkbox
      setPassword(''); // Reset password field
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setCurrentVendor({
      ...currentVendor,
      [name]: value,
    });
  };

  const handleCreateVendorAccount = async (vendorId) => {
    try {
      setLoading(true);
      
      // Get vendor details
      const { data: vendor, error: vendorError } = await supabase
        .from('vendors')
        .select('*, auth_user_id')
        .eq('id', vendorId)
        .single();

      if (vendorError) throw new Error('Failed to fetch vendor details');
      if (!vendor) throw new Error('Vendor not found');
      
      // Check if vendor already has an account
      if (vendor.auth_user_id) {
        throw new Error('Vendor already has an account');
      }

      if (!vendor.email) {
        throw new Error('Vendor must have an email to create an account');
      }

      // Generate a secure temporary password
      const tempPassword = Math.random().toString(36).slice(-8);

      // Create auth account
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: vendor.email,
        password: tempPassword,
        options: {
          emailRedirectTo: window.location.origin
        }
      });

      if (authError) throw authError;
      if (!authData?.user?.id) throw new Error('Failed to create auth account');

      // Update vendor with auth user ID
      const { error: updateError } = await supabase
        .from('vendors')
        .update({ 
          auth_user_id: authData.user.id,
          updated_at: new Date().toISOString() 
        })
        .eq('id', vendorId);

      if (updateError) throw updateError;

      // Refresh vendor list
      await fetchVendors();
      
      alert(`Account created successfully!\nTemporary password: ${tempPassword}\nPlease share this with the vendor securely.`);
    } catch (error) {
      console.error('Error creating vendor account:', error);
      alert(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteVendor = async (vendorId) => {
    if (!confirm('Are you sure you want to delete this vendor?')) return;
    
    try {
      // First check if vendor has an auth account
      const { data: vendor, error: vendorError } = await supabase
        .from('vendors')
        .select('auth_user_id')
        .eq('id', vendorId)
        .single();

      if (vendorError) throw vendorError;

      // Delete auth account if exists
      if (vendor.auth_user_id) {
        const { error: authError } = await supabase.auth.admin.deleteUser(
          vendor.auth_user_id
        );
        if (authError) throw authError;
      }

      // Delete vendor record
      const { error } = await supabase
        .from('vendors')
        .delete()
        .eq('id', vendorId);

      if (error) throw error;
      
      alert('Vendor deleted successfully');
      fetchVendors(); // Refresh the list
    } catch (error) {
      console.error('Error deleting vendor:', error);
      alert(`Error deleting vendor: ${error.message}`);
    }
  };

  const handleSaveVendor = async () => {
    try {
      // Validate required fields
      if (!currentVendor.full_name) {
        alert('Full Name is required');
        return;
      }

      // Validate email for account creation
      if (!currentVendor.id && createAccount && !currentVendor.email) {
        alert('Email is required when creating a user account');
        return;
      }
      
      // Validate password for account creation
      if (!currentVendor.id && createAccount && !password) {
        alert('Password is required when creating a user account');
        return;
      }

      const vendorData = {
        email: currentVendor.email,
        full_name: currentVendor.full_name,
        phone: currentVendor.phone || '',
        region_id: currentVendor.region_id
      };

      let result;
      if (currentVendor.id) {
        // Update existing vendor
        result = await supabase
          .from('vendors')
          .update(vendorData)
          .eq('id', currentVendor.id);
      } else {
        // Create new vendor
        result = await supabase
          .from('vendors')
          .insert(vendorData)
          .select();

        if (result.error) {
          console.error('Error saving vendor:', result.error);
          alert(`Error saving vendor: ${result.error.message}`);
          return;
        }

        // Account creation logic removed from here. It is handled by the 'Account' button.
      }

      // Check for errors after insert/update
      if (result.error) {
        console.error('Error saving vendor:', result.error);
        alert(`Error saving vendor: ${result.error.message}`);
        return;
      }
      
      // Refresh vendor list
      fetchVendors();
      handleCloseDialog();
    } catch (error) {
      console.error('Error saving vendor:', error);
      alert(`Error saving vendor: ${error.message}`);
    }
  };

  // Removed misplaced/duplicate code block
  
  const handleViewProfile = (vendor) => {
  setSelectedVendor(vendor);
  setProfileDialog(true);
  setOpenDialog(false); // Close any open edit dialog
};

// Removed duplicate handleDeleteVendor function definition.

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5" component="h2">
          Vendors
        </Typography>
        <Button 
          variant="contained" 
          color="primary"
          onClick={() => handleOpenDialog()}
        >
          Add New Vendor
        </Button>
      </Box>
      <Grid container spacing={3}>
        {vendors.map((vendor) => (
          <Grid item xs={12} sm={6} md={4} key={vendor.id}>
            <Card>
              <CardContent>
                <Typography variant="h6">{vendor.full_name}</Typography>
                <Typography variant="body2" color="text.secondary">
                  {vendor.email}
                </Typography>
                <Typography variant="body2">
                  Phone: {vendor.phone}
                </Typography>
                <Typography variant="body2">
                  Region: {vendor.region?.name || 'Unknown'}
                </Typography>
                <Typography variant="caption">
                  Joined: {new Date(vendor.created_at).toLocaleString()}
                </Typography>
              </CardContent>
              <CardActions>
                <Button 
                  size="small" 
                  onClick={() => handleViewProfile(vendor)}
                >
                  Profile
                </Button>
                <Button 
                  size="small" 
                  color="secondary"
                  onClick={() => handleCreateVendorAccount(vendor.id)}
                >
                  Account
                </Button>
                <Button 
                  size="small" 
                  color="error"
                  onClick={() => handleDeleteVendor(vendor.id)}
                >
                  Delete
                </Button>
              </CardActions>
            </Card>
          </Grid>
        ))}
      </Grid>

      <Dialog open={openDialog} onClose={handleCloseDialog}>
        <DialogTitle>
          {currentVendor.id ? 'Edit Vendor' : 'Add New Vendor'}
        </DialogTitle>
        <DialogContent>
          {(!currentVendor.id && createAccount) || currentVendor.id ? (
            <>
              <TextField
                autoFocus
                margin="dense"
                name="email"
                label="Email"
                type="email"
                fullWidth
                value={currentVendor.email || ''}
                onChange={handleInputChange}
                sx={{ mb: 2 }}
                required={createAccount}
                helperText={!currentVendor.id && createAccount ? "Will be used for account login" : ""}
              />
              {!currentVendor.id && createAccount && (
                <TextField
                  margin="dense"
                  name="password"
                  label="Password"
                  type="password"
                  fullWidth
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  sx={{ mb: 2, display: createAccount ? 'block' : 'none' }}
                  required
                  helperText="Password for vendor account login"
                />
              )}
            </>
          ) : null}
          <TextField
            margin="dense"
            name="full_name"
            label="Full Name"
            type="text"
            fullWidth
            value={currentVendor.full_name || ''}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
            required
          />
          <TextField
            margin="dense"
            name="phone"
            label="Phone"
            type="text"
            fullWidth
            value={currentVendor.phone || ''}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <FormControl fullWidth margin="dense" sx={{ mb: 2 }}>
            <InputLabel id="region-label">Region</InputLabel>
            <Select
              labelId="region-label"
              name="region_id"
              value={currentVendor.region_id || ''}
              label="Region"
              onChange={handleInputChange}
            >
              <MenuItem value="">None</MenuItem>
              {regions.map((region) => (
                <MenuItem key={region.id} value={region.id}>
                  {region.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          
          {!currentVendor.id && (
            <FormControl fullWidth margin="dense" sx={{ mb: 2 }}>
              <Box display="flex" alignItems="center">
                <Checkbox
                  checked={createAccount}
                  onChange={(e) => setCreateAccount(e.target.checked)}
                  name="createAccount"
                  color="primary"
                />
                <Typography>Create user account for this vendor</Typography>
              </Box>
            </FormControl>
          )}
          
          {/* Password field moved under email field */}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button onClick={handleSaveVendor} color="primary">
            Save
          </Button>
        </DialogActions>
      </Dialog>

      {/* Vendor Profile Dialog */}
      <Dialog open={profileDialog} onClose={() => setProfileDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle>Vendor Profile</DialogTitle>
        <DialogContent>
          {selectedVendor && (
            <Box sx={{ mt: 2 }}>
              <Typography variant="h6">{selectedVendor.full_name}</Typography>
              <Typography>Email: {selectedVendor.email}</Typography>
              <Typography>Phone: {selectedVendor.phone}</Typography>
              <Typography>Region: {selectedVendor.region?.name || 'Unknown'}</Typography>
              <Typography>Joined: {new Date(selectedVendor.created_at).toLocaleString()}</Typography>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setProfileDialog(false)}>Close</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}