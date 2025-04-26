import { useState, useEffect } from 'react';
import { DataGrid } from '@mui/x-data-grid';
import { Box, Button, Typography, Dialog, DialogTitle, DialogContent, DialogActions, TextField, FormControlLabel, Switch, IconButton } from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import EditIcon from '@mui/icons-material/Edit';
import { supabase } from '../lib/supabase';

const columns = [
  { field: 'id', headerName: 'ID', width: 90 },
  { field: 'name', headerName: 'Name', width: 200 },
  { field: 'description', headerName: 'Description', width: 250 },
  { 
    field: 'price', 
    headerName: 'Price', 
    width: 130,
    valueFormatter: (params) => {
      if (params.value == null) return '';
      return `$${params.value.toFixed(2)}`;
    },
  },
  { 
    field: 'is_active', 
    headerName: 'Active', 
    width: 130,
    type: 'boolean',
  },
  { 
    field: 'created_at', 
    headerName: 'Created At', 
    width: 180,
    valueFormatter: (params) => {
      if (!params.value) return '';
      return new Date(params.value).toLocaleString();
    },
  },
  {
    field: 'actions',
    headerName: 'Actions',
    width: 150,
    sortable: false,
    disableColumnMenu: true,
    renderCell: (params) => (
      <Box sx={{ display: 'flex', gap: 1 }}>
        <IconButton
          aria-label="edit"
          size="small"
          onClick={(e) => {
            e.stopPropagation(); // Prevent row click event
            handleOpenDialog(params.row);
          }}
        >
          <EditIcon />
        </IconButton>
        <IconButton
          aria-label="delete"
          size="small"
          color="error"
          onClick={(e) => {
            e.stopPropagation(); // Prevent row click event
            handleOpenDeleteConfirm(params.row.id);
          }}
        >
          <DeleteIcon />
        </IconButton>
      </Box>
    ),
  },
];

export default function ProductList() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [confirmDeleteDialog, setConfirmDeleteDialog] = useState(false);
  const [productToDelete, setProductToDelete] = useState(null);
  const [currentProduct, setCurrentProduct] = useState({
    name: '',
    description: '',
    price: 0,
    is_active: true,
  });

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setProducts(data || []);
    } catch (error) {
      console.error('Error fetching products:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = (product = null) => {
    if (product) {
      setCurrentProduct(product);
    } else {
      setCurrentProduct({
        name: '',
        description: '',
        price: 0,
        is_active: true,
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
  };

  const handleOpenDeleteConfirm = (productId) => {
    setProductToDelete(productId);
    setConfirmDeleteDialog(true);
  };

  const handleCloseDeleteConfirm = () => {
    setProductToDelete(null);
    setConfirmDeleteDialog(false);
  };

  const handleDeleteProduct = async () => {
    if (!productToDelete) return;
    try {
      setLoading(true);
      const { error } = await supabase
        .from('products')
        .delete()
        .eq('id', productToDelete);

      if (error) throw error;

      // Refresh product list
      fetchProducts();
      handleCloseDeleteConfirm();
    } catch (error) {
      console.error('Error deleting product:', error);
      // Add user feedback here (e.g., snackbar)
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value, checked, type } = e.target;
    setCurrentProduct({
      ...currentProduct,
      [name]: type === 'checkbox' ? checked : value,
    });
  };

  const handleSaveProduct = async () => {
    try {
      const productData = {
        name: currentProduct.name,
        description: currentProduct.description,
        price: parseFloat(currentProduct.price),
        is_active: currentProduct.is_active,
      };

      let result;
      if (currentProduct.id) {
        // Update existing product
        result = await supabase
          .from('products')
          .update(productData)
          .eq('id', currentProduct.id)
          .select();
      } else {
        // Create new product
        result = await supabase
          .from('products')
          .insert(productData)
          .select();
      }

      if (result.error) throw result.error;
      
      // Refresh product list
      fetchProducts();
      handleCloseDialog();
    } catch (error) {
      console.error('Error saving product:', error);
    }
  };

  return (
    <Box sx={{ height: 600, width: '100%' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5" component="h2">
          Products
        </Typography>
        <Button 
          variant="contained" 
          color="primary" 
          onClick={() => handleOpenDialog()}
        >
          Add Product
        </Button>
      </Box>

      <DataGrid
        rows={products}
        columns={columns} // Pass the updated columns definition here
        pageSize={10}
        rowsPerPageOptions={[10]}
        loading={loading}
        disableSelectionOnClick
        // Removed onRowClick to prevent conflict with action buttons
        // onRowClick={(params) => handleOpenDialog(params.row)}
      />

      {/* Add/Edit Product Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog}>
        <DialogTitle>
          {currentProduct.id ? 'Edit Product' : 'Add New Product'}
        </DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            name="name"
            label="Product Name"
            type="text"
            fullWidth
            value={currentProduct.name}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            name="description"
            label="Description"
            type="text"
            fullWidth
            multiline
            rows={3}
            value={currentProduct.description || ''}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            name="price"
            label="Price"
            type="number"
            fullWidth
            value={currentProduct.price}
            onChange={handleInputChange}
            sx={{ mb: 2 }}
          />
          <FormControlLabel
            control={
              <Switch
                checked={currentProduct.is_active}
                onChange={handleInputChange}
                name="is_active"
              />
            }
            label="Active"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button onClick={handleSaveProduct} color="primary">
            Save
          </Button>
        </DialogActions>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={confirmDeleteDialog}
        onClose={handleCloseDeleteConfirm}
        aria-labelledby="alert-dialog-title"
        aria-describedby="alert-dialog-description"
      >
        <DialogTitle id="alert-dialog-title">Confirm Deletion</DialogTitle>
        <DialogContent>
          <Typography>Are you sure you want to delete this product? This action cannot be undone.</Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDeleteConfirm}>Cancel</Button>
          <Button onClick={handleDeleteProduct} color="error" autoFocus>
            Delete
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}