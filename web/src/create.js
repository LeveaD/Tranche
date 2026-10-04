import { ethers } from "ethers";
import { web3Manager } from "./web3.js";
import { DEMO_DELIVERABLE_CODEHASH, EMPTY_ACCOUNT_CODEHASH } from "./contracts/config.js";

export class CreateTrancheManager {
  constructor(onTrancheCreated) {
    this.onTrancheCreated = onTrancheCreated;
    this.isApproving = false;
    this.isCreating = false;
    this.statusMessage = null;
    this.statusType = "info"; // "info", "error", "success"

    web3Manager.subscribe(() => {
      this.updateTokenFields();
      this.checkAllowanceStatus();
    });
  }

  init() {
    this.bindEvents();
    this.updateTokenFields();
    this.setDeadlineOffset(3600); // Default to +1 hour
  }

  bindEvents() {
    const form = document.getElementById("create-tranche-form");
    if (form) {
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        this.handleSubmit();
      });
    }

    // Quick fill demo hash
    const fillHashBtn = document.getElementById("btn-fill-demo-hash");
    if (fillHashBtn) {
      fillHashBtn.addEventListener("click", () => {
        const hashInput = document.getElementById("input-expected-hash");
        if (hashInput) {
          hashInput.value = DEMO_DELIVERABLE_CODEHASH;
          this.validateExpectedHash();
        }
      });
    }

    // Deadline presets
    document.querySelectorAll(".btn-deadline-preset").forEach(btn => {
      btn.addEventListener("click", () => {
        const seconds = parseInt(btn.getAttribute("data-seconds"), 10);
        this.setDeadlineOffset(seconds);
      });
    });

    // Target address change listener for live code inspection
    const targetInput = document.getElementById("input-target-address");
    if (targetInput) {
      targetInput.addEventListener("input", () => this.validateTargetAddress());
      targetInput.addEventListener("blur", () => this.validateTargetAddress());
    }

    // Amount input change listener for allowance check
    const amountInput = document.getElementById("input-amount");
    if (amountInput) {
      amountInput.addEventListener("input", () => this.checkAllowanceStatus());
    }

    // Hash validation listener
    const hashInput = document.getElementById("input-expected-hash");
    if (hashInput) {
      hashInput.addEventListener("input", () => this.validateExpectedHash());
    }
  }

  setDeadlineOffset(seconds) {
    const targetDate = new Date(Date.now() + seconds * 1000);
    // Format to YYYY-MM-DDTHH:mm for datetime-local
    const offset = targetDate.getTimezoneOffset() * 60000;
    const localISOTime = (new Date(targetDate.getTime() - offset)).toISOString().slice(0, 16);

    const deadlineInput = document.getElementById("input-deadline");
    if (deadlineInput) {
      deadlineInput.value = localISOTime;
    }
    this.updateDeadlinePreview(Math.floor(targetDate.getTime() / 1000));
  }

  updateDeadlinePreview(unixSecs) {
    const preview = document.getElementById("deadline-preview");
    if (preview) {
      preview.textContent = `UNIX TIMESTAMP: ${unixSecs} (UTC: ${new Date(unixSecs * 1000).toUTCString()})`;
    }
  }

  updateTokenFields() {
    const state = web3Manager.getState();
    const tokenInput = document.getElementById("input-token-address");
    if (tokenInput && state.tokenAddress) {
      if (!tokenInput.value || tokenInput.dataset.autoFilled === "true") {
        tokenInput.value = state.tokenAddress;
        tokenInput.dataset.autoFilled = "true";
      }
    }
  }

  async validateTargetAddress() {
    const targetInput = document.getElementById("input-target-address");
    const noticeEl = document.getElementById("target-check-notice");
    if (!targetInput || !noticeEl) return;

    const val = targetInput.value.trim();
    if (!ethers.isAddress(val)) {
      noticeEl.innerHTML = "";
      return;
    }

    try {
      const code = await web3Manager.getCode(val);
      if (code && code !== "0x") {
        noticeEl.innerHTML = `
          <div class="m-notice m-notice--error" style="margin-top: 0.5rem; padding: 0.5rem 0.75rem;">
            <strong>[!] TargetAlreadyDeployed():</strong> Bytecode already exists at this address (${code.length / 2 - 1} bytes). The vault will revert. Target must be empty at creation time.
          </div>
        `;
      } else {
        noticeEl.innerHTML = `
          <div style="font-family: var(--font-mono); font-size: 0.75rem; color: var(--ok); margin-top: 0.35rem;">
            [OK] Target address is clean (0 deployed bytes). Valid for new deployment.
          </div>
        `;
      }
    } catch (e) {
      noticeEl.innerHTML = "";
    }
  }

  validateExpectedHash() {
    const hashInput = document.getElementById("input-expected-hash");
    const noticeEl = document.getElementById("hash-check-notice");
    if (!hashInput || !noticeEl) return;

    const val = hashInput.value.trim().toLowerCase();
    if (!val) {
      noticeEl.innerHTML = "";
      return;
    }

    if (val === "0x0000000000000000000000000000000000000000000000000000000000000000" || val === "0x0") {
      noticeEl.innerHTML = `
        <div class="m-notice m-notice--error" style="margin-top: 0.5rem; padding: 0.5rem 0.75rem;">
          <strong>[!] ZeroCodeHash():</strong> Code hash cannot be zero.
        </div>
      `;
      return;
    }

    if (val === EMPTY_ACCOUNT_CODEHASH.toLowerCase()) {
      noticeEl.innerHTML = `
        <div class="m-notice m-notice--error" style="margin-top: 0.5rem; padding: 0.5rem 0.75rem;">
          <strong>[!] ForbiddenCodeHash():</strong> Hash equals keccak256("") (empty account codehash). Not allowed.
        </div>
      `;
      return;
    }

    if (val.length !== 66 || !val.startsWith("0x")) {
      noticeEl.innerHTML = `
        <div style="font-family: var(--font-mono); font-size: 0.75rem; color: var(--error); margin-top: 0.35rem;">
          [!] Must be a 32-byte hexadecimal string prefixed with 0x (66 characters).
        </div>
      `;
      return;
    }

    noticeEl.innerHTML = `
      <div style="font-family: var(--font-mono); font-size: 0.75rem; color: var(--ok); margin-top: 0.35rem;">
        [OK] Valid bytes32 runtime bytecode hash.
      </div>
    `;
  }

  checkAllowanceStatus() {
    const state = web3Manager.getState();
    const amountInput = document.getElementById("input-amount");
    const submitBtn = document.getElementById("btn-submit-create");
    if (!submitBtn) return;

    if (!state.isConnected) {
      submitBtn.textContent = "[CONNECT WALLET TO CONTINUE]";
      submitBtn.disabled = true;
      return;
    }

    submitBtn.disabled = false;
    const amountVal = parseFloat(amountInput ? amountInput.value : "0") || 0;
    const allowanceVal = parseFloat(state.userAllowance) || 0;

    if (amountVal > 0 && allowanceVal < amountVal) {
      submitBtn.textContent = `[STEP 1: APPROVE ${amountVal} USDG]`;
      submitBtn.dataset.action = "approve";
      submitBtn.className = "m-button m-button-primary";
    } else {
      submitBtn.textContent = "[STEP 2: CREATE & FUND ESCROW TRANCHE]";
      submitBtn.dataset.action = "create";
      submitBtn.className = "m-button m-button-primary";
    }
  }

  async handleSubmit() {
    const state = web3Manager.getState();
    if (!state.isConnected) {
      alert("Please connect your Web3 wallet first.");
      return;
    }

    const tokenAddr = document.getElementById("input-token-address").value.trim();
    const recipientAddr = document.getElementById("input-recipient-address").value.trim();
    const amountStr = document.getElementById("input-amount").value.trim();
    const targetAddr = document.getElementById("input-target-address").value.trim();
    const expectedHash = document.getElementById("input-expected-hash").value.trim();
    const deadlineVal = document.getElementById("input-deadline").value;

    if (!ethers.isAddress(tokenAddr)) return this.showNotice("Invalid token address.", "error");
    if (!ethers.isAddress(recipientAddr)) return this.showNotice("Invalid recipient address.", "error");
    if (!ethers.isAddress(targetAddr)) return this.showNotice("Invalid target address.", "error");
    if (!expectedHash.startsWith("0x") || expectedHash.length !== 66) {
      return this.showNotice("Expected code hash must be a 66-character bytes32 hex string.", "error");
    }

    const amountNum = parseFloat(amountStr);
    if (isNaN(amountNum) || amountNum <= 0) {
      return this.showNotice("Amount must be greater than zero.", "error");
    }

    const deadlineUnix = Math.floor(new Date(deadlineVal).getTime() / 1000);
    const nowUnix = Math.floor(Date.now() / 1000);
    if (deadlineUnix <= nowUnix) {
      return this.showNotice("DeadlineNotFuture(): Deadline must be strictly in the future.", "error");
    }

    const amountUnits = ethers.parseUnits(amountStr, 6);
    const submitBtn = document.getElementById("btn-submit-create");
    const action = submitBtn.dataset.action;

    if (action === "approve") {
      await this.executeApprove(tokenAddr, amountUnits);
    } else {
      await this.executeCreate(tokenAddr, recipientAddr, amountUnits, targetAddr, expectedHash, deadlineUnix);
    }
  }

  async executeApprove(tokenAddr, amountUnits) {
    const submitBtn = document.getElementById("btn-submit-create");
    try {
      this.isApproving = true;
      submitBtn.disabled = true;
      submitBtn.textContent = "APPROVING IN WALLET...";
      this.showNotice("Please confirm token approval transaction in your wallet...", "info");

      const token = web3Manager.getTokenContract(true);
      const vaultAddr = web3Manager.getVaultAddress();
      const tx = await token.approve(vaultAddr, amountUnits);
      this.showNotice(`Approval submitted (tx: ${tx.hash.substring(0, 10)}...). Waiting for confirmation...`, "info");

      await tx.wait(1);
      await web3Manager.refreshUserData();
      this.showNotice(`[OK] Approved successfully. Proceed to create tranche.`, "success");
      this.checkAllowanceStatus();
    } catch (err) {
      const decoded = web3Manager.decodeError(err);
      this.showNotice(`Approval failed: ${decoded}`, "error");
    } finally {
      this.isApproving = false;
      this.checkAllowanceStatus();
    }
  }

  async executeCreate(tokenAddr, recipientAddr, amountUnits, targetAddr, expectedHash, deadlineUnix) {
    const submitBtn = document.getElementById("btn-submit-create");
    const state = web3Manager.getState();
    const explorer = state.chainConfig ? state.chainConfig.explorerUrl : "";

    try {
      this.isCreating = true;
      submitBtn.disabled = true;
      submitBtn.textContent = "TRANSACTING ONCHAIN...";
      this.showNotice("Please confirm createTranche in your wallet...", "info");

      const vault = web3Manager.getVaultContract(true);
      const tx = await vault.createTranche(
        tokenAddr,
        recipientAddr,
        amountUnits,
        targetAddr,
        expectedHash,
        deadlineUnix
      );

      this.showNotice(`Transaction broadcasted: ${tx.hash}. Awaiting block inclusion...`, "info");
      const receipt = await tx.wait(1);

      // Extract TrancheCreated event
      let createdId = null;
      if (receipt.logs) {
        for (const log of receipt.logs) {
          try {
            const parsed = vault.interface.parseLog(log);
            if (parsed && parsed.name === "TrancheCreated") {
              createdId = parsed.args.id.toString();
              break;
            }
          } catch (e) {
            // Not a vault log
          }
        }
      }

      const txLink = explorer ? `<a href="${explorer}/tx/${receipt.hash}" target="_blank" rel="noopener">View on Explorer</a>` : "";
      const idNotice = createdId ? `New Tranche ID: #${createdId}` : "Tranche created successfully";

      this.showNotice(`
        <strong>[OK] ${idNotice}</strong><br>
        Transaction Block: ${receipt.blockNumber} — ${txLink}
      `, "success");

      await web3Manager.refreshUserData();
      if (this.onTrancheCreated) this.onTrancheCreated(createdId);
    } catch (err) {
      const decoded = web3Manager.decodeError(err);
      this.showNotice(`createTranche failed: ${decoded}`, "error");
    } finally {
      this.isCreating = false;
      this.checkAllowanceStatus();
    }
  }

  showNotice(msg, type = "info") {
    const box = document.getElementById("create-notice-box");
    if (!box) return;

    if (!msg) {
      box.style.display = "none";
      return;
    }

    box.style.display = "block";
    if (type === "error") {
      box.className = "m-notice m-notice--error";
      box.innerHTML = `<strong>ERROR:</strong> ${msg}`;
    } else if (type === "success") {
      box.className = "m-box m-box--heavy";
      box.style.borderColor = "var(--ink)";
      box.innerHTML = `<span class="m-tag m-tag--accent">[SUCCESS]</span> ${msg}`;
    } else {
      box.className = "m-box";
      box.innerHTML = `<span class="m-tag">[INFO]</span> ${msg}`;
    }
  }
}
