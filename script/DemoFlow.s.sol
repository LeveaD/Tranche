// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITrancheVault} from "../src/interfaces/ITrancheVault.sol";
import {MockUSDG} from "../src/mocks/MockUSDG.sol";
import {DemoDeliverable} from "./helpers/DemoDeliverable.sol";

/// @title DemoFlow
/// @notice Demonstration flow for TrancheVault on testnets.
///         Includes full claim flow, expiring flow, and clawback flow.
contract DemoFlow is Script {
    uint128 public constant DEMO_AMOUNT = 100 * 1e6; // 100 USDG (6 decimals)

    /// @notice Helper to read deployment addresses from deployments/<chainId>.json
    function _loadDeployment(uint256 chainId) internal view returns (address vault, address token, bool isMock) {
        string memory path = string.concat("deployments/", vm.toString(chainId), ".json");
        string memory json = vm.readFile(path);
        vault = vm.parseJsonAddress(json, ".contracts.TrancheVault.address");
        token = vm.parseJsonAddress(json, ".contracts.USDG.address");
        try vm.parseJsonBool(json, ".contracts.USDG.isMock") returns (bool _isMock) {
            isMock = _isMock;
        } catch {
            isMock = false;
        }
    }

    /// @notice Helper to resolve the recipient address from DEMO_RECIPIENT env var (default: broadcaster)
    function _resolveRecipient(address broadcaster) internal view returns (address) {
        string memory recipientEnv = vm.envOr("DEMO_RECIPIENT", string(""));
        if (bytes(recipientEnv).length > 0) {
            address parsed = vm.parseAddress(recipientEnv);
            if (parsed != address(0)) {
                return parsed;
            }
        }
        return broadcaster;
    }

    /// @notice Entry point (a): Full Happy Path (mint -> approve -> createTranche -> deploy -> claim)
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address broadcaster = vm.addr(deployerPrivateKey);

        console2.log("=== DemoFlow: run() ===");
        console2.log("Broadcaster: ", broadcaster);
        console2.log("Chain ID:    ", block.chainid);

        (address vaultAddress, address tokenAddress, bool isMock) = _loadDeployment(block.chainid);
        console2.log("Vault:       ", vaultAddress);
        console2.log("Token:       ", tokenAddress);
        console2.log("Is Mock:     ", isMock);

        address recipient = _resolveRecipient(broadcaster);
        console2.log("Recipient:   ", recipient);

        bytes32 expectedCodeHash = keccak256(type(DemoDeliverable).runtimeCode);
        console2.log("Expected Code Hash:");
        console2.logBytes32(expectedCodeHash);

        uint64 startNonce = vm.getNonce(broadcaster);
        console2.log("Broadcaster start nonce:", startNonce);

        // Transaction sequencing:
        // tx 0: mint (if isMock)      -> consumes startNonce
        // tx 1: approve               -> consumes startNonce + (isMock ? 1 : 0)
        // tx 2: createTranche         -> consumes startNonce + (isMock ? 2 : 1)
        // tx 3: deploy DemoDeliverable-> consumes startNonce + (isMock ? 3 : 2)
        uint256 deployNonce = uint256(startNonce) + (isMock ? 3 : 2);
        address target = vm.computeCreateAddress(broadcaster, deployNonce);
        console2.log("Computed Target Address:", target);
        console2.log("Explicit Deploy Nonce:  ", deployNonce);

        uint64 deadline = uint64(block.timestamp + 1 hours);
        console2.log("Deadline (unix):        ", deadline);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Mint tokens if mock
        if (isMock) {
            console2.log("Step 1: Minting 100 MockUSDG to broadcaster...");
            MockUSDG(tokenAddress).mint(broadcaster, DEMO_AMOUNT);
        } else {
            console2.log("Step 1: Token is not a mock; skipping mint.");
        }

        // Step 2: Approve vault
        console2.log("Step 2: Approving TrancheVault to spend 100 USDG...");
        IERC20(tokenAddress).approve(vaultAddress, DEMO_AMOUNT);

        // Step 3: createTranche
        console2.log("Step 3: Creating tranche in TrancheVault...");
        uint256 trancheId = ITrancheVault(vaultAddress).createTranche(
            tokenAddress,
            recipient,
            DEMO_AMOUNT,
            target,
            expectedCodeHash,
            deadline
        );
        console2.log("Tranche created! ID:    ", trancheId);

        // Step 4: Deploy DemoDeliverable
        console2.log("Step 4: Deploying DemoDeliverable...");
        DemoDeliverable deliverable = new DemoDeliverable();
        address deployedAddress = address(deliverable);
        console2.log("Deployed DemoDeliverable at:", deployedAddress);

        // Step 5: Assert deployed address matches precomputed target
        require(deployedAddress == target, "DemoFlow: address(deployed) does not match target!");
        console2.log("Target verification: MATCH! address(deployed) == target");

        // Step 6: Claim tranche
        console2.log("Step 6: Claiming tranche ID", trancheId, "...");
        ITrancheVault(vaultAddress).claim(trancheId);
        console2.log("Step 6: Tranche claimed successfully!");

        vm.stopBroadcast();

        console2.log("=== DemoFlow: run() finished successfully! ===");
    }

    /// @notice Entry point (b): Create an expiring tranche with 180s deadline (no deploy)
    function createExpiring() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address broadcaster = vm.addr(deployerPrivateKey);

        console2.log("=== DemoFlow: createExpiring() ===");
        console2.log("Broadcaster: ", broadcaster);
        console2.log("Chain ID:    ", block.chainid);

        (address vaultAddress, address tokenAddress, bool isMock) = _loadDeployment(block.chainid);
        console2.log("Vault:       ", vaultAddress);
        console2.log("Token:       ", tokenAddress);

        address recipient = _resolveRecipient(broadcaster);
        console2.log("Recipient:   ", recipient);

        bytes32 expectedCodeHash = keccak256(type(DemoDeliverable).runtimeCode);
        console2.log("Expected Code Hash:");
        console2.logBytes32(expectedCodeHash);

        uint64 startNonce = vm.getNonce(broadcaster);
        uint256 deployNonce = uint256(startNonce) + (isMock ? 3 : 2);
        address target = vm.computeCreateAddress(broadcaster, deployNonce);
        console2.log("Computed Target Address:", target);

        uint64 deadline = uint64(block.timestamp + 180); // now + 180 seconds
        console2.log("Expiring Deadline (now + 180s):", deadline);

        vm.startBroadcast(deployerPrivateKey);

        if (isMock) {
            console2.log("Step 1: Minting 100 MockUSDG to broadcaster...");
            MockUSDG(tokenAddress).mint(broadcaster, DEMO_AMOUNT);
        }

        console2.log("Step 2: Approving TrancheVault to spend 100 USDG...");
        IERC20(tokenAddress).approve(vaultAddress, DEMO_AMOUNT);

        console2.log("Step 3: Creating expiring tranche...");
        uint256 trancheId = ITrancheVault(vaultAddress).createTranche(
            tokenAddress,
            recipient,
            DEMO_AMOUNT,
            target,
            expectedCodeHash,
            deadline
        );
        console2.log("Expiring tranche created! ID:", trancheId);
        console2.log("No contract will be deployed to target:", target);
        console2.log("Tranche can be clawed back after timestamp:", deadline);

        vm.stopBroadcast();

        console2.log("=== DemoFlow: createExpiring() finished successfully! ===");
    }

    /// @notice Entry point (c): Clawback an expired tranche specified by DEMO_ID
    function clawbackExpired() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address broadcaster = vm.addr(deployerPrivateKey);

        console2.log("=== DemoFlow: clawbackExpired() ===");
        console2.log("Broadcaster: ", broadcaster);
        console2.log("Chain ID:    ", block.chainid);

        (address vaultAddress,,) = _loadDeployment(block.chainid);
        console2.log("Vault:       ", vaultAddress);

        uint256 id = vm.envOr("DEMO_ID", uint256(1));
        console2.log("DEMO_ID:     ", id);

        vm.startBroadcast(deployerPrivateKey);
        console2.log("Calling clawback(", id, ") on TrancheVault...");
        ITrancheVault(vaultAddress).clawback(id);
        vm.stopBroadcast();

        console2.log("=== DemoFlow: clawbackExpired() finished successfully! ===");
    }
}
