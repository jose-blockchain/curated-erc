import { CATALOG, WINGS } from "./catalog.js";

const grid = document.getElementById("gallery-grid");
const searchInput = document.getElementById("search");
const emptyState = document.getElementById("gallery-empty");
const filters = document.querySelectorAll(".filter");
const modal = document.getElementById("art-modal");
const modalClose = document.querySelector(".modal-close");
const cursorGlow = document.querySelector(".cursor-glow");

let activeFilter = "all";
let searchQuery = "";

function artworkSrc(work) {
  return `img/ercs/${work.id}.jpg`;
}

function createPainting(work) {
  const img = document.createElement("img");
  img.src = artworkSrc(work);
  img.alt = "";
  img.width = 960;
  img.height = 1280;
  img.loading = "lazy";
  img.decoding = "async";
  return img;
}

function renderCard(work) {
  const card = document.createElement("article");
  card.className = "art-card";
  card.dataset.wing = work.wing;
  card.dataset.id = work.id;
  card.tabIndex = 0;
  card.setAttribute("role", "button");
  card.setAttribute("aria-label", `View ERC-${work.number}: ${work.name}`);

  const frame = document.createElement("div");
  frame.className = "art-frame";
  frame.appendChild(createPainting(work));

  const plaque = document.createElement("div");
  plaque.className = "art-plaque";
  plaque.innerHTML = `
    <span class="plaque-wing">${work.category}</span>
    <h3 class="plaque-title">ERC-${work.number}</h3>
    <p class="plaque-name">${work.name}</p>
    <p class="plaque-tagline">${work.tagline}</p>
  `;

  card.append(frame, plaque);

  const open = () => openModal(work);
  card.addEventListener("click", open);
  card.addEventListener("keydown", (e) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      open();
    }
  });

  card.addEventListener("mousemove", (e) => {
    const rect = frame.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    frame.style.transform = `perspective(800px) rotateY(${x * 8}deg) rotateX(${-y * 8}deg) translateZ(12px)`;
  });
  card.addEventListener("mouseleave", () => {
    frame.style.transform = "";
  });

  return card;
}

function filteredWorks() {
  const q = searchQuery.trim().toLowerCase();
  return CATALOG.filter((w) => {
    if (activeFilter !== "all" && w.wing !== activeFilter) return false;
    if (!q) return true;
    const hay = `${w.number} ${w.name} ${w.tagline} ${w.description} ${w.category}`.toLowerCase();
    return hay.includes(q);
  });
}

function renderGallery() {
  const works = filteredWorks();
  grid.innerHTML = "";
  works.forEach((w, i) => {
    const card = renderCard(w);
    card.style.animationDelay = `${i * 0.04}s`;
    grid.appendChild(card);
  });
  emptyState.classList.toggle("hidden", works.length > 0);
}

function openModal(work) {
  document.getElementById("modal-category").textContent = work.category;
  document.getElementById("modal-title").textContent = `ERC-${work.number}`;
  document.getElementById("modal-tagline").textContent = work.name;
  document.getElementById("modal-desc").textContent = work.description;

  const meta = document.getElementById("modal-meta");
  meta.innerHTML = `
    <div><dt>Wing</dt><dd>${WINGS[work.wing] || work.wing}</dd></div>
    <div><dt>Import path</dt><dd><code>curated-erc/${work.path}</code></dd></div>
  `;

  const links = document.getElementById("modal-links");
  links.innerHTML = `
    <a class="btn btn-primary" href="https://github.com/jose-compu/curated-erc/tree/main/src/${work.path.split("/")[0]}" target="_blank" rel="noopener">View in repository</a>
    ${work.eip ? `<a class="btn btn-ghost" href="${work.eip}" target="_blank" rel="noopener">Read EIP</a>` : ""}
  `;

  const art = document.getElementById("modal-art");
  art.src = artworkSrc(work);
  art.alt = `Surrealist painting for ERC-${work.number}: ${work.name}`;

  modal.showModal();
  document.body.classList.add("modal-open");
}

function closeModal() {
  modal.close();
  document.body.classList.remove("modal-open");
}

filters.forEach((btn) => {
  btn.addEventListener("click", () => {
    filters.forEach((b) => {
      b.classList.remove("active");
      b.setAttribute("aria-selected", "false");
    });
    btn.classList.add("active");
    btn.setAttribute("aria-selected", "true");
    activeFilter = btn.dataset.filter || "all";
    renderGallery();
  });
});

searchInput.addEventListener("input", () => {
  searchQuery = searchInput.value;
  renderGallery();
});

modalClose.addEventListener("click", closeModal);
modal.addEventListener("click", (e) => {
  if (e.target === modal) closeModal();
});
modal.addEventListener("cancel", () => document.body.classList.remove("modal-open"));

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && modal.open) closeModal();
});

if (cursorGlow) {
  let gx = 0;
  let gy = 0;
  let tx = 0;
  let ty = 0;
  document.addEventListener("mousemove", (e) => {
    tx = e.clientX;
    ty = e.clientY;
  });
  const tick = () => {
    gx += (tx - gx) * 0.12;
    gy += (ty - gy) * 0.12;
    cursorGlow.style.transform = `translate(${gx - 180}px, ${gy - 180}px)`;
    requestAnimationFrame(tick);
  };
  tick();
}

document.querySelectorAll("[data-count]").forEach((el) => {
  const target = Number(el.dataset.count);
  if (!target) return;
  const duration = 1200;
  const start = performance.now();
  const step = (now) => {
    const t = Math.min(1, (now - start) / duration);
    const eased = 1 - Math.pow(1 - t, 3);
    el.textContent = String(Math.round(target * eased));
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
});

const header = document.querySelector(".site-header");
window.addEventListener(
  "scroll",
  () => {
    header.classList.toggle("scrolled", window.scrollY > 24);
  },
  { passive: true }
);

renderGallery();
