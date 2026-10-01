// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// TESTNET/MOCK ONLY, not Paxos USDG

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDG
/// @notice Plain 6-decimal ERC-20 used in tests. No pause, no freeze, no owner.
contract MockUSDG is ERC20 {
    constructor() ERC20("Mock USDG", "mUSDG") {}

    /// @notice Returns 6 — matching USDG's decimal precision.
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Mint `amount` tokens to `to`. Unrestricted — test use only.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
