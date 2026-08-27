(() => {
  const config = window.STORAGE_CLEARER_CONFIG || {};
  const header = document.querySelector("[data-header]");
  const navToggle = document.querySelector("[data-nav-toggle]");
  const navMenu = document.querySelector("[data-nav-menu]");
  const setScrolled = () => header?.classList.toggle("is-scrolled", window.scrollY > 8);
  setScrolled();
  window.addEventListener("scroll", setScrolled, { passive: true });

  navToggle?.addEventListener("click", () => {
    const open = navToggle.getAttribute("aria-expanded") === "true";
    navToggle.setAttribute("aria-expanded", String(!open));
    navMenu?.classList.toggle("is-open", !open);
  });
  navMenu?.querySelectorAll("a").forEach((link) => link.addEventListener("click", () => {
    navToggle?.setAttribute("aria-expanded", "false");
    navMenu?.classList.remove("is-open");
  }));

  const enableExternalLink = (selector, url) => {
    const link = document.querySelector(selector);
    if (!link || !url) return false;
    link.href = url;
    link.target = "_blank";
    link.rel = "noreferrer noopener";
    link.classList.remove("is-disabled");
    link.removeAttribute("aria-disabled");
    return true;
  };

  if (enableExternalLink("[data-direct-download]", config.directDownloadUrl)) {
    const button = document.querySelector("[data-direct-download]");
    const title = button?.querySelector("b");
    const detail = button?.querySelector("small");
    const note = document.querySelector("[data-release-note]");
    button?.removeAttribute("target");
    button?.removeAttribute("rel");
    button?.setAttribute("download", "Storage-Clearer-1.0.0-arm64.zip");
    if (title) title.textContent = `Download ${config.releaseVersion || "for macOS"}`;
    if (detail) detail.textContent = config.releaseDetail || "Direct ZIP download";
    if (note) note.textContent = config.releaseSha256 ? `SHA-256: ${config.releaseSha256}` : "Verify the published checksum on the release page.";
  }

  const paypalReady = enableExternalLink("[data-paypal]", config.paypalUrl);
  const cryptoReady = enableExternalLink("[data-crypto]", config.cryptoUrl);
  const supportNote = document.querySelector("[data-support-note]");
  if (cryptoReady) {
    const cryptoDetail = document.querySelector("[data-crypto] small");
    const walletPanel = document.querySelector("[data-wallet-panel]");
    const walletLabel = document.querySelector("[data-wallet-label]");
    const walletAddress = document.querySelector("[data-wallet-address]");
    const copyWallet = document.querySelector("[data-copy-wallet]");
    if (cryptoDetail) cryptoDetail.textContent = `${config.cryptoAsset} on ${config.cryptoNetwork} · Choose amount in wallet`;
    if (walletLabel) walletLabel.textContent = `${config.cryptoAsset} · ${config.cryptoNetwork}`;
    if (walletAddress) walletAddress.textContent = config.cryptoAddress;
    if (walletPanel) walletPanel.hidden = false;
    copyWallet?.addEventListener("click", async () => {
      await navigator.clipboard.writeText(config.cryptoAddress);
      copyWallet.textContent = "Copied";
      window.setTimeout(() => { copyWallet.textContent = "Copy"; }, 1600);
    });
    if (supportNote) supportNote.textContent = `Verify ${config.cryptoAsset}, the ${config.cryptoNetwork} network, and the receiving address in your wallet before confirming.`;
  } else if (supportNote && !paypalReady) {
    supportNote.textContent = "Support links are being connected. No payment details are collected on this website.";
  }

  document.querySelectorAll("a[aria-disabled='true']").forEach((link) => link.addEventListener("click", (event) => event.preventDefault()));

  const dialog = document.querySelector("[data-lightbox-dialog]");
  const dialogImage = document.querySelector("[data-lightbox-image]");
  document.querySelectorAll("[data-lightbox]").forEach((button) => button.addEventListener("click", () => {
    if (!dialog || !dialogImage) return;
    dialogImage.src = button.dataset.lightbox;
    dialogImage.alt = button.querySelector("img")?.alt || "Storage Clearer product screenshot";
    dialog.showModal();
  }));
  document.querySelector("[data-lightbox-close]")?.addEventListener("click", () => dialog?.close());
  dialog?.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });
  document.querySelectorAll("[data-year]").forEach((node) => { node.textContent = String(new Date().getFullYear()); });
})();
