const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Future Flux API is running' });
});

app.get('/api/pairs', (req, res) => {
  // TODO: Fetch trading pairs from blockchain
  res.json({
    pairs: [
      {
        id: 0,
        tokenA: { symbol: 'RET', name: 'Real Estate Token' },
        tokenB: { symbol: 'CMT', name: 'Commodity Token' },
        reserveA: '1000000',
        reserveB: '1000000',
        active: true
      }
    ]
  });
});

app.get('/api/stats', (req, res) => {
  res.json({
    totalValueLocked: '2000000',
    totalVolume24h: '150000',
    totalTrades: 1234,
    activePairs: 1
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(PORT, () => {
  console.log(`Future Flux API server running on port ${PORT}`);
});

module.exports = app;
