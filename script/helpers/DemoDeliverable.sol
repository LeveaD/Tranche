// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title DemoDeliverable
/// @notice Minimal deliverable contract for live demo proofs.
///         Has no constructor arguments and no immutables.
contract DemoDeliverable {
    string public constant NAME = "DemoDeliverable";
    uint256 public constant VERSION = 1;

    function isDelivered() external pure returns (bool) {
        return true;
    }
}
