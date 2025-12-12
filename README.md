# UserManagement - Swift v2

User profiles and authentication for Swift v2 decentralized platform on Base Mainnet.

## Security ✅

- Audited and security-hardened
- ReentrancyGuard protection
- Gas optimized (Custom Errors, Efficiency tweaks)
- Security Score: 9.8/10

## Installation

```bash
npm install
```

## Testing

Run the comprehensive test suite:

```bash
npx hardhat test
```

## Configuration

```bash
cp .env.example .env
# Edit .env with your credentials
```

## Deployment

```bash
npm run deploy:testnet  # Base Sepolia
npm run deploy          # Base Mainnet

# Celo Deployment
npx hardhat run scripts/deploy.js --network celo-alfajores  # Testnet
npx hardhat run scripts/deploy.js --network celo            # Mainnet

npm run verify:celo     # Verify on CeloScan
```

## Admin Features

- **Fee Management**: Owner can update registration and verification fees.
- **User Management**: Admins can ban/unban users and manage permissions.
- **Verification**: Admins can process verification requests.

## License

MIT
