// ========================================
// VIP CAR RENTAL - PREMIUM DUAL-NUI SYSTEM
// ========================================

let currentData = null;
let currentVehicles = [];
let currentIndex = 0;
let currentCategory = 'all';
let isModalOpen = false;
let currentMode = 'catalog'; // 'catalog' ou 'mini'

// Configurações Globais
const CONFIG = {
    DEFAULT_IMG: 'img.webp',
    VEHICLE_IMG_BASE: 'https://cfx-nui-qb-vehicleshop/html/img/vehicles/'
};

console.log(`[VIP-DEBUG] Caminho da imagem padrão configurado: ${CONFIG.DEFAULT_IMG}`);

// ========================================
// UTILS
// ========================================

function formatCurrency(value) {
    return `${value.toLocaleString('pt-BR')} ZNCOINS`;
}

function sanitizeHTML(str) {
    if (typeof str !== 'string') return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function generateStats(model) {
    let seed = 0;
    for (let i = 0; i < model.length; i++) seed += model.charCodeAt(i);
    const seededRandom = (min, max) => {
        const x = Math.sin(seed++) * 10000;
        return Math.floor((x - Math.floor(x)) * (max - min + 1) + min);
    };
    return { perf: seededRandom(65, 98), safe: seededRandom(60, 95) };
}

// ========================================
// NUI COMMUNICATION
// ========================================

function postNUI(action, data = {}) {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vip_car_rental';
    return fetch(`https://${resourceName}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(resp => resp.json()).catch(err => console.error(`[NUI ERROR] ${action}:`, err));
}

window.addEventListener('message', (event) => {
    const item = event.data;
    if (item.action === 'openMenu') {
        openMenu(item.data, item.mode || 'catalog');
    } else if (item.action === 'closeMenu') {
        closeMenu(true);
    }
});

// ========================================
// INTERFACE CONTROL
// ========================================

function toggleInfoModal() {
    const modal = document.getElementById('infoModal');
    if (modal.style.display === 'flex') {
        modal.style.display = 'none';
    } else {
        modal.style.display = 'flex';
    }
}

function openMenu(data, mode = 'catalog') {
    currentData = data;
    currentMode = mode;
    
    document.getElementById('mini-nui').style.display = 'none';
    document.getElementById('catalog-nui').style.display = 'none';
    
    if (mode === 'mini') {
        document.getElementById('mini-nui').style.display = 'flex';
        currentVehicles = data.availableVehicles;
        currentIndex = 0;
        updateMiniUI();
    } else {
        document.getElementById('catalog-nui').style.display = 'flex';
        setupCategories();
        filterVehicles('all');
    }
}

function closeMenu(fromClient = false) {
    document.getElementById('mini-nui').style.display = 'none';
    document.getElementById('catalog-nui').style.display = 'none';
    
    if (isModalOpen) closeRentalModal();
    if (!fromClient) postNUI('closeMenu');
}

// --- MINI NUI LOGIC ---
function updateMiniUI() {
    const vehicle = currentVehicles[currentIndex];
    if (!vehicle) return;

    document.getElementById('miniBrand').textContent = vehicle.brand.toUpperCase();
    document.getElementById('miniName').textContent = vehicle.name.toUpperCase();
    document.getElementById('miniPrice').textContent = formatCurrency(vehicle.price * 30);
    document.getElementById('miniCurrentIndex').textContent = currentIndex + 1;
    document.getElementById('miniTotalCount').textContent = currentVehicles.length;

    // Trigger preview no jogo (se estiver no mini mode)
    postNUI('previewVehicle', { model: vehicle.model });
}

// --- CATALOG NUI LOGIC ---
function setupCategories() {
    // Usar os botões estáticos do HTML
    document.querySelectorAll('.cat-link').forEach(btn => {
        btn.onclick = () => {
            const cat = btn.getAttribute('data-category');
            filterVehicles(cat);
        };
    });
}

function filterVehicles(cat, query = '') {
    currentCategory = cat;
    
    // Atualizar classe ativa nos botões
    document.querySelectorAll('.cat-link').forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-category') === cat);
    });

    currentVehicles = currentData.availableVehicles.filter(v => {
        const matchCat = cat === 'all' || v.category === cat;
        const matchQuery = !query || v.name.toLowerCase().includes(query) || v.brand.toLowerCase().includes(query);
        return matchCat && matchQuery;
    });

    currentIndex = 0;
    updateSlider();
}

function updateSlider() {
    const track = document.getElementById('sliderTrack');
    track.innerHTML = '';

    if (!currentVehicles || currentVehicles.length === 0) {
        track.innerHTML = `<div style="color: #666; font-size: 20px; font-weight: 700;">NENHUM VEÍCULO DISPONÍVEL</div>`;
        updateDetails(null);
        return;
    }

    const getIndex = (offset) => {
        let idx = currentIndex + offset;
        while (idx < 0) idx += currentVehicles.length;
        while (idx >= currentVehicles.length) idx -= currentVehicles.length;
        return idx;
    };

    // Mostrar apenas os 3 principais (-1, 0, 1) para manter o efeito 3D
    const offsets = currentVehicles.length === 1 ? [0] : [-1, 0, 1];
    
    offsets.forEach(offset => {
        const idx = getIndex(offset);
        const vehicle = currentVehicles[idx];
        if (!vehicle) return;

        const card = document.createElement('div');
        card.className = `veh-card ${offset === 0 ? 'active' : 'side ' + (offset < 0 ? 'prev' : 'next')}`;
        
        const imgContainer = document.createElement('div');
        imgContainer.className = 'veh-img-container';
        
        const vehicleImg = `${CONFIG.VEHICLE_IMG_BASE}${vehicle.model}.png`;
        const img = new Image();
        img.src = vehicleImg;
        img.onload = () => { imgContainer.style.backgroundImage = `url('${vehicleImg}')`; };
        img.onerror = () => { imgContainer.style.backgroundImage = `url('img.webp')`; };
        imgContainer.style.backgroundImage = `url('img.webp')`;
        
        imgContainer.onclick = () => {
            if (offset !== 0) {
                currentIndex = idx;
                updateSlider();
            }
        };
        
        card.appendChild(imgContainer);
        track.appendChild(card);
    });

    updateDetails(currentVehicles[currentIndex]);
}

function updateDetails(vehicle) {
    const details = document.getElementById('vehicleDetails');
    if (!vehicle) {
        details.style.opacity = '0';
        return;
    }
    details.style.opacity = '1';
    
    // Atualizar Preço e Badge (Novo ID)
    document.getElementById('vehPrice').textContent = `${vehicle.price} ZNCOINS`;
    document.getElementById('detailName').textContent = vehicle.name;
    document.getElementById('detailBrand').textContent = vehicle.brand || 'PREMIUM';
    
    const stats = generateStats(vehicle.model);
    document.getElementById('val-perf').textContent = `${stats.perf}%`;
    document.getElementById('bar-perf').style.width = `${stats.perf}%`;
    document.getElementById('val-safe').textContent = `${stats.safe}%`;
    document.getElementById('bar-safe').style.width = `${stats.safe}%`;
    
    const btnBuy = document.getElementById('btnBuy');
    if (!btnBuy) return;

    if (vehicle.isRented) {
        btnBuy.textContent = 'CONTRATO ATIVO';
        btnBuy.disabled = true;
        btnBuy.style.opacity = '0.4';
    } else {
        btnBuy.textContent = 'ADQUIRIR CONTRATO';
        btnBuy.disabled = false;
        btnBuy.style.opacity = '1';
    }
}

// SLIDER NAV
document.getElementById('prevBtn').onclick = () => navigateSlider(-1);
document.getElementById('nextBtn').onclick = () => navigateSlider(1);

function navigateSlider(dir) {
    if (currentVehicles.length <= 1) return;
    currentIndex += dir;
    if (currentIndex < 0) currentIndex = currentVehicles.length - 1;
    if (currentIndex >= currentVehicles.length) currentIndex = 0;
    
    if (currentMode === 'mini') updateMiniUI();
    else updateSlider();
}

// SEARCH
document.getElementById('searchInput').addEventListener('input', (e) => {
    filterVehicles(currentCategory, e.target.value.toLowerCase());
});

// MODAL
function openRentalModal(vehicle) {
    const modal = document.getElementById('rentalModal');
    const priceDay = parseInt(vehicle.price) || 0;
    
    document.getElementById('modalPriceDay').textContent = formatCurrency(priceDay);
    document.getElementById('modalTotalPrice').textContent = formatCurrency(priceDay * 30);
    
    modal.style.display = 'flex';
    isModalOpen = true;
}

function closeRentalModal() {
    document.getElementById('rentalModal').style.display = 'none';
    isModalOpen = false;
}

// --- LISTENERS ---
const btnBuy = document.getElementById('btnBuy');
if (btnBuy) {
    btnBuy.onclick = () => {
        const v = currentVehicles[currentIndex];
        if (v && !v.isRented) openRentalModal(v);
    };
}

const modalClose = document.getElementById('modalClose');
if (modalClose) modalClose.onclick = closeRentalModal;

const btnCancel = document.getElementById('btnCancel');
if (btnCancel) btnCancel.onclick = closeRentalModal;

const closeBtn = document.getElementById('closeBtn');
if (closeBtn) closeBtn.onclick = () => closeMenu();

const btnConfirm = document.getElementById('btnConfirm');
if (btnConfirm) {
    btnConfirm.onclick = () => {
        const v = currentVehicles[currentIndex];
        if (!v) return;
        
        btnConfirm.disabled = true;
        btnConfirm.textContent = 'PROCESSANDO...';
        
        postNUI('rentVehicle', { model: v.model, days: 30 }).then(data => {
            btnConfirm.disabled = false;
            btnConfirm.textContent = 'CONFIRMAR';
            if (data && data.success) {
                closeRentalModal();
                closeMenu();
            }
        });
    };
}

const btnTestDrive = document.getElementById('btnTestDrive');
if (btnTestDrive) {
    btnTestDrive.onclick = () => {
        const v = currentVehicles[currentIndex];
        if (v) {
            postNUI('testDrive', { model: v.model }).then(data => {
                if (data && data.success) closeMenu();
            });
        }
    };
}

// KEYBOARD
window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (isModalOpen) closeRentalModal();
        else closeMenu();
    } else if (e.key === 'ArrowLeft') {
        navigateSlider(-1);
    } else if (e.key === 'ArrowRight') {
        navigateSlider(1);
    } else if (e.key === 'Enter') {
        if (currentMode === 'mini') {
            postNUI('openFullCatalog');
        } else if (!isModalOpen) {
            const buyBtn = document.getElementById('btnBuy');
            if (buyBtn) buyBtn.click();
        }
    } else if (e.key.toLowerCase() === 'h' && currentMode === 'mini') {
        const v = currentVehicles[currentIndex];
        if (v) postNUI('previewVehicle', { model: v.model });
    }
});