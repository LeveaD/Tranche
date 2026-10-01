// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// TESTNET/MOCK ONLY — ERC-20 with address-level freeze behaviour.
// Used to test the setPayoutTo / setRefundTo redirect scenarios.

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockFrozenToken is ERC20 {
    error NotOwner();
    error AddressFrozen(address account);

    address public immutable owner;
    mapping(address => bool) public frozen;

    constructor() ERC20("Mock Frozen Token", "FRZ") {
        owner = msg.sender;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        _mint(to, amount);
    }

    function freeze(address account) external {
        if (msg.sender != owner) revert NotOwner();
        frozen[account] = true;
    }

    function unfreeze(address account) external {
        if (msg.sender != owner) revert NotOwner();
        frozen[account] = false;
    }

    /// @dev Freeze check applies to non-zero sender and non-zero recipient.
    ///      Mint (from == 0) and burn (to == 0) bypass freeze so test setup
    ///      works even when an address is frozen.
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && frozen[from]) revert AddressFrozen(from);
        if (to   != address(0) && frozen[to])   revert AddressFrozen(to);
        super._update(from, to, value);
    }
}
