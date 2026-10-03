# Tranche Protocol

Deterministic milestone escrow vault for onchain deliverables. Replaces human attestations and third-party oracles with raw EVM state transitions (`extcodehash`) and absolute unix timestamp cutoffs.

Targeted for the Arbitrum Open House Singapore Online Buildathon (October 4, 2026).

## Architecture

- **Vault (`TrancheVault.sol`)**: Single immutable, non-upgradeable contract managing deterministic milestone tranches.
- **Accounting**: Strict internal ledger via `totalAllocated[token]` preventing donation attacks and decoupling internal liability from raw `balanceOf`.
- **Validation**: Raw EVM `extcodehash` inspection to verify onchain deployment without oracles or trusted signatories.

## Core Invariants

1. **Solvency**: `totalAllocated[token] <= IERC20(token).balanceOf(address(vault))` under all conditions.
2. **Terminal State Exclusivity**: A tranche ID transitions strictly from `ACTIVE` to either `CLAIMED` or `REFUNDED`; never both.
3. **Clawback Liveness**: For any tranche with `status == ACTIVE` and `block.timestamp > deadline`, `clawback()` will execute without reverting.

## Project Structure

```
├── .agent/
│   └── rules.md                  # Autonomous agent execution constraints and invariant guards
├── .github/
│   └── workflows/
│       └── test.yml              # Automated CI running forge test and static checks
├── abi/
│   └── TrancheVault.json         # Compiled ABI for TrancheVault
├── deployments/
│   ├── 46630.json                # Robinhood testnet contract deployment manifest
│   └── 421614.json               # Arbitrum Sepolia contract deployment manifest
├── docs/
│   └── INTEGRATION.md            # Front-end integration, error catalog, event specifications
├── lib/
│   ├── forge-std/                # Foundry standard library
│   └── openzeppelin-contracts/   # OpenZeppelin Contracts v5.x
├── script/
│   └── DeployTranche.s.sol       # Deployment script for TrancheVault and MockUSDG
├── src/
│   ├── interfaces/
│   │   └── ITrancheVault.sol     # Structs, custom errors, events, and external signatures
│   ├── mocks/
│   │   └── MockUSDG.sol          # 6-decimal ERC-20 mock token for testnet
│   └── TrancheVault.sol          # Core immutable vault contract
├── test/
│   ├── helpers/
│   │   ├── MockDeliverable.sol   # Deterministic bytecode target for claim tests
│   │   ├── MockFeeToken.sol      # Fee-on-transfer token rejecting test helper
│   │   ├── MockFrozenToken.sol   # Freeze-simulation token test helper
│   │   └── MaliciousToken.sol    # Re-entrancy attack token for nonReentrant tests
│   ├── invariants/
│   │   ├── InvariantHandler.sol  # Stateful fuzzing handler and ghost state
│   │   └── TrancheInvariants.t.sol # Stateful invariant assertions (I1-I4)
│   └── TrancheVault.t.sol        # Unit & branch test suite (80 tests, 100% coverage)
├── .env.example                  # Template for RPC endpoints and deployer private key
├── .gitignore                    # Standard Foundry gitignore (out/, cache/, .env)
├── foundry.toml                  # Solc 0.8.24, Cancun, optimizer 200, invariant settings
├── LICENSE                       # MIT License
├── README.md                     # Architecture, threat model, invariant specs, verification steps
└── slither.config.json           # Static analysis configuration and remapping paths
```

## Verification & Testing

```bash
# Build contracts
forge build

# Run unit tests
forge test -vvv

# Run stateful fuzz invariant suite
forge test --match-test invariant -vvv
```

## Links

- **Integration Guide & Demo Recipe**: [`docs/INTEGRATION.md`](docs/INTEGRATION.md)
- **Live Demo Proof (Robinhood Testnet `46630`)**: [`demo/demo-46630.md`](demo/demo-46630.md)
- **Live Demo Proof (Arbitrum Sepolia `421614`)**: [`demo/demo-421614.md`](demo/demo-421614.md)
- **Live Demo Flow Script**: [`script/DemoFlow.s.sol`](script/DemoFlow.s.sol)
- **Demo Deliverable Helper**: [`script/helpers/DemoDeliverable.sol`](script/helpers/DemoDeliverable.sol)
- **Robinhood Testnet Manifest**: [`deployments/46630.json`](deployments/46630.json)
- **Arbitrum Sepolia Manifest**: [`deployments/421614.json`](deployments/421614.json)