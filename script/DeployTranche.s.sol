// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TrancheVault} from "../src/TrancheVault.sol";
import {MockUSDG} from "../src/mocks/MockUSDG.sol";

/// @title DeployTranche
/// @notice Deployment script for TrancheVault and optional MockUSDG.
contract DeployTranche is Script {

    function run() external returns (address vaultAddress, address tokenAddress, bool isMock) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== DeployTranche ===");
        console2.log("Deployer address:", deployer);
        console2.log("Chain ID:        ", block.chainid);

        address configuredToken = _getUsdgAddress(block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        TrancheVault vault = new TrancheVault();
        vaultAddress = address(vault);

        if (configuredToken == address(0)) {
            MockUSDG mockUsdg = new MockUSDG();
            tokenAddress = address(mockUsdg);
            isMock = true;
            console2.log("-----------------------------------------------------------------");
            console2.log("NOTICE: No configured USDG address found for chainId", block.chainid);
            console2.log("DEPLOYED MOCK TOKEN (MockUSDG - TESTNET/MOCK ONLY):", tokenAddress);
            console2.log("-----------------------------------------------------------------");
        } else {
            tokenAddress = configuredToken;
            isMock = false;
            console2.log("Using existing configured USDG address:", tokenAddress);
        }

        vm.stopBroadcast();

        console2.log("TrancheVault deployed at:", vaultAddress);
        console2.log("Token address:           ", tokenAddress);
        console2.log("Is mock token:           ", isMock);
        console2.log("=====================");
    }

    /// @dev Read USDG token address from environment for specific chains.
    function _getUsdgAddress(uint256 chainId) internal view returns (address) {
        string memory tokenStr;

        if (chainId == 46630) {
            tokenStr = vm.envOr("ROBINHOOD_USDG", string(""));
        } else if (chainId == 421614) {
            tokenStr = vm.envOr("ARBITRUM_SEPOLIA_USDG", string(""));
        } else {
            tokenStr = vm.envOr("USDG_ADDRESS", string(""));
        }

        // Generic fallback if chain-specific was empty
        if (bytes(tokenStr).length == 0) {
            tokenStr = vm.envOr("USDG_ADDRESS", string(""));
        }

        if (bytes(tokenStr).length == 0) {
            return address(0);
        }

        // If string is all zeros or zero address format
        if (
            keccak256(bytes(tokenStr)) == keccak256(bytes("0x0000000000000000000000000000000000000000")) ||
            keccak256(bytes(tokenStr)) == keccak256(bytes("0x0"))
        ) {
            return address(0);
        }

        return vm.parseAddress(tokenStr);
    }
}
