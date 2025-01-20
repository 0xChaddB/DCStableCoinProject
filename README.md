

# 🚧👷 WORK IN PROGRESS 🚧⚠️ #


# GorillaStableCoin 🦍🍌💰

GorillaStableCoin (GSC) is an algorithmic stablecoin designed to maintain a **relative stability** pegged to $1.00. Built using cutting-edge blockchain technologies, GSC provides a robust mechanism for decentralized minting, leveraging collateralized assets and Chainlink price feeds to ensure reliability and transparency.

## Features

### 1. **Relative Stability** 🍌
- The stablecoin is **anchored** or **pegged** to **$1.00**.
- Utilizes **Chainlink Price Feeds** to ensure accurate and decentralized price data.
- Supports exchange functionality to seamlessly convert **ETH** and **BTC** into GSC, ensuring smooth usability across ecosystems.

### 2. **Stability Mechanism** 🦍
- GSC employs a **decentralized algorithmic minting process**.
- Users can mint GSC tokens only when providing **sufficient collateral**.
  - This ensures the value of the stablecoin is always backed by assets, protecting it from volatility.

### 3. **Collateral** 💰
- GSC uses **exogenous collateral** (external crypto assets) to back its value.
- Supported collateral types include:
  - **wETH** (Wrapped Ethereum)
  - **wBTC** (Wrapped Bitcoin)

---

## Technology Stack
GorillaStableCoin is built on a robust foundation using the following tools and libraries:

### **Smart Contracts** 🍌
- **[OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)**
  - **ERC20** implementation for token standard compliance.
  - **ReentrancyGuard** to prevent reentrancy attacks and ensure contract security.

### **Oracles** 🦍
- **[Chainlink Price Feeds](https://chain.link/)**
  - For reliable, tamper-proof, and decentralized price data.

### **Development Framework** 💰
- **[Forge](https://book.getfoundry.sh/forge/)**
  - Used for efficient smart contract development, testing, and deployment.

---

## How It Works

### Minting GorillaStableCoin 🍌💰
1. **Collateralized Minting**:
   - Users can mint GSC tokens by providing wETH or wBTC as collateral.
   - The required collateral is dynamically calculated using Chainlink price feeds to maintain the $1.00 peg.

2. **Security Features**:
   - ReentrancyGuard prevents malicious actors from exploiting reentrancy vulnerabilities.

### Exchange Functionality 🦍
- Users can swap ETH or BTC for GSC seamlessly through a custom function in the smart contract, utilizing Chainlink price feeds for conversion rates.

---

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/0xChaddB/gorilla-stablecoin.git
   cd gorilla-stablecoin
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Compile the contracts:
   ```bash
   forge build
   ```

4. Run tests:
   ```bash
   forge test
   ```

---

## Deployment

1. Deploy the smart contracts to your desired blockchain network (e.g., Ethereum mainnet, testnets):
   ```bash
   forge script script/Deploy.s.sol:Deploy --rpc-url <NETWORK_RPC_URL> --private-key <PRIVATE_KEY>
   ```

2. Verify the contracts:
   ```bash
   forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_PATH> --chain-id <CHAIN_ID> --etherscan-api-key <API_KEY>
   ```

---

## Security Considerations 🦍🍌
- The smart contracts include protections against reentrancy attacks using OpenZeppelin's **ReentrancyGuard**.
- Chainlink oracles ensure tamper-proof price data, reducing the risk of manipulation.
- Thorough testing has been conducted to minimize vulnerabilities, but users should conduct their own due diligence.

---

## Future Improvements 🍌💰
- Support for additional collateral types (e.g., DAI, USDC).
- Enhanced governance mechanisms for adjusting the collateralization ratio and stability parameters.
- Integration with Layer 2 solutions for faster and cheaper transactions.

---

## License
This project is licensed under the [MIT License](LICENSE).

---

## Contributing
We welcome contributions from the community! Please open an issue or submit a pull request if you have suggestions or improvements.

---

## Contact 🦍
For questions or support, reach out to:
- **Email**: 0xChaddB@proton.me
- **GitHub Issues**: [Issues Page](https://github.com/0xChaddB/gorilla-stablecoin/issues)
