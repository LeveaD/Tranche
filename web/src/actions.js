import { ethers } from "ethers";
import { web3Manager } from "./web3.js";
import { STATUS_MAP, EMPTY_ACCOUNT_CODEHASH } from "./contracts/config.js";

export class ActionsManager {
  constructor(onActionComplete) {
    this.onActionComplete = onActionComplete;
    this.currentTranche = null;
    this.isLoading = false;
  }

  init() {
    this.bindEvents();
  }

  bindEvents() {
    const lookupBtn = document.getElementById("btn-lookup-tranche");
    const lookupInput = document.getElementById("input-lookup-id");
    if (lookupBtn && lookupInput) {
      lookupBtn.addEventListener("click", () => {
        const id = parseInt(lookupInput.value.trim(), 10);
        if (!isNaN(id) && id > 0) this.inspectTranche(id);
      });
      lookupInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter") {
          const id = parseInt(lookupInput.value.trim(), 10);
          if (!isNaN(id) && id > 0) this.inspectTranche(id);
        }
      });
    }
  }

  async inspectTranche(id) {
    this.isLoading = true;
    const container = document.getElementById("inspect-result-container");
    if (container) {
      container.innerHTML = `<div class="m-box"><span class="m-cursor">QUERYING TRANCHE #${id} ONCHAIN</span></div>`;
    }

    try {
      const state = web3Manager.getState();
      const vault = web3Manager.getVaultContract(false);
      const provider = web3Manager.getProvider();

      const t = await vault.getTranche(id);
      const isClaim = await vault.isClaimable(id).catch(() => false);
      const isClaw = await vault.isClawbackable(id).catch(() => false);

      // Check current deployed code on target
      let targetCode = "0x";
      let targetCodeHash = EMPTY_ACCOUNT_CODEHASH;
      if (provider && t.target) {
        targetCode = await provider.getCode(t.target).catch(() => "0x");
        if (targetCode && targetCode !== "0x") {
          targetCodeHash = ethers.keccak256(targetCode);
        }
      }

      this.currentTranche = {
        id: id,
        funder: t.funder,
        recipient: t.recipient,
        token: t.token,
        amount: t.amount.toString(),
        target: t.target,
        expectedCodeHash: t.expectedCodeHash,
        deadline: Number(t.deadline),
        status: Number(t.status),
        payoutTo: t.payoutTo,
        refundTo: t.refundTo,
        isClaimable: isClaim,
        isClawbackable: isClaw,
        targetCode: targetCode,
        targetCodeHash: targetCodeHash
      };

      this.renderInspector();
    } catch (err) {
      const decoded = web3Manager.decodeError(err);
      if (container) {
        container.innerHTML = `
          <div class="m-notice m-notice--error">
            <strong>ERROR:</strong> Tranche #${id} could not be retrieved. ${decoded}
          </div>
        `;
      }
    } finally {
      this.isLoading = false;
    }
  }

  renderInspector() {
    const container = document.getElementById("inspect-result-container");
    if (!container || !this.currentTranche) return;

    const t = this.currentTranche;
    const state = web3Manager.getState();
    const explorer = state.chainConfig ? state.chainConfig.explorerUrl : "";
    const statusMeta = STATUS_MAP[t.status] || { label: "UNKNOWN", tagClass: "m-tag" };

    const now = Math.floor(Date.now() / 1000);
    const isPastDeadline = now > t.deadline;
    const isExactBoundary = now === t.deadline;
    const deadlineDate = new Date(t.deadline * 1000).toUTCString();

    const isCodeMatch = t.targetCodeHash.toLowerCase() === t.expectedCodeHash.toLowerCase();
    const isTargetEmpty = t.targetCodeHash.toLowerCase() === EMPTY_ACCOUNT_CODEHASH.toLowerCase();

    let codeStatusBadge = "";
    if (isCodeMatch) {
      codeStatusBadge = `<span class="m-tag m-tag--accent">[CODE VERIFIED: EXACT MATCH]</span>`;
    } else if (isTargetEmpty) {
      codeStatusBadge = `<span class="m-tag">[UNDEPLOYED: 0 BYTES AT TARGET]</span>`;
    } else {
      codeStatusBadge = `<span class="m-tag m-tag--error">[MISMATCH: UNEXPECTED BYTECODE]</span>`;
    }

    const isCallerRecipient = state.walletAddress && state.walletAddress.toLowerCase() === t.recipient.toLowerCase();
    const isCallerFunder = state.walletAddress && state.walletAddress.toLowerCase() === t.funder.toLowerCase();
    const isActive = t.status === 1;

    const linkOf = (addr) => explorer ? `<a href="${explorer}/address/${addr}" target="_blank" rel="noopener">${addr}</a>` : addr;

    let html = `
      <div class="m-box m-box--heavy">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1rem;">
          <h3 class="text-heading" style="font-size: 1.5rem;">TRANCHE #${t.id}</h3>
          <div>
            <span class="${statusMeta.tagClass}">${statusMeta.label}</span>
            ${codeStatusBadge}
          </div>
        </div>

        <div class="m-table-wrap">
          <table class="m-table">
            <tbody>
              <tr><td style="width: 25%;"><strong>LOCKED AMOUNT</strong></td><td><strong>${ethers.formatUnits(t.amount, 6)} USDG</strong></td></tr>
              <tr><td><strong>FUNDER</strong></td><td>${linkOf(t.funder)}</td></tr>
              <tr><td><strong>RECIPIENT</strong></td><td>${linkOf(t.recipient)}</td></tr>
              <tr><td><strong>PAYOUT DESTINATION</strong></td><td>${linkOf(t.payoutTo)} ${t.payoutTo !== t.recipient ? '<span class="m-tag">[REDIRECTED]</span>' : ''}</td></tr>
              <tr><td><strong>REFUND DESTINATION</strong></td><td>${linkOf(t.refundTo)} ${t.refundTo !== t.funder ? '<span class="m-tag">[REDIRECTED]</span>' : ''}</td></tr>
              <tr><td><strong>TARGET ADDRESS</strong></td><td>${linkOf(t.target)}</td></tr>
              <tr>
                <td><strong>EXPECTED CODEHASH</strong></td>
                <td><code style="word-break: break-all;">${t.expectedCodeHash}</code></td>
              </tr>
              <tr>
                <td><strong>CURRENT CODEHASH</strong></td>
                <td>
                  <code style="word-break: break-all;">${t.targetCodeHash}</code>
                  ${isCodeMatch ? '<br><span class="m-tag m-tag--accent" style="margin-top: 4px;">VERIFIED DELIVERABLE ONCHAIN</span>' : ''}
                </td>
              </tr>
              <tr>
                <td><strong>DEADLINE (UNIX)</strong></td>
                <td>
                  <strong>${t.deadline}</strong> — ${deadlineDate}<br>
                  ${isPastDeadline ? `<span class="m-tag m-tag--error">EXPIRED (DEADLINE PASSED)</span>` : `<span class="m-tag m-tag--accent">ACTIVE WINDOW (${t.deadline - now}s REMAINING)</span>`}
                </td>
              </tr>
              <tr>
                <td><strong>VIEW STATUS</strong></td>
                <td>
                  isClaimable: <strong>${t.isClaimable ? '<span class="m-tag m-tag--accent">[TRUE]</span>' : '[FALSE]'}</strong> &nbsp;|&nbsp;
                  isClawbackable: <strong>${t.isClawbackable ? '<span class="m-tag m-tag--error">[TRUE]</span>' : '[FALSE]'}</strong>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="rule rule--hair"></div>

        <!-- Settlement Actions Grid -->
        <h4 class="text-heading" style="margin-bottom: 0.75rem;">SETTLEMENT & PROTOCOL ACTIONS</h4>

        <div style="display: flex; gap: 0.75rem; flex-wrap: wrap; margin-bottom: 1.25rem;">
          <!-- Claim Button -->
          <button id="btn-action-claim" class="m-button ${t.isClaimable ? 'm-button-primary' : ''}" ${!t.isClaimable || !isActive ? 'disabled' : ''}>
            [CLAIM (${ethers.formatUnits(t.amount, 6)} USDG)]
          </button>

          <!-- Clawback Button -->
          <button id="btn-action-clawback" class="m-button ${t.isClawbackable ? 'm-button-primary' : ''}" ${!t.isClawbackable || !isActive ? 'disabled' : ''}>
            [CLAWBACK REFUND]
          </button>

          <!-- Decline Button (Recipient only) -->
          <button id="btn-action-decline" class="m-button m-button-danger" ${!isActive || !isCallerRecipient ? 'disabled' : ''} title="${!isCallerRecipient ? 'Only callable by recipient' : ''}">
            [DECLINE TRANCHE]
          </button>
        </div>

        <!-- Optional Redirection Panel -->
        ${isActive ? `
          <div class="m-box" style="margin-top: 1rem; background: var(--paper-tint);">
            <div style="font-family: var(--font-mono); font-size: 0.8rem; font-weight: 700; margin-bottom: 0.5rem; text-transform: uppercase;">
              ADDRESS REDIRECTION (EMERGENCY ADDRESS FREEZING / COMPROMISE FALLBACK)
            </div>
            <div class="m-form-grid">
              <div>
                <label>Set Payout To (Recipient Only)</label>
                <div style="display: flex; gap: 0.5rem;">
                  <input type="text" id="input-new-payout" class="m-input" placeholder="0x... new payout address" ${!isCallerRecipient ? 'disabled' : ''}>
                  <button id="btn-action-set-payout" class="m-button m-button-sm" ${!isCallerRecipient ? 'disabled' : ''}>UPDATE</button>
                </div>
                ${!isCallerRecipient ? '<div class="text-micro" style="margin-top: 4px;">Connected wallet is not recipient</div>' : ''}
              </div>
              <div>
                <label>Set Refund To (Funder Only)</label>
                <div style="display: flex; gap: 0.5rem;">
                  <input type="text" id="input-new-refund" class="m-input" placeholder="0x... new refund address" ${!isCallerFunder ? 'disabled' : ''}>
                  <button id="btn-action-set-refund" class="m-button m-button-sm" ${!isCallerFunder ? 'disabled' : ''}>UPDATE</button>
                </div>
                ${!isCallerFunder ? '<div class="text-micro" style="margin-top: 4px;">Connected wallet is not funder</div>' : ''}
              </div>
            </div>
          </div>
        ` : ''}

        <div id="action-notice-box" style="margin-top: 1rem; display: none;"></div>
      </div>
    `;

    container.innerHTML = html;

    // Attach Action Listeners
    const claimBtn = document.getElementById("btn-action-claim");
    if (claimBtn && t.isClaimable && isActive) {
      claimBtn.addEventListener("click", () => this.executeClaim(t.id));
    }

    const clawbackBtn = document.getElementById("btn-action-clawback");
    if (clawbackBtn && t.isClawbackable && isActive) {
      clawbackBtn.addEventListener("click", () => this.executeClawback(t.id));
    }

    const declineBtn = document.getElementById("btn-action-decline");
    if (declineBtn && isCallerRecipient && isActive) {
      declineBtn.addEventListener("click", () => this.executeDecline(t.id));
    }

    const setPayoutBtn = document.getElementById("btn-action-set-payout");
    if (setPayoutBtn && isCallerRecipient && isActive) {
      setPayoutBtn.addEventListener("click", () => {
        const addr = document.getElementById("input-new-payout").value.trim();
        this.executeSetPayoutTo(t.id, addr);
      });
    }

    const setRefundBtn = document.getElementById("btn-action-set-refund");
    if (setRefundBtn && isCallerFunder && isActive) {
      setRefundBtn.addEventListener("click", () => {
        const addr = document.getElementById("input-new-refund").value.trim();
        this.executeSetRefundTo(t.id, addr);
      });
    }
  }

  async executeClaim(id) {
    try {
      this.showNotice("Please sign claim transaction in your wallet...", "info");
      const vault = web3Manager.getVaultContract(true);
      const tx = await vault.claim(id);
      this.showNotice(`Transaction submitted (${tx.hash}). Waiting confirmation...`, "info");
      const receipt = await tx.wait(1);
      this.showNotice(`[OK] Tranche #${id} claimed successfully! Funds released. Block ${receipt.blockNumber}`, "success");
      await this.inspectTranche(id);
      if (this.onActionComplete) this.onActionComplete();
    } catch (err) {
      this.showNotice(`Claim failed: ${web3Manager.decodeError(err)}`, "error");
    }
  }

  async executeClawback(id) {
    try {
      this.showNotice("Please sign clawback transaction in your wallet...", "info");
      const vault = web3Manager.getVaultContract(true);
      const tx = await vault.clawback(id);
      this.showNotice(`Transaction submitted (${tx.hash}). Waiting confirmation...`, "info");
      const receipt = await tx.wait(1);
      this.showNotice(`[OK] Tranche #${id} clawed back! Funds refunded. Block ${receipt.blockNumber}`, "success");
      await this.inspectTranche(id);
      if (this.onActionComplete) this.onActionComplete();
    } catch (err) {
      this.showNotice(`Clawback failed: ${web3Manager.decodeError(err)}`, "error");
    }
  }

  async executeDecline(id) {
    if (!confirm(`Are you sure you want to decline Tranche #${id}? Tokens will be immediately returned to the funder.`)) return;
    try {
      this.showNotice("Signing decline transaction in your wallet...", "info");
      const vault = web3Manager.getVaultContract(true);
      const tx = await vault.decline(id);
      this.showNotice(`Transaction submitted (${tx.hash})...`, "info");
      await tx.wait(1);
      this.showNotice(`[OK] Tranche #${id} declined. Funds returned to funder.`, "success");
      await this.inspectTranche(id);
      if (this.onActionComplete) this.onActionComplete();
    } catch (err) {
      this.showNotice(`Decline failed: ${web3Manager.decodeError(err)}`, "error");
    }
  }

  async executeSetPayoutTo(id, newAddr) {
    if (!ethers.isAddress(newAddr)) return this.showNotice("Invalid payout address.", "error");
    try {
      this.showNotice("Updating payout destination...", "info");
      const vault = web3Manager.getVaultContract(true);
      const tx = await vault.setPayoutTo(id, newAddr);
      await tx.wait(1);
      this.showNotice(`[OK] Payout address updated to ${newAddr}`, "success");
      await this.inspectTranche(id);
    } catch (err) {
      this.showNotice(`Update payout failed: ${web3Manager.decodeError(err)}`, "error");
    }
  }

  async executeSetRefundTo(id, newAddr) {
    if (!ethers.isAddress(newAddr)) return this.showNotice("Invalid refund address.", "error");
    try {
      this.showNotice("Updating refund destination...", "info");
      const vault = web3Manager.getVaultContract(true);
      const tx = await vault.setRefundTo(id, newAddr);
      await tx.wait(1);
      this.showNotice(`[OK] Refund address updated to ${newAddr}`, "success");
      await this.inspectTranche(id);
    } catch (err) {
      this.showNotice(`Update refund failed: ${web3Manager.decodeError(err)}`, "error");
    }
  }

  showNotice(msg, type = "info") {
    const box = document.getElementById("action-notice-box");
    if (!box) return;
    box.style.display = "block";
    if (type === "error") {
      box.className = "m-notice m-notice--error";
      box.innerHTML = `<strong>ERROR:</strong> ${msg}`;
    } else if (type === "success") {
      box.className = "m-box m-box--heavy";
      box.innerHTML = `<span class="m-tag m-tag--accent">[SUCCESS]</span> ${msg}`;
    } else {
      box.className = "m-box";
      box.innerHTML = `<span class="m-tag">[INFO]</span> ${msg}`;
    }
  }
}
