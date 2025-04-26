import { useState, useEffect } from 'react';
import { Grid, Paper, Typography } from '@mui/material';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { collection, query, orderBy, limit, getDocs } from 'firebase/firestore';

// Mock data - replace with real data from Firebase
const mockData = [
  { name: 'Mon', sales: 4000 },
  { name: 'Tue', sales: 3000 },
  { name: 'Wed', sales: 2000 },
  { name: 'Thu', sales: 2780 },
  { name: 'Fri', sales: 1890 },
  { name: 'Sat', sales: 2390 },
  { name: 'Sun', sales: 3490 },
];

export default function Dashboard() {
  const [stats, setStats] = useState({
    totalVendors: 0,
    activeMarkets: 0,
    todaySales: 0,
    totalProducts: 0,
  });

  useEffect(() => {
    // TODO: Fetch real-time stats from Firebase
    // This is where you'll implement the actual data fetching
    setStats({
      totalVendors: 12,
      activeMarkets: 45,
      todaySales: 1250,
      totalProducts: 28,
    });
  }, []);

  return (
    <Grid container spacing={3}>
      {/* Stats Overview */}
      <Grid item xs={12} md={3}>
        <Paper sx={{ p: 2, display: 'flex', flexDirection: 'column', height: 140 }}>
          <Typography component="h2" variant="h6" color="primary" gutterBottom>
            Total Vendors
          </Typography>
          <Typography component="p" variant="h4">
            {stats.totalVendors}
          </Typography>
        </Paper>
      </Grid>
      <Grid item xs={12} md={3}>
        <Paper sx={{ p: 2, display: 'flex', flexDirection: 'column', height: 140 }}>
          <Typography component="h2" variant="h6" color="primary" gutterBottom>
            Active Markets
          </Typography>
          <Typography component="p" variant="h4">
            {stats.activeMarkets}
          </Typography>
        </Paper>
      </Grid>
      <Grid item xs={12} md={3}>
        <Paper sx={{ p: 2, display: 'flex', flexDirection: 'column', height: 140 }}>
          <Typography component="h2" variant="h6" color="primary" gutterBottom>
            Today's Sales
          </Typography>
          <Typography component="p" variant="h4">
            ${stats.todaySales}
          </Typography>
        </Paper>
      </Grid>
      <Grid item xs={12} md={3}>
        <Paper sx={{ p: 2, display: 'flex', flexDirection: 'column', height: 140 }}>
          <Typography component="h2" variant="h6" color="primary" gutterBottom>
            Total Products
          </Typography>
          <Typography component="p" variant="h4">
            {stats.totalProducts}
          </Typography>
        </Paper>
      </Grid>

      {/* Sales Chart */}
      <Grid item xs={12}>
        <Paper sx={{ p: 2 }}>
          <Typography component="h2" variant="h6" color="primary" gutterBottom>
            Weekly Sales
          </Typography>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart
              data={mockData}
              margin={{
                top: 16,
                right: 16,
                bottom: 0,
                left: 24,
              }}
            >
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Line
                type="monotone"
                dataKey="sales"
                stroke="#1976d2"
                strokeWidth={2}
              />
            </LineChart>
          </ResponsiveContainer>
        </Paper>
      </Grid>
    </Grid>
  );
}