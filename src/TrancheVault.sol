// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITrancheVault} from "./interfaces/ITrancheVault.sol";

/// @title TrancheVault
/// @notice Immutable, non-upgradeable escrow vault for onchain deliverables.
/// @dev    A funder locks ERC-20 tokens for a recipient. The recipient (or
///         anyone) can trigger a claim that transfers tokens to `payoutTo` if,
///         at or before an absolute unix `deadline`, the runtime bytecode hash
///         at a pre-committed `target` address matches `expectedCodeHash`.
///         After the deadline passes without a claim the funder (or anyone)
///         can claw back the funds to `refundTo`.
///
///         No owner, no admin, no upgradeability, no fees, no oracles.
///
///         KNOWN LIMITATION (a): Code hash is checked at claim time only.
///         Deploying the deliverable before the deadline but calling claim
///         after it loses to clawback.
///
///         KNOWN LIMITATION (b): `extcodehash` covers runtime bytecode only.
///         A proxy's hash says nothing about its implementation contract.
///
///         KNOWN LIMITATION (c): Real USDG can be paused and can freeze
///         addresses, causing transfers to revert. Use setPayoutTo /
///         setRefundTo to redirect to an unfrozen address before settling.
///
/// @custom:invariant I1  totalAllocated[t] <= IERC20(t).balanceOf(vault)
///                       for any well-behaved (non-rebasing, non-fee) token.
/// @custom:invariant I2  totalAllocated[t] == sum of amounts of all Active
///                       tranches whose token == t.
/// @custom:invariant I3  A tranche leaves Active at most once and tokens are
///                       transferred exactly once per tranche.
/// @custom:invariant I4  No tranche is simultaneously Claimed and ClawedBack.
contract TrancheVault is ITrancheVault, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev keccak256("") — codehash of any account with no deployed bytecode.
    ///      Using this as expectedCodeHash would match EOAs, which is forbidden.
    bytes32 private constant EMPTY_CODEHASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    // ─────────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Tranche data indexed by ID.
    mapping(uint256 => Tranche) public tranches;

    /// @notice Total tokens currently locked per token address.
    /// @dev    Maintained as an internal accounting ledger. Never equals
    ///         balanceOf(this) in general because external donations may
    ///         increase the vault's balance without affecting this mapping.
    mapping(address => uint256) public totalAllocated;

    /// @notice Next tranche ID to assign. Starts at 1; ID 0 is permanently
    ///         invalid (the zero-value Status.None tranche is non-existent).
    uint256 public nextId;

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    constructor() {
        nextId = 1;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // External — write
    // ─────────────────────────────────────────────────────────────────────────

    /// @inheritdoc ITrancheVault
    function createTranche(
        address token,
        address recipient,
        uint128 amount,
        address target,
        bytes32 expectedCodeHash,
        uint64 deadline
    ) external nonReentrant returns (uint256 id) {
        // ── Validation ───────────────────────────────────────────────────────
        if (token == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (target == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        // forge-lint: disable-next-line(block-timestamp) -- deadline comparison is intentional; see spec
        if (deadline <= block.timestamp) revert DeadlineNotFuture();
        if (expectedCodeHash == bytes32(0)) revert ZeroCodeHash();
        if (expectedCodeHash == EMPTY_CODEHASH) revert ForbiddenCodeHash();
        if (target.code.length != 0) revert TargetAlreadyDeployed();

        // Read balance BEFORE transfer — the ONLY balanceOf call in src.
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // ── Effects ──────────────────────────────────────────────────────────
        id = nextId++;

        tranches[id] = Tranche({
            funder: msg.sender,
            recipient: recipient,
            token: token,
            amount: amount,
            target: target,
            expectedCodeHash: expectedCodeHash,
            deadline: deadline,
            status: Status.Active,
            payoutTo: recipient,
            refundTo: msg.sender
        });

        totalAllocated[token] += amount;

        // ── Interaction ───────────────────────────────────────────────────────
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // ── Post-transfer delta check ─────────────────────────────────────────
        // Reverts if the vault received fewer tokens than requested.
        // Fee-on-transfer tokens are NOT supported.
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;
        if (received != amount) revert AmountMismatch();

        emit TrancheCreated(id, msg.sender, recipient, token, amount, target, expectedCodeHash, deadline);
    }

    /// @inheritdoc ITrancheVault
    function claim(uint256 id) external nonReentrant {
        Tranche storage t = tranches[id];

        // ── Checks ───────────────────────────────────────────────────────────
        if (t.status != Status.Active) revert NotActive();
        // forge-lint: disable-next-line(block-timestamp) -- deadline comparison is intentional; see spec
        if (block.timestamp > t.deadline) revert DeadlinePassed();
        if (t.target.codehash != t.expectedCodeHash) revert BytecodeMismatch();

        // ── Effects ──────────────────────────────────────────────────────────
        t.status = Status.Claimed;
        totalAllocated[t.token] -= t.amount;

        // Cache to memory before interaction (CEI)
        address token = t.token;
        uint128 amount = t.amount;
        address payoutTo = t.payoutTo;

        // ── Interaction ───────────────────────────────────────────────────────
        IERC20(token).safeTransfer(payoutTo, amount);

        emit TrancheClaimed(id, payoutTo, amount);
    }

    /// @inheritdoc ITrancheVault
    function clawback(uint256 id) external nonReentrant {
        Tranche storage t = tranches[id];

        // ── Checks ───────────────────────────────────────────────────────────
        if (t.status != Status.Active) revert NotActive();
        // forge-lint: disable-next-line(block-timestamp) -- deadline comparison is intentional; see spec
        if (block.timestamp <= t.deadline) revert DeadlineNotPassed();

        // ── Effects ──────────────────────────────────────────────────────────
        t.status = Status.ClawedBack;
        totalAllocated[t.token] -= t.amount;

        address token = t.token;
        uint128 amount = t.amount;
        address refundTo = t.refundTo;

        // ── Interaction ───────────────────────────────────────────────────────
        IERC20(token).safeTransfer(refundTo, amount);

        emit TrancheClawedBack(id, refundTo, amount);
    }

    /// @inheritdoc ITrancheVault
    function decline(uint256 id) external nonReentrant {
        Tranche storage t = tranches[id];

        // ── Checks ───────────────────────────────────────────────────────────
        if (t.status != Status.Active) revert NotActive();
        if (msg.sender != t.recipient) revert Unauthorized();

        // ── Effects ──────────────────────────────────────────────────────────
        t.status = Status.Declined;
        totalAllocated[t.token] -= t.amount;

        address token = t.token;
        uint128 amount = t.amount;
        address refundTo = t.refundTo;

        // ── Interaction ───────────────────────────────────────────────────────
        IERC20(token).safeTransfer(refundTo, amount);

        emit TrancheDeclined(id, refundTo, amount);
    }

    /// @inheritdoc ITrancheVault
    function setPayoutTo(uint256 id, address addr) external {
        Tranche storage t = tranches[id];
        if (t.status != Status.Active) revert NotActive();
        if (msg.sender != t.recipient) revert Unauthorized();
        if (addr == address(0)) revert ZeroAddress();

        t.payoutTo = addr;
        emit PayoutToUpdated(id, addr);
    }

    /// @inheritdoc ITrancheVault
    function setRefundTo(uint256 id, address addr) external {
        Tranche storage t = tranches[id];
        if (t.status != Status.Active) revert NotActive();
        if (msg.sender != t.funder) revert Unauthorized();
        if (addr == address(0)) revert ZeroAddress();

        t.refundTo = addr;
        emit RefundToUpdated(id, addr);
    }
}
