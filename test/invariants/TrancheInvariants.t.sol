// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TrancheVault} from "../../src/TrancheVault.sol";
import {ITrancheVault} from "../../src/interfaces/ITrancheVault.sol";
import {MockUSDG} from "../../src/mocks/MockUSDG.sol";
import {InvariantHandler} from "./InvariantHandler.sol";
import {console2} from "forge-std/console2.sol";

/// @title TrancheInvariants
/// @notice Invariant test suite for TrancheVault.
///         Verifies I1, I2, I3, I4 against InvariantHandler.
contract TrancheInvariants is Test {

    TrancheVault     public vault;
    MockUSDG         public token;
    InvariantHandler public handler;

    function setUp() public {
        vault = new TrancheVault();
        token = new MockUSDG();
        handler = new InvariantHandler(vault, token);

        // Only target the handler; exclude vault and tokens
        targetContract(address(handler));
        excludeContract(address(vault));
        excludeContract(address(token));

        // Target the 8 action selectors explicitly
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = InvariantHandler.create.selector;
        selectors[1] = InvariantHandler.deployAndClaim.selector;
        selectors[2] = InvariantHandler.clawback.selector;
        selectors[3] = InvariantHandler.decline.selector;
        selectors[4] = InvariantHandler.donate.selector;
        selectors[5] = InvariantHandler.warpTime.selector;
        selectors[6] = InvariantHandler.setPayoutTo.selector;
        selectors[7] = InvariantHandler.setRefundTo.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Invariants
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice I1: totalAllocated[token] <= token.balanceOf(vault)
    function invariant_I1() public view {
        assertLe(
            vault.totalAllocated(address(token)),
            token.balanceOf(address(vault)),
            "I1: totalAllocated must be <= vault balance"
        );
    }

    /// @notice I2: totalAllocated[token] == sum of Active tranche amounts for that token
    function invariant_I2() public view {
        assertEq(
            vault.totalAllocated(address(token)),
            handler.ghost_activeAmountSum(address(token)),
            "I2: totalAllocated must equal sum of Active tranche amounts"
        );
    }

    /// @notice I3: each tranche leaves Active at most once and is paid out exactly once
    function invariant_I3() public view {
        uint256 count = handler.allTranchesLength();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.allTranches(i);

            uint256 timesLeft = handler.ghost_timesLeftActive(id);
            assertLe(timesLeft, 1, "I3: tranche left Active more than once");

            if (timesLeft == 1) {
                // Must be paid out exactly once with the exact tranche amount
                assertEq(
                    handler.ghost_payoutCount(id),
                    1,
                    "I3: settled tranche must be paid out exactly once"
                );
                assertEq(
                    handler.ghost_paidOutAmount(id),
                    handler.trancheAmount(id),
                    "I3: settled tranche paid out amount mismatch"
                );

                // Status in vault must not be Active
                (,,,,,,, ITrancheVault.Status vaultStatus,,) = vault.tranches(id);
                assertTrue(
                    vaultStatus != ITrancheVault.Status.Active,
                    "I3: settled tranche must not have Active status in vault"
                );
            } else {
                // Still Active: payout must be 0
                assertEq(
                    handler.ghost_payoutCount(id),
                    0,
                    "I3: active tranche must not be paid out"
                );
                assertEq(
                    handler.ghost_paidOutAmount(id),
                    0,
                    "I3: active tranche paid out amount must be 0"
                );

                // Status in vault must still be Active
                (,,,,,,, ITrancheVault.Status vaultStatus,,) = vault.tranches(id);
                assertTrue(
                    vaultStatus == ITrancheVault.Status.Active,
                    "I3: active tranche must have Active status in vault"
                );
            }
        }
    }

    /// @notice I4: no tranche is ever both claimed and clawed back
    function invariant_I4() public view {
        uint256 count = handler.allTranchesLength();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.allTranches(i);
            assertFalse(
                handler.ghost_wasClaimed(id) && handler.ghost_wasClawedBack(id),
                "I4: tranche was both claimed and clawed back"
            );
        }
    }
}
