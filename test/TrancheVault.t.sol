// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TrancheVault} from "../src/TrancheVault.sol";
import {ITrancheVault} from "../src/interfaces/ITrancheVault.sol";
import {MockUSDG} from "../src/mocks/MockUSDG.sol";
import {MockDeliverable} from "./helpers/MockDeliverable.sol";
import {MockFrozenToken} from "./helpers/MockFrozenToken.sol";
import {MockFeeToken} from "./helpers/MockFeeToken.sol";
import {MaliciousToken} from "./helpers/MaliciousToken.sol";

contract TrancheVaultTest is Test {

    // ─────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────

    uint128 internal constant AMOUNT          = 1_000_000; // 1.000000 USDG (6 decimals)
    uint64  internal constant DEADLINE_OFFSET = 1 days;
    uint128 internal constant DONATION        = 5_000;

    /// @dev OZ ReentrancyGuard.ReentrancyGuardReentrantCall() selector.
    bytes4 private constant REENTRANT_SEL = bytes4(keccak256("ReentrancyGuardReentrantCall()"));

    // ─────────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────────

    TrancheVault internal vault;
    MockUSDG     internal token;

    address internal funder;
    address internal recipient;
    address internal stranger;
    address internal altFunder;
    address internal altRecipient;

    bytes32 internal expectedCodeHash;
    uint256 private _saltCounter;

    // ─────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────

    function setUp() public {
        vault        = new TrancheVault();
        token        = new MockUSDG();
        funder       = makeAddr("funder");
        recipient    = makeAddr("recipient");
        stranger     = makeAddr("stranger");
        altFunder    = makeAddr("altFunder");
        altRecipient = makeAddr("altRecipient");

        // Deploy a scratch instance to read the deterministic runtime codehash.
        // MockDeliverable has no constructor args and no immutables, so the
        // codehash is the same regardless of deployment address.
        MockDeliverable scratch = new MockDeliverable();
        expectedCodeHash = address(scratch).codehash;

        token.mint(funder, uint256(AMOUNT) * 200);
        vm.prank(funder);
        token.approve(address(vault), type(uint256).max);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _freshSalt() internal returns (bytes32) {
        return bytes32(++_saltCounter);
    }

    /// @dev Pre-compute the CREATE2 address for MockDeliverable deployed from
    ///      address(this) (the test contract) with `salt`.
    function _targetForSalt(bytes32 salt) internal view returns (address) {
        return vm.computeCreate2Address(
            salt,
            keccak256(type(MockDeliverable).creationCode),
            address(this)
        );
    }

    /// @dev Deploy MockDeliverable at the CREATE2 address matching `salt`.
    function _deploy(bytes32 salt) internal returns (address) {
        return address(new MockDeliverable{salt: salt}());
    }

    function _defaultDeadline() internal view returns (uint64) {
        return uint64(block.timestamp + DEADLINE_OFFSET);
    }

    /// @dev Create a tranche from funder with the supplied parameters.
    function _createTranche(
        address token_,
        address recipient_,
        uint128 amount_,
        address target_,
        bytes32 codeHash_,
        uint64  deadline_
    ) internal returns (uint256 id) {
        vm.prank(funder);
        id = vault.createTranche(token_, recipient_, amount_, target_, codeHash_, deadline_);
    }

    /// @dev Create a tranche with all defaults. Returns (id, salt).
    function _defaultSetup() internal returns (uint256 id, bytes32 salt) {
        salt = _freshSalt();
        id   = _createTranche(
            address(token), recipient, AMOUNT,
            _targetForSalt(salt), expectedCodeHash, _defaultDeadline()
        );
    }

    /// @dev Return the full Tranche struct via getTranche (mapping auto-getter
    ///      returns a flat tuple, not an assignable struct).
    function _tranche(uint256 id) internal view returns (ITrancheVault.Tranche memory) {
        return vault.getTranche(id);
    }

    /// @dev Shorthand: return tranche status as uint8.
    function _status(uint256 id) internal view returns (uint8) {
        // Use the public mapping directly for status — returns a tuple where
        // the 8th element is Status. Destructure fully to reach it.
        (,,,,,,,ITrancheVault.Status s,,) = vault.tranches(id);
        return uint8(s);
    }

    /// @dev Read the deadline of a (possibly terminal) tranche via the mapping.
    function _deadline(uint256 id) internal view returns (uint64 dl) {
        (,,,,,,dl,,,) = vault.tranches(id);
    }

    /// @dev Read payoutTo via the mapping.
    function _payoutTo(uint256 id) internal view returns (address p) {
        (,,,,,,,, p,) = vault.tranches(id);
    }

    /// @dev Read refundTo via the mapping.
    function _refundTo(uint256 id) internal view returns (address r) {
        (,,,,,,,,, r) = vault.tranches(id);
    }


    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: create — revert paths
    // ─────────────────────────────────────────────────────────────────────────

    function test_create_revert_tokenZero() public {
        bytes32 salt = _freshSalt();
        vm.expectRevert(ITrancheVault.ZeroAddress.selector);
        vm.prank(funder);
        vault.createTranche(address(0), recipient, AMOUNT, _targetForSalt(salt), expectedCodeHash, _defaultDeadline());
    }

    function test_create_revert_recipientZero() public {
        bytes32 salt = _freshSalt();
        vm.expectRevert(ITrancheVault.ZeroAddress.selector);
        vm.prank(funder);
        vault.createTranche(address(token), address(0), AMOUNT, _targetForSalt(salt), expectedCodeHash, _defaultDeadline());
    }

    function test_create_revert_targetZero() public {
        vm.expectRevert(ITrancheVault.ZeroAddress.selector);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, AMOUNT, address(0), expectedCodeHash, _defaultDeadline());
    }

    function test_create_revert_zeroAmount() public {
        bytes32 salt = _freshSalt();
        vm.expectRevert(ITrancheVault.ZeroAmount.selector);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, 0, _targetForSalt(salt), expectedCodeHash, _defaultDeadline());
    }

    function test_create_revert_deadlineAtNow() public {
        bytes32 salt = _freshSalt();
        vm.expectRevert(ITrancheVault.DeadlineNotFuture.selector);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, AMOUNT, _targetForSalt(salt), expectedCodeHash, uint64(block.timestamp));
    }

    function test_create_revert_deadlinePast() public {
        bytes32 salt = _freshSalt();
        vm.warp(100);
        vm.expectRevert(ITrancheVault.DeadlineNotFuture.selector);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, AMOUNT, _targetForSalt(salt), expectedCodeHash, uint64(block.timestamp - 1));
    }

    function test_create_revert_zeroCodeHash() public {
        bytes32 salt = _freshSalt();
        vm.expectRevert(ITrancheVault.ZeroCodeHash.selector);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, AMOUNT, _targetForSalt(salt), bytes32(0), _defaultDeadline());
    }

    function test_create_revert_forbiddenCodeHash() public {
        bytes32 salt = _freshSalt();
        vm.expectRevert(ITrancheVault.ForbiddenCodeHash.selector);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, AMOUNT, _targetForSalt(salt), keccak256(""), _defaultDeadline());
    }

    function test_create_revert_targetAlreadyDeployed() public {
        // vault itself carries bytecode
        vm.expectRevert(ITrancheVault.TargetAlreadyDeployed.selector);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, AMOUNT, address(vault), expectedCodeHash, _defaultDeadline());
    }

    function test_create_revert_amountMismatch() public {
        MockFeeToken fee = new MockFeeToken();
        fee.mint(funder, AMOUNT);
        vm.prank(funder);
        fee.approve(address(vault), AMOUNT);

        bytes32 salt = _freshSalt();
        vm.expectRevert(ITrancheVault.AmountMismatch.selector);
        vm.prank(funder);
        vault.createTranche(address(fee), recipient, AMOUNT, _targetForSalt(salt), expectedCodeHash, _defaultDeadline());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: create — success paths
    // ─────────────────────────────────────────────────────────────────────────

    function test_create_success_storedFields() public {
        bytes32 salt    = _freshSalt();
        address target  = _targetForSalt(salt);
        uint64  dl      = _defaultDeadline();

        uint256 balBefore = token.balanceOf(address(vault));
        vm.prank(funder);
        uint256 id = vault.createTranche(address(token), recipient, AMOUNT, target, expectedCodeHash, dl);

        ITrancheVault.Tranche memory t = _tranche(id);
        assertEq(t.funder,            funder,           "funder");
        assertEq(t.recipient,         recipient,        "recipient");
        assertEq(t.token,             address(token),   "token");
        assertEq(uint256(t.amount),   uint256(AMOUNT),  "amount");
        assertEq(t.target,            target,           "target");
        assertEq(t.expectedCodeHash,  expectedCodeHash, "expectedCodeHash");
        assertEq(uint256(t.deadline), uint256(dl),      "deadline");
        assertEq(uint8(t.status),     uint8(ITrancheVault.Status.Active), "status Active");
        assertEq(t.payoutTo,          recipient,        "payoutTo == recipient");
        assertEq(t.refundTo,          funder,           "refundTo == funder");
        assertEq(token.balanceOf(address(vault)), balBefore + AMOUNT, "vault received AMOUNT");
    }

    function test_create_success_idStartsAtOne() public {
        (uint256 id,) = _defaultSetup();
        assertEq(id, 1,        "first id is 1");
        assertEq(vault.nextId(), 2, "nextId is 2");
    }

    function test_create_success_idIncrements() public {
        (uint256 id1,) = _defaultSetup();
        (uint256 id2,) = _defaultSetup();
        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(vault.nextId(), 3);
    }

    function test_create_success_totalAllocated() public {
        assertEq(vault.totalAllocated(address(token)), 0);
        _defaultSetup();
        assertEq(vault.totalAllocated(address(token)), AMOUNT);
        _defaultSetup();
        assertEq(vault.totalAllocated(address(token)), uint256(AMOUNT) * 2);
    }

    function test_create_success_event() public {
        bytes32 salt = _freshSalt();
        address tgt  = _targetForSalt(salt);
        uint64  dl   = _defaultDeadline();

        vm.expectEmit(true, true, true, true, address(vault));
        emit ITrancheVault.TrancheCreated(1, funder, recipient, address(token), AMOUNT, tgt, expectedCodeHash, dl);
        vm.prank(funder);
        vault.createTranche(address(token), recipient, AMOUNT, tgt, expectedCodeHash, dl);
    }

    function test_create_success_uint128MaxAmount() public {
        uint128 maxAmt = type(uint128).max;
        token.mint(funder, maxAmt);
        bytes32 salt = _freshSalt();
        uint256 id = _createTranche(address(token), recipient, maxAmt, _targetForSalt(salt), expectedCodeHash, _defaultDeadline());
        assertEq(uint256(_tranche(id).amount), uint256(maxAmt));
        assertEq(vault.totalAllocated(address(token)), uint256(maxAmt));
    }

    function test_create_success_uint64MaxDeadline() public {
        bytes32 salt = _freshSalt();
        uint256 id = _createTranche(address(token), recipient, AMOUNT, _targetForSalt(salt), expectedCodeHash, type(uint64).max);
        assertEq(uint256(_deadline(id)), uint256(type(uint64).max));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: claim
    // ─────────────────────────────────────────────────────────────────────────

    function test_claim_success() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);

        uint256 recBefore = token.balanceOf(recipient);
        vm.expectEmit(true, true, false, true, address(vault));
        emit ITrancheVault.TrancheClaimed(id, recipient, AMOUNT);
        vault.claim(id);

        assertEq(token.balanceOf(recipient), recBefore + AMOUNT, "recipient received");
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.Claimed));
        assertEq(vault.totalAllocated(address(token)), 0);
    }

    function test_claim_success_thirdParty() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);

        vm.prank(stranger);
        vault.claim(id); // anyone may trigger

        assertGt(token.balanceOf(recipient), 0, "recipient received tokens");
        assertEq(token.balanceOf(stranger), 0,  "stranger received nothing");
    }

    function test_claim_success_atDeadline() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vm.warp(_deadline(id)); // block.timestamp == deadline
        vault.claim(id);                      // allowed: not strictly >
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.Claimed));
    }

    function test_claim_revert_notActive_doubleClaim() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vault.claim(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vault.claim(id);
    }

    function test_claim_revert_notActive_afterClawback() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vault.claim(id);
    }

    function test_claim_revert_notActive_afterDecline() public {
        (uint256 id,) = _defaultSetup();
        vm.prank(recipient); vault.decline(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vault.claim(id);
    }

    function test_claim_revert_notActive_neverCreated() public {
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vault.claim(999);
    }

    function test_claim_revert_bytecodeMismatch_noCode() public {
        (uint256 id,) = _defaultSetup(); // deliverable not deployed
        vm.expectRevert(ITrancheVault.BytecodeMismatch.selector);
        vault.claim(id);
    }

    function test_claim_revert_bytecodeMismatch_wrongCode() public {
        // Commit expectedCodeHash = MockDeliverable.codehash but deploy
        // MockFeeToken at the target (different runtime bytecode).
        bytes32 salt   = _freshSalt();
        address target = vm.computeCreate2Address(
            salt, keccak256(type(MockFeeToken).creationCode), address(this)
        );
        uint256 id = _createTranche(address(token), recipient, AMOUNT, target, expectedCodeHash, _defaultDeadline());
        new MockFeeToken{salt: salt}(); // wrong contract at target

        vm.expectRevert(ITrancheVault.BytecodeMismatch.selector);
        vault.claim(id);
    }

    function test_claim_revert_deadlinePassed() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vm.warp(uint256(_deadline(id)) + 1); // one second past
        vm.expectRevert(ITrancheVault.DeadlinePassed.selector);
        vault.claim(id);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: clawback
    // ─────────────────────────────────────────────────────────────────────────

    function test_clawback_revert_deadlineNotPassed_before() public {
        (uint256 id,) = _defaultSetup();
        vm.expectRevert(ITrancheVault.DeadlineNotPassed.selector);
        vault.clawback(id);
    }

    function test_clawback_revert_deadlineNotPassed_atDeadline() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(_deadline(id)); // == deadline, strict > required
        vm.expectRevert(ITrancheVault.DeadlineNotPassed.selector);
        vault.clawback(id);
    }

    function test_clawback_success_atDeadlinePlusOne() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.ClawedBack));
    }

    function test_clawback_success_anyCallerCanTrigger() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        vm.prank(stranger);
        vault.clawback(id);
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.ClawedBack));
    }

    function test_clawback_success_paysRefundTo() public {
        (uint256 id,) = _defaultSetup();
        uint256 funBefore = token.balanceOf(funder);
        vm.warp(uint256(_deadline(id)) + 1);

        vm.expectEmit(true, true, false, true, address(vault));
        emit ITrancheVault.TrancheClawedBack(id, funder, AMOUNT);
        vault.clawback(id);

        assertEq(token.balanceOf(funder), funBefore + AMOUNT);
    }

    function test_clawback_revert_secondCall_notActive() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vault.clawback(id);
    }

    function test_clawback_then_claim_notActive() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vault.claim(id);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: decline
    // ─────────────────────────────────────────────────────────────────────────

    function test_decline_revert_unauthorized() public {
        (uint256 id,) = _defaultSetup();
        vm.expectRevert(ITrancheVault.Unauthorized.selector);
        vm.prank(stranger);
        vault.decline(id);
    }

    function test_decline_success_refundsRefundTo() public {
        (uint256 id,) = _defaultSetup();
        uint256 funBefore = token.balanceOf(funder);

        vm.expectEmit(true, true, false, true, address(vault));
        emit ITrancheVault.TrancheDeclined(id, funder, AMOUNT);
        vm.prank(recipient);
        vault.decline(id);

        assertEq(token.balanceOf(funder), funBefore + AMOUNT);
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.Declined));
        assertEq(vault.totalAllocated(address(token)), 0);
    }

    function test_decline_success_afterDeadline() public {
        // decline has no deadline check — recipient may decline at any time
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        vm.prank(recipient);
        vault.decline(id);
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.Declined));
    }

    function test_decline_then_claim_notActive() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vm.prank(recipient); vault.decline(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vault.claim(id);
    }

    /// @dev Covers BRDA:185,14,0: the true branch of `if (t.status != Status.Active)`
    ///      inside decline — triggered by calling decline on an already-Declined tranche.
    function test_decline_revert_notActive() public {
        (uint256 id,) = _defaultSetup();
        vm.prank(recipient); vault.decline(id); // first decline succeeds
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vm.prank(recipient); vault.decline(id); // second hits NotActive
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: redirects
    // ─────────────────────────────────────────────────────────────────────────

    function test_setPayoutTo_revert_unauthorized() public {
        (uint256 id,) = _defaultSetup();
        vm.expectRevert(ITrancheVault.Unauthorized.selector);
        vm.prank(stranger);
        vault.setPayoutTo(id, altRecipient);
    }

    function test_setPayoutTo_revert_zeroAddress() public {
        (uint256 id,) = _defaultSetup();
        vm.expectRevert(ITrancheVault.ZeroAddress.selector);
        vm.prank(recipient);
        vault.setPayoutTo(id, address(0));
    }

    function test_setPayoutTo_revert_notActive() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt); vault.claim(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vm.prank(recipient);
        vault.setPayoutTo(id, altRecipient);
    }

    function test_setPayoutTo_success_event() public {
        (uint256 id,) = _defaultSetup();
        vm.expectEmit(true, true, false, false, address(vault));
        emit ITrancheVault.PayoutToUpdated(id, altRecipient);
        vm.prank(recipient);
        vault.setPayoutTo(id, altRecipient);
        assertEq(_payoutTo(id), altRecipient);
    }

    function test_setPayoutTo_success_redirectsPayout() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        vm.prank(recipient);
        vault.setPayoutTo(id, altRecipient);
        _deploy(salt);
        vault.claim(id);
        assertEq(token.balanceOf(altRecipient), AMOUNT, "altRecipient received");
        assertEq(token.balanceOf(recipient),    0,      "original recipient got nothing");
    }

    function test_setRefundTo_revert_unauthorized() public {
        (uint256 id,) = _defaultSetup();
        vm.expectRevert(ITrancheVault.Unauthorized.selector);
        vm.prank(stranger);
        vault.setRefundTo(id, altFunder);
    }

    function test_setRefundTo_revert_zeroAddress() public {
        (uint256 id,) = _defaultSetup();
        vm.expectRevert(ITrancheVault.ZeroAddress.selector);
        vm.prank(funder);
        vault.setRefundTo(id, address(0));
    }

    function test_setRefundTo_revert_notActive() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        vm.expectRevert(ITrancheVault.NotActive.selector);
        vm.prank(funder);
        vault.setRefundTo(id, altFunder);
    }

    function test_setRefundTo_success_event() public {
        (uint256 id,) = _defaultSetup();
        vm.expectEmit(true, true, false, false, address(vault));
        emit ITrancheVault.RefundToUpdated(id, altFunder);
        vm.prank(funder);
        vault.setRefundTo(id, altFunder);
        assertEq(_refundTo(id), altFunder);
    }

    function test_setRefundTo_success_redirectsRefund() public {
        (uint256 id,) = _defaultSetup();
        vm.prank(funder);
        vault.setRefundTo(id, altFunder);
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        assertEq(token.balanceOf(altFunder), AMOUNT);
    }

    function test_frozenPayee_claimReverts_thenSucceedsAfterRedirect() public {
        MockFrozenToken ft = new MockFrozenToken(); // owner = address(this)
        ft.mint(funder, AMOUNT);
        vm.prank(funder); ft.approve(address(vault), AMOUNT);

        bytes32 salt = _freshSalt();
        vm.prank(funder);
        uint256 id = vault.createTranche(address(ft), recipient, AMOUNT, _targetForSalt(salt), expectedCodeHash, _defaultDeadline());

        _deploy(salt);
        ft.freeze(recipient); // freeze current payoutTo

        // Claim reverts — transfer to frozen address fails; all effects roll back.
        vm.expectRevert();
        vault.claim(id);
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.Active), "still Active");

        // recipient can still call vault (freeze only blocks token transfers)
        vm.prank(recipient);
        vault.setPayoutTo(id, altRecipient);

        vault.claim(id);
        assertEq(ft.balanceOf(altRecipient), AMOUNT, "altRecipient received");
        assertEq(ft.balanceOf(recipient),    0,      "frozen recipient got nothing");
    }

    function test_frozenRefund_clawbackReverts_thenSucceedsAfterRedirect() public {
        MockFrozenToken ft = new MockFrozenToken();
        ft.mint(funder, AMOUNT);
        vm.prank(funder); ft.approve(address(vault), AMOUNT);

        bytes32 salt = _freshSalt();
        vm.prank(funder);
        uint256 id = vault.createTranche(address(ft), recipient, AMOUNT, _targetForSalt(salt), expectedCodeHash, _defaultDeadline());

        vm.warp(uint256(_deadline(id)) + 1);
        ft.freeze(funder); // freeze current refundTo

        vm.expectRevert();
        vault.clawback(id);
        assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.Active), "still Active");

        vm.prank(funder); // funder can call vault even while frozen for token transfers
        vault.setRefundTo(id, altFunder);

        vault.clawback(id);
        assertEq(ft.balanceOf(altFunder), AMOUNT);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: views
    // ─────────────────────────────────────────────────────────────────────────

    function test_getTranche_revert_idZero() public {
        vm.expectRevert(ITrancheVault.TrancheNotFound.selector);
        vault.getTranche(0);
    }

    function test_getTranche_revert_unissuedId() public {
        uint256 unissued = vault.nextId(); // read before setting expectRevert
        vm.expectRevert(ITrancheVault.TrancheNotFound.selector);
        vault.getTranche(unissued); // not yet assigned — status is None
    }

    function test_getTranche_success_exactFields() public {
        bytes32 salt = _freshSalt();
        address tgt  = _targetForSalt(salt);
        uint64  dl   = _defaultDeadline();
        vm.prank(funder);
        uint256 id = vault.createTranche(address(token), recipient, AMOUNT, tgt, expectedCodeHash, dl);

        ITrancheVault.Tranche memory t = vault.getTranche(id);
        assertEq(t.funder,            funder,           "funder");
        assertEq(t.recipient,         recipient,        "recipient");
        assertEq(t.token,             address(token),   "token");
        assertEq(uint256(t.amount),   uint256(AMOUNT),  "amount");
        assertEq(t.target,            tgt,              "target");
        assertEq(t.expectedCodeHash,  expectedCodeHash, "expectedCodeHash");
        assertEq(uint256(t.deadline), uint256(dl),      "deadline");
        assertEq(uint8(t.status),     uint8(ITrancheVault.Status.Active));
        assertEq(t.payoutTo,          recipient,        "payoutTo");
        assertEq(t.refundTo,          funder,           "refundTo");
    }

    function test_isClaimable_falseBeforeDeadline_noCode() public {
        (uint256 id,) = _defaultSetup();
        assertFalse(vault.isClaimable(id), "false: no code");
    }

    function test_isClaimable_trueBeforeDeadline_withCode() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        assertTrue(vault.isClaimable(id), "true: before deadline, code present");
    }

    function test_isClaimable_trueAtDeadline_withCode() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vm.warp(_deadline(id)); // exactly at deadline
        assertTrue(vault.isClaimable(id), "true: at deadline with code");
    }

    function test_isClaimable_falseAfterDeadline_withCode() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt);
        vm.warp(uint256(_deadline(id)) + 1);
        assertFalse(vault.isClaimable(id), "false: one second past deadline");
    }

    function test_isClaimable_falseAfterClaimed() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt); vault.claim(id);
        assertFalse(vault.isClaimable(id));
    }

    function test_isClaimable_falseAfterClawedBack() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        assertFalse(vault.isClaimable(id));
    }

    function test_isClaimable_falseAfterDeclined() public {
        (uint256 id,) = _defaultSetup();
        vm.prank(recipient); vault.decline(id);
        assertFalse(vault.isClaimable(id));
    }

    function test_isClaimable_falseNonexistent() public view {
        assertFalse(vault.isClaimable(0));
        assertFalse(vault.isClaimable(999));
    }

    function test_isClawbackable_falseBeforeDeadline() public {
        (uint256 id,) = _defaultSetup();
        assertFalse(vault.isClawbackable(id));
    }

    function test_isClawbackable_falseAtDeadline() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(_deadline(id)); // == deadline, strict > required
        assertFalse(vault.isClawbackable(id), "false: at deadline");
    }

    function test_isClawbackable_trueAfterDeadline() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        assertTrue(vault.isClawbackable(id));
    }

    function test_isClawbackable_falseAfterClawedBack() public {
        (uint256 id,) = _defaultSetup();
        vm.warp(uint256(_deadline(id)) + 1);
        vault.clawback(id);
        assertFalse(vault.isClawbackable(id));
    }

    function test_isClawbackable_falseAfterClaimed() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        _deploy(salt); vault.claim(id);
        assertFalse(vault.isClawbackable(id));
    }

    function test_isClawbackable_falseNonexistent() public view {
        assertFalse(vault.isClawbackable(0));
        assertFalse(vault.isClawbackable(999));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: donation
    // ─────────────────────────────────────────────────────────────────────────

    function test_donation_leavesTotalAllocatedUnchanged() public {
        _defaultSetup();
        uint256 before = vault.totalAllocated(address(token));
        token.mint(address(vault), DONATION); // direct transfer, not via createTranche
        assertEq(vault.totalAllocated(address(token)), before, "totalAllocated unchanged");
    }

    function test_donation_claimStillWorks() public {
        (uint256 id, bytes32 salt) = _defaultSetup();
        token.mint(address(vault), DONATION); // donate on top
        _deploy(salt);
        vault.claim(id);
        assertEq(token.balanceOf(recipient),    AMOUNT,   "recipient got exactly AMOUNT");
        assertEq(token.balanceOf(address(vault)), DONATION, "vault retains donation");
        assertEq(vault.totalAllocated(address(token)), 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: reentrancy
    // ─────────────────────────────────────────────────────────────────────────

    function test_reentrancy_createTranche() public {
        MaliciousToken mal = new MaliciousToken(); // owner = address(this)
        mal.mint(funder, AMOUNT);
        vm.prank(funder); mal.approve(address(vault), AMOUNT);

        bytes32 outerSalt   = _freshSalt();
        address outerTarget = _targetForSalt(outerSalt);
        bytes32 innerSalt   = _freshSalt();
        address innerTarget = _targetForSalt(innerSalt);
        uint64  dl = _defaultDeadline();

        bytes memory hookData = abi.encodeCall(
            vault.createTranche, (address(mal), recipient, AMOUNT, innerTarget, expectedCodeHash, dl)
        );
        // Hook: re-enter createTranche during safeTransferFrom
        mal.setHook(address(vault), hookData);

        // (a) Exact selector; (b) assert the re-entry call was attempted
        // vm.expectCall tracks infrastructure-level calls, surviving EVM rollback
        vm.expectCall(address(vault), hookData);
        vm.expectRevert(REENTRANT_SEL);
        vm.prank(funder);
        vault.createTranche(address(mal), recipient, AMOUNT, outerTarget, expectedCodeHash, dl);

        // All effects must be rolled back
        assertEq(vault.nextId(), 1,                                                    "nextId rolled back");
        assertEq(uint8(_status(1)), uint8(ITrancheVault.Status.None),                 "no tranche stored");
        assertEq(vault.totalAllocated(address(mal)), 0,                                "totalAllocated rolled back");
        assertEq(mal.balanceOf(address(vault)), 0,                                     "vault holds no MAL");
    }

    function test_reentrancy_claim() public {
        MaliciousToken mal = new MaliciousToken();
        mal.mint(funder, AMOUNT);
        vm.prank(funder); mal.approve(address(vault), AMOUNT);

        bytes32 salt   = _freshSalt();
        address target = _targetForSalt(salt);
        vm.prank(funder);
        uint256 id = vault.createTranche(address(mal), recipient, AMOUNT, target, expectedCodeHash, _defaultDeadline());

        _deploy(salt);

        bytes memory hookData = abi.encodeCall(vault.claim, (id));
        // Arm hook: re-enter claim during safeTransfer to payoutTo
        mal.setHook(address(vault), hookData);

        // (a) Exact selector; (b) re-entry attempt was made
        vm.expectCall(address(vault), hookData);
        vm.expectRevert(REENTRANT_SEL);
        vault.claim(id);

        assertEq(uint8(_status(id)), uint8(ITrancheVault.Status.Active), "status rolled back");
        assertEq(mal.balanceOf(address(vault)), AMOUNT,                   "vault still holds tokens");
        assertEq(mal.balanceOf(recipient), 0,                             "recipient got nothing");
    }

    function test_reentrancy_clawback() public {
        MaliciousToken mal = new MaliciousToken();
        mal.mint(funder, AMOUNT);
        vm.prank(funder); mal.approve(address(vault), AMOUNT);

        bytes32 salt   = _freshSalt();
        address target = _targetForSalt(salt);
        vm.prank(funder);
        uint256 id = vault.createTranche(address(mal), recipient, AMOUNT, target, expectedCodeHash, _defaultDeadline());

        vm.warp(uint256(_deadline(id)) + 1);

        bytes memory hookData = abi.encodeCall(vault.clawback, (id));
        // Arm hook: re-enter clawback during safeTransfer to refundTo
        mal.setHook(address(vault), hookData);

        // (a) Exact selector; (b) re-entry attempt was made
        vm.expectCall(address(vault), hookData);
        vm.expectRevert(REENTRANT_SEL);
        vault.clawback(id);

        assertEq(uint8(_status(id)), uint8(ITrancheVault.Status.Active));
        assertEq(mal.balanceOf(address(vault)), AMOUNT);
    }

    function test_reentrancy_decline() public {
        MaliciousToken mal = new MaliciousToken();
        mal.mint(funder, AMOUNT);
        vm.prank(funder); mal.approve(address(vault), AMOUNT);

        bytes32 salt   = _freshSalt();
        address target = _targetForSalt(salt);
        vm.prank(funder);
        uint256 id = vault.createTranche(address(mal), recipient, AMOUNT, target, expectedCodeHash, _defaultDeadline());

        bytes memory hookData = abi.encodeCall(vault.decline, (id));
        // Arm hook: re-enter decline during safeTransfer to refundTo
        mal.setHook(address(vault), hookData);

        // (a) Exact selector; (b) re-entry attempt was made
        vm.expectCall(address(vault), hookData);
        vm.expectRevert(REENTRANT_SEL);
        vm.prank(recipient);
        vault.decline(id);

        assertEq(uint8(_status(id)), uint8(ITrancheVault.Status.Active));
        assertEq(mal.balanceOf(address(vault)), AMOUNT);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: accounting
    // ─────────────────────────────────────────────────────────────────────────

    function test_accounting_multiTranche_sameToken() public {
        bytes32 s1 = _freshSalt();
        bytes32 s2 = _freshSalt();
        bytes32 s3 = _freshSalt();

        uint256 id1 = _createTranche(address(token), recipient, AMOUNT, _targetForSalt(s1), expectedCodeHash, _defaultDeadline());
        uint256 id2 = _createTranche(address(token), recipient, AMOUNT, _targetForSalt(s2), expectedCodeHash, _defaultDeadline());
        uint256 id3 = _createTranche(address(token), recipient, AMOUNT, _targetForSalt(s3), expectedCodeHash, _defaultDeadline());

        assertEq(vault.totalAllocated(address(token)), uint256(AMOUNT) * 3, "3x AMOUNT locked");

        // Claim id1 (before deadline, deliver)
        _deploy(s1);
        vault.claim(id1);
        assertEq(vault.totalAllocated(address(token)), uint256(AMOUNT) * 2, "2x AMOUNT after claim");

        // Decline id3 (no deadline constraint on decline)
        vm.prank(recipient);
        vault.decline(id3);
        assertEq(vault.totalAllocated(address(token)), uint256(AMOUNT) * 1, "1x AMOUNT after decline");

        // Clawback id2 after deadline
        vm.warp(uint256(_deadline(id2)) + 1);
        vault.clawback(id2);
        assertEq(vault.totalAllocated(address(token)), 0,  "0 after clawback");
        assertEq(token.balanceOf(address(vault)),       0,  "vault empty");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP: fuzz (1000 runs — see [fuzz] section in foundry.toml)
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev For any random deadline offset and warp offset:
    ///      1. isClaimable and isClawbackable are never simultaneously true.
    ///      2. When the deliverable is deployed, exactly one of claim / clawback
    ///         succeeds and produces the correct terminal status.
    function testFuzz_mutualExclusivity(uint64 deadlineOffset, uint64 warpOffset) public {
        deadlineOffset = uint64(bound(deadlineOffset, 1,  365 days));
        warpOffset     = uint64(bound(warpOffset,     0,  2 * uint256(365 days)));

        bytes32 salt   = _freshSalt();
        address target = _targetForSalt(salt);
        uint64  dl     = uint64(block.timestamp + deadlineOffset);

        uint256 id = _createTranche(address(token), recipient, AMOUNT, target, expectedCodeHash, dl);

        vm.warp(block.timestamp + warpOffset);
        _deploy(salt); // code now present at target

        bool claimable    = vault.isClaimable(id);
        bool clawbackable = vault.isClawbackable(id);

        assertFalse(claimable && clawbackable, "never both true simultaneously");

        if (claimable) {
            vault.claim(id);
            assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.Claimed));
        } else {
            // code is present and tranche is Active → must be clawbackable
            assertTrue(clawbackable, "not claimable with code present implies clawbackable");
            vault.clawback(id);
            assertEq(uint8(_status(id)) , uint8(ITrancheVault.Status.ClawedBack));
        }
    }
}



