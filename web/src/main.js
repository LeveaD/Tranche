import { ethers } from "ethers";
import { web3Manager } from "./web3.js";
import { LedgerManager } from "./ledger.js";
import { CreateTrancheManager } from "./create.js";
import { ActionsManager } from "./actions.js";
import { HasherManager } from "./hasher.js";
import { CUSTOM_ERRORS_SPEC } from "./contracts/config.js";

// Initialize Subsystems
let ledgerManager;
let createManager;
let actionsManager;
let hasherManager;

document.addEventListener("DOMContentLoaded", () => {
  initTheme();
  initNavigation();
  initSubsystems();
  initWeb3UI();
  initFaucet();
  renderCustomErrorsTable();
});

function initTheme() {
  const root = document.documentElement;
  const themeBtn = document.getElementById("btn-toggle-theme");
  const savedTheme = localStorage.getItem("tranche-theme") || "monolith";

  setTheme(savedTheme);

  if (themeBtn) {
    themeBtn.addEventListener("click", () => {
      const current = root.getAttribute("data-theme") || "monolith";
      const next = current === "monolith" ? "monolith-inverted" : "monolith";
      setTheme(next);
    });
  }

  function setTheme(t) {
    root.setAttribute("data-theme", t);
    localStorage.setItem("tranche-theme", t);
    if (themeBtn) {
      themeBtn.textContent = t === "monolith" ? "[THEME: MONOLITH]" : "[THEME: INVERTED]";
    }
  }
}

function initNavigation() {
  const navLinks = document.querySelectorAll(".m-index-nav__item");
  const tabContents = document.querySelectorAll(".tab-content");

  function switchTab(targetTabId) {
    navLinks.forEach(link => {
      if (link.getAttribute("data-tab") === targetTabId) {
        link.classList.add("active");
      } else {
        link.classList.remove("active");
      }
    });

    tabContents.forEach(tab => {
      if (tab.id === targetTabId) {
        tab.classList.add("active");
      } else {
        tab.classList.remove("active");
      }
    });

    window.location.hash = targetTabId;
    window.scrollTo({ top: 0, behavior: "instant" });
  }

  navLinks.forEach(link => {
    link.addEventListener("click", (e) => {
      e.preventDefault();
      const tabId = link.getAttribute("data-tab");
      switchTab(tabId);
    });
  });

  // Feature block action buttons
  const featureCreate = document.getElementById("btn-feature-create");
  if (featureCreate) {
    featureCreate.addEventListener("click", () => switchTab("tab-create"));
  }

  const featureAudit = document.getElementById("btn-feature-audit");
  if (featureAudit) {
    featureAudit.addEventListener("click", () => switchTab("tab-spec"));
  }

  // Scroll to top
  const scrollTop = document.getElementById("link-scroll-top");
  if (scrollTop) {
    scrollTop.addEventListener("click", (e) => {
      e.preventDefault();
      window.scrollTo({ top: 0, behavior: "instant" });
    });
  }

  // Check URL hash on load
  if (window.location.hash) {
    const hash = window.location.hash.replace("#", "");
    if (document.getElementById(hash)) {
      switchTab(hash);
    }
  }

  // Expose global switch tab function for inspect shortcuts
  window.navigateToTab = switchTab;
}

function initSubsystems() {
  actionsManager = new ActionsManager(() => {
    ledgerManager.loadTranches();
  });
  actionsManager.init();

  ledgerManager = new LedgerManager((trancheId) => {
    window.navigateToTab("tab-actions");
    const lookupInput = document.getElementById("input-lookup-id");
    if (lookupInput) lookupInput.value = trancheId;
    actionsManager.inspectTranche(trancheId);
  });
  ledgerManager.loadTranches();

  createManager = new CreateTrancheManager((newId) => {
    ledgerManager.loadTranches();
    if (newId) {
      window.navigateToTab("tab-actions");
      const lookupInput = document.getElementById("input-lookup-id");
      if (lookupInput) lookupInput.value = newId;
      actionsManager.inspectTranche(parseInt(newId, 10));
    }
  });
  createManager.init();

  hasherManager = new HasherManager();
  hasherManager.init();

  // Ledger Filter Buttons
  document.querySelectorAll(".btn-filter").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".btn-filter").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      ledgerManager.setFilter(btn.getAttribute("data-status"));
    });
  });

  const searchInput = document.getElementById("input-search-ledger");
  if (searchInput) {
    searchInput.addEventListener("input", (e) => {
      ledgerManager.setSearch(e.target.value);
    });
  }

  const refreshBtn = document.getElementById("btn-refresh-ledger");
  if (refreshBtn) {
    refreshBtn.addEventListener("click", () => {
      ledgerManager.loadTranches();
    });
  }
}

function initWeb3UI() {
  const connectBtn = document.getElementById("btn-connect-wallet");
  const networkSelect = document.getElementById("select-network");
  const blockNumEl = document.getElementById("meta-block-num");
  const usdgBalEl = document.getElementById("meta-user-usdg");
  const walletStatusEl = document.getElementById("meta-wallet-status");
  const vaultAddrEl = document.getElementById("meta-vault-addr");
  const railAllowanceEl = document.getElementById("rail-allowance-status");
  const faucetRecipientInput = document.getElementById("input-faucet-recipient");

  // Network Select Listener
  if (networkSelect) {
    networkSelect.addEventListener("change", async (e) => {
      try {
        await web3Manager.setChain(e.target.value);
      } catch (err) {
        alert(err.message);
      }
    });
  }

  // Connect Wallet Listener
  if (connectBtn) {
    connectBtn.addEventListener("click", async () => {
      const state = web3Manager.getState();
      if (state.isConnected) {
        web3Manager.disconnect();
      } else {
        try {
          connectBtn.textContent = "CONNECTING...";
          await web3Manager.connectWallet();
        } catch (err) {
          alert(`Wallet connection failed: ${err.message}`);
          connectBtn.textContent = "[CONNECT WALLET]";
        }
      }
    });
  }

  // Subscribe to Web3 Manager updates
  web3Manager.subscribe((state) => {
    if (networkSelect && networkSelect.value !== String(state.chainId)) {
      networkSelect.value = String(state.chainId);
    }

    if (vaultAddrEl && state.vaultAddress) {
      vaultAddrEl.textContent = state.vaultAddress;
    }

    if (blockNumEl) {
      blockNumEl.textContent = state.blockNumber ? `#${state.blockNumber}` : "CONNECTING...";
    }

    if (usdgBalEl) {
      usdgBalEl.textContent = `${parseFloat(state.userUsdgBalance).toFixed(2)} USDG`;
    }

    if (railAllowanceEl) {
      railAllowanceEl.textContent = `${parseFloat(state.userAllowance).toFixed(2)} USDG`;
    }

    if (walletStatusEl) {
      if (state.isConnected) {
        const short = state.walletAddress.substring(0, 6) + "…" + state.walletAddress.substring(state.walletAddress.length - 4);
        walletStatusEl.innerHTML = `<span class="m-tag m-tag--accent">[CONNECTED: ${short}]</span>`;
        if (connectBtn) connectBtn.textContent = `[DISCONNECT ${short}]`;
        if (faucetRecipientInput && !faucetRecipientInput.value) {
          faucetRecipientInput.value = state.walletAddress;
        }
      } else {
        walletStatusEl.innerHTML = `<span class="m-tag">[READ-ONLY RPC ACTIVE]</span>`;
        if (connectBtn) connectBtn.textContent = "[CONNECT WALLET]";
      }
    }
  });

  // Periodically refresh block number every 10 seconds
  setInterval(() => {
    web3Manager.refreshBlockNumber();
  }, 10000);
}

function initFaucet() {
  const mintBtn = document.getElementById("btn-execute-mint");
  const recipientInput = document.getElementById("input-faucet-recipient");
  const amountInput = document.getElementById("input-faucet-amount");
  const noticeBox = document.getElementById("faucet-notice-box");

  if (mintBtn) {
    mintBtn.addEventListener("click", async () => {
      const state = web3Manager.getState();
      if (!state.isConnected) {
        alert("Please connect your wallet first to mint test tokens.");
        return;
      }

      const to = recipientInput.value.trim() || state.walletAddress;
      if (!ethers.isAddress(to)) {
        showNotice("Invalid recipient address.", "error");
        return;
      }

      const amountVal = parseFloat(amountInput.value) || 100;
      const units = ethers.parseUnits(amountVal.toString(), 6);

      try {
        mintBtn.disabled = true;
        mintBtn.textContent = "MINTING ONCHAIN...";
        showNotice(`Broadcasting mint tx for ${amountVal} USDG to ${to}...`, "info");

        const token = web3Manager.getTokenContract(true);
        const tx = await token.mint(to, units);
        showNotice(`Transaction submitted (${tx.hash}). Waiting for confirmation...`, "info");

        const receipt = await tx.wait(1);
        showNotice(`[OK] Successfully minted ${amountVal} USDG! Block ${receipt.blockNumber}`, "success");
        await web3Manager.refreshUserData();
      } catch (err) {
        const decoded = web3Manager.decodeError(err);
        showNotice(`Mint failed: ${decoded}`, "error");
      } finally {
        mintBtn.disabled = false;
        mintBtn.textContent = "[MINT 100 USDG TESTNET TOKENS]";
      }
    });
  }

  function showNotice(msg, type) {
    if (!noticeBox) return;
    noticeBox.style.display = "block";
    if (type === "error") {
      noticeBox.className = "m-notice m-notice--error";
      noticeBox.innerHTML = `<strong>ERROR:</strong> ${msg}`;
    } else if (type === "success") {
      noticeBox.className = "m-box m-box--heavy";
      noticeBox.innerHTML = `<span class="m-tag m-tag--accent">[SUCCESS]</span> ${msg}`;
    } else {
      noticeBox.className = "m-box";
      noticeBox.innerHTML = `<span class="m-tag">[INFO]</span> ${msg}`;
    }
  }
}

function renderCustomErrorsTable() {
  const tbody = document.getElementById("custom-errors-body");
  if (!tbody) return;

  let html = "";
  for (const err of CUSTOM_ERRORS_SPEC) {
    html += `
      <tr>
        <td><code>${err.selector}</code></td>
        <td><strong>${err.name}</strong></td>
        <td>${err.rule}</td>
      </tr>
    `;
  }
  tbody.innerHTML = html;
}
