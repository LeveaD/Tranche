// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ITrancheVault
/// @notice Interface for the Tranche immutable escrow vault.
/// @dev Funds are locked until an exact runtime bytecode hash appears at a
///      pre-committed address before an absolute unix deadline, or returned
///      to the funder after the deadline.
interface ITrancheVault {
    // ─────────────────────────────────────────────────────────────────────────
    // Types
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Lifecycle states for a tranche.
    /// @dev    `None` is the zero value; an ID that has never been written
    ///         has status None and is considered non-existent.
    enum Status {
        None,
        Active,
        Claimed,
        ClawedBack,
        Declined
    }

    /// @notice All data for a single escrow tranche.
    struct Tranche {
        address funder;
        address recipient;
        address token;
        uint128 amount;
        address target;
        bytes32 expectedCodeHash;
        uint64 deadline;
        Status status;
        address payoutTo;
        address refundTo;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Custom errors
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice A required address argument was the zero address.
    error ZeroAddress();

    /// @notice Amount must be greater than zero.
    error ZeroAmount();

    /// @notice `expectedCodeHash` must not be `bytes32(0)`.
    error ZeroCodeHash();

    /// @notice `expectedCodeHash` must not equal `keccak256("")`
    ///         (0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470),
    ///         which is the codehash of an account with no deployed bytecode.
    error ForbiddenCodeHash();

    /// @notice `deadline` must be strictly greater than `block.timestamp`.
    error DeadlineNotFuture();

    /// @notice The `target` address already has bytecode deployed.
    error TargetAlreadyDeployed();

    /// @notice The token balance delta after `safeTransferFrom` did not equal
    ///         the requested `amount`. Fee-on-transfer tokens are not supported.
    error AmountMismatch();

    /// @notice The tranche is not in the `Active` state.
    error NotActive();

    /// @notice `claim` attempted after the deadline.
    error DeadlinePassed();

    /// @notice `clawback` attempted at or before the deadline.
    error DeadlineNotPassed();

    /// @notice The caller is not authorised to perform this action.
    error Unauthorized();

    /// @notice The runtime bytecode hash at `target` does not match
    ///         `expectedCodeHash`.
    error BytecodeMismatch();

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Emitted when a new tranche is created.
    event TrancheCreated(
        uint256 indexed id,
        address indexed funder,
        address indexed recipient,
        address token,
        uint128 amount,
        address target,
        bytes32 expectedCodeHash,
        uint64 deadline
    );

    /// @notice Emitted when a tranche is successfully claimed.
    event TrancheClaimed(uint256 indexed id, address indexed payoutTo, uint128 amount);

    /// @notice Emitted when a tranche is clawed back after the deadline.
    event TrancheClawedBack(uint256 indexed id, address indexed refundTo, uint128 amount);

    /// @notice Emitted when the recipient voluntarily declines a tranche.
    event TrancheDeclined(uint256 indexed id, address indexed refundTo, uint128 amount);

    /// @notice Emitted when the payout destination is updated.
    event PayoutToUpdated(uint256 indexed id, address indexed newPayoutTo);

    /// @notice Emitted when the refund destination is updated.
    event RefundToUpdated(uint256 indexed id, address indexed newRefundTo);

    // ─────────────────────────────────────────────────────────────────────────
    // External functions
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Create a new escrow tranche, locking `amount` of `token`.
    /// @dev    Pulls tokens from `msg.sender` via SafeERC20.safeTransferFrom.
    ///         Fee-on-transfer tokens are not supported.
    ///
    ///         KNOWN LIMITATION: Code hash is checked at claim time only.
    ///         If the deliverable is deployed before the deadline but claim is
    ///         not called until after it, the tranche becomes clawable.
    ///
    ///         KNOWN LIMITATION: `extcodehash` covers runtime bytecode only.
    ///         A proxy's hash says nothing about its implementation contract.
    ///
    /// @param token           ERC-20 token address (must not be zero).
    /// @param recipient       Beneficiary address (must not be zero).
    /// @param amount          Tokens to lock; must be greater than zero.
    /// @param target          Address that must receive matching bytecode.
    /// @param expectedCodeHash Runtime codehash required for claim.
    /// @param deadline        Absolute unix deadline; must be > block.timestamp.
    /// @return id             Unique identifier (starts at 1).
    function createTranche(
        address token,
        address recipient,
        uint128 amount,
        address target,
        bytes32 expectedCodeHash,
        uint64 deadline
    ) external returns (uint256 id);

    /// @notice Claim a tranche by demonstrating the expected bytecode is live.
    /// @dev    Callable by anyone. Tokens are sent to `payoutTo`.
    ///         Allowed at `block.timestamp == deadline`; reverts after.
    /// @param id Tranche identifier.
    function claim(uint256 id) external;

    /// @notice Claw back a tranche whose deadline has passed without a claim.
    /// @dev    Callable by anyone. Tokens are sent to `refundTo`.
    ///         Requires `block.timestamp > deadline` strictly.
    /// @param id Tranche identifier.
    function clawback(uint256 id) external;

    /// @notice Recipient voluntarily returns the tranche before any claim.
    /// @dev    Only the original `recipient` may call while status is Active.
    /// @param id Tranche identifier.
    function decline(uint256 id) external;

    /// @notice Update the address that receives tokens on a successful claim.
    /// @dev    Only the original `recipient` may call while status is Active.
    ///
    ///         KNOWN LIMITATION: real USDG can be paused and can freeze
    ///         addresses. A frozen `payoutTo` will cause claim to revert.
    ///
    /// @param id   Tranche identifier.
    /// @param addr New payout address; must not be zero.
    function setPayoutTo(uint256 id, address addr) external;

    /// @notice Update the address that receives tokens on clawback or decline.
    /// @dev    Only the original `funder` may call while status is Active.
    ///
    ///         KNOWN LIMITATION: real USDG can be paused and can freeze
    ///         addresses. A frozen `refundTo` will cause clawback/decline
    ///         to revert.
    ///
    /// @param id   Tranche identifier.
    /// @param addr New refund address; must not be zero.
    function setRefundTo(uint256 id, address addr) external;
}
