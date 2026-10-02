// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TrancheVault} from "../../src/TrancheVault.sol";
import {ITrancheVault} from "../../src/interfaces/ITrancheVault.sol";
import {MockUSDG} from "../../src/mocks/MockUSDG.sol";
import {MockDeliverable} from "../helpers/MockDeliverable.sol";
import {console2} from "forge-std/console2.sol";

/// @title InvariantHandler
/// @notice Dedicated handler contract for invariant testing of TrancheVault.
///         Executes bounded actions and maintains ghost state.
contract InvariantHandler is Test {

    // ─────────────────────────────────────────────────────────────────────────
    // Immutables & Configuration
    // ─────────────────────────────────────────────────────────────────────────

    TrancheVault public immutable vault;
    MockUSDG     public immutable token;
    bytes32      public immutable expectedCodeHash;

    // Fixed arrays of actors
    address[] public funders;
    address[] public recipients;
    address[] public callers;

    // Salt monotonic counter for unique CREATE2 target addresses
    uint256 private _saltCounter;

    // ─────────────────────────────────────────────────────────────────────────
    // Ghost variables
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Sum of Active tranche amounts per token address.
    mapping(address => uint256) public ghost_activeAmountSum;

    /// @notice Cumulative paid-out token amount per tranche ID.
    mapping(uint256 => uint256) public ghost_paidOutAmount;

    /// @notice Number of times a tranche was paid out (claim, clawback, decline).
    mapping(uint256 => uint256) public ghost_payoutCount;

    /// @notice Number of times a tranche left Active.
    mapping(uint256 => uint256) public ghost_timesLeftActive;

    /// @notice Status transition history per tranche ID.
    mapping(uint256 => ITrancheVault.Status[]) private _ghost_statusHistory;

    /// @notice Flags tracking whether claim, clawback or decline occurred.
    mapping(uint256 => bool) public ghost_wasClaimed;
    mapping(uint256 => bool) public ghost_wasClawedBack;
    mapping(uint256 => bool) public ghost_wasDeclined;

    // Tranche parameter tracking
    mapping(uint256 => bytes32) public trancheSalt;
    mapping(uint256 => address) public trancheToken;
    mapping(uint256 => uint128) public trancheAmount;
    mapping(uint256 => uint64)  public trancheDeadline;
    mapping(uint256 => address) public trancheRecipient;
    mapping(uint256 => address) public trancheFunder;

    // Tranche ID lists
    uint256[] public allTranches;
    uint256[] public activeTranches;
    mapping(uint256 => uint256) private _activeTrancheIndex;

    // Action success counters
    uint256 public count_create;
    uint256 public count_claim;
    uint256 public count_clawback;
    uint256 public count_decline;
    uint256 public count_donate;
    uint256 public count_warpTime;
    uint256 public count_setPayoutTo;
    uint256 public count_setRefundTo;
    uint256 public calls;

    function _afterAction() internal {
        calls++;
        if (calls == 64) {
            console2.log("=== Action Success Counters (Depth 64) ===");
            console2.log("create:    ", count_create);
            console2.log("claim:     ", count_claim);
            console2.log("clawback:  ", count_clawback);
            console2.log("decline:   ", count_decline);
            console2.log("donate:    ", count_donate);
            console2.log("setPayout: ", count_setPayoutTo);
            console2.log("setRefund: ", count_setRefundTo);
            console2.log("warpTime:  ", count_warpTime);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    constructor(TrancheVault _vault, MockUSDG _token) {
        vault = _vault;
        token = _token;

        // Deploy a scratch instance to get runtime codehash
        MockDeliverable scratch = new MockDeliverable();
        expectedCodeHash = address(scratch).codehash;

        // Populate funders
        funders.push(makeAddr("funder1"));
        funders.push(makeAddr("funder2"));
        funders.push(makeAddr("funder3"));

        // Populate recipients
        recipients.push(makeAddr("recipient1"));
        recipients.push(makeAddr("recipient2"));
        recipients.push(makeAddr("recipient3"));

        // Mint generous balance and set unlimited vault approvals for funders
        for (uint256 i = 0; i < funders.length; i++) {
            token.mint(funders[i], 1_000_000_000 * 1e6);
            vm.prank(funders[i]);
            token.approve(address(vault), type(uint256).max);
        }

        // Populate callers (funders, recipients, and external strangers)
        for (uint256 i = 0; i < funders.length; i++) {
            callers.push(funders[i]);
        }
        for (uint256 i = 0; i < recipients.length; i++) {
            callers.push(recipients[i]);
        }
        callers.push(makeAddr("stranger1"));
        callers.push(makeAddr("stranger2"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _removeFromActive(uint256 id) internal {
        uint256 len = activeTranches.length;
        if (len == 0) return;
        uint256 idx = _activeTrancheIndex[id];
        if (idx < len && activeTranches[idx] == id) {
            uint256 lastId = activeTranches[len - 1];
            activeTranches[idx] = lastId;
            _activeTrancheIndex[lastId] = idx;
            activeTranches.pop();
            delete _activeTrancheIndex[id];
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Actions
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Create a new escrow tranche with bounded parameters.
    function create(
        uint256 funderIdx,
        uint256 recipientIdx,
        uint256 amountSeed,
        uint256 deadlineOffsetSeed
    ) external {
        address funder = funders[bound(funderIdx, 0, funders.length - 1)];
        address recipient = recipients[bound(recipientIdx, 0, recipients.length - 1)];
        uint128 amount = uint128(bound(amountSeed, 100, 10_000_000));
        uint64 deadline = uint64(block.timestamp + bound(deadlineOffsetSeed, 1 hours, 7 days));

        bytes32 salt = bytes32(++_saltCounter);
        address target = vm.computeCreate2Address(
            salt,
            keccak256(type(MockDeliverable).creationCode),
            address(this)
        );

        vm.prank(funder);
        uint256 id = vault.createTranche(
            address(token),
            recipient,
            amount,
            target,
            expectedCodeHash,
            deadline
        );

        allTranches.push(id);
        activeTranches.push(id);
        _activeTrancheIndex[id] = activeTranches.length - 1;

        trancheSalt[id]      = salt;
        trancheToken[id]     = address(token);
        trancheAmount[id]    = amount;
        trancheDeadline[id]  = deadline;
        trancheRecipient[id] = recipient;
        trancheFunder[id]    = funder;

        ghost_activeAmountSum[address(token)] += amount;
        _ghost_statusHistory[id].push(ITrancheVault.Status.Active);
        count_create++;
        _afterAction();
    }

    /// @notice Deploy MockDeliverable at CREATE2 address and trigger claim.
    ///         Callable by any pranked caller.
    function deployAndClaim(uint256 idSeed, uint256 callerIdx) external {
        if (allTranches.length == 0) return;

        uint256 id;
        if (activeTranches.length > 0 && (idSeed % 10 < 8)) {
            // Prioritize an active tranche whose deadline has not passed
            uint256 startIdx = bound(idSeed, 0, activeTranches.length - 1);
            id = activeTranches[startIdx];
            for (uint256 i = 0; i < activeTranches.length; i++) {
                uint256 checkId = activeTranches[(startIdx + i) % activeTranches.length];
                if (block.timestamp <= trancheDeadline[checkId]) {
                    id = checkId;
                    break;
                }
            }
        } else {
            // Fuzz across all tranches (tests settled / expired attempts)
            id = allTranches[bound(idSeed, 0, allTranches.length - 1)];
        }

        // Deploy deliverable at target address if not already present
        bytes32 salt = trancheSalt[id];
        address target = vm.computeCreate2Address(
            salt,
            keccak256(type(MockDeliverable).creationCode),
            address(this)
        );
        if (target.code.length == 0) {
            new MockDeliverable{salt: salt}();
        }

        address caller = callers[bound(callerIdx, 0, callers.length - 1)];
        vm.prank(caller);
        try vault.claim(id) {
            _removeFromActive(id);
            ghost_activeAmountSum[trancheToken[id]] -= trancheAmount[id];
            ghost_paidOutAmount[id] += trancheAmount[id];
            ghost_payoutCount[id]++;
            ghost_timesLeftActive[id]++;
            ghost_wasClaimed[id] = true;
            _ghost_statusHistory[id].push(ITrancheVault.Status.Claimed);
            count_claim++;
        } catch {}
        _afterAction();
    }

    /// @notice Claw back an expired tranche. Warps past the deadline so clawback succeeds.
    ///         Callable by any pranked caller.
    function clawback(uint256 idSeed, uint256 callerIdx) external {
        if (allTranches.length == 0) return;

        uint256 id;
        if (activeTranches.length > 0 && (idSeed % 10 < 8)) {
            id = activeTranches[bound(idSeed, 0, activeTranches.length - 1)];
        } else {
            id = allTranches[bound(idSeed, 0, allTranches.length - 1)];
        }

        // Warp past deadline if necessary
        if (block.timestamp <= trancheDeadline[id]) {
            vm.warp(uint256(trancheDeadline[id]) + 1);
        }

        address caller = callers[bound(callerIdx, 0, callers.length - 1)];
        vm.prank(caller);
        try vault.clawback(id) {
            _removeFromActive(id);
            ghost_activeAmountSum[trancheToken[id]] -= trancheAmount[id];
            ghost_paidOutAmount[id] += trancheAmount[id];
            ghost_payoutCount[id]++;
            ghost_timesLeftActive[id]++;
            ghost_wasClawedBack[id] = true;
            _ghost_statusHistory[id].push(ITrancheVault.Status.ClawedBack);
            count_clawback++;
        } catch {}
        _afterAction();
    }

    /// @notice Recipient voluntarily declines an active tranche.
    function decline(uint256 idSeed, uint256 callerIdx) external {
        if (allTranches.length == 0) return;

        uint256 id;
        if (activeTranches.length > 0 && (idSeed % 10 < 8)) {
            id = activeTranches[bound(idSeed, 0, activeTranches.length - 1)];
        } else {
            id = allTranches[bound(idSeed, 0, allTranches.length - 1)];
        }

        // 75% call as recipient, 25% call as arbitrary caller (tests unauthorized reverts)
        address caller = (callerIdx % 4 != 0)
            ? trancheRecipient[id]
            : callers[bound(callerIdx, 0, callers.length - 1)];

        vm.prank(caller);
        try vault.decline(id) {
            _removeFromActive(id);
            ghost_activeAmountSum[trancheToken[id]] -= trancheAmount[id];
            ghost_paidOutAmount[id] += trancheAmount[id];
            ghost_payoutCount[id]++;
            ghost_timesLeftActive[id]++;
            ghost_wasDeclined[id] = true;
            _ghost_statusHistory[id].push(ITrancheVault.Status.Declined);
            count_decline++;
        } catch {}
        _afterAction();
    }

    /// @notice Donate tokens directly to the vault.
    function donate(uint256 callerIdx, uint256 amountSeed) external {
        address caller = callers[bound(callerIdx, 0, callers.length - 1)];
        uint256 amount = bound(amountSeed, 1, 10_000);
        token.mint(caller, amount);
        vm.prank(caller);
        token.transfer(address(vault), amount);
        count_donate++;
        _afterAction();
    }

    /// @notice Advance block.timestamp by a bounded jump.
    function warpTime(uint256 timeJumpSeed) external {
        uint256 jump = bound(timeJumpSeed, 1 minutes, 1 days);
        vm.warp(block.timestamp + jump);
        count_warpTime++;
        _afterAction();
    }

    /// @notice Update payoutTo destination.
    function setPayoutTo(uint256 idSeed, uint256 newPayoutIdx, uint256 callerIdx) external {
        if (allTranches.length == 0) return;

        uint256 id;
        if (activeTranches.length > 0 && (idSeed % 10 < 8)) {
            id = activeTranches[bound(idSeed, 0, activeTranches.length - 1)];
        } else {
            id = allTranches[bound(idSeed, 0, allTranches.length - 1)];
        }

        address newPayout = recipients[bound(newPayoutIdx, 0, recipients.length - 1)];
        address caller = (callerIdx % 4 != 0)
            ? trancheRecipient[id]
            : callers[bound(callerIdx, 0, callers.length - 1)];

        vm.prank(caller);
        try vault.setPayoutTo(id, newPayout) {
            count_setPayoutTo++;
        } catch {}
        _afterAction();
    }

    /// @notice Update refundTo destination.
    function setRefundTo(uint256 idSeed, uint256 newRefundIdx, uint256 callerIdx) external {
        if (allTranches.length == 0) return;

        uint256 id;
        if (activeTranches.length > 0 && (idSeed % 10 < 8)) {
            id = activeTranches[bound(idSeed, 0, activeTranches.length - 1)];
        } else {
            id = allTranches[bound(idSeed, 0, allTranches.length - 1)];
        }

        address newRefund = funders[bound(newRefundIdx, 0, funders.length - 1)];
        address caller = (callerIdx % 4 != 0)
            ? trancheFunder[id]
            : callers[bound(callerIdx, 0, callers.length - 1)];

        vm.prank(caller);
        try vault.setRefundTo(id, newRefund) {
            count_setRefundTo++;
        } catch {}
        _afterAction();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Getters for Invariants
    // ─────────────────────────────────────────────────────────────────────────

    function allTranchesLength() external view returns (uint256) {
        return allTranches.length;
    }

    function activeTranchesLength() external view returns (uint256) {
        return activeTranches.length;
    }

    function getStatusHistory(uint256 id) external view returns (ITrancheVault.Status[] memory) {
        return _ghost_statusHistory[id];
    }
}
