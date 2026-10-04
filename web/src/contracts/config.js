// Tranche Deployment Manifests and Protocol Configuration
// Per docs/INTEGRATION.md Section 1: Addresses and configs loaded from deployment manifests

export const DEPLOYMENTS = {
  46630: {
    chainId: 46630,
    chainName: "Robinhood Chain Testnet",
    shortName: "ROBINHOOD-46630",
    rpcUrl: "https://rpc.testnet.chain.robinhood.com",
    explorerUrl: "https://explorer.testnet.chain.robinhood.com",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    deployer: "0x4191ee0d12f78211826572a1cb71b646f94d9a14",
    contracts: {
      TrancheVault: {
        address: "0x6060a9dcefb34bec82a9a95fdd97987e6215d352",
        txHash: "0x692fea594f7762c0721bc37f273b40b9932590292a09eb8e1857c456c28afb11",
        blockNumber: 127529868
      },
      USDG: {
        address: "0xbe5a8c180712be720bc8f1da3c1cff2b85effaa9",
        txHash: "0x125c8705d8757c51b752ecb38335e1f34f4848fd98729582019587f56c0f3629",
        blockNumber: 127529888,
        isMock: true
      }
    },
    demoTranches: [
      {
        id: 1,
        status: 3, // ClawedBack
        amount: "100000000",
        funder: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        recipient: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        refundTo: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        payoutTo: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        target: "0xc01d0eE1dEed1C2540Bd697cB6aF20CA161461d8",
        expectedCodeHash: "0x4f2c2560b3cfd6480bfc7600029770cc30aebf950b85f16f8fd8b82136da7415",
        deadline: 1791039615,
        token: "0xbe5a8c180712be720bc8f1da3c1cff2b85effaa9",
        note: "Expired 180s tranche clawed back to funder (Tx: 0x39ee...e20c)"
      },
      {
        id: 2,
        status: 3, // ClawedBack
        amount: "100000000",
        funder: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        recipient: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        refundTo: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        payoutTo: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        target: "0xc01d0eE1dEed1C2540Bd697cB6aF20CA161461d8",
        expectedCodeHash: "0x4f2c2560b3cfd6480bfc7600029770cc30aebf950b85f16f8fd8b82136da7415",
        deadline: 1791039615,
        token: "0xbe5a8c180712be720bc8f1da3c1cff2b85effaa9",
        note: "Expired 180s tranche clawed back to funder (Tx: 0x81c0...9513)"
      },
      {
        id: 3,
        status: 2, // Claimed
        amount: "100000000",
        funder: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        recipient: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        refundTo: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        payoutTo: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        target: "0x01DDae39204A37753Ccc4BcB4b51D77C1B8c5E7d",
        expectedCodeHash: "0x4f2c2560b3cfd6480bfc7600029770cc30aebf950b85f16f8fd8b82136da7415",
        deadline: 1791043138,
        token: "0xbe5a8c180712be720bc8f1da3c1cff2b85effaa9",
        note: "Happy path: DemoDeliverable deployed & claimed (Tx: 0x91d7...f22e)"
      }
    ]
  },
  421614: {
    chainId: 421614,
    chainName: "Arbitrum Sepolia",
    shortName: "ARB-SEPOLIA-421614",
    rpcUrl: "https://sepolia-rollup.arbitrum.io/rpc",
    explorerUrl: "https://sepolia.arbiscan.io",
    nativeCurrency: { name: "Arbitrum Sepolia Ether", symbol: "ETH", decimals: 18 },
    deployer: "0x4191ee0d12f78211826572a1cb71b646f94d9a14",
    contracts: {
      TrancheVault: {
        address: "0x6060a9dcefb34bec82a9a95fdd97987e6215d352",
        txHash: "0x7ce3ac5c05f18dad7527b3cfbec85fea3456080e376cc0a8d285555e129c12eb",
        blockNumber: 314957661
      },
      USDG: {
        address: "0xbe5a8c180712be720bc8f1da3c1cff2b85effaa9",
        txHash: "0xd9084c9c3d24476d248141e8c2829a951e82ec3d4168960ec0957c53051fe7dd",
        blockNumber: 314957675,
        isMock: true
      }
    },
    demoTranches: [
      {
        id: 1,
        status: 3, // ClawedBack
        amount: "100000000",
        funder: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        recipient: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        refundTo: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        payoutTo: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        target: "0x11D3B7e7aEA59A335f5E78bCdC48D87d1b811550",
        expectedCodeHash: "0x4f2c2560b3cfd6480bfc7600029770cc30aebf950b85f16f8fd8b82136da7415",
        deadline: 1791039792,
        token: "0xbe5a8c180712be720bc8f1da3c1cff2b85effaa9",
        note: "Expired 180s tranche clawed back (Tx: 0xd25d...3de2)"
      },
      {
        id: 2,
        status: 2, // Claimed
        amount: "100000000",
        funder: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        recipient: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        refundTo: "0x4191eE0d12F78211826572a1cB71B646f94D9A14",
        payoutTo: "0xc217386ecBa691BFae282162B4385CCF300794ce",
        target: "0xc01d0eE1dEed1C2540Bd697cB6aF20CA161461d8",
        expectedCodeHash: "0x4f2c2560b3cfd6480bfc7600029770cc30aebf950b85f16f8fd8b82136da7415",
        deadline: 1791043339,
        token: "0xbe5a8c180712be720bc8f1da3c1cff2b85effaa9",
        note: "DemoDeliverable deployed & claimed (Tx: 0x16b6...4223)"
      }
    ]
  }
};

export const STATUS_MAP = {
  0: { label: "NONE", tagClass: "m-tag" },
  1: { label: "ACTIVE", tagClass: "m-tag m-tag--accent" },
  2: { label: "CLAIMED", tagClass: "m-tag m-tag--inverted" },
  3: { label: "CLAWEDBACK", tagClass: "m-tag m-tag--error" },
  4: { label: "DECLINED", tagClass: "m-tag" }
};

export const TRANCHE_VAULT_ABI = [
  "function createTranche(address token, address recipient, uint128 amount, address target, bytes32 expectedCodeHash, uint64 deadline) external returns (uint256 id)",
  "function claim(uint256 id) external",
  "function clawback(uint256 id) external",
  "function decline(uint256 id) external",
  "function setPayoutTo(uint256 id, address addr) external",
  "function setRefundTo(uint256 id, address addr) external",
  "function getTranche(uint256 id) external view returns (tuple(address funder, address recipient, address token, uint128 amount, address target, bytes32 expectedCodeHash, uint64 deadline, uint8 status, address payoutTo, address refundTo))",
  "function isClaimable(uint256 id) external view returns (bool)",
  "function isClawbackable(uint256 id) external view returns (bool)",
  "event TrancheCreated(uint256 indexed id, address indexed funder, address indexed recipient, address token, uint128 amount, address target, bytes32 expectedCodeHash, uint64 deadline)",
  "event TrancheClaimed(uint256 indexed id, address indexed payoutTo, uint128 amount)",
  "event TrancheClawedBack(uint256 indexed id, address indexed refundTo, uint128 amount)",
  "event TrancheDeclined(uint256 indexed id, address indexed refundTo, uint128 amount)",
  "event PayoutToUpdated(uint256 indexed id, address indexed newPayoutTo)",
  "event RefundToUpdated(uint256 indexed id, address indexed newRefundTo)",
  "error ZeroAddress()",
  "error ZeroAmount()",
  "error ZeroCodeHash()",
  "error ForbiddenCodeHash()",
  "error DeadlineNotFuture()",
  "error TargetAlreadyDeployed()",
  "error AmountMismatch()",
  "error NotActive()",
  "error DeadlinePassed()",
  "error DeadlineNotPassed()",
  "error Unauthorized()",
  "error BytecodeMismatch()",
  "error TrancheNotFound()"
];

export const ERC20_ABI = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address account) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function mint(address to, uint256 amount) external"
];

export const DEMO_DELIVERABLE_CODEHASH = "0x4f2c2560b3cfd6480bfc7600029770cc30aebf950b85f16f8fd8b82136da7415";
export const EMPTY_ACCOUNT_CODEHASH = "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";

export const CUSTOM_ERRORS_SPEC = [
  { name: "ZeroAddress()", selector: "0xd92e233d", rule: "A required address parameter was address(0)." },
  { name: "ZeroAmount()", selector: "0x1f2a2005", rule: "The amount parameter was 0. Must be > 0." },
  { name: "ZeroCodeHash()", selector: "0x032e5197", rule: "expectedCodeHash was bytes32(0)." },
  { name: "ForbiddenCodeHash()", selector: "0x021f7dc1", rule: "expectedCodeHash equals keccak256('') (empty account codehash)." },
  { name: "DeadlineNotFuture()", selector: "0x7f31cc85", rule: "deadline <= block.timestamp during createTranche." },
  { name: "TargetAlreadyDeployed()", selector: "0x2e896af6", rule: "target.code.length != 0 at creation time." },
  { name: "AmountMismatch()", selector: "0x55e97b0d", rule: "Balance delta != amount. Fee-on-transfer tokens rejected." },
  { name: "NotActive()", selector: "0x4065aaf1", rule: "Action attempted on non-Active tranche." },
  { name: "DeadlinePassed()", selector: "0x387b2e55", rule: "claim attempted when block.timestamp > deadline." },
  { name: "DeadlineNotPassed()", selector: "0x02eb3543", rule: "clawback attempted when block.timestamp <= deadline." },
  { name: "Unauthorized()", selector: "0x82b42960", rule: "Caller unauthorized for decline or payout/refund redirection." },
  { name: "BytecodeMismatch()", selector: "0xd0d8722b", rule: "Bytecode hash at target does not equal expectedCodeHash." },
  { name: "TrancheNotFound()", selector: "0xb54ae23f", rule: "getTranche queried for uncreated or zero tranche ID." }
];
