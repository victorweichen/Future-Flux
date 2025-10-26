# Deployment Guide

## Prerequisites

- Node.js >= 18.0.0
- npm >= 9.0.0
- Access to an Ethereum network (testnet or mainnet)
- Wallet with ETH for gas fees

## Smart Contract Deployment

### Local Network (Hardhat)

1. Navigate to contracts package:
```bash
cd packages/contracts
```

2. Install dependencies:
```bash
npm install
```

3. Start local Hardhat node:
```bash
npm run node
```

4. Deploy contracts (in a new terminal):
```bash
npm run deploy
```

5. Save the deployed contract addresses for use in frontend/backend

### Testnet Deployment

1. Update `hardhat.config.js` with network configuration:

```javascript
module.exports = {
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
}
```

2. Create `.env` file:
```env
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
PRIVATE_KEY=your_private_key_here
```

3. Deploy to testnet:
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### Mainnet Deployment

⚠️ **Warning**: Deploying to mainnet involves real costs and risks.

1. Ensure comprehensive testing is complete
2. Conduct security audits
3. Update network configuration for mainnet
4. Deploy with extra caution:
```bash
npx hardhat run scripts/deploy.js --network mainnet
```

## Frontend Deployment

### Vercel (Recommended)

1. Install Vercel CLI:
```bash
npm install -g vercel
```

2. Navigate to frontend:
```bash
cd packages/frontend
```

3. Deploy:
```bash
vercel
```

4. Set environment variables in Vercel dashboard:
```
NEXT_PUBLIC_CHAIN_ID=1
NEXT_PUBLIC_RPC_URL=your_rpc_url
NEXT_PUBLIC_DEX_CONTRACT_ADDRESS=deployed_address
```

### Manual Deployment

1. Build the frontend:
```bash
cd packages/frontend
npm run build
```

2. Deploy the `.next` directory to your hosting service

## Backend Deployment

### Using PM2 (Production)

1. Install PM2:
```bash
npm install -g pm2
```

2. Start the backend:
```bash
cd packages/backend
pm2 start src/index.js --name future-flux-api
```

3. Configure PM2 to restart on system boot:
```bash
pm2 startup
pm2 save
```

### Using Docker

1. Create `Dockerfile` in backend directory:
```dockerfile
FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3001
CMD ["node", "src/index.js"]
```

2. Build and run:
```bash
docker build -t future-flux-backend .
docker run -p 3001:3001 future-flux-backend
```

### Environment Configuration

Set the following environment variables:

```env
PORT=3001
NODE_ENV=production
RPC_URL=your_rpc_url
CHAIN_ID=1
DEX_CONTRACT_ADDRESS=deployed_address
MONGODB_URI=your_mongodb_uri
```

## Post-Deployment

### Verification

1. Verify smart contracts on Etherscan:
```bash
npx hardhat verify --network mainnet DEPLOYED_ADDRESS
```

2. Test all functionality:
- Trading pairs creation
- Liquidity addition/removal
- Token swaps
- API endpoints
- Frontend interactions

### Monitoring

Set up monitoring for:
- Contract events
- API uptime
- Transaction success rates
- Error logs

### Security

1. Run final security checks
2. Set up monitoring alerts
3. Prepare incident response plan
4. Keep private keys secure
5. Enable multi-sig for contract ownership

## Scaling Considerations

### Database

For production, use a managed MongoDB service:
- MongoDB Atlas
- AWS DocumentDB

### API

Consider:
- Load balancing
- Rate limiting
- Caching (Redis)
- CDN for static assets

### Blockchain

- Use reliable RPC providers (Infura, Alchemy)
- Implement fallback RPC endpoints
- Monitor gas prices
- Set up event indexing

## Maintenance

### Updates

1. Test updates on testnet first
2. Use contract upgrade patterns if needed
3. Maintain backward compatibility
4. Document all changes

### Backups

- Regular database backups
- Contract state snapshots
- Configuration backups
- Key management system

## Rollback Plan

Have a plan ready for:
1. Contract bugs or exploits
2. Frontend issues
3. API failures
4. Database corruption

Include:
- Emergency contacts
- Backup deployments
- Communication templates
- Recovery procedures
