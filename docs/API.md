# API Documentation

## Base URL

```
http://localhost:3001/api
```

## Endpoints

### Health Check

**GET** `/health`

Check if the API is running.

**Response:**
```json
{
  "status": "ok",
  "message": "Future Flux API is running"
}
```

### Get Trading Pairs

**GET** `/pairs`

Retrieve all active trading pairs.

**Response:**
```json
{
  "pairs": [
    {
      "id": 0,
      "tokenA": {
        "symbol": "RET",
        "name": "Real Estate Token"
      },
      "tokenB": {
        "symbol": "CMT",
        "name": "Commodity Token"
      },
      "reserveA": "1000000",
      "reserveB": "1000000",
      "active": true
    }
  ]
}
```

### Get Platform Statistics

**GET** `/stats`

Get overall platform statistics.

**Response:**
```json
{
  "totalValueLocked": "2000000",
  "totalVolume24h": "150000",
  "totalTrades": 1234,
  "activePairs": 1
}
```

## Future Endpoints (To Be Implemented)

### Get Pair Details

**GET** `/pairs/:pairId`

Get detailed information about a specific trading pair.

### Get Transaction History

**GET** `/transactions`

Get recent transactions across all pairs.

**Query Parameters:**
- `limit`: Number of transactions to return (default: 50)
- `offset`: Pagination offset
- `pairId`: Filter by specific pair

### Get User Portfolio

**GET** `/users/:address/portfolio`

Get a user's liquidity positions and balances.

### Get Token Information

**GET** `/tokens/:address`

Get detailed information about a specific RWA token.

## Error Responses

All endpoints may return the following error responses:

**400 Bad Request**
```json
{
  "error": "Invalid request parameters"
}
```

**404 Not Found**
```json
{
  "error": "Resource not found"
}
```

**500 Internal Server Error**
```json
{
  "error": "Something went wrong!"
}
```

## Rate Limiting

Currently no rate limiting is implemented. This will be added in future versions.

## Authentication

No authentication is required for read-only endpoints. Future write endpoints will require wallet signature authentication.
