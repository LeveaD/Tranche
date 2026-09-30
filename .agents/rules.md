# Antigravity Operational Rules: Tranche Protocol

## Autonomous Scope Boundaries
- NEVER execute across multiple phases in a single turn. Wait for explicit user confirmation before advancing.
- DO NOT invent, install, or import external dependencies beyond `forge-std` and `@openzeppelin/contracts` (v5.x).
- NO UPGRADES, ORACLES, OR GOVERNANCE: The contract must remain an immutable, non-upgradeable single-contract vault. Do not add admin fees, protocol pauses, human dispute resolutions, or external oracle hooks.
- ZERO CODE ASSUMPTIONS: Target USDG uses 6 decimals. Never assume or hardcode 18 decimals (`1e18`).
- ACCOUNTING INVARIANT: Vault balance must never be checked via `IERC20.balanceOf(address(this))` for internal state; maintain internal accounting via `totalAllocated[token]`. Direct token transfers must not disrupt contract solvency.
- CODEHASH VERIFICATION: Deployed bytecode evaluation must strictly check that `targetAddress.codehash` is non-zero and not equal to `0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470` (keccak256("")).

## Verification Artifact Protocol
- Before touching or generating code, output a concise Implementation Plan.
- After code generation, execute the relevant Foundry commands (`forge build`, `forge test`).
- Conclude every turn with exact terminal output proofs. If a test fails, diagnose and patch without widening scope.