# Tranche

**Deterministic milestone payouts for onchain deployments.**

Tranche is an escrow vault. A funder locks a token for a recipient. If an exact contract bytecode appears at a pre-agreed address before a deadline, the recipient is paid. If not, the funder gets a refund. There is no reviewer, oracle, admin key, fee or pause switch in the vault.

Built for the Arbitrum Open House Singapore Online Buildathon 2026. Deployed on Robinhood Chain Testnet and Arbitrum Sepolia. MIT licensed.

> **Status: testnet prototype, not audited.** The demos use a mock 6-decimal token ("MockUSDG"), not Paxos USDG. See [Limitations](#limitations).

## Problem

Grant programs, hackathon prize pools and DAOs pay in tranches tied to milestones. Verifying a milestone usually needs a human reviewer, a multisig or an oracle, and someone has to remember to send the money. One class of milestone does not need any of that: "this exact contract is live at this address." The chain can check that by itself.

## How it works

1. The funder and recipient agree on a deliverable off-chain. The funder computes the expected runtime code hash from a dry-run deployment and picks the target address.
2. The funder calls `createTranche(token, recipient, amount, target, expectedCodeHash, deadline)`. The token is pulled into the vault. The target must have no code yet.
3. The recipient deploys the committed contract at the target address.
4. **Anyone** can call `claim(id)`. If `target.codehash == expectedCodeHash` and the deadline has not passed, the recipient is paid.
5. After the deadline, **anyone** can call `clawback(id)` and the funder is refunded.

## Contract rules

| Function | Who | Rule |
|---|---|---|
| `createTranche` | Funder | Reverts on zero addresses or amount, a deadline not in the future, a code hash of 0 or `keccak256("")`, a target that already has code, or a fee-on-transfer token |
| `claim(id)` | Anyone | Active, `block.timestamp <= deadline`, code hash matches. Pays `payoutTo` |
| `clawback(id)` | Anyone | Active, `block.timestamp > deadline`. Pays `refundTo` |
| `decline(id)` | Recipient | Active. Refunds the funder |
| `setPayoutTo(id, addr)` / `setRefundTo(id, addr)` | Recipient / Funder | Active only. Lets a blocked or frozen address be replaced |
| `getTranche`, `isClaimable`, `isClawbackable` | Anyone | Read-only helpers for UIs |

At exactly `block.timestamp == deadline`, claim is allowed and clawback is not.

## Deployments

| Chain | Chain ID | TrancheVault | Mock token |
|---|---|---|---|
| Robinhood Chain Testnet | 46630 | `0x6060A9dCeFB34bEc82A9a95FDd97987e6215D352` | `0xBE5A8c180712BE720bc8f1da3c1CfF2b85eFFaA9` |
| Arbitrum Sepolia | 421614 | `0x6060A9dCeFB34bEc82A9a95FDd97987e6215D352` | `0xBE5A8c180712BE720bc8f1da3c1CfF2b85eFFaA9` |

Explorers: [Robinhood testnet](https://explorer.testnet.chain.robinhood.com) · [Arbitrum Sepolia](https://sepolia.arbiscan.io)

Verification: [CONFIRM before submitting: Blockscout (Robinhood), Sourcify and/or Arbiscan (Arbitrum Sepolia)]. Machine-readable addresses are in [`deployments/`](deployments/), and the ABI is in [`abi/TrancheVault.json`](abi/TrancheVault.json).

## Live proof (real testnet transactions)

Each flow: fund a tranche, deploy the committed contract at the target, claim. Plus an expired tranche that is clawed back. The recipient is a separate wallet from the funder.

**Robinhood Chain Testnet**
- Vault deployment: [`0x692fea59…afb11`](https://explorer.testnet.chain.robinhood.com/tx/0x692fea594f7762c0721bc37f273b40b9932590292a09eb8e1857c456c28afb11)
- Create: [`0x06b7705b…9095`](https://explorer.testnet.chain.robinhood.com/tx/0x06b7705b4343e2bcd176b9d38f152bf74316d40422d269b9e6a1d4d83c879095)
- Deploy deliverable: [`0xa1edc84f…e035`](https://explorer.testnet.chain.robinhood.com/tx/0xa1edc84f2f33c70dca2ba1bf1963df8df820bed725f1295518f969e440dee035)
- Claim: [`0x91d76d4c…f22e`](https://explorer.testnet.chain.robinhood.com/tx/0x91d76d4ccd99f84c14cff767e0274d19577cea171dc072e4cca2069f3429f22e)
- Clawback (expired tranche): [`0x39ee632a…e20c`](https://explorer.testnet.chain.robinhood.com/tx/0x39ee632ae1b1314eecf201d0ad419259b881d62db186cb5e2ae7d6253181e20c)

**Arbitrum Sepolia**
- Vault deployment: [`0x7ce3ac5c…12eb`](https://sepolia.arbiscan.io/tx/0x7ce3ac5c05f18dad7527b3cfbec85fea3456080e376cc0a8d285555e129c12eb)
- Create: [`0xfb8ac599…feae`](https://sepolia.arbiscan.io/tx/0xfb8ac59960112aaf2cd01e7942f695fbe06e1335c71cec4c4b2a833928edfeae)
- Deploy deliverable: [`0x634e9111…42df`](https://sepolia.arbiscan.io/tx/0x634e91113c642fe22923d4aab0c03f39817cad0c22eb2fa66623b23cbcbf42df)
- Claim: [`0x16b6238e…4223`](https://sepolia.arbiscan.io/tx/0x16b6238e09dfe8a02f994c061ccea308d2e105898a0ae13ca7d2bb6a593b4223)
- Clawback (expired tranche): [`0xd25d1045…3de2`](https://sepolia.arbiscan.io/tx/0xd25d104553532218832c55a3add61b720fb1f6379614e05967d8225fb2a33de2)

Full tables and final tranche states: [`demo/demo-46630.md`](demo/demo-46630.md), [`demo/demo-421614.md`](demo/demo-421614.md).

## Testing

[CONFIRM by running `forge test` and `forge coverage --report summary` before submitting, then update the numbers.]

- 80 unit and fuzz tests (including a 1000-run fuzz that claim and clawback are never both possible).
- 4 stateful invariants over 256 runs × 64 calls: the vault never owes more than it holds, the internal ledger equals the sum of active tranches, a tranche leaves Active at most once and is paid exactly once, and no tranche is both claimed and clawed back.
- 100% line, statement, branch and function coverage of [`src/TrancheVault.sol`](src/TrancheVault.sol).
- Mutation checks: the vault source was deliberately broken in 24 ways (for example removing a guard, changing a comparison, paying the wrong address) and the tests caught every one.

```
forge build
forge test
forge coverage --report summary
```

## Limitations

This is a prototype. Read these before relying on it.

- **Not audited.**
- **Mock token in demos.** Real Paxos USDG integration has not been tested. USDG can be paused and addresses can be frozen by the issuer, which can make transfers revert. `setPayoutTo` and `setRefundTo` let a party replace a blocked address, but an issuer-level pause cannot be engineered away.
- **Claim must happen before the deadline.** If the deliverable is deployed in time but nobody calls `claim` until after the deadline, anyone can claw the funds back. Recipients should claim immediately; funders should leave a buffer.
- **The check proves deployment, not quality.** Anyone can deploy the same bytecode, so it shows the committed artifact is live, not who wrote it or whether it is good.
- **Proxies prove nothing.** The code hash of a proxy or minimal clone says nothing about its logic. Use immutable, self-contained deliverables.
- **Hash reproducibility.** Compiler metadata and immutables change the hash. Build deliverables with `bytecode_hash = "none"` and `cbor_metadata = false`, and take the hash from a dry-run deployment (`cast codehash`).
- **One condition type.** No subjective milestones, no disputes, no multi-tranche grouping.
- **Testnet only.**

## How Tranche compares

Based on the public READMEs of other entries and repositories we found; this may be incomplete and was not independently verified.

| Project | What triggers payout | Notes |
|---|---|---|
| **Tranche** | Pre-committed code hash at a pre-committed address, before a deadline | No human or attestor in the loop; one condition type only |
| Stagepay | Client approval, or silence past a review window | Freelance milestone escrow with revisions and split proposals |
| ScopePay | Client release or an arbiter split | Freelance milestone escrow |
| MileMark | Attestor quorum | Sponsor-funded milestone campaigns |
| OutcomePay AI | A verifier checks a submitted contract address and deployment transaction | Closest in spirit; agent-oriented |
| AgentGuard / FlowGuard | Independent verification or attestor threshold | Attestation-based release |

Our difference is narrow: a minimal, immutable vault whose only trigger is chain state fixed at creation, with a guaranteed refund path.

## Why Arbitrum and Robinhood Chain

At current ETH prices (about $2,750), a claim costs roughly a quarter of a cent on Robinhood Chain Testnet and about a cent on Arbitrum Sepolia (testnet gas is free; these are equivalent costs), which keeps per-milestone payouts practical. Robinhood Chain is an Arbitrum Orbit chain, and the same contract and script deploy to both unchanged.

## Progress during the hackathon

- Repository created during the hackathon window: [CONFIRM first commit date with `git log --reverse --format="%ad %s" --date=short`].
- Ideation and design: Sept 29-30 (we evaluated several ideas and dropped them after finding overlapping entries).
- Implementation: core vault, interface, tests, invariants, deploy and demo scripts, committed in phases (see `git log`).
- Deployed and verified on two testnets; live demo transactions listed above.
- **AI assistance disclosure:** AI coding assistants were used to write and review code. We specified the design, checked every phase against it, and verified the result with tests, mutation checks and live transactions.
- UI: [CONFIRM: link or "in progress"].

## Roadmap

- Reviewer-signed tranches with a challenge window and a default-on-silence rule set at creation.
- Grouping several tranches into one grant.
- Testing against real USDG, then an independent audit.
- A mainnet pilot with a real grant or prize payout.

## Repo layout

```
src/             TrancheVault.sol, interface, MockUSDG
test/            unit, fuzz and invariant tests, helpers
script/          deploy and demo scripts
abi/             exported ABI
deployments/     addresses per chain
docs/            INTEGRATION.md for front-end developers
demo/            live proof per chain
```

## Links

- **Integration Guide & Demo Recipe**: [`docs/INTEGRATION.md`](docs/INTEGRATION.md)
- **Live Demo Proof (Robinhood Testnet `46630`)**: [`demo/demo-46630.md`](demo/demo-46630.md)
- **Live Demo Proof (Arbitrum Sepolia `421614`)**: [`demo/demo-421614.md`](demo/demo-421614.md)
- **Live Demo Flow Script**: [`script/DemoFlow.s.sol`](script/DemoFlow.s.sol)
- **Demo Deliverable Helper**: [`script/helpers/DemoDeliverable.sol`](script/helpers/DemoDeliverable.sol)
- **Robinhood Testnet Manifest**: [`deployments/46630.json`](deployments/46630.json)
- **Arbitrum Sepolia Manifest**: [`deployments/421614.json`](deployments/421614.json)

## License

MIT