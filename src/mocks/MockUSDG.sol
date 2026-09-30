// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDG
/// @notice 6-decimal ERC-20 test token with controllable pause and freeze.
/// @dev    Used in tests only. Not a production contract.
///         Simulates real USDG behaviour:
///         - Pause: all transfers revert.
///         - Freeze: transfers to or from a frozen address revert.
///         These restrictions are the primary motivation for setPayoutTo /
///         setRefundTo on TrancheVault.
contract MockUSDG is ERC20 {
    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error NotOwner();
    error TokenPaused();
    error AddressFrozen(address account);

    // ─────────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Owner who may mint, pause, freeze.
    address public immutable owner;

    /// @notice Whether all transfers are paused.
    bool public paused;

    /// @notice Frozen address map.
    mapping(address => bool) public frozen;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    event Paused(bool indexed isPaused);
    event Frozen(address indexed account, bool indexed isFrozen);

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    constructor() ERC20("Mock USDG", "mUSDG") {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner actions
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Mint `amount` tokens to `to`.
    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        _mint(to, amount);
    }

    /// @notice Toggle the global transfer pause.
    function setPaused(bool _paused) external {
        if (msg.sender != owner) revert NotOwner();
        paused = _paused;
        emit Paused(_paused);
    }

    /// @notice Freeze or unfreeze `account`.
    /// @param account  Address to modify.
    /// @param isFrozen True to freeze, false to unfreeze.
    function setFrozen(address account, bool isFrozen) external {
        if (msg.sender != owner) revert NotOwner();
        frozen[account] = isFrozen;
        emit Frozen(account, isFrozen);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ERC-20 overrides
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Returns 6 — matching USDG's decimal precision.
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @dev Enforces pause and freeze before every transfer (including mint /
    ///      burn which pass address(0) as from / to respectively).
    function _update(address from, address to, uint256 value) internal override {
        // Skip checks for mint (from == 0) and burn (to == 0) on pause/freeze
        // to allow minting in paused state for test setup.
        // Freeze always applies to non-zero addresses.
        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        if (!isMint && !isBurn) {
            if (paused) revert TokenPaused();
        }
        if (!isMint && frozen[from]) revert AddressFrozen(from);
        if (!isBurn && frozen[to]) revert AddressFrozen(to);

        super._update(from, to, value);
    }
}
