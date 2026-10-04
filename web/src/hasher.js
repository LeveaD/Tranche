import { ethers } from "ethers";
import { web3Manager } from "./web3.js";
import { DEMO_DELIVERABLE_CODEHASH, EMPTY_ACCOUNT_CODEHASH } from "./contracts/config.js";

// DemoDeliverable runtime bytecode for live testing
const SAMPLE_DEMO_BYTECODE = "0x6080604052348015600f57600080fd5b506004361060265760003560e01c806385f0ef3214602b575b600080fd5b60336049565b604051901515815260200160405180910390f35b60019056fea26469706673582212204f2c2560b3cfd6480bfc7600029770cc30aebf950b85f16f8fd8b82136da741564736f6c63430008180033";

export class HasherManager {
  init() {
    this.bindEvents();
  }

  bindEvents() {
    // 1. Bytecode Hasher
    const hashBtn = document.getElementById("btn-compute-hash");
    const inputBytecode = document.getElementById("input-raw-bytecode");
    if (hashBtn && inputBytecode) {
      hashBtn.addEventListener("click", () => this.computeBytecodeHash());
    }

    const sampleBtn = document.getElementById("btn-load-sample-bytecode");
    if (sampleBtn && inputBytecode) {
      sampleBtn.addEventListener("click", () => {
        inputBytecode.value = SAMPLE_DEMO_BYTECODE;
        this.computeBytecodeHash();
      });
    }

    // 2. CREATE Address Calculator
    const calcCreateBtn = document.getElementById("btn-calc-create-addr");
    if (calcCreateBtn) {
      calcCreateBtn.addEventListener("click", () => this.calcCreateAddress());
    }

    // 3. Live Address Inspector
    const inspectBtn = document.getElementById("btn-inspect-address-code");
    if (inspectBtn) {
      inspectBtn.addEventListener("click", () => this.inspectAddressCode());
    }
  }

  computeBytecodeHash() {
    const input = document.getElementById("input-raw-bytecode");
    const resultBox = document.getElementById("hasher-result-box");
    if (!input || !resultBox) return;

    let hex = input.value.trim();
    if (!hex) {
      resultBox.innerHTML = `<div class="m-notice m-notice--error">Please enter or paste hex bytecode.</div>`;
      return;
    }

    if (!hex.startsWith("0x")) hex = "0x" + hex;

    try {
      const hash = ethers.keccak256(hex);
      const byteLen = (hex.length - 2) / 2;
      const isEmpty = hash.toLowerCase() === EMPTY_ACCOUNT_CODEHASH.toLowerCase();

      resultBox.innerHTML = `
        <div class="m-box m-box--heavy">
          <div style="margin-bottom: 0.5rem;">
            <strong>RUNTIME BYTECODE HASH (keccak256):</strong>
          </div>
          <pre><code>${hash}</code></pre>
          <div class="text-data" style="margin-top: 0.5rem;">
            Byte Length: <strong>${byteLen} bytes</strong> &nbsp;|&nbsp;
            ${isEmpty ? '<span class="m-tag m-tag--error">[EMPTY BYTECODE - FORBIDDEN]</span>' : '<span class="m-tag m-tag--accent">[VALID HASH]</span>'}
          </div>
          <div style="margin-top: 0.75rem;">
            <button class="m-button m-button-sm" id="btn-copy-hash" data-hash="${hash}">[COPY HASH TO CLIPBOARD]</button>
          </div>
        </div>
      `;

      const copyBtn = document.getElementById("btn-copy-hash");
      if (copyBtn) {
        copyBtn.addEventListener("click", () => {
          navigator.clipboard.writeText(hash);
          copyBtn.textContent = "[COPIED!]";
          setTimeout(() => { copyBtn.textContent = "[COPY HASH TO CLIPBOARD]"; }, 2000);
        });
      }
    } catch (err) {
      resultBox.innerHTML = `<div class="m-notice m-notice--error">Invalid hex bytecode: ${err.message}</div>`;
    }
  }

  calcCreateAddress() {
    const deployerInput = document.getElementById("input-create-deployer");
    const nonceInput = document.getElementById("input-create-nonce");
    const resultBox = document.getElementById("create-calc-result");
    if (!deployerInput || !nonceInput || !resultBox) return;

    const deployer = deployerInput.value.trim();
    const nonceStr = nonceInput.value.trim();

    if (!ethers.isAddress(deployer)) {
      resultBox.innerHTML = `<div class="m-notice m-notice--error">Invalid deployer address.</div>`;
      return;
    }

    const nonce = parseInt(nonceStr, 10);
    if (isNaN(nonce) || nonce < 0) {
      resultBox.innerHTML = `<div class="m-notice m-notice--error">Invalid nonce (must be >= 0).</div>`;
      return;
    }

    try {
      const predictedAddr = ethers.getCreateAddress({ from: deployer, nonce: nonce });
      resultBox.innerHTML = `
        <div class="m-box">
          <div style="margin-bottom: 0.25rem;">PREDICTED CONTRACT DEPLOYMENT ADDRESS (CREATE):</div>
          <pre><code>${predictedAddr}</code></pre>
          <div class="text-micro" style="margin-top: 0.25rem;">
            Formula: keccak256(rlp([deployer, nonce]))[12..32]
          </div>
        </div>
      `;
    } catch (err) {
      resultBox.innerHTML = `<div class="m-notice m-notice--error">${err.message}</div>`;
    }
  }

  async inspectAddressCode() {
    const input = document.getElementById("input-inspect-address");
    const resultBox = document.getElementById("inspect-code-result");
    if (!input || !resultBox) return;

    const addr = input.value.trim();
    if (!ethers.isAddress(addr)) {
      resultBox.innerHTML = `<div class="m-notice m-notice--error">Invalid Ethereum address.</div>`;
      return;
    }

    resultBox.innerHTML = `<div class="m-box"><span class="m-cursor">FETCHING ONCHAIN BYTECODE...</span></div>`;

    try {
      const provider = web3Manager.getProvider();
      if (!provider) throw new Error("No provider available.");

      const code = await provider.getCode(addr);
      const isContract = code && code !== "0x";
      const hash = isContract ? ethers.keccak256(code) : EMPTY_ACCOUNT_CODEHASH;
      const byteLen = isContract ? (code.length - 2) / 2 : 0;

      resultBox.innerHTML = `
        <div class="m-box m-box--heavy">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
            <strong>ADDRESS INSPECTION:</strong>
            ${isContract ? '<span class="m-tag m-tag--accent">[CONTRACT BYTECODE PRESENT]</span>' : '<span class="m-tag">[EOA / EMPTY ACCOUNT]</span>'}
          </div>
          <div class="text-data">
            Runtime Size: <strong>${byteLen} bytes</strong><br>
            Runtime Code Hash: <code style="word-break: break-all;">${hash}</code>
          </div>
          ${isContract ? `
            <div style="margin-top: 0.75rem;">
              <details>
                <summary style="cursor: pointer; font-family: var(--font-mono); font-size: 0.75rem;">[VIEW RAW BYTECODE HEX (${code.length} chars)]</summary>
                <pre style="max-height: 150px; overflow-y: auto; margin-top: 0.5rem;"><code>${code}</code></pre>
              </details>
            </div>
          ` : ''}
        </div>
      `;
    } catch (err) {
      resultBox.innerHTML = `<div class="m-notice m-notice--error">Inspection failed: ${err.message}</div>`;
    }
  }
}
