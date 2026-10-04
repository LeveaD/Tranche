import { ethers } from "ethers";
import { web3Manager } from "./web3.js";
import { STATUS_MAP, DEPLOYMENTS, EMPTY_ACCOUNT_CODEHASH } from "./contracts/config.js";

export class LedgerManager {
  constructor(onSelectTranche) {
    this.onSelectTranche = onSelectTranche;
    this.tranches = [];
    this.filterStatus = "ALL";
    this.searchQuery = "";
    this.sortField = "id";
    this.sortAsc = false;
    this.isLoading = false;

    // Listen to web3 manager changes
    web3Manager.subscribe(() => {
      this.loadTranches();
    });
  }

  async loadTranches() {
    this.isLoading = true;
    this.render();

    const state = web3Manager.getState();
    const chainConfig = state.chainConfig;
    const items = [];

    // Preload known demo tranches from manifest
    if (chainConfig && chainConfig.demoTranches) {
      for (const dt of chainConfig.demoTranches) {
        items.push({
          id: dt.id,
          funder: dt.funder,
          recipient: dt.recipient,
          token: dt.token,
          amount: dt.amount,
          target: dt.target,
          expectedCodeHash: dt.expectedCodeHash,
          deadline: Number(dt.deadline),
          status: dt.status,
          payoutTo: dt.payoutTo,
          refundTo: dt.refundTo,
          isClaimable: false,
          isClawbackable: false,
          currentCodeHash: null,
          note: dt.note || ""
        });
      }
    }

    // Try reading live from chain if provider available
    const provider = web3Manager.getProvider();
    if (provider && state.vaultAddress) {
      try {
        const vault = web3Manager.getVaultContract(false);
        // Query IDs 1 through 10 (or until TrancheNotFound error)
        for (let id = 1; id <= 10; id++) {
          try {
            const t = await vault.getTranche(id);
            const isClaim = await vault.isClaimable(id).catch(() => false);
            const isClaw = await vault.isClawbackable(id).catch(() => false);
            const code = await provider.getCode(t.target).catch(() => "0x");
            const currentCodeHash = code && code !== "0x" ? ethers.keccak256(code) : EMPTY_ACCOUNT_CODEHASH;

            const existingIdx = items.findIndex(x => x.id === id);
            const trancheData = {
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
              currentCodeHash: currentCodeHash,
              note: existingIdx >= 0 ? items[existingIdx].note : "Live onchain tranche"
            };

            if (existingIdx >= 0) {
              items[existingIdx] = trancheData;
            } else {
              items.push(trancheData);
            }
          } catch (err) {
            // Reached non-existent tranche ID or revert
            break;
          }
        }
      } catch (err) {
        console.warn("Could not query live vault tranches:", err);
      }
    }

    this.tranches = items;
    this.isLoading = false;
    this.render();
  }

  setFilter(status) {
    this.filterStatus = status;
    this.render();
  }

  setSearch(query) {
    this.searchQuery = query.toLowerCase().trim();
    this.render();
  }

  setSort(field) {
    if (this.sortField === field) {
      this.sortAsc = !this.sortAsc;
    } else {
      this.sortField = field;
      this.sortAsc = true;
    }
    this.render();
  }

  getFilteredTranches() {
    let result = [...this.tranches];

    if (this.filterStatus !== "ALL") {
      const targetStatusNum = parseInt(this.filterStatus, 10);
      result = result.filter(t => t.status === targetStatusNum);
    }

    if (this.searchQuery) {
      result = result.filter(t =>
        String(t.id).includes(this.searchQuery) ||
        t.recipient.toLowerCase().includes(this.searchQuery) ||
        t.funder.toLowerCase().includes(this.searchQuery) ||
        t.target.toLowerCase().includes(this.searchQuery)
      );
    }

    result.sort((a, b) => {
      let va = a[this.sortField];
      let vb = b[this.sortField];
      if (typeof va === "string") va = va.toLowerCase();
      if (typeof vb === "string") vb = vb.toLowerCase();
      if (va < vb) return this.sortAsc ? -1 : 1;
      if (va > vb) return this.sortAsc ? 1 : -1;
      return 0;
    });

    return result;
  }

  formatAmount(rawAmount) {
    try {
      const val = ethers.formatUnits(rawAmount, 6);
      return `$${Number(val).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 6 })} USDG`;
    } catch {
      return `${rawAmount} units`;
    }
  }

  formatDeadline(deadlineUnix) {
    const now = Math.floor(Date.now() / 1000);
    const diff = deadlineUnix - now;
    const dateStr = new Date(deadlineUnix * 1000).toISOString().replace("T", " ").substring(0, 19) + " UTC";

    if (diff <= 0) {
      const pastSeconds = Math.abs(diff);
      const hours = Math.floor(pastSeconds / 3600);
      const mins = Math.floor((pastSeconds % 3600) / 60);
      return {
        text: `EXPIRED (${hours}h ${mins}m ago)`,
        tagClass: "m-tag m-tag--error",
        raw: dateStr,
        isExpired: true
      };
    } else {
      const days = Math.floor(diff / 86400);
      const hours = Math.floor((diff % 86400) / 3600);
      const mins = Math.floor((diff % 3600) / 60);
      const timeRemaining = days > 0 ? `${days}d ${hours}h left` : `${hours}h ${mins}m left`;
      return {
        text: timeRemaining,
        tagClass: "m-tag m-tag--accent",
        raw: dateStr,
        isExpired: false
      };
    }
  }

  shorten(addr) {
    if (!addr || addr.length < 10) return addr;
    return addr.substring(0, 6) + "…" + addr.substring(addr.length - 4);
  }

  render() {
    const container = document.getElementById("ledger-table-container");
    if (!container) return;

    const filtered = this.getFilteredTranches();
    const state = web3Manager.getState();
    const explorer = state.chainConfig ? state.chainConfig.explorerUrl : "";

    const sortArrow = (field) => {
      if (this.sortField !== field) return "";
      return this.sortAsc ? " ↑" : " ↓";
    };

    let tableHtml = `
      <div class="m-table-wrap">
        <table class="m-table" id="archive-table">
          <thead>
            <tr>
              <th data-sort="id">ID${sortArrow("id")}</th>
              <th data-sort="status">STATUS${sortArrow("status")}</th>
              <th data-sort="amount">AMOUNT (USDG)${sortArrow("amount")}</th>
              <th>RECIPIENT / PAYOUT</th>
              <th>TARGET ADDRESS</th>
              <th>EXPECTED CODEHASH</th>
              <th data-sort="deadline">DEADLINE & REMAINING${sortArrow("deadline")}</th>
              <th>ACTIONS</th>
            </tr>
          </thead>
          <tbody>
    `;

    if (filtered.length === 0) {
      tableHtml += `
        <tr>
          <td colspan="8" style="text-align: center; padding: 2rem; color: var(--ink-mid); font-weight: 700;">
            ${this.isLoading ? "LOADING ONCHAIN TRANCHES..." : "NO TRANCHES FOUND."}
          </td>
        </tr>
      `;
    } else {
      for (const t of filtered) {
        const statusMeta = STATUS_MAP[t.status] || { label: "UNKNOWN", tagClass: "m-tag" };
        const deadlineInfo = this.formatDeadline(t.deadline);
        const recipientLink = explorer ? `${explorer}/address/${t.recipient}` : `#`;
        const targetLink = explorer ? `${explorer}/address/${t.target}` : `#`;

        tableHtml += `
          <tr data-tranche-id="${t.id}">
            <td><strong>#${t.id}</strong></td>
            <td><span class="${statusMeta.tagClass}">${statusMeta.label}</span></td>
            <td><strong>${this.formatAmount(t.amount)}</strong></td>
            <td>
              <a href="${recipientLink}" target="_blank" rel="noopener">${this.shorten(t.recipient)}</a>
              ${t.payoutTo && t.payoutTo !== t.recipient ? `<br><span class="text-micro">→ ${this.shorten(t.payoutTo)}</span>` : ""}
            </td>
            <td>
              <a href="${targetLink}" target="_blank" rel="noopener">${this.shorten(t.target)}</a>
            </td>
            <td>
              <span title="${t.expectedCodeHash}" style="font-family: var(--font-mono); font-size: 0.75rem;">
                ${t.expectedCodeHash.substring(0, 10)}…${t.expectedCodeHash.substring(t.expectedCodeHash.length - 8)}
              </span>
            </td>
            <td>
              <span class="${deadlineInfo.tagClass}">${deadlineInfo.text}</span>
              <div class="text-micro" style="margin-top: 2px;">${deadlineInfo.raw}</div>
            </td>
            <td style="white-space: nowrap;">
              <button class="m-button m-button-sm action-inspect" data-id="${t.id}">INSPECT</button>
              ${t.status === 1 ? `<button class="m-button m-button-sm m-button-primary action-quick-settle" data-id="${t.id}">SETTLE</button>` : ""}
            </td>
          </tr>
        `;
      }
    }

    tableHtml += `
          </tbody>
        </table>
      </div>
    `;

    container.innerHTML = tableHtml;

    // Attach sort event listeners to table headers
    container.querySelectorAll("th[data-sort]").forEach(th => {
      th.addEventListener("click", () => {
        this.setSort(th.getAttribute("data-sort"));
      });
    });

    // Attach inspect and settle actions
    container.querySelectorAll(".action-inspect, .action-quick-settle").forEach(btn => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const id = parseInt(btn.getAttribute("data-id"), 10);
        if (this.onSelectTranche) this.onSelectTranche(id);
      });
    });

    // Row click to inspect
    container.querySelectorAll("tbody tr[data-tranche-id]").forEach(row => {
      row.addEventListener("click", () => {
        const id = parseInt(row.getAttribute("data-tranche-id"), 10);
        if (this.onSelectTranche) this.onSelectTranche(id);
      });
    });
  }
}
