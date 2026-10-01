// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal deliverable used in TrancheVault claim tests.
/// @dev    Deployed by tests after the tranche is created.
///         Its `extcodehash` is deterministic and can be committed to in
///         `expectedCodeHash` before the contract is deployed.
///
///         IMPORTANT: any change to this file changes its bytecode and
///         therefore its codehash.  Recompute the committed hash in tests
///         after any modification.
contract MockDeliverable {
    /// @notice A single public constant so the runtime bytecode is
    ///         non-trivial and cannot be confused with an empty-bytecode account.
    uint256 public constant VERSION = 1;
}
