// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// TESTNET/MOCK ONLY — ERC-20 that takes a 1-unit fee on every non-mint/burn transfer.
// Used to verify that createTranche rejects fee-on-transfer tokens via AmountMismatch.

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockFeeToken is ERC20 {
    constructor() ERC20("Mock Fee Token", "FEE") {}

    /// @notice Returns 6 — matching USDG decimal precision.
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Unrestricted mint — test use only.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @dev Burns 1 unit as a fee on every transfer between non-zero addresses.
    ///      Recipient receives (value - 1); sender spends the full value.
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && value > 0) {
            super._update(from, address(0), 1);   // burn 1-unit fee
            super._update(from, to, value - 1);   // transfer remainder
        } else {
            super._update(from, to, value);        // mint / burn pass through
        }
    }
}
