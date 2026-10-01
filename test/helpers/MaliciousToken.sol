// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice ERC-20 with a configurable re-entrancy hook used in reentrancy tests.
/// @dev    Before every transfer the hook is called if `hookActive` is true.
///         The test sets `hookTarget` and `hookCalldata` to point at the vault
///         and the selector it wants to re-enter (createTranche, claim,
///         clawback, or decline).  The call is expected to be blocked by
///         ReentrancyGuard and the whole transaction reverts.
///
///         NOT a production contract. Test use only.
contract MaliciousToken is ERC20 {
    // ─────────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Owner who may mint and configure the hook.
    address public immutable owner;

    /// @notice Whether the re-entrancy hook fires on the next transfer.
    bool public hookActive;

    /// @notice Address the hook will call back into.
    address public hookTarget;

    /// @notice Calldata the hook will forward.
    bytes public hookCalldata;

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    constructor() ERC20("Malicious Token", "MAL") {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Mint `amount` tokens to `to`.
    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "not owner");
        _mint(to, amount);
    }

    /// @notice Configure the hook that fires during the next transfer.
    /// @param target   Contract to call back into (the vault).
    /// @param data     Encoded call to attempt (e.g. abi.encodeCall(vault.claim, (id))).
    function setHook(address target, bytes calldata data) external {
        require(msg.sender == owner, "not owner");
        hookTarget = target;
        hookCalldata = data;
        hookActive = true;
    }

    /// @notice Disable the hook.
    function clearHook() external {
        require(msg.sender == owner, "not owner");
        hookActive = false;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ERC-20 override
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Fires the re-entrancy hook (if active) before every non-mint transfer
    ///      and propagates any revert from the inner call.  The expected behaviour
    ///      is that the vault's nonReentrant guard fires (ReentrancyGuardReentrantCall),
    ///      that error is re-raised here, and the outer vault call also reverts.
    function _update(address from, address to, uint256 value) internal override {
        if (hookActive && from != address(0)) {
            (bool _ok, bytes memory _ret) =
                hookTarget.call(hookCalldata); // solhint-disable-line avoid-low-level-calls
            if (!_ok) {
                // Propagate the inner revert so the outer call reverts too.
                assembly {
                    revert(add(_ret, 0x20), mload(_ret))
                }
            }
        }
        super._update(from, to, value);
    }
}
