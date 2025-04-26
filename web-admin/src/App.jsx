import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { useState } from 'react';

// Layout components
import Dashboard from './components/Dashboard';
import Login from './components/Login';
import Layout from './components/Layout';
import MarketList from './components/MarketList';
import VendorList from './components/VendorList';
import ProductList from './components/ProductList';
import SalesList from './components/SalesList';

// Theme configuration
const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
    background: {
      default: '#f5f5f5',
    },
  },
});

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <Routes>
          <Route path="/login" element={<Login setIsAuthenticated={setIsAuthenticated} />} />
          <Route
            path="/*"
            element={
              isAuthenticated ? (
                <Layout>
                  <Routes>
                    <Route path="/" element={<Dashboard />} />
                    <Route path="/markets" element={<MarketList />} />
                    <Route path="/vendors" element={<VendorList />} />
                    <Route path="/products" element={<ProductList />} />
                    <Route path="/sales" element={<SalesList />} />
                    {/* Add more routes here */}
                  </Routes>
                </Layout>
              ) : (
                <Navigate to="/login" replace />
              )
            }
          />
        </Routes>
      </Router>
    </ThemeProvider>
  );
}

export default App;