# Frontend Guide

## Technology Stack

- **Framework**: Next.js 14 (App Router)
- **UI Library**: React 18
- **Styling**: Tailwind CSS
- **Language**: TypeScript
- **Web3**: ethers.js v6 (ready for integration)

## Project Structure

```
packages/frontend/
├── app/                    # Next.js app directory
│   ├── layout.tsx         # Root layout
│   ├── page.tsx           # Home page
│   └── globals.css        # Global styles
├── components/            # Reusable React components
├── lib/                   # Utility functions and configurations
├── public/               # Static assets
├── next.config.js        # Next.js configuration
├── tailwind.config.js    # Tailwind CSS configuration
└── tsconfig.json         # TypeScript configuration
```

## Getting Started

### Development

1. Install dependencies:
```bash
cd packages/frontend
npm install
```

2. Start development server:
```bash
npm run dev
```

3. Open http://localhost:3000 in your browser

### Building for Production

```bash
npm run build
npm run start
```

## Key Features

### Current Implementation

- **Landing Page**: Attractive landing page with project overview
- **Responsive Design**: Works on desktop and mobile devices
- **Modern UI**: Clean, gradient-based design with Tailwind CSS
- **Feature Cards**: Highlighting key platform capabilities

### Planned Features

- **Wallet Connection**: Integration with MetaMask and other wallets
- **Trading Interface**: Token swap functionality
- **Liquidity Management**: Add/remove liquidity UI
- **Portfolio View**: User's positions and balances
- **Analytics Dashboard**: Charts and statistics

## Web3 Integration

The frontend is prepared for Web3 integration. To add wallet connectivity:

1. Install required packages:
```bash
npm install wagmi @rainbow-me/rainbowkit
```

2. Configure providers in `app/layout.tsx`
3. Add wallet connect button
4. Implement contract interactions using ethers.js

## Styling Guidelines

The project uses Tailwind CSS with a custom configuration:

- **Primary Colors**: Blue and purple gradients
- **Background**: Dark theme with gradient overlays
- **Typography**: Clean, modern font stack
- **Components**: Card-based layout with backdrop blur effects

## Component Development

Create new components in the `components/` directory:

```typescript
// components/ExampleComponent.tsx
export function ExampleComponent({ title }: { title: string }) {
  return (
    <div className="bg-white/10 rounded-lg p-4">
      <h2 className="text-xl font-bold">{title}</h2>
    </div>
  )
}
```

## State Management

For complex state management, consider adding:

- **Zustand**: Lightweight state management
- **React Query**: Server state management
- **Context API**: For global app state

## Environment Variables

Create a `.env.local` file for environment-specific configuration:

```env
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_RPC_URL=http://localhost:8545
NEXT_PUBLIC_DEX_CONTRACT_ADDRESS=
```

## Testing

To add testing:

```bash
npm install --save-dev @testing-library/react @testing-library/jest-dom jest
```

Create test files alongside components with `.test.tsx` extension.

## Deployment

The frontend can be deployed to:

- **Vercel** (recommended for Next.js)
- **Netlify**
- **AWS Amplify**
- Any static hosting service

Configure build command: `npm run build`
Configure output directory: `.next`

## Performance Optimization

- Use Next.js Image component for images
- Implement code splitting with dynamic imports
- Enable React Server Components where applicable
- Optimize bundle size with tree shaking

## Accessibility

- Use semantic HTML elements
- Add ARIA labels where needed
- Ensure keyboard navigation works
- Test with screen readers

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers
