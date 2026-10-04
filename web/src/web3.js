import { ethers } from "ethers";
import { DEPLOYMENTS, TRANCHE_VAULT_ABI, ERC20_ABI, CUSTOM_ERRORS_SPEC } from "./contracts/config.js";

class Web3Manager {
  constructor() {
    this.currentChainId = 421614; // Default to Arbitrum Sepolia
    this.isSandbox = false;
    this.walletAddress = null;
    this.signer = null;
    this.provider = null;
    this.readProvider = null;
    this.vaultContract = null;
    this.tokenContract = null;
    this.listeners = new Set();
    this.blockNumber = 0;
    this.userEthBalance = "0";
    this.userUsdgBalance = "0";
    this.userAllowance = "0";

    this.initProviders();
  }

  subscribe(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify() {
    this.listeners.forEach(cb => {
      try { cb(this.getState()); } catch (err) { console.error("Listener error:", err); }
    });
  }

  getState() {
    return {
      chainId: this.currentChainId,
      chainConfig: DEPLOYMENTS[this.currentChainId] || null,
      isSandbox: this.isSandbox,
      walletAddress: this.walletAddress,
      isConnected: !!this.walletAddress,
      blockNumber: this.blockNumber,
      userEthBalance: this.userEthBalance,
      userUsdgBalance: this.userUsdgBalance,
      userAllowance: this.userAllowance,
      vaultAddress: this.getVaultAddress(),
      tokenAddress: this.getTokenAddress()
    };
  }

  getVaultAddress() {
    const d = DEPLOYMENTS[this.currentChainId];
    return d ? d.contracts.TrancheVault.address : null;
  }

  getTokenAddress() {
    const d = DEPLOYMENTS[this.currentChainId];
    return d ? d.contracts.USDG.address : null;
  }

  initProviders() {
    const deployment = DEPLOYMENTS[this.currentChainId];
    if (deployment && deployment.rpcUrl) {
      try {
        this.readProvider = new ethers.JsonRpcProvider(deployment.rpcUrl, {
          chainId: deployment.chainId,
          name: deployment.chainName
        });
      } catch (e) {
        console.warn("Public RPC init failed, fallback:", e);
      }
    }
    this.refreshBlockNumber();
  }

  async setChain(chainId) {
    if (chainId === "sandbox") {
      this.isSandbox = true;
      this.currentChainId = 421614;
      this.notify();
      return;
    }

    const id = Number(chainId);
    if (!DEPLOYMENTS[id]) throw new Error(`Unsupported chain ID: ${id}`);
    this.isSandbox = false;
    this.currentChainId = id;
    this.initProviders();

    // If connected via browser wallet, request chain switch
    if (window.ethereum && this.walletAddress) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x" + id.toString(16) }]
        });
      } catch (switchError) {
        // If chain is not added to metamask, request add
        if (switchError.code === 4902) {
          const cfg = DEPLOYMENTS[id];
          await window.ethereum.request({
            method: "wallet_addEthereumChain",
            params: [{
              chainId: "0x" + id.toString(16),
              chainName: cfg.chainName,
              rpcUrls: [cfg.rpcUrl],
              nativeCurrency: cfg.nativeCurrency,
              blockExplorerUrls: [cfg.explorerUrl]
            }]
          });
        }
      }
    }

    await this.refreshUserData();
    this.notify();
  }

  async connectWallet() {
    if (!window.ethereum) {
      throw new Error("No Web3 browser wallet detected (MetaMask or similar).");
    }

    const browserProvider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await browserProvider.send("eth_requestAccounts", []);
    if (!accounts || accounts.length === 0) throw new Error("No accounts selected");

    const network = await browserProvider.getNetwork();
    const networkChainId = Number(network.chainId);

    if (DEPLOYMENTS[networkChainId]) {
      this.currentChainId = networkChainId;
    } else {
      // Ask to switch to current selected chain
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x" + this.currentChainId.toString(16) }]
        });
      } catch (err) {
        console.warn("Chain switch rejected:", err);
      }
    }

    this.provider = browserProvider;
    this.signer = await browserProvider.getSigner();
    this.walletAddress = await this.signer.getAddress();

    // Setup window.ethereum listeners
    if (window.ethereum.on) {
      window.ethereum.on("accountsChanged", (accs) => {
        if (!accs || accs.length === 0) {
          this.disconnect();
        } else {
          this.walletAddress = accs[0];
          this.refreshUserData().then(() => this.notify());
        }
      });
      window.ethereum.on("chainChanged", (hexId) => {
        const newId = parseInt(hexId, 16);
        if (DEPLOYMENTS[newId]) {
          this.currentChainId = newId;
          this.initProviders();
          this.refreshUserData().then(() => this.notify());
        }
      });
    }

    await this.refreshUserData();
    this.notify();
    return this.walletAddress;
  }

  disconnect() {
    this.walletAddress = null;
    this.signer = null;
    this.provider = null;
    this.userEthBalance = "0";
    this.userUsdgBalance = "0";
    this.userAllowance = "0";
    this.notify();
  }

  async refreshBlockNumber() {
    try {
      const p = this.getProvider();
      if (p) {
        this.blockNumber = await p.getBlockNumber();
        this.notify();
      }
    } catch (e) {
      // Silent error for periodic block fetch
    }
  }

  getProvider() {
    return this.provider || this.readProvider;
  }

  async refreshUserData() {
    if (!this.walletAddress) return;
    try {
      const p = this.getProvider();
      if (p) {
        const bal = await p.getBalance(this.walletAddress);
        this.userEthBalance = ethers.formatEther(bal);
      }

      const tokenAddr = this.getTokenAddress();
      const vaultAddr = this.getVaultAddress();
      if (tokenAddr && p) {
        const token = new ethers.Contract(tokenAddr, ERC20_ABI, p);
        const usdgBal = await token.balanceOf(this.walletAddress);
        this.userUsdgBalance = ethers.formatUnits(usdgBal, 6);

        if (vaultAddr) {
          const allow = await token.allowance(this.walletAddress, vaultAddr);
          this.userAllowance = ethers.formatUnits(allow, 6);
        }
      }
    } catch (err) {
      console.warn("Failed to fetch user balances:", err);
    }
  }

  getVaultContract(withSigner = false) {
    const addr = this.getVaultAddress();
    if (!addr) throw new Error("Vault address not configured for chain");
    const runner = withSigner ? (this.signer || this.getProvider()) : this.getProvider();
    return new ethers.Contract(addr, TRANCHE_VAULT_ABI, runner);
  }

  getTokenContract(withSigner = false) {
    const addr = this.getTokenAddress();
    if (!addr) throw new Error("USDG token address not configured for chain");
    const runner = withSigner ? (this.signer || this.getProvider()) : this.getProvider();
    return new ethers.Contract(addr, ERC20_ABI, runner);
  }

  async getCode(address) {
    const p = this.getProvider();
    if (!p) return "0x";
    return await p.getCode(address);
  }

  decodeError(err) {
    if (!err) return "Unknown error occurred.";
    if (err.data) {
      const data = typeof err.data === "string" ? err.data : err.data.data;
      if (data && typeof data === "string") {
        for (const spec of CUSTOM_ERRORS_SPEC) {
          if (data.startsWith(spec.selector)) {
            return `Custom Error [${spec.name}]: ${spec.rule}`;
          }
        }
      }
    }
    if (err.reason) return err.reason;
    if (err.shortMessage) return err.shortMessage;
    if (err.message) return err.message;
    return String(err);
  }
}

export const web3Manager = new Web3Manager();
