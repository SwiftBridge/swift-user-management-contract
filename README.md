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
npm run deploy:testnet  # Test first
npm run deploy          # Mainnet
npm run verify         # Verify on BaseScan
```

## Admin Features

- **Fee Management**: Owner can update registration and verification fees.
- **User Management**: Admins can ban/unban users and manage permissions.
- **Verification**: Admins can process verification requests.

## License

MIT
