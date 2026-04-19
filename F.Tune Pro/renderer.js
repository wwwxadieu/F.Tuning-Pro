const { ipcRenderer } = require('electron');

// --- 1. Window Controls ---
const minBtn = document.getElementById('min-btn');
const maxBtn = document.getElementById('max-btn');
const maxBtnIcon = document.getElementById('max-btn-icon');
const closeBtn = document.getElementById('close-btn');
let isWindowMaximized = false;

function syncMaximizeButtonIcon(isMaximized) {
    if (!maxBtnIcon) {
        return;
    }
    maxBtnIcon.textContent = isMaximized ? 'fullscreen_exit' : 'fullscreen';
}

if (minBtn) {
    minBtn.addEventListener('click', () => {
        ipcRenderer.send('minimize-app');
    });
}

if (maxBtn) {
    maxBtn.addEventListener('click', () => {
        ipcRenderer.send('toggle-maximize-app');
    });
}

if (closeBtn) {
    closeBtn.addEventListener('click', () => {
        ipcRenderer.send('close-app');
    });
}

ipcRenderer.on('window-maximize-changed', (event, isMaximized) => {
    isWindowMaximized = Boolean(isMaximized);
    document.body.classList.toggle('window-maximized', isWindowMaximized);
    syncMaximizeButtonIcon(isWindowMaximized);
    applyGarageFullscreenRowPreference();
});

// --- 2. Navigation ---
const pageDashboard = document.getElementById('page-dashboard');
const pageCreateTune = document.getElementById('page-create-tune');
const pageSettings = document.getElementById('page-settings');
const pageGarage = document.getElementById('page-garage');
const createTuneGrid = pageCreateTune?.querySelector('.create-tune-grid') || null;
const createCardModelInfo = pageCreateTune?.querySelector('.create-card-model-info') || null;
const createCardPerformance = pageCreateTune?.querySelector('.create-card-performance') || null;
const createCardAdvanced = pageCreateTune?.querySelector('.create-card-advanced') || null;
const createCardConfig = pageCreateTune?.querySelector('.create-card-config') || null;
const createCardEnvironment = pageCreateTune?.querySelector('.create-card-environment') || null;
const createTuneHeaderTitle = pageCreateTune?.querySelector('.create-tune-header h1') || null;
const CREATE_TUNE_HEADER_DEFAULT_TEXT = createTuneHeaderTitle?.textContent?.trim() || 'Create New Tune';
const CREATE_TUNE_HEADER_EDIT_TEXT = 'Edit Tune';
const btnCreateTune = document.getElementById('btn-dashboard-create');
const btnGarage = document.getElementById('btn-dashboard-garage');
const btnCreateBack = document.getElementById('btn-create-back');
const btnGarageBack = document.getElementById('btn-garage-back');
const btnSettings = document.getElementById('btn-settings');
const btnSettingsBack = document.getElementById('btn-settings-back');
const mainElement = document.querySelector('main');
const PANEL_TRANSITION_MS = 320;
const panelHideTimers = new WeakMap();
let createLayoutStabilizeRaf = null;

function isDesktopCreateLayoutContext() {
    return Boolean(
        pageCreateTune
        && !isCreateTuneEditMode()
        && !document.body.classList.contains('app-short-window')
        && !document.body.classList.contains('app-compact-window')
        && !document.body.classList.contains('app-portrait-window')
    );
}

function isFluidCreateLayoutContext() {
    return Boolean(
        pageCreateTune
        && !isCreateTuneEditMode()
        && !document.body.classList.contains('app-compact-window')
        && !document.body.classList.contains('app-portrait-window')
    );
}

function syncCreateResponsiveLayoutClasses() {
    if (!createTuneGrid) {
        return;
    }

    const isFluidLayout = isFluidCreateLayoutContext();
    createTuneGrid.classList.toggle('layout-fluid', isFluidLayout);

    if (!isFluidLayout) {
        createTuneGrid.classList.remove('layout-dense', 'layout-tight');
        return;
    }

    const gridWidth = Math.max(
        0,
        Number(createTuneGrid.clientWidth) || Number(createTuneGrid.getBoundingClientRect().width) || 0
    );
    const gridHeight = Math.max(
        0,
        Number(createTuneGrid.clientHeight) || Number(createTuneGrid.getBoundingClientRect().height) || 0
    );
    const hasModelInfo = createTuneGrid.classList.contains('has-model-info');
    const isDenseLayout =
        gridWidth <= 1380
        || gridHeight <= 620
        || hasModelInfo;
    const isTightLayout =
        gridWidth <= 1220
        || gridHeight <= 500
        || (hasModelInfo && gridWidth <= 1320 && gridHeight <= 560);

    createTuneGrid.classList.toggle('layout-dense', isDenseLayout);
    createTuneGrid.classList.toggle('layout-tight', isTightLayout);
}

function resetCreateCardOffsets() {
    [
        createCardPerformance,
        createCardAdvanced,
        createCardConfig,
        createCardEnvironment
    ].forEach((card) => {
        if (!card) {
            return;
        }
        card.style.marginTop = '0px';
    });
}

function stabilizeCreateCardOverlaps() {
    if (
        !createTuneGrid
        || !createCardModelInfo
        || !createCardPerformance
        || !createCardAdvanced
        || !createCardConfig
        || !createCardEnvironment
    ) {
        return;
    }

    if (!isDesktopCreateLayoutContext()) {
        resetCreateCardOffsets();
        syncCreateResponsiveLayoutClasses();
        return;
    }

    resetCreateCardOffsets();
    syncCreateResponsiveLayoutClasses();
}

function scheduleCreateLayoutStabilize() {
    if (!pageCreateTune) {
        return;
    }
    if (createLayoutStabilizeRaf !== null) {
        cancelAnimationFrame(createLayoutStabilizeRaf);
    }
    createLayoutStabilizeRaf = requestAnimationFrame(() => {
        stabilizeCreateCardOverlaps();
        setTimeout(stabilizeCreateCardOverlaps, 40);
        createLayoutStabilizeRaf = null;
    });
}

function syncResponsiveWindowMode() {
    const viewportWidth = Math.max(
        0,
        Number(window.innerWidth) || Number(document.documentElement?.clientWidth) || 0
    );
    const viewportHeight = Math.max(
        0,
        Number(window.innerHeight) || Number(document.documentElement?.clientHeight) || 0
    );
    const isPortraitWindow = viewportHeight > viewportWidth;
    const isCompactWindow = viewportWidth <= 980;
    const isShortWindow = viewportHeight <= 760 || (viewportHeight <= 820 && viewportWidth <= 1120);

    document.body.classList.toggle('app-portrait-window', isPortraitWindow);
    document.body.classList.toggle('app-compact-window', isCompactWindow);
    document.body.classList.toggle('app-short-window', isShortWindow);
    syncFunctionalPanelHeight();
    syncMainScrollMode();
    scheduleCreateLayoutStabilize();
}

function syncFunctionalPanelHeight() {
    if (!mainElement) {
        return;
    }

    const computedStyle = window.getComputedStyle(mainElement);
    const paddingTop = Number.parseFloat(computedStyle.paddingTop) || 0;
    const paddingBottom = Number.parseFloat(computedStyle.paddingBottom) || 0;
    const mainInnerHeight = Math.max(
        0,
        Number(mainElement.clientHeight) || Number(mainElement.getBoundingClientRect().height) || 0
    );
    const availablePanelHeight = Math.max(260, Math.floor(mainInnerHeight - paddingTop - paddingBottom));

    document.documentElement.style.setProperty('--functional-panel-height', `${availablePanelHeight}px`);
}

function syncMainScrollMode() {
    if (!mainElement) {
        return;
    }

    const isConstrainedWindow =
        document.body.classList.contains('app-short-window')
        || document.body.classList.contains('app-compact-window')
        || document.body.classList.contains('app-portrait-window');

    const isDashboardOpen = Boolean(
        pageDashboard
        && !pageDashboard.classList.contains('hidden')
        && pageDashboard.classList.contains('is-open')
    );

    mainElement.classList.toggle('main-scroll-enabled', isConstrainedWindow && isDashboardOpen);
}

function toggleCreateTuneBackgroundBlur(isEnabled) {
    document.body.classList.toggle('create-tune-open', Boolean(isEnabled));
    syncFunctionalPanelHeight();
    scheduleCreateLayoutStabilize();
}

function clearPanelHideTimer(panel) {
    const activeTimer = panelHideTimers.get(panel);
    if (activeTimer) {
        clearTimeout(activeTimer);
        panelHideTimers.delete(panel);
    }
}

function collapseOtherMainPanels(activePanel) {
    const managedPanels = [pageDashboard, pageCreateTune, pageGarage, pageSettings].filter(Boolean);
    managedPanels.forEach((panel) => {
        if (panel === activePanel) {
            return;
        }
        clearPanelHideTimer(panel);
        panel.classList.remove('is-open', 'is-closing');
        panel.classList.add('hidden');
    });
}

function showAnimatedPanel(panel) {
    if (!panel) {
        return;
    }

    collapseOtherMainPanels(panel);
    clearPanelHideTimer(panel);
    panel.classList.remove('hidden', 'is-closing');
    requestAnimationFrame(() => {
        panel.classList.add('is-open');
        syncMainScrollMode();
        syncCapsuleGroupIndicators(panel);
        updateCreateCalcButtonState();
        if (panel === pageCreateTune) {
            scheduleCreateLayoutStabilize();
        }
        setTimeout(() => {
            syncMainScrollMode();
            syncCapsuleGroupIndicators(panel);
            updateCreateCalcButtonState();
            if (panel === pageCreateTune) {
                scheduleCreateLayoutStabilize();
            }
        }, PANEL_TRANSITION_MS);
    });
}

function hideAnimatedPanel(panel, onHidden = null) {
    if (!panel) {
        return;
    }

    if (panel.classList.contains('hidden')) {
        syncMainScrollMode();
        if (typeof onHidden === 'function') {
            onHidden();
        }
        return;
    }

    clearPanelHideTimer(panel);
    panel.classList.remove('is-open');
    panel.classList.add('is-closing');

    const hideTimer = setTimeout(() => {
        panel.classList.add('hidden');
        panel.classList.remove('is-closing');
        panelHideTimers.delete(panel);
        syncMainScrollMode();
        if (typeof onHidden === 'function') {
            onHidden();
        }
    }, PANEL_TRANSITION_MS);

    panelHideTimers.set(panel, hideTimer);
}

function isCreateTuneEditMode() {
    return Boolean(createTuneEditRecordId);
}

function setCreateTuneEditRecord(recordId = null) {
    const normalizedId = typeof recordId === 'string' ? recordId.trim() : '';
    createTuneEditRecordId = normalizedId || null;

    if (pageCreateTune) {
        pageCreateTune.classList.toggle('is-edit-mode', Boolean(createTuneEditRecordId));
    }
    if (createTuneHeaderTitle) {
        createTuneHeaderTitle.textContent = createTuneEditRecordId
            ? getSettingsLanguageText('createMainTitleEdit') || CREATE_TUNE_HEADER_EDIT_TEXT
            : getSettingsLanguageText('createMainTitle') || CREATE_TUNE_HEADER_DEFAULT_TEXT;
    }
    scheduleCreateLayoutStabilize();
}

function openCreateTunePage(sourcePanel = null) {
    ensureVehicleBrowserInitialized();
    closePowerBandModal({ immediate: true });
    closeTuneCalcModal({ immediate: true });
    closeUiDemoModal({ immediate: true });
    closeDonateModal({ immediate: true });
    closeFeedbackModal({ immediate: true });
    closeUpdateLogModal({ immediate: true });
    closeGarageViewModal({ immediate: true });
    closeGarageDeleteModal({ immediate: true, decision: false });
    hideAnimatedPanel(pageSettings);
    hideAnimatedPanel(pageGarage);
    mainElement.classList.remove('blur-background');
    toggleCreateTuneBackgroundBlur(true);

    const panelCandidates = [sourcePanel, pageDashboard, pageGarage, pageSettings, pageCreateTune]
        .filter((panel, index, arr) => panel && arr.indexOf(panel) === index);
    const activePanel = panelCandidates.find((panel) => panel && panel !== pageCreateTune && !panel.classList.contains('hidden'));

    if (!activePanel) {
        showAnimatedPanel(pageCreateTune);
        return;
    }

    hideAnimatedPanel(activePanel, () => {
        showAnimatedPanel(pageCreateTune);
    });
}

function navigateToGaragePage() {
    if (!pageGarage) {
        return;
    }

    setCreateTuneEditRecord(null);
    closePowerBandModal({ immediate: true });
    closeTuneCalcModal({ immediate: true });
    closeUiDemoModal({ immediate: true });
    closeDonateModal({ immediate: true });
    closeFeedbackModal({ immediate: true });
    closeUpdateLogModal({ immediate: true });
    closeGarageViewModal({ immediate: true });
    closeGarageDeleteModal({ immediate: true, decision: false });
    mainElement.classList.add('blur-background');
    toggleCreateTuneBackgroundBlur(false);
    renderGarageList();

    const panelOrder = [pageCreateTune, pageSettings, pageDashboard];
    const activePanel = panelOrder.find((panel) => panel && !panel.classList.contains('hidden'));

    if (!activePanel || activePanel === pageGarage) {
        showAnimatedPanel(pageGarage);
        return;
    }

    hideAnimatedPanel(activePanel, () => {
        showAnimatedPanel(pageGarage);
    });
}

if (btnCreateTune) {
    btnCreateTune.addEventListener('click', () => {
        setCreateTuneEditRecord(null);
        openCreateTunePage(pageDashboard);
    });
}

if (btnCreateBack) {
    btnCreateBack.addEventListener('click', () => {
        const shouldReturnGarage = isCreateTuneEditMode();
        setCreateTuneEditRecord(null);
        closePowerBandModal({ immediate: true });
        closeTuneCalcModal({ immediate: true });
        closeUiDemoModal({ immediate: true });
        closeDonateModal({ immediate: true });
        closeFeedbackModal({ immediate: true });
        closeUpdateLogModal({ immediate: true });
        closeGarageViewModal({ immediate: true });
        closeGarageDeleteModal({ immediate: true, decision: false });
        hideAnimatedPanel(pageCreateTune, () => {
            if (shouldReturnGarage) {
                renderGarageList();
            }
            showAnimatedPanel(shouldReturnGarage ? pageGarage : pageDashboard);
            toggleCreateTuneBackgroundBlur(false);
        });
        mainElement.classList.remove('blur-background');
    });
}

if (btnGarage) {
    btnGarage.addEventListener('click', () => {
        navigateToGaragePage();
    });
}

if (btnGarageBack) {
    btnGarageBack.addEventListener('click', () => {
        closePowerBandModal({ immediate: true });
        closeTuneCalcModal({ immediate: true });
        closeUiDemoModal({ immediate: true });
        closeDonateModal({ immediate: true });
        closeFeedbackModal({ immediate: true });
        closeUpdateLogModal({ immediate: true });
        closeGarageViewModal({ immediate: true });
        closeGarageDeleteModal({ immediate: true, decision: false });
        hideAnimatedPanel(pageGarage, () => {
            showAnimatedPanel(pageDashboard);
        });
        mainElement.classList.remove('blur-background');
        toggleCreateTuneBackgroundBlur(false);
    });
}

if (btnSettings) {
    btnSettings.addEventListener('click', () => {
        closePowerBandModal({ immediate: true });
        closeTuneCalcModal({ immediate: true });
        closeUiDemoModal({ immediate: true });
        closeDonateModal({ immediate: true });
        closeFeedbackModal({ immediate: true });
        closeUpdateLogModal({ immediate: true });
        closeGarageViewModal({ immediate: true });
        closeGarageDeleteModal({ immediate: true, decision: false });
        hideAnimatedPanel(pageGarage);
        const isCreateVisible = !pageCreateTune.classList.contains('hidden');
        if (isCreateVisible) {
            hideAnimatedPanel(pageCreateTune, () => {
                toggleCreateTuneBackgroundBlur(false);
            });
        } else {
            toggleCreateTuneBackgroundBlur(false);
        }

        hideAnimatedPanel(pageDashboard);
        mainElement.classList.add('blur-background');
        loadSettings();
        showAnimatedPanel(pageSettings);
    });
}

if (btnSettingsBack) {
    btnSettingsBack.addEventListener('click', () => {
        closeUiDemoModal({ immediate: true });
        closeDonateModal({ immediate: true });
        closeFeedbackModal({ immediate: true });
        closeUpdateLogModal({ immediate: true });
        closeGarageViewModal({ immediate: true });
        closeGarageDeleteModal({ immediate: true, decision: false });
        hideAnimatedPanel(pageSettings);
        showAnimatedPanel(pageDashboard);
        mainElement.classList.remove('blur-background');
        toggleCreateTuneBackgroundBlur(false);
    });
}

// --- 3. Settings ---
const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/webm', 'video/ogg', 'video/quicktime'];
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024;
const MAX_VIDEO_SIZE_BYTES = 25 * 1024 * 1024;

const uploadArea = document.getElementById('background-upload-area');
const fileInput = document.getElementById('background-file-input');
const uploadIcon = document.getElementById('background-upload-icon');
const uploadText = document.getElementById('background-upload-text');
const uploadSubtext = document.getElementById('background-upload-subtext');
const customBgVideo = document.getElementById('custom-bg-video');
const btnOpenDonate = document.getElementById('btn-open-donate');
const btnOpenFeedback = document.getElementById('btn-open-feedback');
const donateModal = document.getElementById('donate-modal');
const donateModalBackdrop = document.getElementById('donate-modal-backdrop');
const btnDonateClose = document.getElementById('btn-donate-close');
const updateLogModal = document.getElementById('update-log-modal');
const updateLogModalBackdrop = document.getElementById('update-log-modal-backdrop');
const btnUpdateLogClose = document.getElementById('btn-update-log-close');
const btnUpdateLogDone = document.getElementById('btn-update-log-done');
const feedbackModal = document.getElementById('feedback-modal');
const feedbackModalBackdrop = document.getElementById('feedback-modal-backdrop');
const btnFeedbackClose = document.getElementById('btn-feedback-close');
const btnFeedbackCancel = document.getElementById('btn-feedback-cancel');
const btnFeedbackSend = document.getElementById('btn-feedback-send');
const feedbackTitleInput = document.getElementById('feedback-title-input');
const feedbackNameInput = document.getElementById('feedback-name-input');
const feedbackEmailInput = document.getElementById('feedback-email-input');
const feedbackMessageInput = document.getElementById('feedback-message-input');
const welcomeModal = document.getElementById('welcome-modal');
const welcomeSlidesTrack = document.getElementById('welcome-slides-track');
const welcomeDots = Array.from(document.querySelectorAll('#welcome-dots .welcome-dot'));
const welcomeSetupScreen = document.getElementById('welcome-setup-screen');
const welcomeSetupLanguageGroup = document.getElementById('welcome-setup-language-group');
const welcomeSetupUnitGroup = document.getElementById('welcome-setup-unit-group');
const welcomeSetupThemeGroup = document.getElementById('welcome-setup-theme-group');
const welcomeFinalOptin = document.getElementById('welcome-final-optin');
const welcomeDontShowCheckbox = document.getElementById('welcome-dont-show-checkbox');
const welcomeNextBtn = document.getElementById('welcome-next-btn');
const welcomeCloseBtn = document.getElementById('welcome-close-btn');
const welcomeSlideCreateImage = document.getElementById('welcome-slide-image-create');
const welcomeSlideCalcImage = document.getElementById('welcome-slide-image-calc');
const welcomeSlideGarageImage = document.getElementById('welcome-slide-image-garage');
const welcomeSlideOverlayImage = document.getElementById('welcome-slide-image-overlay');

const DONATE_MODAL_TRANSITION_MS = 240;
let donateModalHideTimer = null;
const UPDATE_LOG_MODAL_TRANSITION_MS = 240;
let updateLogModalHideTimer = null;
const FEEDBACK_MODAL_TRANSITION_MS = 240;
let feedbackModalHideTimer = null;
const PRIMARY_PREVIEW_STYLE_CLASS = 'preview-style-motorsport';
const LEGACY_PREVIEW_STYLE_CLASSES = Object.freeze([
    'preview-style-studio',
    'preview-style-hud'
]);
let appToastHideTimer = null;
let appToastRenderToken = 0;
const WELCOME_MODAL_TRANSITION_MS = 340;
const WELCOME_TOTAL_PAGES = Math.max(1, document.querySelectorAll('#welcome-slides-track .welcome-slide').length);
const WELCOME_LAST_INDEX = WELCOME_TOTAL_PAGES - 1;
const WELCOME_STORAGE_KEY = 'welcomeSeen.v1';
const WELCOME_CAPTURE_CACHE_KEY = 'welcomeFeatureSlides.v5';
const WELCOME_CAPTURE_OUTPUT_WIDTH = 1600;
const WELCOME_CAPTURE_OUTPUT_HEIGHT = 800;
const APP_BUILD_VERSION = 'Beta 1.0';
const UPDATE_LOG_SEEN_KEY = 'updateLogSeen.v1';
let welcomeHideTimer = null;
let welcomeSlideIndex = 0;
let welcomeFeatureSlidesHydrated = false;
let welcomeInSetupStep = true;
let pendingStartupUpdateLog = false;

let settingsState = {
    darkMode: false,
    themeMode: 'light',
    autosave: true,
    language: 'en',
    unitSystem: 'metric',
    overlayMode: false,
    overlayOnTop: true,
    overlayOpacity: 0.88,
    overlayTextScale: 1,
    overlayLayout: 'vertical',
    overlayLocked: false,
    gameVersion: 'fh5',
    customBackground: null,
    customBackgroundType: null,
    customBackgroundName: null
};
const systemThemeMediaQuery = typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-color-scheme: dark)')
    : null;
const GARAGE_STORAGE_KEY = 'garageTunes';
const GARAGE_SAMPLE_SEED_KEY = 'garageSamplesSeed.v1';
const GARAGE_EXPORT_PREFIX = 'FTUNEPRO::GARAGE::1';
const GARAGE_ACTIVE_OVERLAY_KEY = 'garageOverlayTune';
const MAX_GARAGE_TUNES = 250;
const SAMPLE_GARAGE_TUNE_COUNT = 15;
const ENABLE_SAMPLE_GARAGE_TUNES = false;
let garageTunes = [];
let lastTuneCalculationPayload = null;
let tuneCalcLayoutMode = 'compact';
let activeOverlayTune = null;
let overlayDismissed = false;
let garageSortState = {
    key: 'savedAt',
    direction: 'desc'
};
const GARAGE_PAGE_SIZE_OPTIONS = Object.freeze([10, 20, 40]);
const GARAGE_DEFAULT_PAGE_SIZE = 10;
const GARAGE_MAX_VISIBLE_ROWS = 15;
const GARAGE_MAX_VISIBLE_ROWS_FULLSCREEN = 20;
const GARAGE_FULLSCREEN_PREFERRED_PAGE_SIZE = 20;
let garagePageSize = GARAGE_DEFAULT_PAGE_SIZE;
let garageCurrentPage = 1;
let garageSelectedTuneIds = new Set();
let garagePageTransitionDirection = '';

function buildVehicleSpecKey(brand, model) {
    return `${String(brand || '').trim().toLowerCase()}|||${String(model || '').trim().toLowerCase()}`;
}

function buildBrandModelMap(cars) {
    const map = {};
    if (!Array.isArray(cars)) {
        return map;
    }

    cars.forEach((car) => {
        if (!car || !car.brand || !car.model) {
            return;
        }

        if (!map[car.brand]) {
            map[car.brand] = new Set();
        }
        map[car.brand].add(car.model);
    });

    Object.keys(map).forEach((brand) => {
        map[brand] = Array.from(map[brand]).sort((a, b) => a.localeCompare(b));
    });

    return map;
}

function normalizeDriveType(value) {
    const normalized = String(value || '').trim().toUpperCase();
    if (normalized === 'FWD' || normalized === 'RWD' || normalized === 'AWD') {
        return normalized;
    }
    return null;
}

function buildCarSpecMap(cars) {
    const map = new Map();
    if (!Array.isArray(cars)) {
        return map;
    }

    cars.forEach((car) => {
        if (!car || !car.brand || !car.model) {
            return;
        }

        const key = buildVehicleSpecKey(car.brand, car.model);
        if (!map.has(key)) {
            const normalizedDifferential = typeof car.differential === 'string' ? car.differential.trim() : '';
            const normalizedTireType = typeof car.tireType === 'string' ? car.tireType.trim() : '';
            const normalizedDriveType = normalizeDriveType(car.driveType);
            map.set(key, {
                pi: car.pi,
                topSpeedKmh: car.topSpeedKmh,
                driveType: normalizedDriveType,
                differential: normalizedDifferential || null,
                tireType: normalizedTireType || null
            });
        }
    });

    return map;
}

let fh5Cars = [];
try {
    fh5Cars = require('./FH5_cars.json');
} catch (_) {
    fh5Cars = [];
}

const FH5_CAR_SPEC_MAP = buildCarSpecMap(fh5Cars);

const fallbackBrandModelData = {
    Ferrari: ['488 Pista', 'F8 Tributo', '812 Superfast', 'SF90 Stradale'],
    Porsche: ['911 GT3 RS', '911 Turbo S', 'Cayman GT4', 'Taycan Turbo S'],
    Ford: ['Focus RS', 'Mustang GT', 'GT40 Mk I', 'Fiesta ST'],
    McLaren: ['720S', '765LT', 'P1', 'Senna'],
    Lamborghini: ['Huracan Performante', 'Aventador SVJ', 'Sesto Elemento', 'Revuelto'],
    Nissan: ['GT-R R35', '370Z Nismo', 'Silvia S15', 'Skyline R34'],
    BMW: ['M3 GTR', 'M4 Competition', 'M5 CS', 'M2']
};

const BRAND_MODEL_DATA = (() => {
    const generatedMap = buildBrandModelMap(fh5Cars);
    return Object.keys(generatedMap).length > 0 ? generatedMap : fallbackBrandModelData;
})();

const vehiclePagesSlider = document.getElementById('vehicle-pages-slider');
const vehicleBrandList = document.getElementById('vehicle-brand-list');
const vehicleModelList = document.getElementById('vehicle-model-list');
const vehicleModelBack = document.getElementById('vehicle-model-back');
const vehicleFilterRow = document.getElementById('vehicle-filter-row');
const vehicleFilterInput = document.getElementById('vehicle-filter-input');
const vehicleSortTrigger = document.getElementById('vehicle-sort-trigger');
const vehicleSortMenu = document.getElementById('vehicle-sort-menu');
const vehicleSortTriggerIcon = vehicleSortTrigger?.querySelector('.vehicle-sort-trigger-icon') || null;
const selectedVehicleLabel = document.getElementById('selected-vehicle-label');
const selectedVehicleInline = document.getElementById('selected-vehicle-inline');
const vehiclePreviewWrap = document.getElementById('vehicle-preview-wrap');
const vehiclePreviewImage = document.getElementById('vehicle-preview-image');
const vehiclePreviewPlaceholder = document.getElementById('vehicle-preview-placeholder');
const vehiclePreviewCaption = document.getElementById('vehicle-preview-caption');
const vehiclePreviewCaptionLogo = document.getElementById('vehicle-preview-caption-logo');
const vehiclePreviewCaptionLogoImg = document.getElementById('vehicle-preview-caption-logo-img');
const vehiclePreviewCaptionLogoFallback = document.getElementById('vehicle-preview-caption-logo-fallback');
const vehiclePreviewCaptionText = document.getElementById('vehicle-preview-caption-text');
const vehiclePreviewPiBadge = document.getElementById('vehicle-preview-pi-badge');
const vehiclePreviewSpecs = document.getElementById('vehicle-preview-specs');
const vehiclePreviewDrive = document.getElementById('vehicle-preview-drive');
const vehiclePreviewTire = document.getElementById('vehicle-preview-tire');
const vehicleModelInfo = document.getElementById('vehicle-model-info');
const vehicleModelStats = document.getElementById('vehicle-model-stats');
const vehicleModelMetrics = document.getElementById('vehicle-model-metrics');
const createModelPresetBar = document.getElementById('create-model-preset-bar');
const createModelPresetLabel = document.getElementById('create-model-preset-label');
const createModelPresetButtons = Array.from(document.querySelectorAll('[data-model-preset]'));
const createCalcBtn = document.getElementById('btn-create-calc');
const createUnitGroup = document.getElementById('create-unit-group');
const createGameVersionGroup = document.getElementById('create-game-version-group');
const createWeightLabel = document.getElementById('create-weight-label');
const createTopSpeedLabel = document.getElementById('create-top-speed-label');
const createMaxTorqueLabel = document.getElementById('create-max-torque-label');
const createWeightInput = document.getElementById('create-weight-input');
const createFrontDistributionInput = document.getElementById('create-front-distribution-input');
const createCurrentPiInput = document.getElementById('create-current-pi-input');
const createMaxTorqueInput = document.getElementById('create-max-torque-rpm-input');
const createTopSpeedInput = document.getElementById('create-top-speed-input');
const createGearsSelect = document.getElementById('create-gears-select');
const createTireWidthInput = document.getElementById('create-tire-width-input');
const createTireAspectInput = document.getElementById('create-tire-aspect-input');
const createTireRimInput = document.getElementById('create-tire-rim-input');
const createCurrentPiBadge = document.getElementById('create-current-pi-badge');
const createDrivingSurfaceGroup = document.getElementById('create-driving-surface-group');
const createTuneTypeGroup = document.getElementById('create-tune-type-group');
const createDriveTypeGroup = document.getElementById('create-drive-type-group');
const createPowerBandTrigger = document.getElementById('create-power-band-trigger');
const createPowerBandDisplay = document.getElementById('create-power-band-display');
const createPowerBandValue = document.getElementById('create-power-band-value');
const powerBandModal = document.getElementById('power-band-modal');
const powerBandModalBackdrop = document.getElementById('power-band-modal-backdrop');
const powerBandModalCloseBtn = document.getElementById('power-band-close-btn');
const powerBandModalCancelBtn = document.getElementById('power-band-cancel-btn');
const powerBandModalApplyBtn = document.getElementById('power-band-apply-btn');
const powerBandScaleGrid = document.getElementById('power-band-scale-grid');
const powerBandScaleValue = document.getElementById('power-band-scale-value');
const powerBandRedlineSlider = document.getElementById('power-band-redline-slider');
const powerBandTorqueSlider = document.getElementById('power-band-torque-slider');
const powerBandRedlineValue = document.getElementById('power-band-redline-value');
const powerBandTorqueValue = document.getElementById('power-band-torque-value');
const powerBandRedlineMid = document.getElementById('power-band-redline-mid');
const powerBandRedlineMax = document.getElementById('power-band-redline-max');
const powerBandTorqueMid = document.getElementById('power-band-torque-mid');
const powerBandTorqueMax = document.getElementById('power-band-torque-max');
const powerBandCustomScaleRow = document.getElementById('power-band-custom-scale-row');
const powerBandCustomScaleInput = document.getElementById('power-band-custom-scale-input');
const powerBandChartTorquePath = document.getElementById('power-band-chart-torque');
const powerBandChartPowerPath = document.getElementById('power-band-chart-power');
const powerBandChartYMax = document.getElementById('power-band-chart-y-max');
const powerBandChartYMid = document.getElementById('power-band-chart-y-mid');
const powerBandChartYMin = document.getElementById('power-band-chart-y-min');
const powerBandChartXMid = document.getElementById('power-band-chart-x-mid');
const powerBandChartXMax = document.getElementById('power-band-chart-x-max');
const tuneCalcModal = document.getElementById('tune-calc-modal');
const tuneCalcModalBackdrop = document.getElementById('tune-calc-modal-backdrop');
const tuneCalcModalPanel = tuneCalcModal?.querySelector('.tune-calc-modal-panel') || null;
const tuneCalcLayoutBtn = document.getElementById('tune-calc-layout-btn');
const tuneCalcLayoutIcon = document.getElementById('tune-calc-layout-icon');
const tuneCalcOverlayBtn = document.getElementById('tune-calc-overlay-btn');
const tuneCalcOverlayIcon = document.getElementById('tune-calc-overlay-icon');
const tuneCalcModalCloseBtn = document.getElementById('tune-calc-close-btn');
const tuneCalcSaveBtn = document.getElementById('tune-calc-save-btn');
const tuneCalcSubtitle = document.getElementById('tune-calc-subtitle');
const tuneSaveNameInput = document.getElementById('tune-save-name-input');
const tuneSaveShareInput = document.getElementById('tune-save-share-input');
const tuneCalcList = document.getElementById('tune-calc-list');
const tuneGearingGraphModal = document.getElementById('tune-gearing-graph-modal');
const tuneGearingGraphBackdrop = document.getElementById('tune-gearing-graph-backdrop');
const tuneGearingGraphCloseBtn = document.getElementById('tune-gearing-graph-close');
const tuneGearingGraphTitle = document.getElementById('tune-gearing-graph-title');
const tuneGearingGraphSvg = document.getElementById('tune-gearing-graph-svg');
const tuneGearingGraphLegend = document.getElementById('tune-gearing-graph-legend');
const tuneGearingGraphMetaFinal = document.getElementById('tune-gearing-graph-meta-final');
const tuneGearingGraphMetaGears = document.getElementById('tune-gearing-graph-meta-gears');
const tuneGearingGraphYLabel = document.getElementById('tune-gearing-graph-y-label');
const tuneGearingGraphYMax = document.getElementById('tune-gearing-graph-y-max');
const tuneGearingGraphYMid = document.getElementById('tune-gearing-graph-y-mid');
const tuneGearingGraphYMin = document.getElementById('tune-gearing-graph-y-min');
const tuneGearingGraphXMin = document.getElementById('tune-gearing-graph-x-min');
const tuneGearingGraphXMid = document.getElementById('tune-gearing-graph-x-mid');
const tuneGearingGraphXMax = document.getElementById('tune-gearing-graph-x-max');
const tuneGearingGraphXLabel = document.getElementById('tune-gearing-graph-x-label');
const garageImportBtn = document.getElementById('garage-import-btn');
const garageExportBtn = document.getElementById('garage-export-btn');
const garageSelectAllBtn = document.getElementById('garage-select-all-btn');
const garageDeleteSelectedBtn = document.getElementById('garage-delete-selected-btn');
const garagePageSizeSelect = document.getElementById('garage-page-size-select');
const garageImportInput = document.getElementById('garage-import-input');
const garageCountBadge = document.getElementById('garage-count-badge');
const garageEmpty = document.getElementById('garage-empty');
const garageList = document.getElementById('garage-list');
const garageDeleteModal = document.getElementById('garage-delete-modal');
const garageDeleteModalBackdrop = document.getElementById('garage-delete-modal-backdrop');
const garageDeleteModalMessage = document.getElementById('garage-delete-modal-message');
const btnGarageDeleteNo = document.getElementById('btn-garage-delete-no');
const btnGarageDeleteYes = document.getElementById('btn-garage-delete-yes');
const garageViewModal = document.getElementById('garage-view-modal');
const garageViewModalBackdrop = document.getElementById('garage-view-modal-backdrop');
const garageViewCloseBtn = document.getElementById('garage-view-close-btn');
const garageViewSubtitle = document.getElementById('garage-view-subtitle');
const garageViewBrandLogoSlot = document.getElementById('garage-view-brand-logo-slot');
const garageViewName = document.getElementById('garage-view-name');
const garageViewCar = document.getElementById('garage-view-car');
const garageViewChips = document.getElementById('garage-view-chips');
const garageViewPi = document.getElementById('garage-view-pi');
const garageViewSpeed = document.getElementById('garage-view-speed');
const garageViewWeight = document.getElementById('garage-view-weight');
const garageViewDrive = document.getElementById('garage-view-drive');
const garageViewShare = document.getElementById('garage-view-share');
const garageViewSaved = document.getElementById('garage-view-saved');
const garageViewPreviewImage = document.getElementById('garage-view-preview-image');
const garageViewPreviewPlaceholder = document.getElementById('garage-view-preview-placeholder');
const toggleOverlayMode = document.getElementById('toggle-overlay-mode');
const toggleOverlayOnTop = document.getElementById('toggle-overlay-on-top');
const settingsThemeModeSelect = document.getElementById('settings-theme-mode-select');
const settingsLanguageSelect = document.getElementById('settings-language-select');
const overlayOpacitySlider = document.getElementById('overlay-opacity-slider');
const overlayOpacityValue = document.getElementById('overlay-opacity-value');
const settingsOverlayOnTopItem = document.getElementById('settings-overlay-on-top-item');
const settingsOverlayOpacityItem = document.getElementById('settings-overlay-opacity-item');
const tuneOverlay = document.getElementById('tune-overlay');
const tuneOverlayTitle = document.getElementById('tune-overlay-title');
const tuneOverlaySubtitle = document.getElementById('tune-overlay-subtitle');
const tuneOverlayLines = document.getElementById('tune-overlay-lines');
const tuneOverlayClose = document.getElementById('tune-overlay-close');
const appToast = document.getElementById('app-toast');
const appToastIcon = document.getElementById('app-toast-icon');
const appToastMessage = document.getElementById('app-toast-message');

const DEFAULT_VEHICLE_FILTER_PLACEHOLDER = 'Filter brand or model...';
const FORZA_INGAME_FALLBACK_URLS = [
    'https://www.allkeyshop.com/blog/wp-content/uploads/fh5.png',
    'https://cdn.forza.net/strapi-uploads/assets/FH_6_Static_Asset_4k_Mountain_423ce9ca2b.jpg'
];
const VEHICLE_SORT_LABELS = {
    name: 'Name A-Z',
    topSpeed: 'Top Speed',
    pi: 'PI'
};
const VEHICLE_SORT_DEFAULT_DIRECTION = Object.freeze({
    name: 'asc',
    topSpeed: 'desc',
    pi: 'desc'
});
const CREATE_MODEL_INFO_PRESETS = Object.freeze({
    maxGrip: Object.freeze({
        driveType: 'awd',
        surface: 'street',
        tuneType: 'race',
        frontDistributionPercent: 53
    }),
    oversteer: Object.freeze({
        driveType: 'rwd',
        surface: 'street',
        tuneType: 'drift',
        frontDistributionPercent: 47
    }),
    understeer: Object.freeze({
        driveType: 'fwd',
        surface: 'street',
        tuneType: 'race',
        frontDistributionPercent: 58
    }),
    comfort: Object.freeze({
        driveType: 'awd',
        surface: 'street',
        tuneType: 'rain',
        frontDistributionPercent: 50
    })
});
const GARAGE_SORT_LABEL_KEYS = Object.freeze({
    tuneName: 'garageSortTune',
    car: 'garageSortVehicle',
    driveType: 'garageSortDrive',
    surface: 'garageSortSurface',
    tuneType: 'garageSortType',
    pi: 'garageSortPi',
    topSpeed: 'garageSortTopSpeed',
    savedAt: 'garageSortSaved'
});

const SETTINGS_LANGUAGE_PACK = Object.freeze({
    en: Object.freeze({
        settingsMainTitle: 'General Settings',
        settingsMainSubtitle: 'Configure your application workspace preferences.',
        settingsAppPreferencesTitle: 'APP PREFERENCES',
        settingsLanguageTitle: 'Language',
        settingsLanguageDescription: 'Choose your preferred app language',
        settingsThemeModeTitle: 'Theme Mode',
        settingsThemeModeDescription: 'Choose light, dark, or follow system appearance',
        settingsThemeModeAriaLabel: 'Theme mode',
        settingsThemeModeOptionLight: 'Light',
        settingsThemeModeOptionDark: 'Dark',
        settingsThemeModeOptionSystem: 'System',
        settingsAutosaveTitle: 'Auto-save',
        settingsAutosaveDescription: 'Automatically save tuning profiles on change',
        settingsOverlayModeTitle: 'Overlay Mode',
        settingsOverlayModeDescription: 'Open tune overlay in a separate floating window',
        settingsOverlayOnTopTitle: 'Overlay On Top',
        settingsOverlayOnTopDescription: 'Keep overlay window above game and other apps',
        settingsCustomBackgroundTitle: 'CUSTOM BACKGROUND',
        backgroundUploadDefaultText: 'Drag and drop an image or video here or click to browse',
        backgroundUploadDefaultSubtext: 'Supports PNG, JPG, WEBP, MP4, WEBM, OGG, MOV (Image max 5MB, Video max 25MB)',
        backgroundUploadImageSelectedPrefix: 'Image selected',
        backgroundUploadVideoSelectedPrefix: 'Video selected',
        backgroundUploadReplaceFileText: 'Click to replace file',
        backgroundFallbackImageName: 'image background',
        backgroundFallbackVideoName: 'video background',
        settingsDonateLabel: 'Donate',
        settingsFeedbackLabel: 'Feedback',
        settingsResetAriaLabel: 'Reset settings to default',
        settingsResetTitle: 'Reset settings',
        settingsResetConfirm: 'Are you sure you want to reset all settings to default? This action cannot be undone.',
        settingsResetDone: 'Settings have been reset to default.',
        settingsInvalidFileType: 'Please select a valid image or video file (PNG, JPG, WEBP, MP4, WEBM, OGG, MOV).',
        settingsFileTooLargeImage: 'File is too large. Image max size is 5MB.',
        settingsFileTooLargeVideo: 'File is too large. Video max size is 25MB.',
        settingsLanguageAriaLabel: 'Language',
        settingsLanguageOptionEn: 'English',
        settingsLanguageOptionVi: 'Vietnamese',
        dashboardHeroSubtitle: 'Advanced Performance Engineering Suite',
        dashboardCardCreateTitle: 'Create Tune',
        dashboardCardCreateSubtitle: 'Initialize New ECU Map',
        dashboardCardGarageTitle: 'My Garage',
        dashboardCardGarageSubtitle: 'Manage Saved Profiles',
        dashboardCardSettingsTitle: 'Settings',
        dashboardCardSettingsSubtitle: 'System Preferences',
        createMainTitle: 'Create New Tune',
        createMainTitleEdit: 'Edit Tune',
        createSectionVehicleTitle: '1. Select Vehicle',
        createSectionModelInfoTitle: 'Model Info',
        createSectionPerformanceTitle: '2. Performance Data',
        createSectionAdvancedTitle: '3. Advanced Specs',
        createSectionConfigTitle: '4. Configuration',
        createSectionEnvironmentTitle: '5. Environment & Purpose',
        createFrontDistributionLabel: 'F. Distribution (%)',
        createFrontDistributionPlaceholder: 'Enter front distribution (%)',
        createCurrentPiLabel: 'Current PI',
        createCurrentPiPlaceholder: 'Enter current PI',
        createDriveTypeLabel: 'Drive Type',
        createGameVersionLabel: 'Game Version',
        createPowerBandLabel: 'Power Band',
        createPowerBandDisplayDefault: 'Set power band',
        createGearsLabel: 'Gears',
        createTireSizeLabel: 'Drive Tire Size (Width / Aspect / R Rim)',
        createTuneTypeLabel: 'Tune Type',
        createVerifyText: 'Verify all parameters before continuing',
        createCalculationButton: 'Calculation',
        createModelPresetLabel: 'Presets:',
        createModelPresetMaxGrip: 'Max Grip',
        createModelPresetOversteer: 'Oversteer',
        createModelPresetUndersteer: 'Understeer',
        createModelPresetComfort: 'Comfort',
        createUnitSystemAria: 'Unit system',
        createWeightLabelTemplate: 'Weight ({unit})',
        createWeightPlaceholderTemplate: 'Enter weight ({unit})',
        createTopSpeedLabelTemplate: 'Top Speed ({unit})',
        createTopSpeedPlaceholderTemplate: 'Enter top speed ({unit})',
        createMaxTorqueLabelTemplate: 'Max Torque ({unit})',
        createMaxTorquePlaceholderTemplate: 'Enter max torque from game ({unit})',
        createTireWidthPlaceholder: 'Width',
        createTireAspectPlaceholder: 'Aspect',
        createTireRimPlaceholder: 'Rim',
        createUnitMetricLabel: 'Metric',
        createUnitImperialLabel: 'Imperial',
        createSurfaceStreet: 'Street',
        createSurfaceDirt: 'Dirt',
        createSurfaceCross: 'Cross',
        createSurfaceOffroad: 'Off-road',
        createTuneTypeRace: 'Race',
        createTuneTypeDrift: 'Drift',
        createTuneTypeRain: 'Rain',
        createTuneTypeDrag: 'Drag',
        createTuneTypeRally: 'Rally',
        createTuneTypeTruck: 'Truck',
        createTuneTypeBuggy: 'Buggy',
        createVehicleFilterPlaceholder: 'Filter brand or model...',
        createVehicleBackAria: 'Back to brands',
        createVehicleSortMenuAria: 'Vehicle sort options',
        createVehicleSortTriggerPrefix: 'Sort',
        createVehicleSortTriggerAriaPrefix: 'Sort vehicles',
        createVehiclePreviewPlaceholder: 'Select a model to preview.',
        createVehicleListUpdating: 'Vehicle list is being updated.',
        createNoBrandOrModelFound: 'No brand or model found.',
        createSelectBrandFirst: 'Select a brand first.',
        createNoModelFound: 'No model found.',
        createModelsCount: '{count} models',
        createMatchingModelsCount: '{count} matching models',
        vehiclePreviewLoadingLabel: 'Loading in-game preview for {label}...',
        vehiclePreviewLoadingGeneric: 'Loading vehicle image...',
        vehiclePreviewUnavailable: 'Vehicle image unavailable.',
        vehiclePreviewLoadFailed: 'Unable to load vehicle preview.',
        vehiclePreviewIngameFailed: 'Unable to load in-game preview.',
        createModelInfoSpeed: 'Speed',
        createModelInfoHandling: 'Handling',
        createModelInfoAccel: 'Accel',
        createModelInfoLaunch: 'Launch',
        createModelInfoBraking: 'Braking',
        createModelInfoTopSpeed: 'Top Speed',
        createModelInfoPi: 'PI',
        createModelInfoDrive: 'Drive',
        createModelInfoTire: 'Tire',
        createModelInfoDifferential: 'Differential',
        createModelInfoSectionTiresAlignment: 'Tires & Alignment',
        createModelInfoSectionSpringsDampers: 'Springs & Dampers',
        createModelInfoSectionAero: 'Aerodynamics',
        createModelInfoSectionDrivetrain: 'Drivetrain & Diff',
        createModelInfoSectionBrakes: 'Brakes',
        vehicleSortNameAsc: 'Name A-Z',
        vehicleSortNameDesc: 'Name Z-A',
        vehicleSortTopSpeedDesc: 'Top Speed High-Low',
        vehicleSortTopSpeedAsc: 'Top Speed Low-High',
        vehicleSortPiDesc: 'PI High-Low',
        vehicleSortPiAsc: 'PI Low-High',
        garageMainTitle: 'My Garage',
        garageRowsLabel: 'Rows',
        garageRowsAria: 'Rows per page',
        garageImportLabel: 'Import',
        garageExportLabel: 'Export',
        garageSelectAllLabel: 'Select All',
        garageClearAllLabel: 'Clear All',
        garageDeleteMarkedLabel: 'Delete Marked',
        garageSortTune: 'Tune',
        garageSortVehicle: 'Vehicle',
        garageSortDrive: 'Drive',
        garageSortSurface: 'Surface',
        garageSortType: 'Type',
        garageSortPi: 'PI',
        garageSortTopSpeed: 'Top Speed',
        garageSortSaved: 'Saved',
        garageSavedRecently: 'Saved recently',
        garageEmpty: 'No saved tunes yet. Save a tune from Tune Results to see it here.',
        garageTableAria: 'Saved tune table',
        garageHeadMark: 'Mark',
        garageHeadActions: 'Actions',
        garageSortStateAsc: ' (ascending)',
        garageSortStateDesc: ' (descending)',
        garageSortByAria: 'Sort by {label}{state}',
        garageMarkedPrefix: 'Marked tune.',
        garageOpenTuneDetails: 'Open tune details for {title}',
        garageMarkTune: 'Mark tune',
        garageUnmarkTune: 'Unmark tune',
        garageEditTune: 'Edit tune',
        garageOverlayTune: 'Pin tune to overlay',
        garageDeleteTune: 'Delete tune',
        garageActionEditTitle: 'Edit',
        garageActionOverlayTitle: 'Overlay',
        garageActionDeleteTitle: 'Delete',
        garagePaginationAria: 'Garage pages',
        garagePrevPageAria: 'Previous page',
        garageNextPageAria: 'Next page',
        garageDeleteMarkedCount: 'Delete Marked ({count})',
        garageCountSummary: '{count} tune{plural}',
        garageCountSummaryMarked: '{count} tune{plural} • {selected} marked',
        garageDeleteModalTitle: 'Delete Marked Tunes?',
        garageDeleteModalMessage: 'Delete {count} marked tune{plural}? This action cannot be undone.',
        garageDeleteFallbackConfirm: 'Delete {count} marked tune{plural}?',
        garageDeleteNo: 'No',
        garageDeleteYes: 'Yes',
        garageNoTuneSelected: 'No tune selected',
        garageOverlayHint: 'Select a tune in My Garage to preview it here',
        garagePiUnavailable: 'PI unavailable',
        garageExportNoTunes: 'No tunes to export.',
        garageExportSelectAtLeast: 'Mark at least one tune to export.',
        garageExportFailed: 'Failed to export selected tunes.',
        garageExportSuccess: 'Exported {count} tune{plural}.',
        garageImportOnlyTune: 'Import only supports .tune files.',
        garageImportNoValid: 'No valid tune data found in selected file.',
        garageImportSuccess: 'Imported {count} tune{plural} successfully.',
        garageImportFailed: 'Failed to import tunes. Please check .tune file format.',
        powerBandModalTitle: 'Power Band Setup',
        powerBandCloseAria: 'Close RPM setup',
        powerBandRedlineTitle: 'Redline RPM',
        powerBandMaxTorqueTitle: 'Max Torque RPM',
        powerBandScaleTitle: 'RPM Scale',
        powerBandCustomLabel: 'Custom Max RPM',
        powerBandGraphTitle: 'Performance Graph',
        powerBandLegendTorque: 'Torque',
        powerBandLegendPower: 'Power',
        powerBandCancel: 'Cancel',
        powerBandApply: 'Apply',
        tuneResultsTitle: 'Tune Results',
        tuneResultsCloseAria: 'Close tune results',
        tuneResultsSubtitle: 'Values are for reference only.',
        tuneResultsLayoutExpandedTitle: 'Switch to expanded view',
        tuneResultsLayoutCompactTitle: 'Switch to compact view',
        tuneResultsOverlayEnableTitle: 'Turn overlay on',
        tuneResultsOverlayDisableTitle: 'Turn overlay off',
        tuneResultsGearingChartTitle: 'Open gearing chart',
        tuneResultsGearingModalTitle: 'Gearing Chart',
        tuneResultsGearingCloseAria: 'Close gearing chart',
        tuneResultsGearingSpeedLabel: 'Speed',
        tuneResultsGearingRpmAxisLabel: 'RPM (x1000)',
        tuneResultsGearingLegendPrefix: 'Gear',
        tuneSaveNamePlaceholder: 'Tune name',
        tuneSaveSharePlaceholder: 'Share code (000 000 000)',
        tuneSaveButton: 'Save',
        tuneDetailsTitle: 'Tune Details',
        tuneDetailsCloseAria: 'Close tune details',
        tuneDetailsSubtitle: 'Detailed tune profile from My Garage.',
        tuneMetaTopSpeed: 'Top Speed',
        tuneMetaWeight: 'Weight',
        tuneMetaDrive: 'Drive',
        tuneMetaShareCode: 'Share Code',
        tuneMetaRpm: 'RPM',
        donateTitle: 'Support F.Tuning Pro',
        donateSubtitle: 'Scan QR to donate for app development',
        donateCloseAria: 'Close donate',
        updateLogTitle: 'Update Log',
        updateLogSubtitle: 'Latest improvements in this version',
        updateLogItemMainUi: 'Updated main screen interface layout for cleaner navigation.',
        updateLogItemTextFix: 'Fixed text rendering issues in multiple UI sections.',
        updateLogItemUiOptimize: 'Optimized responsive layout and overall UI spacing.',
        updateLogVersionLabel: 'Version',
        updateLogCloseAria: 'Close update log modal',
        updateLogCloseButton: 'Close',
        feedbackTitle: 'Send Feedback',
        feedbackSubtitle: 'Share your feedback directly from the app.',
        feedbackCloseAria: 'Close feedback modal',
        feedbackTitlePlaceholder: 'Feedback title',
        feedbackNamePlaceholder: 'Your name (optional)',
        feedbackEmailPlaceholder: 'Your email (required)',
        feedbackMessagePlaceholder: 'Type your feedback...',
        feedbackCancelButton: 'Cancel',
        feedbackSendButton: 'Send',
        feedbackSending: 'Sending...',
        feedbackTitleRequired: 'Please enter a feedback title.',
        feedbackEmailRequired: 'Please enter a valid email address.',
        feedbackMessageRequired: 'Please enter your feedback before sending.',
        feedbackSuccess: 'Feedback sent successfully. Thank you for your contribution.',
        feedbackFailed: 'Unable to send feedback. Please try again.',
        welcomeTitle: 'Welcome to F.Tuning Pro',
        welcomeSubtitle: 'Quick tour of the main features',
        welcomeSetupTitle: 'Choose your preferences before the tour',
        welcomeSetupLanguageLabel: 'Language',
        welcomeSetupUnitLabel: 'Measurement',
        welcomeSetupThemeLabel: 'Theme',
        welcomeThemeLightLabel: 'Light',
        welcomeThemeDarkLabel: 'Dark',
        welcomeSetupContinueAria: 'Continue to feature slides',
        welcomeSlideCreateTitle: 'Create New Tune',
        welcomeSlideCreateText: 'Build complete tune profiles with vehicle selection, setup inputs, and power band calibration.',
        welcomeSlideCalcTitle: 'Calculate Tune',
        welcomeSlideCalcText: 'Open Tune Results to review every generated setup value before saving your tune.',
        welcomeSlideGarageTitle: 'My Garage',
        welcomeSlideGarageText: 'Manage saved tunes in table view, sort quickly, and open overlay for in-game reference.',
        welcomeSlideOverlayTitle: 'Overlay',
        welcomeSlideOverlayText: 'Track tune values in a floating overlay while driving in-game.',
        welcomeCheckText: 'Do not show again next time',
        welcomeCloseLabel: 'Close',
        welcomeNextAria: 'Next page',
        footerOnline: 'Online',
        settingsBackgroundTooLargeWarning: 'Background file is too large to save permanently. It will remain active until you restart the app.',
        genericUnknown: 'Unknown',
        genericUnknownBrand: 'Unknown Brand',
        genericUnknownModel: 'Unknown Model',
        genericUnknownVehicle: 'Unknown Vehicle',
        genericUntitledTune: 'Untitled Tune',
        vehiclePreviewAlt: 'Vehicle preview',
        vehiclePreviewLabel: 'Vehicle',
        vehiclePreviewDrivePrefix: 'Drive Type',
        vehiclePreviewTirePrefix: 'Tire Type',
        overlayHeadTitle: 'Tune Overlay',
        overlayControlsAria: 'Overlay controls',
        overlayOpacityLabel: 'Opacity',
        overlayTextSizeLabel: 'Text Size',
        overlayOnTopLabel: 'Always On Top',
        overlayLayoutLabel: 'Layout',
        overlayLayoutVertical: 'Vertical',
        overlayLayoutGrid: 'Grid',
        overlayLayoutCompact: 'Compact',
        overlayOpacityAria: 'Overlay opacity',
        overlayTextSizeAria: 'Overlay text size',
        overlayOnTopAria: 'Keep overlay always on top',
        overlayLayoutAria: 'Overlay layout',
        overlayLockTitle: 'Lock position',
        overlayUnlockTitle: 'Unlock position',
        overlaySettingsTitle: 'Overlay settings',
        overlayCloseTitle: 'Close overlay',
        overlayNoData: 'No Data',
        overlayCardFallbackTitle: 'Tune',
        overlayFinalDriveLabel: 'Final Drive',
        overlayGearsLabel: 'Gears'
    }),
    vi: Object.freeze({
        settingsMainTitle: 'Cài Đặt Chung',
        settingsMainSubtitle: 'Thiết lập không gian làm việc và tùy chọn ứng dụng.',
        settingsAppPreferencesTitle: 'TÙY CHỌN ỨNG DỤNG',
        settingsLanguageTitle: 'Ngôn ngữ',
        settingsLanguageDescription: 'Chọn ngôn ngữ hiển thị cho ứng dụng',
        settingsThemeModeTitle: 'Chế độ giao diện',
        settingsThemeModeDescription: 'Chọn sáng, tối hoặc theo giao diện hệ thống',
        settingsThemeModeAriaLabel: 'Chế độ giao diện',
        settingsThemeModeOptionLight: 'Sáng',
        settingsThemeModeOptionDark: 'Tối',
        settingsThemeModeOptionSystem: 'Hệ thống',
        settingsAutosaveTitle: 'Tự động lưu',
        settingsAutosaveDescription: 'Tự động lưu profile tune khi có thay đổi',
        settingsOverlayModeTitle: 'Chế độ Overlay',
        settingsOverlayModeDescription: 'Mở bảng tune ở cửa sổ nổi riêng',
        settingsOverlayOnTopTitle: 'Overlay luôn nổi',
        settingsOverlayOnTopDescription: 'Giữ cửa sổ overlay luôn nằm trên game và ứng dụng khác',
        settingsCustomBackgroundTitle: 'NỀN TÙY CHỈNH',
        backgroundUploadDefaultText: 'Kéo thả ảnh hoặc video vào đây, hoặc bấm để chọn tệp',
        backgroundUploadDefaultSubtext: 'Hỗ trợ PNG, JPG, WEBP, MP4, WEBM, OGG, MOV (Ảnh tối đa 5MB, Video tối đa 25MB)',
        backgroundUploadImageSelectedPrefix: 'Đã chọn ảnh',
        backgroundUploadVideoSelectedPrefix: 'Đã chọn video',
        backgroundUploadReplaceFileText: 'Bấm để thay tệp khác',
        backgroundFallbackImageName: 'nền ảnh',
        backgroundFallbackVideoName: 'nền video',
        settingsDonateLabel: 'Ủng hộ',
        settingsFeedbackLabel: 'Góp ý',
        settingsResetAriaLabel: 'Đặt lại cài đặt mặc định',
        settingsResetTitle: 'Đặt lại cài đặt',
        settingsResetConfirm: 'Bạn có chắc muốn đưa toàn bộ cài đặt về mặc định? Hành động này không thể hoàn tác.',
        settingsResetDone: 'Đã đặt lại cài đặt về mặc định.',
        settingsInvalidFileType: 'Vui lòng chọn tệp ảnh hoặc video hợp lệ (PNG, JPG, WEBP, MP4, WEBM, OGG, MOV).',
        settingsFileTooLargeImage: 'Tệp quá lớn. Ảnh tối đa 5MB.',
        settingsFileTooLargeVideo: 'Tệp quá lớn. Video tối đa 25MB.',
        settingsLanguageAriaLabel: 'Ngôn ngữ',
        settingsLanguageOptionEn: 'Tiếng Anh',
        settingsLanguageOptionVi: 'Tiếng Việt',
        dashboardHeroSubtitle: 'Bộ công cụ kỹ thuật hiệu năng nâng cao',
        dashboardCardCreateTitle: 'Tạo Tune',
        dashboardCardCreateSubtitle: 'Khởi tạo cấu hình ECU mới',
        dashboardCardGarageTitle: 'Kho Tune',
        dashboardCardGarageSubtitle: 'Quản lý các cấu hình đã lưu',
        dashboardCardSettingsTitle: 'Cài đặt',
        dashboardCardSettingsSubtitle: 'Tùy chọn hệ thống',
        createMainTitle: 'Tạo Tune Mới',
        createMainTitleEdit: 'Chỉnh Sửa Tune',
        createSectionVehicleTitle: '1. Chọn Xe',
        createSectionModelInfoTitle: 'Model Info',
        createSectionPerformanceTitle: '2. Dữ Liệu Hiệu Năng',
        createSectionAdvancedTitle: '3. Thông Số Nâng Cao',
        createSectionConfigTitle: '4. Cấu Hình',
        createSectionEnvironmentTitle: '5. Môi Trường & Mục Đích',
        createFrontDistributionLabel: 'Phân bổ trước (%)',
        createFrontDistributionPlaceholder: 'Nhập phân bổ cầu trước (%)',
        createCurrentPiLabel: 'PI hiện tại',
        createCurrentPiPlaceholder: 'Nhập PI hiện tại',
        createDriveTypeLabel: 'Kiểu truyền động',
        createGameVersionLabel: 'Phiên bản game',
        createPowerBandLabel: 'Power Band',
        createPowerBandDisplayDefault: 'Thiết lập power band',
        createGearsLabel: 'Số cấp số',
        createTireSizeLabel: 'Kích thước lốp (Bề rộng / Tỷ lệ / R Mâm)',
        createTuneTypeLabel: 'Loại Tune',
        createVerifyText: 'Xác nhận đầy đủ thông số trước khi tiếp tục',
        createCalculationButton: 'Tính toán',
        createModelPresetLabel: 'Presets:',
        createModelPresetMaxGrip: 'Max Grip',
        createModelPresetOversteer: 'Oversteer',
        createModelPresetUndersteer: 'Understeer',
        createModelPresetComfort: 'Comfort',
        createUnitSystemAria: 'Hệ đơn vị',
        createWeightLabelTemplate: 'Khối lượng ({unit})',
        createWeightPlaceholderTemplate: 'Nhập khối lượng ({unit})',
        createTopSpeedLabelTemplate: 'Tốc độ tối đa ({unit})',
        createTopSpeedPlaceholderTemplate: 'Nhập tốc độ tối đa ({unit})',
        createMaxTorqueLabelTemplate: 'Mô-men xoắn cực đại ({unit})',
        createMaxTorquePlaceholderTemplate: 'Nhập mô-men xoắn từ game ({unit})',
        createTireWidthPlaceholder: 'Bề rộng',
        createTireAspectPlaceholder: 'Tỷ lệ',
        createTireRimPlaceholder: 'Mâm',
        createUnitMetricLabel: 'Hệ mét',
        createUnitImperialLabel: 'Hệ Anh',
        createSurfaceStreet: 'Đường nhựa',
        createSurfaceDirt: 'Đường đất',
        createSurfaceCross: 'Hỗn hợp',
        createSurfaceOffroad: 'Off-road',
        createTuneTypeRace: 'Đua',
        createTuneTypeDrift: 'Drift',
        createTuneTypeRain: 'Mưa',
        createTuneTypeDrag: 'Drag',
        createTuneTypeRally: 'Rally',
        createTuneTypeTruck: 'Truck',
        createTuneTypeBuggy: 'Buggy',
        createVehicleFilterPlaceholder: 'Lọc theo hãng hoặc mẫu xe...',
        createVehicleBackAria: 'Quay lại danh sách hãng',
        createVehicleSortMenuAria: 'Tùy chọn sắp xếp xe',
        createVehicleSortTriggerPrefix: 'Sắp xếp',
        createVehicleSortTriggerAriaPrefix: 'Sắp xếp xe',
        createVehiclePreviewPlaceholder: 'Chọn model để xem trước.',
        createVehicleListUpdating: 'Danh sách xe đang được cập nhật.',
        createNoBrandOrModelFound: 'Không tìm thấy hãng hoặc model.',
        createSelectBrandFirst: 'Vui lòng chọn hãng trước.',
        createNoModelFound: 'Không tìm thấy model.',
        createModelsCount: '{count} mẫu',
        createMatchingModelsCount: '{count} mẫu khớp',
        vehiclePreviewLoadingLabel: 'Đang tải ảnh in-game cho {label}...',
        vehiclePreviewLoadingGeneric: 'Đang tải ảnh xe...',
        vehiclePreviewUnavailable: 'Không có ảnh xe.',
        vehiclePreviewLoadFailed: 'Không thể tải ảnh xem trước xe.',
        vehiclePreviewIngameFailed: 'Không thể tải ảnh xem trước in-game.',
        createModelInfoSpeed: 'Tốc độ',
        createModelInfoHandling: 'Bám đường',
        createModelInfoAccel: 'Tăng tốc',
        createModelInfoLaunch: 'Đề-pa',
        createModelInfoBraking: 'Phanh',
        createModelInfoTopSpeed: 'Tốc độ tối đa',
        createModelInfoPi: 'PI',
        createModelInfoDrive: 'Dẫn động',
        createModelInfoTire: 'Lốp',
        createModelInfoDifferential: 'Vi sai',
        createModelInfoSectionTiresAlignment: 'Lốp & Cân chỉnh',
        createModelInfoSectionSpringsDampers: 'Lò xo & Giảm chấn',
        createModelInfoSectionAero: 'Khí động học',
        createModelInfoSectionDrivetrain: 'Truyền động & Vi sai',
        createModelInfoSectionBrakes: 'Phanh',
        vehicleSortNameAsc: 'Tên A-Z',
        vehicleSortNameDesc: 'Tên Z-A',
        vehicleSortTopSpeedDesc: 'Tốc độ cao-thấp',
        vehicleSortTopSpeedAsc: 'Tốc độ thấp-cao',
        vehicleSortPiDesc: 'PI cao-thấp',
        vehicleSortPiAsc: 'PI thấp-cao',
        garageMainTitle: 'Kho Tune',
        garageRowsLabel: 'Số dòng',
        garageRowsAria: 'Số dòng mỗi trang',
        garageImportLabel: 'Nhập',
        garageExportLabel: 'Xuất',
        garageSelectAllLabel: 'Chọn tất cả',
        garageClearAllLabel: 'Bỏ chọn tất cả',
        garageDeleteMarkedLabel: 'Xóa đã chọn',
        garageSortTune: 'Tune',
        garageSortVehicle: 'Xe',
        garageSortDrive: 'Dẫn động',
        garageSortSurface: 'Bề mặt',
        garageSortType: 'Loại',
        garageSortPi: 'PI',
        garageSortTopSpeed: 'Tốc độ',
        garageSortSaved: 'Đã lưu',
        garageSavedRecently: 'Vừa lưu',
        garageEmpty: 'Chưa có tune nào được lưu. Hãy lưu tune từ Tune Results để hiển thị tại đây.',
        garageTableAria: 'Bảng tune đã lưu',
        garageHeadMark: 'Chọn',
        garageHeadActions: 'Thao tác',
        garageSortStateAsc: ' (tăng dần)',
        garageSortStateDesc: ' (giảm dần)',
        garageSortByAria: 'Sắp xếp theo {label}{state}',
        garageMarkedPrefix: 'Tune đã đánh dấu.',
        garageOpenTuneDetails: 'Mở chi tiết tune cho {title}',
        garageMarkTune: 'Đánh dấu tune',
        garageUnmarkTune: 'Bỏ đánh dấu tune',
        garageEditTune: 'Chỉnh sửa tune',
        garageOverlayTune: 'Ghim tune lên overlay',
        garageDeleteTune: 'Xóa tune',
        garageActionEditTitle: 'Sửa',
        garageActionOverlayTitle: 'Overlay',
        garageActionDeleteTitle: 'Xóa',
        garagePaginationAria: 'Trang trong kho tune',
        garagePrevPageAria: 'Trang trước',
        garageNextPageAria: 'Trang sau',
        garageDeleteMarkedCount: 'Xóa đã chọn ({count})',
        garageCountSummary: '{count} tune{plural}',
        garageCountSummaryMarked: '{count} tune{plural} • {selected} đã chọn',
        garageDeleteModalTitle: 'Xóa Các Tune Đã Chọn?',
        garageDeleteModalMessage: 'Xóa {count} tune đã đánh dấu{plural}? Hành động này không thể hoàn tác.',
        garageDeleteFallbackConfirm: 'Xóa {count} tune đã đánh dấu{plural}?',
        garageDeleteNo: 'Không',
        garageDeleteYes: 'Có',
        garageNoTuneSelected: 'Chưa chọn tune',
        garageOverlayHint: 'Chọn một tune trong Kho Tune để xem trên overlay',
        garagePiUnavailable: 'PI không có',
        garageExportNoTunes: 'Không có tune để xuất.',
        garageExportSelectAtLeast: 'Hãy đánh dấu ít nhất một tune để xuất.',
        garageExportFailed: 'Không thể xuất các tune đã chọn.',
        garageExportSuccess: 'Đã xuất {count} tune{plural}.',
        garageImportOnlyTune: 'Chỉ hỗ trợ import tệp .tune.',
        garageImportNoValid: 'Không tìm thấy dữ liệu tune hợp lệ trong tệp đã chọn.',
        garageImportSuccess: 'Đã nhập thành công {count} tune{plural}.',
        garageImportFailed: 'Không thể nhập tune. Vui lòng kiểm tra định dạng tệp .tune.',
        powerBandModalTitle: 'Thiết Lập Power Band',
        powerBandCloseAria: 'Đóng thiết lập RPM',
        powerBandRedlineTitle: 'Redline RPM',
        powerBandMaxTorqueTitle: 'RPM mô-men xoắn cực đại',
        powerBandScaleTitle: 'Thang RPM',
        powerBandCustomLabel: 'RPM tối đa tùy chỉnh',
        powerBandGraphTitle: 'Biểu đồ hiệu năng',
        powerBandLegendTorque: 'Mô-men',
        powerBandLegendPower: 'Công suất',
        powerBandCancel: 'Hủy',
        powerBandApply: 'Áp dụng',
        tuneResultsTitle: 'Kết Quả Tune',
        tuneResultsCloseAria: 'Đóng kết quả tune',
        tuneResultsSubtitle: 'Thông số chỉ mang tính chất tham khảo.',
        tuneResultsLayoutExpandedTitle: 'Chuyển sang chế độ mở rộng',
        tuneResultsLayoutCompactTitle: 'Chuyển sang chế độ thu gọn',
        tuneResultsOverlayEnableTitle: 'Bật overlay',
        tuneResultsOverlayDisableTitle: 'Tắt overlay',
        tuneResultsGearingChartTitle: 'Mở biểu đồ hộp số',
        tuneResultsGearingModalTitle: 'Biểu Đồ Hộp Số',
        tuneResultsGearingCloseAria: 'Đóng biểu đồ hộp số',
        tuneResultsGearingSpeedLabel: 'Tốc độ',
        tuneResultsGearingRpmAxisLabel: 'RPM (x1000)',
        tuneResultsGearingLegendPrefix: 'Số',
        tuneSaveNamePlaceholder: 'Tên tune',
        tuneSaveSharePlaceholder: 'Share code (000 000 000)',
        tuneSaveButton: 'Lưu',
        tuneDetailsTitle: 'Chi Tiết Tune',
        tuneDetailsCloseAria: 'Đóng chi tiết tune',
        tuneDetailsSubtitle: 'Thông tin tune chi tiết từ Kho Tune.',
        tuneMetaTopSpeed: 'Tốc độ tối đa',
        tuneMetaWeight: 'Khối lượng',
        tuneMetaDrive: 'Truyền động',
        tuneMetaShareCode: 'Mã chia sẻ',
        tuneMetaRpm: 'RPM',
        donateTitle: 'Ủng Hộ F.Tuning Pro',
        donateSubtitle: 'Quét mã QR để ủng hộ phát triển ứng dụng',
        donateCloseAria: 'Đóng bảng ủng hộ',
        updateLogTitle: 'Nhật Ký Cập Nhật',
        updateLogSubtitle: 'Các cải tiến mới trong phiên bản này',
        updateLogItemMainUi: 'Cập nhật giao diện màn hình chính để điều hướng gọn gàng hơn.',
        updateLogItemTextFix: 'Sửa lỗi hiển thị văn bản ở nhiều khu vực giao diện.',
        updateLogItemUiOptimize: 'Tối ưu bố cục responsive và khoảng cách giao diện tổng thể.',
        updateLogVersionLabel: 'Phiên bản',
        updateLogCloseAria: 'Đóng nhật ký cập nhật',
        updateLogCloseButton: 'Đóng',
        feedbackTitle: 'Gửi Góp Ý',
        feedbackSubtitle: 'Chia sẻ góp ý trực tiếp từ trong ứng dụng.',
        feedbackCloseAria: 'Đóng cửa sổ góp ý',
        feedbackTitlePlaceholder: 'Tiêu đề góp ý',
        feedbackNamePlaceholder: 'Tên của bạn (không bắt buộc)',
        feedbackEmailPlaceholder: 'Email của bạn (bắt buộc)',
        feedbackMessagePlaceholder: 'Nhập nội dung góp ý...',
        feedbackCancelButton: 'Hủy',
        feedbackSendButton: 'Gửi',
        feedbackSending: 'Đang gửi...',
        feedbackTitleRequired: 'Vui lòng nhập tiêu đề góp ý.',
        feedbackEmailRequired: 'Vui lòng nhập đúng địa chỉ email.',
        feedbackMessageRequired: 'Vui lòng nhập nội dung góp ý trước khi gửi.',
        feedbackSuccess: 'Đã gửi góp ý thành công. Cảm ơn bạn đã đóng góp.',
        feedbackFailed: 'Không thể gửi góp ý. Vui lòng thử lại.',
        welcomeTitle: 'Chào mừng đến với F.Tuning Pro',
        welcomeSubtitle: 'Xem nhanh các tính năng chính',
        welcomeSetupTitle: 'Chọn thiết lập trước khi bắt đầu',
        welcomeSetupLanguageLabel: 'Ngôn ngữ',
        welcomeSetupUnitLabel: 'Hệ đo lường',
        welcomeSetupThemeLabel: 'Giao diện',
        welcomeThemeLightLabel: 'Sáng',
        welcomeThemeDarkLabel: 'Tối',
        welcomeSetupContinueAria: 'Tiếp tục tới các slide tính năng',
        welcomeSlideCreateTitle: 'Tạo Tune Mới',
        welcomeSlideCreateText: 'Thiết lập đầy đủ cấu hình tune với chọn xe, nhập thông số và cân chỉnh power band.',
        welcomeSlideCalcTitle: 'Tính Toán Tune',
        welcomeSlideCalcText: 'Mở Tune Results để xem toàn bộ thông số trước khi lưu tune.',
        welcomeSlideGarageTitle: 'Kho Tune',
        welcomeSlideGarageText: 'Quản lý tune đã lưu dạng bảng, sắp xếp nhanh và mở overlay theo dõi trong game.',
        welcomeSlideOverlayTitle: 'Overlay',
        welcomeSlideOverlayText: 'Theo dõi thông số tune bằng cửa sổ overlay nổi trong lúc nhập vào game.',
        welcomeCheckText: 'Không hiển thị lại ở lần sau',
        welcomeCloseLabel: 'Đóng',
        welcomeNextAria: 'Trang tiếp theo',
        footerOnline: 'Trực tuyến',
        settingsBackgroundTooLargeWarning: 'Tệp nền quá lớn nên không thể lưu vĩnh viễn. Nền hiện tại sẽ được giữ cho đến khi bạn khởi động lại ứng dụng.',
        genericUnknown: 'Chưa rõ',
        genericUnknownBrand: 'Hãng chưa rõ',
        genericUnknownModel: 'Mẫu chưa rõ',
        genericUnknownVehicle: 'Xe chưa rõ',
        genericUntitledTune: 'Tune chưa đặt tên',
        vehiclePreviewAlt: 'Xem trước xe',
        vehiclePreviewLabel: 'Xe',
        vehiclePreviewDrivePrefix: 'Dẫn động',
        vehiclePreviewTirePrefix: 'Lốp',
        overlayHeadTitle: 'Overlay Tune',
        overlayControlsAria: 'Tùy chỉnh overlay',
        overlayOpacityLabel: 'Độ trong suốt',
        overlayTextSizeLabel: 'Cỡ chữ',
        overlayOnTopLabel: 'Luôn nổi',
        overlayLayoutLabel: 'Bố cục',
        overlayLayoutVertical: 'Dọc',
        overlayLayoutGrid: 'Lưới',
        overlayLayoutCompact: 'Gọn',
        overlayOpacityAria: 'Độ trong suốt overlay',
        overlayTextSizeAria: 'Cỡ chữ overlay',
        overlayOnTopAria: 'Giữ overlay luôn nổi trên cùng',
        overlayLayoutAria: 'Bố cục overlay',
        overlayLockTitle: 'Khóa vị trí',
        overlayUnlockTitle: 'Mở khóa vị trí',
        overlaySettingsTitle: 'Cài đặt overlay',
        overlayCloseTitle: 'Đóng overlay',
        overlayNoData: 'Chưa có dữ liệu',
        overlayCardFallbackTitle: 'Tune',
        overlayFinalDriveLabel: 'Truyền cuối',
        overlayGearsLabel: 'Số'
    })
});

const UNIT_SYSTEMS = Object.freeze({
    metric: Object.freeze({
        weightLabel: 'kg',
        speedLabel: 'km/h',
        torqueLabel: 'N-M',
        pressureLabel: 'bar'
    }),
    imperial: Object.freeze({
        weightLabel: 'lb',
        speedLabel: 'mph',
        torqueLabel: 'lb-ft',
        pressureLabel: 'psi'
    })
});

const TUNE_TYPE_OPTIONS_BY_SURFACE = Object.freeze({
    race: Object.freeze(['Race', 'Drift', 'Rain', 'Drag']),
    dirt: Object.freeze(['Rally', 'Truck', 'Buggy']),
    offroad: Object.freeze(['Rally', 'Truck', 'Buggy'])
});

const POWER_BAND_PRESET_SCALE_OPTIONS = Object.freeze([8000, 10000, 12000]);
const POWER_BAND_CUSTOM_SCALE_MIN = 6000;
const POWER_BAND_CUSTOM_SCALE_MAX = 20000;
const POWER_BAND_CUSTOM_SCALE_STEP = 100;
const POWER_BAND_CUSTOM_DEFAULT_SCALE = 14000;
const GARAGE_VIEW_MODAL_TRANSITION_MS = 240;
const GARAGE_DELETE_MODAL_TRANSITION_MS = 220;
const DEFAULT_POWER_BAND_STATE = Object.freeze({
    scaleMax: 10000,
    redlineRpm: 10000,
    maxTorqueRpm: 6800,
    isCustomScale: false,
    customScaleMax: POWER_BAND_CUSTOM_DEFAULT_SCALE
});

const BRAND_LOGO_SLUG_BY_KEY = Object.freeze({
    abarth: 'abarth',
    acura: 'acura',
    alfa: 'alfaromeo',
    alpine: 'alpine',
    amg: 'mercedesbenz',
    aston: 'astonmartin',
    audi: 'audi',
    bentley: 'bentley',
    bmw: 'bmw',
    bugatti: 'bugatti',
    buick: 'buick',
    cadillac: 'cadillac',
    chevrolet: 'chevrolet',
    citroen: 'citroen',
    cupra: 'cupra',
    datsun: 'datsun',
    delorean: 'delorean',
    dodge: 'dodge',
    ds: 'dsautomobiles',
    ferrari: 'ferrari',
    fiat: 'fiat',
    ford: 'ford',
    gmc: 'gmc',
    holden: 'holden',
    honda: 'honda',
    hummer: 'hummer',
    hyundai: 'hyundai',
    infiniti: 'infiniti',
    jaguar: 'jaguar',
    jeep: 'jeep',
    kia: 'kia',
    koenigsegg: 'koenigsegg',
    ktm: 'ktm',
    lamborghini: 'lamborghini',
    lancia: 'lancia',
    land: 'landrover',
    lexus: 'lexus',
    lincoln: 'lincoln',
    lotus: 'lotuscars',
    lucid: 'lucidmotors',
    lynk: 'lynkco',
    maserati: 'maserati',
    mazda: 'mazda',
    mclaren: 'mclaren',
    mercedesamg: 'mercedesbenz',
    mercedesbenz: 'mercedesbenz',
    mg: 'mg',
    mini: 'mini',
    mitsubishi: 'mitsubishi',
    morgan: 'morgan',
    nio: 'nio',
    nissan: 'nissan',
    opel: 'opel',
    pagani: 'pagani',
    peugeot: 'peugeot',
    polaris: 'polaris',
    pontiac: 'pontiac',
    porsche: 'porsche',
    ram: 'ram',
    renault: 'renault',
    rimac: 'rimacautomobili',
    rivian: 'rivian',
    subaru: 'subaru',
    toyota: 'toyota',
    vauxhall: 'vauxhall',
    volkswagen: 'volkswagen',
    volvo: 'volvo',
    wuling: 'wuling',
    xpeng: 'xpeng'
});

const BRAND_LOGO_CARLOGO_SLUG_OVERRIDES = Object.freeze({
    alfa: 'alfa-romeo',
    aston: 'aston-martin',
    land: 'land-rover',
    lynk: 'lynkco',
    amg: 'mercedes-amg',
    austinhealey: 'austin',
    automobili: 'pininfarina',
    spania: 'spania-gta',
    w: 'w-motors',
    willys: 'willys-overland'
});

const BRAND_LOGO_GITHUB_SLUG_OVERRIDES = Object.freeze({
    cupra: 'cupra',
    amc: 'amc'
});

let createTuneGameVersion = 'fh5';
let activeCreateModelPreset = '';
let isVehicleBrowserInitialized = false;
let vehiclePreviewRequestToken = 0;
let vehiclePreviewLogoRequestToken = 0;
let garageViewPreviewRequestToken = 0;
let powerBandHideTimer = null;
let powerBandCustomRowHideTimer = null;
let tuneCalcHideTimer = null;
let tuneGearingGraphHideTimer = null;
let garageViewHideTimer = null;
let garageDeleteModalHideTimer = null;
let garageDeleteModalResolver = null;
let activeGarageViewRecordId = null;
let createTuneEditRecordId = null;
let activeTuneGearingGraphKey = '';
const tuneCalcGearingGraphCache = new Map();
const vehicleBrandLogoResolvedUrlCache = new Map();
const vehiclePreviewSourceUrlCache = new Map();
const vehiclePreviewSourceRequestCache = new Map();
const vehiclePreviewResolvedUrlCache = new Map();
const vehiclePreviewImageProbeCache = new Map();
const MAX_PREVIEW_CANDIDATES = 8;
let powerBandState = { ...DEFAULT_POWER_BAND_STATE };
let powerBandDraftState = { ...DEFAULT_POWER_BAND_STATE };

const vehicleBrowserState = {
    mode: 'brand',
    selectedBrand: null,
    selectedModel: null,
    filter: '',
    sort: 'name',
    sortDirection: 'asc'
};

function isCreateTuneVehicleListUpdating() {
    return createTuneGameVersion === 'fh6';
}

function saveSettings(showStorageWarning = true) {
    try {
        localStorage.setItem('appSettings', JSON.stringify(settingsState));
        return true;
    } catch (error) {
        const fallbackState = {
            ...settingsState,
            customBackground: null,
            customBackgroundType: null,
            customBackgroundName: null
        };

        try {
            localStorage.setItem('appSettings', JSON.stringify(fallbackState));
        } catch (_) {
            // Ignore secondary storage failure.
        }

        if (showStorageWarning) {
            alert(getSettingsLanguageText('settingsBackgroundTooLargeWarning'));
        }

        return false;
    }
}

function updateBackgroundUploadUI(fileName = null, fileType = null) {
    if (!uploadIcon || !uploadText || !uploadSubtext) {
        return;
    }

    if (!fileName) {
        uploadIcon.textContent = 'perm_media';
        uploadText.textContent = getSettingsLanguageText('backgroundUploadDefaultText');
        uploadText.style.color = '';
        uploadSubtext.textContent = getSettingsLanguageText('backgroundUploadDefaultSubtext');
        return;
    }

    const isVideo = fileType === 'video';
    uploadIcon.textContent = isVideo ? 'movie' : 'image';
    uploadText.textContent = `${getSettingsLanguageText(isVideo ? 'backgroundUploadVideoSelectedPrefix' : 'backgroundUploadImageSelectedPrefix')}: ${fileName}`;
    uploadText.style.color = '#10b981';
    uploadSubtext.textContent = getSettingsLanguageText('backgroundUploadReplaceFileText');
}

function normalizeSearchValue(value) {
    return (value || '').trim().toLowerCase();
}

function normalizeSegmentKey(value) {
    return String(value || '')
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '');
}

function normalizeAppLanguage(value) {
    return String(value || '').trim().toLowerCase() === 'vi' ? 'vi' : 'en';
}

function normalizeThemeMode(value) {
    const normalized = String(value || '').trim().toLowerCase();
    if (normalized === 'dark' || normalized === 'light' || normalized === 'system') {
        return normalized;
    }
    return 'light';
}

function isSystemDarkMode() {
    return Boolean(systemThemeMediaQuery?.matches);
}

function resolveDarkModeFromThemeMode(themeMode = settingsState.themeMode) {
    const normalizedMode = normalizeThemeMode(themeMode);
    if (normalizedMode === 'system') {
        return isSystemDarkMode();
    }
    return normalizedMode === 'dark';
}

function syncThemeControlsUi() {
    const normalizedMode = normalizeThemeMode(settingsState.themeMode);
    if (settingsThemeModeSelect) {
        settingsThemeModeSelect.value = normalizedMode;
    }
}

function applyThemeMode(mode, { persist = false } = {}) {
    const normalizedMode = normalizeThemeMode(mode);
    settingsState.themeMode = normalizedMode;
    settingsState.darkMode = resolveDarkModeFromThemeMode(normalizedMode);
    applyDarkMode(settingsState.darkMode);
    syncThemeControlsUi();
    if (persist) {
        saveSettings(false);
    }
}

function getSettingsLanguageText(key) {
    const normalizedLanguage = normalizeAppLanguage(settingsState.language);
    const languagePack = SETTINGS_LANGUAGE_PACK[normalizedLanguage] || SETTINGS_LANGUAGE_PACK.en;
    if (Object.prototype.hasOwnProperty.call(languagePack, key)) {
        return languagePack[key];
    }
    return SETTINGS_LANGUAGE_PACK.en[key] || '';
}

function formatLocalizedText(key, replacements = {}) {
    const template = String(getSettingsLanguageText(key) || '');
    if (!template) {
        return '';
    }
    return template.replace(/\{([a-zA-Z0-9_]+)\}/g, (match, token) => {
        if (Object.prototype.hasOwnProperty.call(replacements, token)) {
            return String(replacements[token]);
        }
        return match;
    });
}

function resolveLocalizedSegmentLabel(groupId, segmentKey, fallbackLabel = '') {
    const normalizedGroupId = String(groupId || '').trim();
    const normalizedKey = normalizeSegmentKey(segmentKey);

    if (normalizedGroupId === 'create-unit-group') {
        if (normalizedKey === 'metric') {
            return getSettingsLanguageText('createUnitMetricLabel') || fallbackLabel;
        }
        if (normalizedKey === 'imperial') {
            return getSettingsLanguageText('createUnitImperialLabel') || fallbackLabel;
        }
    }

    if (normalizedGroupId === 'create-driving-surface-group') {
        if (normalizedKey === 'street') {
            return getSettingsLanguageText('createSurfaceStreet') || fallbackLabel;
        }
        if (normalizedKey === 'dirt') {
            return getSettingsLanguageText('createSurfaceDirt') || fallbackLabel;
        }
        if (normalizedKey === 'cross') {
            return getSettingsLanguageText('createSurfaceCross') || fallbackLabel;
        }
        if (normalizedKey === 'offroad') {
            return getSettingsLanguageText('createSurfaceOffroad') || fallbackLabel;
        }
    }

    if (normalizedGroupId === 'create-tune-type-group') {
        if (normalizedKey === 'race') {
            return getSettingsLanguageText('createTuneTypeRace') || fallbackLabel;
        }
        if (normalizedKey === 'drift') {
            return getSettingsLanguageText('createTuneTypeDrift') || fallbackLabel;
        }
        if (normalizedKey === 'rain') {
            return getSettingsLanguageText('createTuneTypeRain') || fallbackLabel;
        }
        if (normalizedKey === 'drag') {
            return getSettingsLanguageText('createTuneTypeDrag') || fallbackLabel;
        }
        if (normalizedKey === 'rally') {
            return getSettingsLanguageText('createTuneTypeRally') || fallbackLabel;
        }
        if (normalizedKey === 'truck') {
            return getSettingsLanguageText('createTuneTypeTruck') || fallbackLabel;
        }
        if (normalizedKey === 'buggy') {
            return getSettingsLanguageText('createTuneTypeBuggy') || fallbackLabel;
        }
    }

    return fallbackLabel || segmentKey;
}

function getCapsuleOptionSegmentKey(option, fallback = '') {
    if (!option) {
        return normalizeSegmentKey(fallback);
    }
    const rawKey = option.dataset?.segmentKey || option.textContent || fallback;
    return normalizeSegmentKey(rawKey);
}

function getActiveCapsuleOptionKey(group, fallback = '') {
    if (!group || !group.querySelector) {
        return normalizeSegmentKey(fallback);
    }

    const activeOption = group.querySelector('.capsule-option.is-active');
    return getCapsuleOptionSegmentKey(activeOption, fallback);
}

function localizeCapsuleGroupOptions(group) {
    if (!group || !group.querySelectorAll || !group.id) {
        return;
    }

    group.querySelectorAll('.capsule-option').forEach((option) => {
        const segmentKey = getCapsuleOptionSegmentKey(option, option.textContent || '');
        if (!segmentKey) {
            return;
        }
        option.dataset.segmentKey = segmentKey;
        option.textContent = resolveLocalizedSegmentLabel(group.id, segmentKey, option.textContent?.trim() || segmentKey);
    });
}

function normalizeSurfaceSegmentKey(value) {
    const normalized = normalizeSegmentKey(value);
    if (normalized === 'street' || normalized === 'duongnhua') {
        return 'street';
    }
    if (normalized === 'dirt' || normalized === 'duongdat') {
        return 'dirt';
    }
    if (normalized === 'cross' || normalized === 'honhop') {
        return 'cross';
    }
    if (normalized === 'offroad' || normalized === 'diahinh') {
        return 'offroad';
    }
    return normalized;
}

function normalizeTuneTypeSegmentKey(value) {
    const normalized = normalizeSegmentKey(value);
    if (normalized === 'dua') {
        return 'race';
    }
    if (normalized === 'mua') {
        return 'rain';
    }
    return normalized;
}

function formatSurfaceDisplayLabel(value) {
    const surfaceKey = normalizeSurfaceSegmentKey(value);
    return resolveLocalizedSegmentLabel('create-driving-surface-group', surfaceKey, String(value || '--'));
}

function formatTuneTypeDisplayLabel(value) {
    const tuneTypeKey = normalizeTuneTypeSegmentKey(value);
    return resolveLocalizedSegmentLabel('create-tune-type-group', tuneTypeKey, String(value || '--'));
}

function applySettingsLanguageUi() {
    const setText = (id, value) => {
        const element = document.getElementById(id);
        if (element && typeof value === 'string') {
            element.textContent = value;
        }
    };

    setText('settings-main-title', getSettingsLanguageText('settingsMainTitle'));
    setText('settings-main-subtitle', getSettingsLanguageText('settingsMainSubtitle'));
    setText('settings-app-preferences-title', getSettingsLanguageText('settingsAppPreferencesTitle'));
    setText('settings-language-title', getSettingsLanguageText('settingsLanguageTitle'));
    setText('settings-language-description', getSettingsLanguageText('settingsLanguageDescription'));
    setText('settings-theme-mode-title', getSettingsLanguageText('settingsThemeModeTitle'));
    setText('settings-theme-mode-description', getSettingsLanguageText('settingsThemeModeDescription'));
    setText('settings-autosave-title', getSettingsLanguageText('settingsAutosaveTitle'));
    setText('settings-autosave-description', getSettingsLanguageText('settingsAutosaveDescription'));
    setText('settings-overlay-mode-title', getSettingsLanguageText('settingsOverlayModeTitle'));
    setText('settings-overlay-mode-description', getSettingsLanguageText('settingsOverlayModeDescription'));
    setText('settings-overlay-on-top-title', getSettingsLanguageText('settingsOverlayOnTopTitle'));
    setText('settings-overlay-on-top-description', getSettingsLanguageText('settingsOverlayOnTopDescription'));
    setText('settings-custom-background-title', getSettingsLanguageText('settingsCustomBackgroundTitle'));
    setText('settings-donate-btn-label', getSettingsLanguageText('settingsDonateLabel'));
    setText('settings-feedback-btn-label', getSettingsLanguageText('settingsFeedbackLabel'));

    const resetButton = document.getElementById('btn-reset-settings');
    if (resetButton) {
        resetButton.setAttribute('aria-label', getSettingsLanguageText('settingsResetAriaLabel'));
        resetButton.setAttribute('title', getSettingsLanguageText('settingsResetTitle'));
    }

    if (settingsLanguageSelect) {
        settingsLanguageSelect.setAttribute('aria-label', getSettingsLanguageText('settingsLanguageAriaLabel'));
        const optionEn = settingsLanguageSelect.querySelector('option[value="en"]');
        const optionVi = settingsLanguageSelect.querySelector('option[value="vi"]');
        if (optionEn) {
            optionEn.textContent = getSettingsLanguageText('settingsLanguageOptionEn');
        }
        if (optionVi) {
            optionVi.textContent = getSettingsLanguageText('settingsLanguageOptionVi');
        }
    }

    if (settingsThemeModeSelect) {
        settingsThemeModeSelect.setAttribute('aria-label', getSettingsLanguageText('settingsThemeModeAriaLabel'));
        const optionLight = settingsThemeModeSelect.querySelector('option[value="light"]');
        const optionDark = settingsThemeModeSelect.querySelector('option[value="dark"]');
        const optionSystem = settingsThemeModeSelect.querySelector('option[value="system"]');
        if (optionLight) {
            optionLight.textContent = getSettingsLanguageText('settingsThemeModeOptionLight');
        }
        if (optionDark) {
            optionDark.textContent = getSettingsLanguageText('settingsThemeModeOptionDark');
        }
        if (optionSystem) {
            optionSystem.textContent = getSettingsLanguageText('settingsThemeModeOptionSystem');
        }
    }

    setText('dashboard-hero-subtitle', getSettingsLanguageText('dashboardHeroSubtitle'));
    setText('dashboard-card-create-title', getSettingsLanguageText('dashboardCardCreateTitle'));
    setText('dashboard-card-create-subtitle', getSettingsLanguageText('dashboardCardCreateSubtitle'));
    setText('dashboard-card-garage-title', getSettingsLanguageText('dashboardCardGarageTitle'));
    setText('dashboard-card-garage-subtitle', getSettingsLanguageText('dashboardCardGarageSubtitle'));
    setText('dashboard-card-settings-title', getSettingsLanguageText('dashboardCardSettingsTitle'));
    setText('dashboard-card-settings-subtitle', getSettingsLanguageText('dashboardCardSettingsSubtitle'));

    if (createTuneHeaderTitle) {
        createTuneHeaderTitle.textContent = isCreateTuneEditMode()
            ? getSettingsLanguageText('createMainTitleEdit')
            : getSettingsLanguageText('createMainTitle');
    }

    setText('create-section-vehicle-title-text', getSettingsLanguageText('createSectionVehicleTitle'));
    setText('create-section-model-info-title', getSettingsLanguageText('createSectionModelInfoTitle'));
    setText('create-section-performance-title', getSettingsLanguageText('createSectionPerformanceTitle'));
    setText('create-section-advanced-title', getSettingsLanguageText('createSectionAdvancedTitle'));
    setText('create-section-config-title', getSettingsLanguageText('createSectionConfigTitle'));
    setText('create-section-environment-title', getSettingsLanguageText('createSectionEnvironmentTitle'));
    setText('create-front-distribution-label', getSettingsLanguageText('createFrontDistributionLabel'));
    setText('create-current-pi-label', getSettingsLanguageText('createCurrentPiLabel'));
    setText('create-drive-type-label', getSettingsLanguageText('createDriveTypeLabel'));
    setText('create-game-version-label', getSettingsLanguageText('createGameVersionLabel'));
    setText('create-power-band-label', getSettingsLanguageText('createPowerBandLabel'));
    setText('create-gears-label', getSettingsLanguageText('createGearsLabel'));
    setText('create-tire-size-label', getSettingsLanguageText('createTireSizeLabel'));
    setText('create-tune-type-label', getSettingsLanguageText('createTuneTypeLabel'));
    setText('create-verify-text', getSettingsLanguageText('createVerifyText'));
    setText('create-calc-btn-text', getSettingsLanguageText('createCalculationButton'));
    setText('create-model-preset-label', getSettingsLanguageText('createModelPresetLabel'));
    setText('create-model-preset-max-grip', getSettingsLanguageText('createModelPresetMaxGrip'));
    setText('create-model-preset-oversteer', getSettingsLanguageText('createModelPresetOversteer'));
    setText('create-model-preset-understeer', getSettingsLanguageText('createModelPresetUndersteer'));
    setText('create-model-preset-comfort', getSettingsLanguageText('createModelPresetComfort'));
    if (createModelPresetBar) {
        const presetAria = String(getSettingsLanguageText('createModelPresetLabel') || 'Presets')
            .replace(/:\s*$/, '')
            .trim();
        createModelPresetBar.setAttribute('aria-label', presetAria);
    }

    if (createFrontDistributionInput) {
        createFrontDistributionInput.placeholder = getSettingsLanguageText('createFrontDistributionPlaceholder');
    }
    if (createCurrentPiInput) {
        createCurrentPiInput.placeholder = getSettingsLanguageText('createCurrentPiPlaceholder');
    }
    if (createPowerBandDisplay && (!createPowerBandValue || !createPowerBandValue.value.trim())) {
        createPowerBandDisplay.textContent = getSettingsLanguageText('createPowerBandDisplayDefault');
    }
    if (createUnitGroup) {
        createUnitGroup.setAttribute('aria-label', getSettingsLanguageText('createUnitSystemAria'));
    }
    if (createTireWidthInput) {
        createTireWidthInput.placeholder = getSettingsLanguageText('createTireWidthPlaceholder');
    }
    if (createTireAspectInput) {
        createTireAspectInput.placeholder = getSettingsLanguageText('createTireAspectPlaceholder');
    }
    if (createTireRimInput) {
        createTireRimInput.placeholder = getSettingsLanguageText('createTireRimPlaceholder');
    }
    if (vehicleFilterInput) {
        vehicleFilterInput.placeholder = getSettingsLanguageText('createVehicleFilterPlaceholder');
    }
    if (vehiclePreviewImage) {
        vehiclePreviewImage.alt = getSettingsLanguageText('vehiclePreviewAlt');
    }
    if (vehicleModelBack) {
        const backLabel = getSettingsLanguageText('createVehicleBackAria');
        vehicleModelBack.setAttribute('aria-label', backLabel);
        vehicleModelBack.setAttribute('title', backLabel);
    }
    if (vehicleSortMenu) {
        vehicleSortMenu.setAttribute('aria-label', getSettingsLanguageText('createVehicleSortMenuAria'));
    }
    localizeCapsuleGroupOptions(createUnitGroup);
    localizeCapsuleGroupOptions(createDriveTypeGroup);
    localizeCapsuleGroupOptions(createDrivingSurfaceGroup);
    localizeCapsuleGroupOptions(createTuneTypeGroup);
    syncTuneTypeOptionsByDrivingSurface(getActiveCapsuleOptionKey(createDrivingSurfaceGroup, 'street'), { animate: false });

    if (!vehicleBrowserState.selectedModel && !isCreateTuneVehicleListUpdating()) {
        setVehiclePreviewPlaceholderState(getSettingsLanguageText('createVehiclePreviewPlaceholder'));
    }

    setText('garage-main-title', getSettingsLanguageText('garageMainTitle'));
    setText('garage-rows-label', getSettingsLanguageText('garageRowsLabel'));
    setText('garage-import-label', getSettingsLanguageText('garageImportLabel'));
    setText('garage-export-label', getSettingsLanguageText('garageExportLabel'));
    setText('garage-select-all-label', getSettingsLanguageText('garageSelectAllLabel'));
    setText('garage-delete-selected-label', getSettingsLanguageText('garageDeleteMarkedLabel'));
    setText('garage-empty', getSettingsLanguageText('garageEmpty'));
    if (garagePageSizeSelect) {
        garagePageSizeSelect.setAttribute('aria-label', getSettingsLanguageText('garageRowsAria'));
    }

    setText('power-band-modal-title', getSettingsLanguageText('powerBandModalTitle'));
    setText('power-band-redline-title', getSettingsLanguageText('powerBandRedlineTitle'));
    setText('power-band-max-torque-title', getSettingsLanguageText('powerBandMaxTorqueTitle'));
    setText('power-band-scale-title', getSettingsLanguageText('powerBandScaleTitle'));
    setText('power-band-custom-label', getSettingsLanguageText('powerBandCustomLabel'));
    setText('power-band-graph-title', getSettingsLanguageText('powerBandGraphTitle'));
    setText('power-band-legend-torque', getSettingsLanguageText('powerBandLegendTorque'));
    setText('power-band-legend-power', getSettingsLanguageText('powerBandLegendPower'));
    setText('power-band-cancel-btn', getSettingsLanguageText('powerBandCancel'));
    setText('power-band-apply-btn', getSettingsLanguageText('powerBandApply'));
    if (powerBandModalCloseBtn) {
        powerBandModalCloseBtn.setAttribute('aria-label', getSettingsLanguageText('powerBandCloseAria'));
    }

    setText('tune-calc-modal-title', getSettingsLanguageText('tuneResultsTitle'));
    setText('tune-calc-subtitle', getSettingsLanguageText('tuneResultsSubtitle'));
    if (tuneCalcModalCloseBtn) {
        tuneCalcModalCloseBtn.setAttribute('aria-label', getSettingsLanguageText('tuneResultsCloseAria'));
    }
    setText('tune-gearing-graph-title', getSettingsLanguageText('tuneResultsGearingModalTitle'));
    setText('tune-gearing-graph-y-label', getSettingsLanguageText('tuneResultsGearingRpmAxisLabel'));
    if (tuneGearingGraphCloseBtn) {
        tuneGearingGraphCloseBtn.setAttribute('aria-label', getSettingsLanguageText('tuneResultsGearingCloseAria'));
        tuneGearingGraphCloseBtn.setAttribute('title', getSettingsLanguageText('tuneResultsGearingCloseAria'));
    }
    syncTuneCalcLayoutUi();
    syncTuneCalcOverlayButtonUi();
    if (tuneCalcList) {
        const graphTitle = getSettingsLanguageText('tuneResultsGearingChartTitle');
        tuneCalcList.querySelectorAll('[data-gearing-graph-key]').forEach((button) => {
            button.setAttribute('title', graphTitle);
            button.setAttribute('aria-label', graphTitle);
        });
    }
    if (activeTuneGearingGraphKey) {
        const activeGraph = tuneCalcGearingGraphCache.get(activeTuneGearingGraphKey);
        if (activeGraph) {
            renderTuneGearingGraphModal(activeGraph);
        }
    }
    if (tuneSaveNameInput) {
        tuneSaveNameInput.placeholder = getSettingsLanguageText('tuneSaveNamePlaceholder');
    }
    if (tuneSaveShareInput) {
        tuneSaveShareInput.placeholder = getSettingsLanguageText('tuneSaveSharePlaceholder');
    }
    setText('tune-calc-save-btn', getSettingsLanguageText('tuneSaveButton'));

    setText('garage-view-modal-title', getSettingsLanguageText('tuneDetailsTitle'));
    setText('garage-view-subtitle', getSettingsLanguageText('tuneDetailsSubtitle'));
    setText('garage-view-meta-speed-label', getSettingsLanguageText('tuneMetaTopSpeed'));
    setText('garage-view-meta-weight-label', getSettingsLanguageText('tuneMetaWeight'));
    setText('garage-view-meta-drive-label', getSettingsLanguageText('tuneMetaDrive'));
    setText('garage-view-meta-share-label', getSettingsLanguageText('tuneMetaShareCode'));
    setText('garage-view-meta-rpm-label', getSettingsLanguageText('tuneMetaRpm'));
    if (garageViewCloseBtn) {
        garageViewCloseBtn.setAttribute('aria-label', getSettingsLanguageText('tuneDetailsCloseAria'));
    }
    if (garageViewPreviewImage) {
        garageViewPreviewImage.alt = getSettingsLanguageText('vehiclePreviewAlt');
    }

    setText('donate-modal-title', getSettingsLanguageText('donateTitle'));
    setText('donate-modal-subtitle', getSettingsLanguageText('donateSubtitle'));
    if (btnDonateClose) {
        btnDonateClose.setAttribute('aria-label', getSettingsLanguageText('donateCloseAria'));
    }

    setText('update-log-modal-title', getSettingsLanguageText('updateLogTitle'));
    setText('update-log-modal-subtitle', getSettingsLanguageText('updateLogSubtitle'));
    setText('update-log-version', `${getSettingsLanguageText('updateLogVersionLabel')}: ${APP_BUILD_VERSION}`);
    setText('update-log-item-main-ui', getSettingsLanguageText('updateLogItemMainUi'));
    setText('update-log-item-text-fix', getSettingsLanguageText('updateLogItemTextFix'));
    setText('update-log-item-ui-optimize', getSettingsLanguageText('updateLogItemUiOptimize'));
    setText('btn-update-log-done', getSettingsLanguageText('updateLogCloseButton'));
    if (btnUpdateLogClose) {
        btnUpdateLogClose.setAttribute('aria-label', getSettingsLanguageText('updateLogCloseAria'));
    }

    setText('feedback-modal-title', getSettingsLanguageText('feedbackTitle'));
    setText('feedback-modal-subtitle', getSettingsLanguageText('feedbackSubtitle'));
    if (btnFeedbackClose) {
        btnFeedbackClose.setAttribute('aria-label', getSettingsLanguageText('feedbackCloseAria'));
    }
    if (feedbackTitleInput) {
        feedbackTitleInput.placeholder = getSettingsLanguageText('feedbackTitlePlaceholder');
    }
    if (feedbackNameInput) {
        feedbackNameInput.placeholder = getSettingsLanguageText('feedbackNamePlaceholder');
    }
    if (feedbackEmailInput) {
        feedbackEmailInput.placeholder = getSettingsLanguageText('feedbackEmailPlaceholder');
    }
    if (feedbackMessageInput) {
        feedbackMessageInput.placeholder = getSettingsLanguageText('feedbackMessagePlaceholder');
    }
    if (btnFeedbackCancel) {
        btnFeedbackCancel.textContent = getSettingsLanguageText('feedbackCancelButton');
    }
    setText('feedback-send-label', getSettingsLanguageText('feedbackSendButton'));

    setText('garage-delete-modal-title', getSettingsLanguageText('garageDeleteModalTitle'));
    setText('btn-garage-delete-no', getSettingsLanguageText('garageDeleteNo'));
    setText('btn-garage-delete-yes', getSettingsLanguageText('garageDeleteYes'));

    setText('welcome-title', getSettingsLanguageText('welcomeTitle'));
    setText('welcome-subtitle', getSettingsLanguageText('welcomeSubtitle'));
    setText('welcome-setup-title', getSettingsLanguageText('welcomeSetupTitle'));
    setText('welcome-setup-language-label', getSettingsLanguageText('welcomeSetupLanguageLabel'));
    setText('welcome-setup-unit-label', getSettingsLanguageText('welcomeSetupUnitLabel'));
    setText('welcome-setup-theme-label', getSettingsLanguageText('welcomeSetupThemeLabel'));
    setText('welcome-slide-title-create', getSettingsLanguageText('welcomeSlideCreateTitle'));
    setText('welcome-slide-text-create', getSettingsLanguageText('welcomeSlideCreateText'));
    setText('welcome-slide-title-calc', getSettingsLanguageText('welcomeSlideCalcTitle'));
    setText('welcome-slide-text-calc', getSettingsLanguageText('welcomeSlideCalcText'));
    setText('welcome-slide-title-garage', getSettingsLanguageText('welcomeSlideGarageTitle'));
    setText('welcome-slide-text-garage', getSettingsLanguageText('welcomeSlideGarageText'));
    setText('welcome-slide-title-overlay', getSettingsLanguageText('welcomeSlideOverlayTitle'));
    setText('welcome-slide-text-overlay', getSettingsLanguageText('welcomeSlideOverlayText'));
    setText('welcome-check-text', getSettingsLanguageText('welcomeCheckText'));
    setText('welcome-close-label', getSettingsLanguageText('welcomeCloseLabel'));
    if (welcomeNextBtn) {
        welcomeNextBtn.setAttribute('aria-label', getSettingsLanguageText('welcomeNextAria'));
    }
    if (welcomeSlideCreateImage) {
        welcomeSlideCreateImage.alt = getSettingsLanguageText('welcomeSlideCreateTitle');
    }
    if (welcomeSlideCalcImage) {
        welcomeSlideCalcImage.alt = getSettingsLanguageText('welcomeSlideCalcTitle');
    }
    if (welcomeSlideGarageImage) {
        welcomeSlideGarageImage.alt = getSettingsLanguageText('welcomeSlideGarageTitle');
    }
    if (welcomeSlideOverlayImage) {
        welcomeSlideOverlayImage.alt = getSettingsLanguageText('welcomeSlideOverlayTitle');
    }
    if (welcomeSetupLanguageGroup) {
        welcomeSetupLanguageGroup.setAttribute('aria-label', getSettingsLanguageText('welcomeSetupLanguageLabel'));
        const enOption = welcomeSetupLanguageGroup.querySelector('[data-welcome-language="en"]');
        const viOption = welcomeSetupLanguageGroup.querySelector('[data-welcome-language="vi"]');
        if (enOption) {
            enOption.textContent = getSettingsLanguageText('settingsLanguageOptionEn');
        }
        if (viOption) {
            viOption.textContent = getSettingsLanguageText('settingsLanguageOptionVi');
        }
    }
    if (welcomeSetupUnitGroup) {
        welcomeSetupUnitGroup.setAttribute('aria-label', getSettingsLanguageText('welcomeSetupUnitLabel'));
        const metricOption = welcomeSetupUnitGroup.querySelector('[data-welcome-unit="metric"]');
        const imperialOption = welcomeSetupUnitGroup.querySelector('[data-welcome-unit="imperial"]');
        if (metricOption) {
            metricOption.textContent = getSettingsLanguageText('createUnitMetricLabel');
        }
        if (imperialOption) {
            imperialOption.textContent = getSettingsLanguageText('createUnitImperialLabel');
        }
    }
    if (welcomeSetupThemeGroup) {
        welcomeSetupThemeGroup.setAttribute('aria-label', getSettingsLanguageText('welcomeSetupThemeLabel'));
        const lightOption = welcomeSetupThemeGroup.querySelector('[data-welcome-theme="light"]');
        const darkOption = welcomeSetupThemeGroup.querySelector('[data-welcome-theme="dark"]');
        if (lightOption) {
            lightOption.textContent = getSettingsLanguageText('welcomeThemeLightLabel');
        }
        if (darkOption) {
            darkOption.textContent = getSettingsLanguageText('welcomeThemeDarkLabel');
        }
    }
    syncWelcomeSetupSelectionUi();

    setText('footer-online-label', getSettingsLanguageText('footerOnline'));
    setText('footer-build-version', APP_BUILD_VERSION);
    if (tuneOverlayClose) {
        tuneOverlayClose.setAttribute('aria-label', getSettingsLanguageText('overlayCloseTitle'));
    }

    syncCreateTuneUnitUi(settingsState.unitSystem);
    if (vehicleBrowserState.selectedBrand && vehicleBrowserState.selectedModel && !isCreateTuneVehicleListUpdating()) {
        const selectedSpecs = getVehicleSpecs(vehicleBrowserState.selectedBrand, vehicleBrowserState.selectedModel);
        updateVehiclePreviewSpecs(selectedSpecs);
        refreshSelectedVehicleModelInfo();
    }
    updateVehicleSortUi();
    updateGarageDeleteSelectedButton();
    renderGarageList();
    renderTuneOverlay();
    syncWelcomeModalUi();
    updateBackgroundUploadUI(settingsState.customBackgroundName, settingsState.customBackgroundType);
}

function normalizeUnitSystem(value) {
    return value === 'imperial' ? 'imperial' : 'metric';
}

function kgToLb(value) {
    return Number(value) * 2.2046226218;
}

function lbToKg(value) {
    return Number(value) / 2.2046226218;
}

function kmhToMph(value) {
    return Number(value) * 0.6213711922;
}

function mphToKmh(value) {
    return Number(value) / 0.6213711922;
}

function nmToLbFt(value) {
    return Number(value) * 0.7375621493;
}

function lbFtToNm(value) {
    return Number(value) / 0.7375621493;
}

function barToPsi(value) {
    return Number(value) * 14.503773773;
}

function psiToBar(value) {
    return Number(value) / 14.503773773;
}

function nmmToLbin(value) {
    return Number(value) * 5.7101471628;
}

function lbinToNmm(value) {
    return Number(value) / 5.7101471628;
}

function mmToIn(value) {
    return Number(value) * 0.0393700787;
}

function inToMm(value) {
    return Number(value) / 0.0393700787;
}

function convertMetricToDisplay(value, kind, unitSystem = settingsState.unitSystem) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return numeric;
    }

    const normalizedUnit = normalizeUnitSystem(unitSystem);
    if (normalizedUnit !== 'imperial') {
        return numeric;
    }

    if (kind === 'weight') {
        return kgToLb(numeric);
    }
    if (kind === 'speed') {
        return kmhToMph(numeric);
    }
    if (kind === 'torque') {
        return nmToLbFt(numeric);
    }
    if (kind === 'pressure') {
        return barToPsi(numeric);
    }
    if (kind === 'spring') {
        return nmmToLbin(numeric);
    }
    if (kind === 'rideHeight') {
        return mmToIn(numeric);
    }
    return numeric;
}

function convertDisplayToMetric(value, kind, unitSystem = settingsState.unitSystem) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return numeric;
    }

    const normalizedUnit = normalizeUnitSystem(unitSystem);
    if (normalizedUnit !== 'imperial') {
        return numeric;
    }

    if (kind === 'weight') {
        return lbToKg(numeric);
    }
    if (kind === 'speed') {
        return mphToKmh(numeric);
    }
    if (kind === 'torque') {
        return lbFtToNm(numeric);
    }
    if (kind === 'pressure') {
        return psiToBar(numeric);
    }
    if (kind === 'spring') {
        return lbinToNmm(numeric);
    }
    if (kind === 'rideHeight') {
        return inToMm(numeric);
    }
    return numeric;
}

function formatDisplayValue(value, decimals = 1) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return '--';
    }
    return numeric
        .toFixed(Math.max(0, Number(decimals) || 0))
        .replace(/\.0+$/, '')
        .replace(/(\.\d*[1-9])0+$/, '$1');
}

function getTuneSurfaceKeyFromLabel(label) {
    const normalizedLabel = normalizeSurfaceSegmentKey(label);
    if (normalizedLabel === 'dirt') {
        return 'dirt';
    }
    if (normalizedLabel === 'offroad' || normalizedLabel === 'cross') {
        return 'offroad';
    }
    return 'race';
}

function syncTuneTypeOptionsByDrivingSurface(surfaceLabel, { animate = true } = {}) {
    if (!createTuneTypeGroup) {
        return;
    }

    const surfaceKey = getTuneSurfaceKeyFromLabel(surfaceLabel);
    const tuneOptions = TUNE_TYPE_OPTIONS_BY_SURFACE[surfaceKey] || TUNE_TYPE_OPTIONS_BY_SURFACE.race;
    const currentActiveKey = getActiveCapsuleOptionKey(createTuneTypeGroup, tuneOptions[0] || 'race');
    const selectedOption = tuneOptions.find((option) => normalizeSegmentKey(option) === currentActiveKey)
        || tuneOptions[0];

    const currentSignature = Array.from(createTuneTypeGroup.querySelectorAll('.capsule-option'))
        .map((option) => getCapsuleOptionSegmentKey(option, option.textContent))
        .join('|');
    const nextSignature = tuneOptions.map((option) => normalizeSegmentKey(option)).join('|');

    if (currentSignature !== nextSignature) {
        createTuneTypeGroup.innerHTML = tuneOptions
            .map((option) => {
                const isActive = normalizeSegmentKey(option) === normalizeSegmentKey(selectedOption);
                const optionKey = normalizeSegmentKey(option);
                const localizedLabel = resolveLocalizedSegmentLabel(
                    'create-tune-type-group',
                    optionKey,
                    option
                );
                return `<button class="capsule-option${isActive ? ' is-active' : ''} no-drag" type="button" data-segment-key="${escapeHtml(optionKey)}">${escapeHtml(localizedLabel)}</button>`;
            })
            .join('');
    } else {
        createTuneTypeGroup.querySelectorAll('.capsule-option').forEach((option) => {
            const optionKey = getCapsuleOptionSegmentKey(option, option.textContent);
            const isActive = optionKey === normalizeSegmentKey(selectedOption);
            option.classList.toggle('is-active', isActive);
            option.dataset.segmentKey = optionKey;
            option.textContent = resolveLocalizedSegmentLabel('create-tune-type-group', optionKey, option.textContent?.trim() || optionKey);
        });
    }

    createTuneTypeGroup.classList.remove('has-active-indicator');
    updateCapsuleGroupIndicator(createTuneTypeGroup, animate);
}

function clampNumber(value, min, max) {
    if (!Number.isFinite(value)) {
        return min;
    }
    return Math.min(max, Math.max(min, value));
}

function roundToStep(value, step = 50) {
    return Math.round(value / step) * step;
}

function toCustomScaleValue(value) {
    return clampNumber(
        roundToStep(Number(value), POWER_BAND_CUSTOM_SCALE_STEP),
        POWER_BAND_CUSTOM_SCALE_MIN,
        POWER_BAND_CUSTOM_SCALE_MAX
    );
}

function normalizePowerBandState(state) {
    const requestedScale = Number(state?.scaleMax);
    const requestedCustomScale = Number(state?.customScaleMax);
    const customScaleMax = toCustomScaleValue(
        Number.isFinite(requestedCustomScale) ? requestedCustomScale : POWER_BAND_CUSTOM_DEFAULT_SCALE
    );
    const requestedIsCustom = state?.isCustomScale === true || state?.isCustomScale === 'true';
    const presetScale = POWER_BAND_PRESET_SCALE_OPTIONS.includes(requestedScale)
        ? requestedScale
        : DEFAULT_POWER_BAND_STATE.scaleMax;
    const scaleMax = requestedIsCustom ? customScaleMax : presetScale;
    const torqueMin = 0;
    const redlineRpm = clampNumber(roundToStep(Number(state?.redlineRpm)), 0, scaleMax);
    const maxTorqueRpm = clampNumber(roundToStep(Number(state?.maxTorqueRpm)), torqueMin, redlineRpm);

    return {
        scaleMax,
        redlineRpm,
        maxTorqueRpm,
        isCustomScale: requestedIsCustom,
        customScaleMax
    };
}

function formatPowerBandRpm(value) {
    return String(Math.round(Number(value) || 0));
}

function formatPowerBandSummary(state) {
    return `${formatPowerBandRpm(state.maxTorqueRpm)} - ${formatPowerBandRpm(state.redlineRpm)} RPM`;
}

function formatScaleChipLabel(scaleMax) {
    const asThousands = scaleMax / 1000;
    const hasFraction = Math.abs(asThousands - Math.round(asThousands)) > 0.001;
    return hasFraction ? `${asThousands.toFixed(1)}K` : `${Math.round(asThousands)}K`;
}

function easeOutCubic(value) {
    const t = clampNumber(Number(value), 0, 1);
    return 1 - Math.pow(1 - t, 3);
}

function easeInOutSine(value) {
    const t = clampNumber(Number(value), 0, 1);
    return -(Math.cos(Math.PI * t) - 1) / 2;
}

function formatChartRpmTickLabel(value) {
    const thousands = Number(value) / 1000;
    const rounded = Math.round(thousands * 10) / 10;
    return Number.isInteger(rounded) ? String(Math.trunc(rounded)) : String(rounded.toFixed(1));
}

function buildPowerBandChartPath(points, scaleMax, yMax) {
    if (!Array.isArray(points) || points.length === 0 || !Number.isFinite(scaleMax) || scaleMax <= 0 || !Number.isFinite(yMax) || yMax <= 0) {
        return '';
    }

    const chartWidth = 100;
    const chartHeight = 56;
    return points
        .map((point, index) => {
            const x = clampNumber((point.rpm / scaleMax) * chartWidth, 0, chartWidth);
            const y = clampNumber(chartHeight - ((point.value || 0) / yMax) * chartHeight, 0, chartHeight);
            return `${index === 0 ? 'M' : 'L'} ${x.toFixed(2)} ${y.toFixed(2)}`;
        })
        .join(' ');
}

function buildPowerBandPerformanceCurves(state) {
    const normalizedState = normalizePowerBandState(state);
    const scaleMax = Math.max(1, normalizedState.scaleMax);
    const redlineRpm = clampNumber(normalizedState.redlineRpm, 0, scaleMax);
    const requestedTorquePeakRpm = clampNumber(normalizedState.maxTorqueRpm, 0, redlineRpm);
    const fallbackTorquePeakRpm = redlineRpm * 0.48;
    const torquePeakRpm = requestedTorquePeakRpm > 0 ? requestedTorquePeakRpm : fallbackTorquePeakRpm;
    const sampleCount = 120;
    const torquePoints = [];
    const powerPoints = [];

    const scaleFactor = clampNumber((scaleMax - 8000) / 12000, 0, 1);
    const peakTorqueNm = 520 + 120 * scaleFactor;
    const baseTorqueNm = peakTorqueNm * 0.56;
    const endTorqueNm = peakTorqueNm * 0.75;

    for (let index = 0; index <= sampleCount; index += 1) {
        const rpm = redlineRpm <= 0 ? 0 : (redlineRpm * index) / sampleCount;

        let torqueNm;
        if (rpm <= torquePeakRpm) {
            const riseProgress = torquePeakRpm <= 0 ? 1 : clampNumber(rpm / torquePeakRpm, 0, 1);
            torqueNm = baseTorqueNm + (peakTorqueNm - baseTorqueNm) * easeOutCubic(riseProgress);
        } else {
            const fallProgress = clampNumber((rpm - torquePeakRpm) / Math.max(redlineRpm - torquePeakRpm, 1), 0, 1);
            torqueNm = peakTorqueNm - (peakTorqueNm - endTorqueNm) * easeInOutSine(fallProgress);
        }

        const idleRamp = clampNumber(rpm / 900, 0, 1);
        torqueNm *= 0.38 + 0.62 * idleRamp;
        torqueNm = Math.max(0, torqueNm);

        // Power follows the physical relation: power ~ torque * rpm
        const powerHp = (torqueNm * rpm) / 7127;

        torquePoints.push({ rpm, value: torqueNm });
        powerPoints.push({ rpm, value: powerHp });
    }

    const maxSeriesValue = Math.max(
        ...torquePoints.map((point) => point.value),
        ...powerPoints.map((point) => point.value),
        100
    );
    const yAxisMax = Math.max(100, Math.ceil(maxSeriesValue / 100) * 100);
    const yAxisMid = Math.round(yAxisMax / 2);

    return {
        scaleMax,
        yAxisMax,
        yAxisMid,
        torquePath: buildPowerBandChartPath(torquePoints, scaleMax, yAxisMax),
        powerPath: buildPowerBandChartPath(powerPoints, scaleMax, yAxisMax)
    };
}

function renderPowerBandChart(state) {
    if (!powerBandChartTorquePath || !powerBandChartPowerPath) {
        return;
    }

    const chartCurves = buildPowerBandPerformanceCurves(state);
    powerBandChartTorquePath.setAttribute('d', chartCurves.torquePath);
    powerBandChartPowerPath.setAttribute('d', chartCurves.powerPath);

    if (powerBandChartYMax) {
        powerBandChartYMax.textContent = String(chartCurves.yAxisMax);
    }
    if (powerBandChartYMid) {
        powerBandChartYMid.textContent = String(chartCurves.yAxisMid);
    }
    if (powerBandChartYMin) {
        powerBandChartYMin.textContent = '0';
    }
    if (powerBandChartXMid) {
        powerBandChartXMid.textContent = formatChartRpmTickLabel(chartCurves.scaleMax / 2);
    }
    if (powerBandChartXMax) {
        powerBandChartXMax.textContent = formatChartRpmTickLabel(chartCurves.scaleMax);
    }
}

function updatePowerBandSliderProgress(slider) {
    if (!slider) {
        return;
    }

    const min = Number(slider.min) || 0;
    const max = Number(slider.max) || 100;
    const value = Number(slider.value) || min;
    const range = max - min;
    const progress = range <= 0 ? 100 : ((value - min) / range) * 100;
    slider.style.setProperty('--range-progress', `${clampNumber(progress, 0, 100)}%`);
}

function syncPowerBandScaleOptionsUi(scaleMax, isCustomScale) {
    if (!powerBandScaleGrid) {
        return;
    }

    powerBandScaleGrid.querySelectorAll('[data-rpm-scale]').forEach((option) => {
        const optionScale = option.dataset.rpmScale;
        if (optionScale === 'custom') {
            option.classList.toggle('is-active', Boolean(isCustomScale));
            return;
        }

        const numericScale = Number(optionScale);
        option.classList.toggle('is-active', !isCustomScale && numericScale === scaleMax);
    });
}

function setPowerBandCustomRowVisibility(isVisible) {
    if (!powerBandCustomScaleRow) {
        return;
    }

    if (powerBandCustomRowHideTimer) {
        clearTimeout(powerBandCustomRowHideTimer);
        powerBandCustomRowHideTimer = null;
    }

    if (isVisible) {
        powerBandCustomScaleRow.classList.remove('hidden');
        powerBandCustomScaleRow.setAttribute('aria-hidden', 'false');

        if (powerBandCustomScaleRow.classList.contains('is-open')) {
            return;
        }

        requestAnimationFrame(() => {
            if (!powerBandCustomScaleRow || powerBandCustomScaleRow.classList.contains('hidden')) {
                return;
            }
            powerBandCustomScaleRow.classList.add('is-open');
        });
        return;
    }

    if (powerBandCustomScaleRow.classList.contains('is-open')) {
        powerBandCustomScaleRow.classList.remove('is-open');
    }
    powerBandCustomScaleRow.setAttribute('aria-hidden', 'true');

    powerBandCustomRowHideTimer = setTimeout(() => {
        if (!powerBandCustomScaleRow || powerBandCustomScaleRow.classList.contains('is-open')) {
            return;
        }
        powerBandCustomScaleRow.classList.add('hidden');
        powerBandCustomRowHideTimer = null;
    }, 220);
}

function syncPowerBandModalUi() {
    if (!powerBandModal) {
        return;
    }

    powerBandDraftState = normalizePowerBandState(powerBandDraftState);

    const scaleMax = powerBandDraftState.scaleMax;
    const isCustomScale = Boolean(powerBandDraftState.isCustomScale);
    const halfScale = Math.round(scaleMax / 2);

    if (powerBandScaleValue) {
        powerBandScaleValue.textContent = formatScaleChipLabel(scaleMax);
    }
    syncPowerBandScaleOptionsUi(scaleMax, isCustomScale);

    setPowerBandCustomRowVisibility(isCustomScale);
    if (powerBandCustomScaleInput) {
        powerBandCustomScaleInput.value = formatPowerBandRpm(powerBandDraftState.customScaleMax);
    }

    if (powerBandRedlineSlider) {
        powerBandRedlineSlider.min = '0';
        powerBandRedlineSlider.max = String(scaleMax);
        powerBandRedlineSlider.value = String(powerBandDraftState.redlineRpm);
        updatePowerBandSliderProgress(powerBandRedlineSlider);
    }

    if (powerBandTorqueSlider) {
        powerBandTorqueSlider.min = '0';
        powerBandTorqueSlider.max = String(scaleMax);
        powerBandTorqueSlider.value = String(powerBandDraftState.maxTorqueRpm);
        updatePowerBandSliderProgress(powerBandTorqueSlider);
    }

    if (powerBandRedlineValue) {
        powerBandRedlineValue.textContent = formatPowerBandRpm(powerBandDraftState.redlineRpm);
    }
    if (powerBandTorqueValue) {
        powerBandTorqueValue.textContent = formatPowerBandRpm(powerBandDraftState.maxTorqueRpm);
    }
    if (powerBandRedlineMid) {
        powerBandRedlineMid.textContent = formatPowerBandRpm(halfScale);
    }
    if (powerBandRedlineMax) {
        powerBandRedlineMax.textContent = formatPowerBandRpm(scaleMax);
    }
    if (powerBandTorqueMid) {
        powerBandTorqueMid.textContent = formatPowerBandRpm(halfScale);
    }
    if (powerBandTorqueMax) {
        powerBandTorqueMax.textContent = formatPowerBandRpm(scaleMax);
    }

    renderPowerBandChart(powerBandDraftState);
}

function syncPowerBandFieldsFromState() {
    powerBandState = normalizePowerBandState(powerBandState);
    const summary = formatPowerBandSummary(powerBandState);

    if (createPowerBandDisplay) {
        createPowerBandDisplay.textContent = summary;
    }
    if (createPowerBandValue) {
        createPowerBandValue.value = summary;
    }
    if (createPowerBandTrigger) {
        createPowerBandTrigger.title = 'Configure Power Band';
    }
}

function applyPowerBandScaleChange(nextScale, { isCustomScale = false } = {}) {
    const currentScale = powerBandDraftState.scaleMax || DEFAULT_POWER_BAND_STATE.scaleMax;
    const redlineRatio = clampNumber(powerBandDraftState.redlineRpm / currentScale, 0, 1);
    const torqueRatio = clampNumber(powerBandDraftState.maxTorqueRpm / currentScale, 0, 0.95);
    const resolvedScale = isCustomScale ? toCustomScaleValue(nextScale) : nextScale;

    powerBandDraftState = {
        ...powerBandDraftState,
        isCustomScale: Boolean(isCustomScale),
        customScaleMax: isCustomScale ? resolvedScale : powerBandDraftState.customScaleMax,
        scaleMax: resolvedScale,
        redlineRpm: roundToStep(resolvedScale * redlineRatio),
        maxTorqueRpm: roundToStep(resolvedScale * torqueRatio)
    };

    syncPowerBandModalUi();
}

function isPowerBandModalOpen() {
    return Boolean(powerBandModal && !powerBandModal.classList.contains('hidden') && powerBandModal.classList.contains('is-open'));
}

function openPowerBandModal() {
    if (!powerBandModal) {
        return;
    }

    if (powerBandHideTimer) {
        clearTimeout(powerBandHideTimer);
        powerBandHideTimer = null;
    }

    powerBandDraftState = { ...powerBandState };
    syncPowerBandModalUi();
    powerBandModal.classList.remove('hidden');
    powerBandModal.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => {
        if (!powerBandModal) {
            return;
        }
        powerBandModal.classList.add('is-open');
    });
}

function closePowerBandModal({ apply = false, immediate = false } = {}) {
    if (!powerBandModal) {
        return;
    }

    if (apply) {
        powerBandState = normalizePowerBandState(powerBandDraftState);
        syncPowerBandFieldsFromState();
        updateCreateCalcButtonState();
    } else {
        powerBandDraftState = { ...powerBandState };
    }

    if (powerBandHideTimer) {
        clearTimeout(powerBandHideTimer);
        powerBandHideTimer = null;
    }

    const hideModal = () => {
        powerBandModal.classList.add('hidden');
        powerBandModal.setAttribute('aria-hidden', 'true');
    };

    powerBandModal.classList.remove('is-open');
    if (immediate) {
        hideModal();
        return;
    }

    powerBandHideTimer = setTimeout(() => {
        hideModal();
        powerBandHideTimer = null;
    }, 240);
}

function bindRangeInteractionMotion(slider) {
    if (!slider) {
        return;
    }

    let releaseTimer = null;
    const clearDraggingState = () => {
        if (releaseTimer) {
            clearTimeout(releaseTimer);
            releaseTimer = null;
        }
        slider.classList.remove('is-dragging');
    };
    const scheduleClearState = () => {
        if (releaseTimer) {
            clearTimeout(releaseTimer);
        }
        releaseTimer = setTimeout(() => {
            slider.classList.remove('is-dragging');
            releaseTimer = null;
        }, 140);
    };

    slider.addEventListener('pointerdown', () => {
        slider.classList.add('is-dragging');
    });
    slider.addEventListener('input', () => {
        slider.classList.add('is-dragging');
    });
    slider.addEventListener('pointerup', scheduleClearState);
    slider.addEventListener('pointercancel', clearDraggingState);
    slider.addEventListener('change', scheduleClearState);
    slider.addEventListener('blur', clearDraggingState);
}

function initPowerBandControls() {
    if (!createPowerBandTrigger || !createPowerBandValue) {
        return;
    }

    syncPowerBandFieldsFromState();

    createPowerBandTrigger.addEventListener('click', () => {
        openPowerBandModal();
    });

    if (powerBandScaleGrid) {
        powerBandScaleGrid.addEventListener('click', (event) => {
            const target = event.target.closest('[data-rpm-scale]');
            if (!target) {
                return;
            }

            const scaleToken = String(target.dataset.rpmScale || '');
            if (scaleToken === 'custom') {
                applyPowerBandScaleChange(powerBandDraftState.customScaleMax, { isCustomScale: true });
                if (powerBandCustomScaleInput) {
                    powerBandCustomScaleInput.focus();
                    powerBandCustomScaleInput.select();
                }
                return;
            }

            const nextScale = Number(scaleToken);
            if (!POWER_BAND_PRESET_SCALE_OPTIONS.includes(nextScale)) {
                return;
            }

            applyPowerBandScaleChange(nextScale, { isCustomScale: false });
        });
    }

    if (powerBandCustomScaleInput) {
        const applyCustomScaleInput = () => {
            const nextCustomScale = toCustomScaleValue(Number(powerBandCustomScaleInput.value));
            applyPowerBandScaleChange(nextCustomScale, { isCustomScale: true });
        };

        powerBandCustomScaleInput.addEventListener('input', applyCustomScaleInput);
        powerBandCustomScaleInput.addEventListener('change', applyCustomScaleInput);
    }

    if (powerBandRedlineSlider) {
        bindRangeInteractionMotion(powerBandRedlineSlider);
        powerBandRedlineSlider.addEventListener('input', () => {
            powerBandDraftState.redlineRpm = Number(powerBandRedlineSlider.value);
            powerBandDraftState.maxTorqueRpm = powerBandDraftState.redlineRpm;
            syncPowerBandModalUi();
        });
    }

    if (powerBandTorqueSlider) {
        bindRangeInteractionMotion(powerBandTorqueSlider);
        powerBandTorqueSlider.addEventListener('input', () => {
            const clampedTorque = clampNumber(Number(powerBandTorqueSlider.value), 0, powerBandDraftState.redlineRpm);
            powerBandDraftState.maxTorqueRpm = clampedTorque;
            powerBandTorqueSlider.value = String(clampedTorque);
            syncPowerBandModalUi();
        });
    }

    if (powerBandModalCloseBtn) {
        powerBandModalCloseBtn.addEventListener('click', () => {
            closePowerBandModal();
        });
    }

    if (powerBandModalCancelBtn) {
        powerBandModalCancelBtn.addEventListener('click', () => {
            closePowerBandModal();
        });
    }

    if (powerBandModalBackdrop) {
        powerBandModalBackdrop.addEventListener('click', () => {
            closePowerBandModal();
        });
    }

    if (powerBandModalApplyBtn) {
        powerBandModalApplyBtn.addEventListener('click', () => {
            closePowerBandModal({ apply: true });
        });
    }

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && isPowerBandModalOpen()) {
            event.preventDefault();
            closePowerBandModal();
        }
    });
}

function getActiveCapsuleOptionLabel(group, fallback = '') {
    if (!group || !group.querySelector) {
        return fallback;
    }

    const activeOption = group.querySelector('.capsule-option.is-active');
    if (!activeOption) {
        return fallback;
    }

    const label = activeOption.textContent?.trim();
    return label || fallback;
}

function setCapsuleGroupOptionByLabel(group, label, { animate = false } = {}) {
    if (!group || !group.querySelectorAll) {
        return false;
    }

    let normalizedLabel = normalizeSegmentKey(label);
    if (group === createDrivingSurfaceGroup) {
        normalizedLabel = normalizeSurfaceSegmentKey(label);
    } else if (group === createTuneTypeGroup) {
        normalizedLabel = normalizeTuneTypeSegmentKey(label);
    }
    const options = Array.from(group.querySelectorAll('.capsule-option'));
    if (!options.length) {
        return false;
    }

    let targetOption = options.find((option) => (
        getCapsuleOptionSegmentKey(option, option.textContent) === normalizedLabel
        || normalizeSegmentKey(option.textContent) === normalizedLabel
    ));
    if (!targetOption) {
        targetOption = options[0];
    }
    if (!targetOption) {
        return false;
    }

    options.forEach((option) => option.classList.remove('is-active'));
    targetOption.classList.add('is-active');

    if (group === createDrivingSurfaceGroup) {
        syncTuneTypeOptionsByDrivingSurface(getCapsuleOptionSegmentKey(targetOption, targetOption.textContent.trim()), { animate: false });
    }

    updateCapsuleGroupIndicator(group, animate);
    return true;
}

function readNumericFieldValue(field, fallback) {
    if (!field) {
        return fallback;
    }

    const numeric = Number(field.value);
    return Number.isFinite(numeric) ? numeric : fallback;
}

function readCreateInputAsMetric(field, fallbackMetricValue, kind) {
    const unitSystem = normalizeUnitSystem(settingsState.unitSystem);
    const fallbackDisplayValue = convertMetricToDisplay(fallbackMetricValue, kind, unitSystem);
    const displayValue = readNumericFieldValue(field, fallbackDisplayValue);
    const metricValue = convertDisplayToMetric(displayValue, kind, unitSystem);
    return Number.isFinite(metricValue) ? metricValue : fallbackMetricValue;
}

function formatTuneCalcNumber(value, decimals = 2) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return '--';
    }

    if (decimals <= 0) {
        return String(Math.round(numeric));
    }

    return numeric
        .toFixed(decimals)
        .replace(/\.0+$/, '')
        .replace(/(\.\d*[1-9])0+$/, '$1');
}

function formatTuneCalcSliderValue(slider) {
    if (Array.isArray(slider.labels) && slider.labels.length > 0) {
        const index = clampNumber(Math.round(Number(slider.value) || 0), 0, slider.labels.length - 1);
        return slider.labels[index];
    }

    const decimals = Number.isInteger(slider.decimals) ? slider.decimals : 0;
    const baseValue = formatTuneCalcNumber(slider.value, decimals);
    return slider.suffix ? `${baseValue}${slider.suffix}` : baseValue;
}

function getTuneCalcSliderProgress(slider) {
    const min = Number(slider.min);
    const max = Number(slider.max);
    const value = Number(slider.value);
    if (!Number.isFinite(min) || !Number.isFinite(max) || !Number.isFinite(value) || max <= min) {
        return 0;
    }
    return clampNumber(((value - min) / (max - min)) * 100, 0, 100);
}

function convertTuneCalcCardTitleForUnit(title, unitSystem) {
    const normalizedUnit = normalizeUnitSystem(unitSystem);
    if (normalizedUnit !== 'imperial') {
        return title;
    }

    return String(title || '')
        .replace('(bar)', '(psi)')
        .replace('(N/mm)', '(lb/in)')
        .replace('(mm)', '(in)');
}

function convertTuneCalcSliderForDisplay(cardTitle, slider, unitSystem) {
    const normalizedUnit = normalizeUnitSystem(unitSystem);
    if (normalizedUnit !== 'imperial') {
        return slider;
    }

    const cardKey = normalizeSegmentKey(cardTitle);
    if (cardKey.includes('pressure')) {
        return {
            ...slider,
            value: convertMetricToDisplay(slider.value, 'pressure', 'imperial'),
            min: convertMetricToDisplay(slider.min, 'pressure', 'imperial'),
            max: convertMetricToDisplay(slider.max, 'pressure', 'imperial'),
            step: 0.1,
            decimals: 1,
            suffix: ' psi'
        };
    }

    if (cardKey.includes('springs')) {
        return {
            ...slider,
            value: convertMetricToDisplay(slider.value, 'spring', 'imperial'),
            min: convertMetricToDisplay(slider.min, 'spring', 'imperial'),
            max: convertMetricToDisplay(slider.max, 'spring', 'imperial'),
            step: 1,
            decimals: 0,
            suffix: ' lb/in'
        };
    }

    if (cardKey.includes('rideheight')) {
        return {
            ...slider,
            value: convertMetricToDisplay(slider.value, 'rideHeight', 'imperial'),
            min: convertMetricToDisplay(slider.min, 'rideHeight', 'imperial'),
            max: convertMetricToDisplay(slider.max, 'rideHeight', 'imperial'),
            step: 0.1,
            decimals: 1,
            suffix: ' in'
        };
    }

    return slider;
}

function buildDisplayTuneCards(cards, unitSystem) {
    const normalizedUnit = normalizeUnitSystem(unitSystem);
    if (!Array.isArray(cards)) {
        return [];
    }

    return cards.map((card) => {
        const title = convertTuneCalcCardTitleForUnit(card?.title, normalizedUnit);
        const sliders = Array.isArray(card?.sliders)
            ? card.sliders.map((slider) => convertTuneCalcSliderForDisplay(card.title, slider, normalizedUnit))
            : [];
        return {
            ...card,
            title,
            sliders
        };
    });
}

function parseGarageTuneRecord(rawRecord) {
    if (!rawRecord || typeof rawRecord !== 'object') {
        return null;
    }

    const id = typeof rawRecord.id === 'string' ? rawRecord.id : '';
    const savedAt = typeof rawRecord.savedAt === 'string' ? rawRecord.savedAt : '';
    const meta = rawRecord.meta && typeof rawRecord.meta === 'object' ? rawRecord.meta : null;
    const cards = Array.isArray(rawRecord.cards) ? rawRecord.cards : [];
    const subtitle = typeof rawRecord.subtitle === 'string' ? rawRecord.subtitle : '';

    if (!id || !meta) {
        return null;
    }

    return {
        id,
        savedAt,
        meta: {
            brand: String(meta.brand || getSettingsLanguageText('genericUnknownBrand')),
            model: String(meta.model || getSettingsLanguageText('genericUnknownModel')),
            tuneName: sanitizeTuneName(meta.tuneName),
            shareCode: sanitizeShareCode(meta.shareCode),
            unitSystem: normalizeUnitSystem(meta.unitSystem),
            driveType: normalizeDriveType(meta.driveType) || '--',
            surface: normalizeSurfaceSegmentKey(meta.surface || '--') || '--',
            tuneType: normalizeTuneTypeSegmentKey(meta.tuneType || '--') || '--',
            pi: Number.isFinite(Number(meta.pi)) ? Number(meta.pi) : null,
            topSpeedKmh: Number.isFinite(Number(meta.topSpeedKmh)) ? Number(meta.topSpeedKmh) : null,
            weightKg: Number.isFinite(Number(meta.weightKg)) ? Number(meta.weightKg) : null,
            frontDistributionPercent: Number.isFinite(Number(meta.frontDistributionPercent)) ? Number(meta.frontDistributionPercent) : null,
            maxTorqueNm: Number.isFinite(Number(meta.maxTorqueNm)) ? Number(meta.maxTorqueNm) : null,
            gears: Number.isFinite(Number(meta.gears)) ? Number(meta.gears) : null,
            tireWidth: Number.isFinite(Number(meta.tireWidth)) ? Number(meta.tireWidth) : null,
            tireAspect: Number.isFinite(Number(meta.tireAspect)) ? Number(meta.tireAspect) : null,
            tireRim: Number.isFinite(Number(meta.tireRim)) ? Number(meta.tireRim) : null,
            powerBand: meta.powerBand ? normalizePowerBandState(meta.powerBand) : null
        },
        cards,
        subtitle
    };
}

function buildSampleTuneCards(values = {}) {
    const pressureF = Number(values.pressureF ?? 2.05);
    const pressureR = Number(values.pressureR ?? 2.1);
    const finalDrive = Number(values.finalDrive ?? 3.45);
    const camberF = Number(values.camberF ?? -2.1);
    const camberR = Number(values.camberR ?? -1.5);
    const toeF = Number(values.toeF ?? 0.05);
    const toeR = Number(values.toeR ?? -0.02);
    const springF = Number(values.springF ?? 135);
    const springR = Number(values.springR ?? 128);
    const rideFront = Number(values.rideFront ?? 92);
    const rideRear = Number(values.rideRear ?? 96);
    const brakeBalance = Number(values.brakeBalance ?? 51.5);
    const brakeForce = Number(values.brakeForce ?? 112);
    const frontDiff = Number(values.frontDiff ?? 18);
    const rearDiff = Number(values.rearDiff ?? 72);
    const centerDiff = Number(values.centerDiff ?? 66);

    return [
        {
            title: 'Pressure (bar)',
            sliders: [
                { side: 'F', value: pressureF, min: 1, max: 3, step: 0.01, decimals: 2, suffix: ' bar' },
                { side: 'R', value: pressureR, min: 1, max: 3, step: 0.01, decimals: 2, suffix: ' bar' }
            ]
        },
        {
            title: 'Camber',
            sliders: [
                { side: 'F', value: camberF, min: -5, max: 5, step: 0.01, decimals: 2, suffix: '\u00b0' },
                { side: 'R', value: camberR, min: -5, max: 5, step: 0.01, decimals: 2, suffix: '\u00b0' }
            ]
        },
        {
            title: 'Gearing',
            sliders: [
                { side: 'Final', value: finalDrive, min: 2.2, max: 5.8, step: 0.01, decimals: 2 }
            ]
        },
        {
            title: 'Toe',
            sliders: [
                { side: 'F', value: toeF, min: -1, max: 1, step: 0.01, decimals: 2, suffix: '\u00b0' },
                { side: 'R', value: toeR, min: -1, max: 1, step: 0.01, decimals: 2, suffix: '\u00b0' }
            ]
        },
        {
            title: 'Springs (N/mm)',
            sliders: [
                { side: 'F', value: springF, min: 20, max: 300, step: 0.1, decimals: 1 },
                { side: 'R', value: springR, min: 20, max: 300, step: 0.1, decimals: 1 }
            ]
        },
        {
            title: 'Ride Height (mm)',
            sliders: [
                { side: 'F', value: rideFront, min: 0, max: 300, step: 0.1, decimals: 1 },
                { side: 'R', value: rideRear, min: 0, max: 300, step: 0.1, decimals: 1 }
            ]
        },
        {
            title: 'Braking',
            sliders: [
                { side: 'Balance', value: brakeBalance, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%' },
                { side: 'Force', value: brakeForce, min: 0, max: 200, step: 0.1, decimals: 1, suffix: '%' }
            ]
        },
        {
            title: 'Front Differential',
            sliders: [
                { side: 'Accel', value: frontDiff, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%' }
            ]
        },
        {
            title: 'Rear Differential',
            sliders: [
                { side: 'Accel', value: rearDiff, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%' }
            ]
        },
        {
            title: 'Center (%)',
            sliders: [
                { side: 'Center', value: centerDiff, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%' }
            ]
        }
    ];
}

function isSampleGarageTuneId(recordId) {
    return /^sample_tune_/i.test(String(recordId || '').trim());
}

function buildSampleGarageTuneRecords() {
    const now = Date.now();
    const samplePresets = [
        {
            tuneName: 'Road Sprint S2',
            shareCode: '123 456 789',
            brand: 'Ferrari',
            model: '488 Pista',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'race',
            pi: 985,
            topSpeedKmh: 352,
            weightKg: 1385,
            frontDistributionPercent: 44,
            maxTorqueNm: 770,
            gears: 7,
            tireWidth: 305,
            tireAspect: 30,
            tireRim: 20,
            redlineRpm: 9000,
            maxTorqueRpm: 6100,
            cardValues: { pressureF: 2.06, pressureR: 2.12, finalDrive: 3.52, springF: 132, springR: 128 }
        },
        {
            tuneName: 'Precision Apex S1',
            shareCode: '214 557 830',
            brand: 'Porsche',
            model: '911 GT3 RS',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'race',
            pi: 898,
            topSpeedKmh: 332,
            weightKg: 1430,
            frontDistributionPercent: 39,
            maxTorqueNm: 470,
            gears: 7,
            tireWidth: 305,
            tireAspect: 30,
            tireRim: 21,
            redlineRpm: 8800,
            maxTorqueRpm: 6300,
            cardValues: { pressureF: 2.02, pressureR: 2.08, finalDrive: 3.36, springF: 130, springR: 124 }
        },
        {
            tuneName: 'Sunset Attack S2',
            shareCode: '307 441 992',
            brand: 'McLaren',
            model: '720S',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'race',
            pi: 945,
            topSpeedKmh: 344,
            weightKg: 1285,
            frontDistributionPercent: 42,
            maxTorqueNm: 710,
            gears: 7,
            tireWidth: 295,
            tireAspect: 30,
            tireRim: 20,
            redlineRpm: 8600,
            maxTorqueRpm: 5900,
            cardValues: { pressureF: 2.03, pressureR: 2.10, finalDrive: 3.42, springF: 125, springR: 121 }
        },
        {
            tuneName: 'Volcano Grip S1',
            shareCode: '418 662 145',
            brand: 'Lamborghini',
            model: 'Huracan Performante',
            driveType: 'AWD',
            surface: 'street',
            tuneType: 'race',
            pi: 920,
            topSpeedKmh: 336,
            weightKg: 1422,
            frontDistributionPercent: 43,
            maxTorqueNm: 650,
            gears: 7,
            tireWidth: 305,
            tireAspect: 30,
            tireRim: 20,
            redlineRpm: 8600,
            maxTorqueRpm: 6100,
            cardValues: { pressureF: 2.00, pressureR: 2.08, finalDrive: 3.40, springF: 134, springR: 129 }
        },
        {
            tuneName: 'Launch Control S2',
            shareCode: '509 780 321',
            brand: 'Nissan',
            model: 'GT-R R35',
            driveType: 'AWD',
            surface: 'street',
            tuneType: 'drag',
            pi: 967,
            topSpeedKmh: 392,
            weightKg: 1715,
            frontDistributionPercent: 46,
            maxTorqueNm: 910,
            gears: 7,
            tireWidth: 315,
            tireAspect: 30,
            tireRim: 20,
            redlineRpm: 7800,
            maxTorqueRpm: 5000,
            cardValues: { pressureF: 1.99, pressureR: 2.22, finalDrive: 2.95, springF: 141, springR: 136, rearDiff: 78, centerDiff: 70 }
        },
        {
            tuneName: 'Urban Drift S1',
            shareCode: '611 238 774',
            brand: 'BMW',
            model: 'M4 Competition Coupe',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'drift',
            pi: 870,
            topSpeedKmh: 308,
            weightKg: 1620,
            frontDistributionPercent: 50,
            maxTorqueNm: 650,
            gears: 7,
            tireWidth: 285,
            tireAspect: 35,
            tireRim: 19,
            redlineRpm: 7600,
            maxTorqueRpm: 5200,
            cardValues: { pressureF: 1.95, pressureR: 2.05, finalDrive: 3.84, camberF: -3.2, camberR: -1.2, toeF: 0.18, springF: 112, springR: 106 }
        },
        {
            tuneName: 'Touge Flick A',
            shareCode: '703 905 186',
            brand: 'Honda',
            model: 'S2000 CR',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'drift',
            pi: 800,
            topSpeedKmh: 289,
            weightKg: 1210,
            frontDistributionPercent: 49,
            maxTorqueNm: 332,
            gears: 6,
            tireWidth: 255,
            tireAspect: 35,
            tireRim: 18,
            redlineRpm: 9400,
            maxTorqueRpm: 7400,
            cardValues: { pressureF: 1.95, pressureR: 2.08, finalDrive: 3.90, springF: 110, springR: 104 }
        },
        {
            tuneName: 'Street Sideways A',
            shareCode: '814 337 662',
            brand: 'Toyota',
            model: 'GR Supra',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'drift',
            pi: 815,
            topSpeedKmh: 301,
            weightKg: 1510,
            frontDistributionPercent: 52,
            maxTorqueNm: 560,
            gears: 6,
            tireWidth: 275,
            tireAspect: 35,
            tireRim: 19,
            redlineRpm: 7400,
            maxTorqueRpm: 4900,
            cardValues: { pressureF: 1.94, pressureR: 2.08, finalDrive: 3.76, camberF: -2.9, camberR: -1.3, toeF: 0.14, springF: 118, springR: 109 }
        },
        {
            tuneName: 'Forest Rally S1',
            shareCode: '905 776 412',
            brand: 'Subaru',
            model: 'Impreza WRX STI',
            driveType: 'AWD',
            surface: 'dirt',
            tuneType: 'rally',
            pi: 892,
            topSpeedKmh: 274,
            weightKg: 1320,
            frontDistributionPercent: 58,
            maxTorqueNm: 470,
            gears: 6,
            tireWidth: 285,
            tireAspect: 45,
            tireRim: 17,
            redlineRpm: 8200,
            maxTorqueRpm: 5400,
            cardValues: { pressureF: 1.86, pressureR: 1.92, finalDrive: 4.12, springF: 124, springR: 132, frontDiff: 28, rearDiff: 64, centerDiff: 62 }
        },
        {
            tuneName: 'Desert Freight A',
            shareCode: '116 245 930',
            brand: 'Ford',
            model: 'Ranger Raptor',
            driveType: 'AWD',
            surface: 'offroad',
            tuneType: 'truck',
            pi: 780,
            topSpeedKmh: 228,
            weightKg: 2250,
            frontDistributionPercent: 57,
            maxTorqueNm: 760,
            gears: 10,
            tireWidth: 305,
            tireAspect: 55,
            tireRim: 17,
            redlineRpm: 6300,
            maxTorqueRpm: 3900,
            cardValues: { pressureF: 1.82, pressureR: 1.88, finalDrive: 4.38, springF: 148, springR: 154, frontDiff: 22, rearDiff: 56, centerDiff: 54 }
        },
        {
            tuneName: 'Canyon Buggy A',
            shareCode: '227 150 648',
            brand: 'Jeep',
            model: 'Trailcat',
            driveType: 'AWD',
            surface: 'offroad',
            tuneType: 'buggy',
            pi: 760,
            topSpeedKmh: 212,
            weightKg: 2020,
            frontDistributionPercent: 55,
            maxTorqueNm: 680,
            gears: 6,
            tireWidth: 315,
            tireAspect: 60,
            tireRim: 17,
            redlineRpm: 6200,
            maxTorqueRpm: 3700,
            cardValues: { pressureF: 1.78, pressureR: 1.84, finalDrive: 4.56, springF: 152, springR: 160, frontDiff: 24, rearDiff: 58, centerDiff: 60 }
        },
        {
            tuneName: 'Storm Commute A',
            shareCode: '338 640 275',
            brand: 'Audi',
            model: 'RS 6 Avant',
            driveType: 'AWD',
            surface: 'street',
            tuneType: 'rain',
            pi: 820,
            topSpeedKmh: 311,
            weightKg: 2010,
            frontDistributionPercent: 56,
            maxTorqueNm: 800,
            gears: 8,
            tireWidth: 295,
            tireAspect: 35,
            tireRim: 21,
            redlineRpm: 7000,
            maxTorqueRpm: 4300,
            cardValues: { pressureF: 1.93, pressureR: 1.99, finalDrive: 3.30, springF: 138, springR: 133, frontDiff: 20, rearDiff: 60, centerDiff: 58 }
        },
        {
            tuneName: 'Wet Hatch B',
            shareCode: '449 511 803',
            brand: 'Volkswagen',
            model: 'Golf R',
            driveType: 'AWD',
            surface: 'street',
            tuneType: 'rain',
            pi: 700,
            topSpeedKmh: 257,
            weightKg: 1485,
            frontDistributionPercent: 59,
            maxTorqueNm: 460,
            gears: 6,
            tireWidth: 245,
            tireAspect: 40,
            tireRim: 18,
            redlineRpm: 6900,
            maxTorqueRpm: 4200,
            cardValues: { pressureF: 1.91, pressureR: 1.98, finalDrive: 3.67, springF: 122, springR: 118, frontDiff: 18, rearDiff: 52, centerDiff: 56 }
        },
        {
            tuneName: 'Quarter Mile S1',
            shareCode: '550 722 119',
            brand: 'Dodge',
            model: 'Challenger SRT Demon',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'drag',
            pi: 900,
            topSpeedKmh: 335,
            weightKg: 1940,
            frontDistributionPercent: 53,
            maxTorqueNm: 1180,
            gears: 8,
            tireWidth: 315,
            tireAspect: 35,
            tireRim: 20,
            redlineRpm: 6600,
            maxTorqueRpm: 4200,
            cardValues: { pressureF: 1.96, pressureR: 2.20, finalDrive: 3.10, springF: 146, springR: 140, rearDiff: 82 }
        },
        {
            tuneName: 'Hyper Velocity X',
            shareCode: '661 903 540',
            brand: 'Koenigsegg',
            model: 'Jesko',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'race',
            pi: 999,
            topSpeedKmh: 452,
            weightKg: 1420,
            frontDistributionPercent: 43,
            maxTorqueNm: 1500,
            gears: 9,
            tireWidth: 325,
            tireAspect: 30,
            tireRim: 21,
            redlineRpm: 8800,
            maxTorqueRpm: 5800,
            cardValues: { pressureF: 2.08, pressureR: 2.16, finalDrive: 2.74, springF: 144, springR: 138, brakeForce: 122 }
        }
    ];

    return samplePresets
        .slice(0, SAMPLE_GARAGE_TUNE_COUNT)
        .map((preset, index) => {
            const payload = {
                subtitle: 'Sample garage tune',
                meta: {
                    brand: preset.brand,
                    model: preset.model,
                    driveType: preset.driveType,
                    surface: preset.surface,
                    tuneType: preset.tuneType,
                    pi: preset.pi,
                    topSpeedKmh: preset.topSpeedKmh,
                    weightKg: preset.weightKg,
                    frontDistributionPercent: preset.frontDistributionPercent,
                    maxTorqueNm: preset.maxTorqueNm,
                    gears: preset.gears,
                    tireWidth: preset.tireWidth,
                    tireAspect: preset.tireAspect,
                    tireRim: preset.tireRim,
                    powerBand: normalizePowerBandState({
                        scaleMax: 10000,
                        redlineRpm: preset.redlineRpm,
                        maxTorqueRpm: preset.maxTorqueRpm
                    })
                },
                cards: buildSampleTuneCards(preset.cardValues)
            };

            const record = buildGarageRecordFromPayload(payload, {
                tuneName: preset.tuneName,
                shareCode: preset.shareCode
            });
            record.id = `sample_tune_${String(index + 1).padStart(2, '0')}`;
            record.savedAt = new Date(now - (index * 11 * 60 * 1000)).toISOString();
            return record;
        });
}

function ensureSampleGarageTunes() {
    if (!ENABLE_SAMPLE_GARAGE_TUNES) {
        try {
            localStorage.removeItem(GARAGE_SAMPLE_SEED_KEY);
        } catch (_) {
            // Ignore storage errors.
        }
        return;
    }

    let hasSeededSamples = false;
    try {
        hasSeededSamples = String(localStorage.getItem(GARAGE_SAMPLE_SEED_KEY) || '').trim() === APP_BUILD_VERSION;
    } catch (_) {
        hasSeededSamples = false;
    }

    if (hasSeededSamples) {
        return;
    }

    const existingIds = new Set(
        (Array.isArray(garageTunes) ? garageTunes : [])
            .map((record) => String(record?.id || '').trim())
            .filter(Boolean)
    );
    const sampleRecordsToAdd = buildSampleGarageTuneRecords()
        .filter((record) => !existingIds.has(record.id));

    if (sampleRecordsToAdd.length > 0) {
        garageTunes = [...sampleRecordsToAdd, ...(Array.isArray(garageTunes) ? garageTunes : [])]
            .slice(0, MAX_GARAGE_TUNES);
        persistGarageTunes();
    }

    try {
        localStorage.setItem(GARAGE_SAMPLE_SEED_KEY, APP_BUILD_VERSION);
    } catch (_) {
        // Ignore storage write failures and continue runtime flow.
    }
}

function loadGarageTunes() {
    garageSelectedTuneIds.clear();
    garageCurrentPage = 1;

    const raw = localStorage.getItem(GARAGE_STORAGE_KEY);
    if (!raw) {
        garageTunes = [];
        ensureSampleGarageTunes();
        return;
    }

    try {
        const parsed = JSON.parse(raw);
        if (!Array.isArray(parsed)) {
            garageTunes = [];
            return;
        }
        garageTunes = parsed
            .map((record) => parseGarageTuneRecord(record))
            .filter(Boolean)
            .slice(0, MAX_GARAGE_TUNES);
    } catch (_) {
        garageTunes = [];
    }

    const beforeFilterCount = garageTunes.length;
    garageTunes = garageTunes.filter((record) => !isSampleGarageTuneId(record?.id));
    if (garageTunes.length !== beforeFilterCount) {
        persistGarageTunes();
    }

    ensureSampleGarageTunes();
}

function persistGarageTunes() {
    try {
        localStorage.setItem(GARAGE_STORAGE_KEY, JSON.stringify(garageTunes.slice(0, MAX_GARAGE_TUNES)));
    } catch (_) {
        // Ignore storage write failures silently to avoid blocking UX.
    }
}

function formatGarageSavedAt(value) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return getSettingsLanguageText('garageSavedRecently');
    }
    return date.toLocaleString();
}

function formatGarageRpmMeta(meta, subtitle = '') {
    const powerBand = meta?.powerBand ? normalizePowerBandState(meta.powerBand) : null;
    if (powerBand) {
        return `${formatPowerBandRpm(powerBand.maxTorqueRpm)} - ${formatPowerBandRpm(powerBand.redlineRpm)} RPM`;
    }

    const context = parseCreateTuneContextToken(subtitle);
    if (context && Number.isFinite(context.maxTorqueRpm) && Number.isFinite(context.redlineRpm)) {
        return `${formatPowerBandRpm(context.maxTorqueRpm)} - ${formatPowerBandRpm(context.redlineRpm)} RPM`;
    }

    return '--';
}

function normalizeGarageSortKey(value) {
    return Object.prototype.hasOwnProperty.call(GARAGE_SORT_LABEL_KEYS, value) ? value : 'savedAt';
}

function normalizeGarageSortDirection(value) {
    return value === 'asc' ? 'asc' : 'desc';
}

function getGarageSortDefaultDirection(sortKey) {
    return sortKey === 'pi' || sortKey === 'topSpeed' || sortKey === 'savedAt' ? 'desc' : 'asc';
}

function setGarageSort(sortKey) {
    const nextKey = normalizeGarageSortKey(sortKey);
    const currentKey = normalizeGarageSortKey(garageSortState.key);
    const currentDirection = normalizeGarageSortDirection(garageSortState.direction);

    if (nextKey === currentKey) {
        garageSortState.direction = currentDirection === 'asc' ? 'desc' : 'asc';
    } else {
        garageSortState.key = nextKey;
        garageSortState.direction = getGarageSortDefaultDirection(nextKey);
    }

    renderGarageList();
}

function buildGarageSortHeaderMarkup(sortKey) {
    const key = normalizeGarageSortKey(sortKey);
    const labelKey = GARAGE_SORT_LABEL_KEYS[key];
    const label = getSettingsLanguageText(labelKey) || key;
    const isActive = normalizeGarageSortKey(garageSortState.key) === key;
    const direction = isActive ? normalizeGarageSortDirection(garageSortState.direction) : '';
    const icon = isActive ? (direction === 'asc' ? 'north' : 'south') : 'unfold_more';
    const stateLabel = isActive
        ? (direction === 'asc'
            ? getSettingsLanguageText('garageSortStateAsc')
            : getSettingsLanguageText('garageSortStateDesc'))
        : '';
    const ariaLabel = formatLocalizedText('garageSortByAria', { label, state: stateLabel });

    return `
        <button class="garage-sort-btn no-drag${isActive ? ' is-active' : ''}" type="button" data-garage-sort="${escapeHtml(key)}" aria-label="${escapeHtml(ariaLabel)}">
            <span class="garage-sort-label">${escapeHtml(label)}</span>
            <span class="material-symbols-outlined" aria-hidden="true">${icon}</span>
        </button>
    `;
}

function getGarageSortRecordTimestamp(record) {
    const stamp = new Date(record?.savedAt || '');
    const time = stamp.getTime();
    return Number.isFinite(time) ? time : null;
}

function getGarageSortTextValue(record, sortKey) {
    const meta = record?.meta || {};
    if (sortKey === 'tuneName') {
        const tuneName = sanitizeTuneName(meta.tuneName);
        if (tuneName) {
            return tuneName;
        }
        return `${meta.brand || 'Unknown'} ${meta.model || ''}`.trim();
    }
    if (sortKey === 'car') {
        return `${meta.brand || 'Unknown'} ${meta.model || ''}`.trim();
    }
    if (sortKey === 'driveType') {
        return String(meta.driveType || '');
    }
    if (sortKey === 'surface') {
        return String(meta.surface || '');
    }
    if (sortKey === 'tuneType') {
        return String(meta.tuneType || '');
    }
    return '';
}

function getGarageSortNumberValue(record, sortKey) {
    const meta = record?.meta || {};
    if (sortKey === 'pi') {
        return toOptionalPi(meta.pi);
    }
    if (sortKey === 'topSpeed') {
        return toOptionalTopSpeed(meta.topSpeedKmh);
    }
    if (sortKey === 'savedAt') {
        return getGarageSortRecordTimestamp(record);
    }
    return null;
}

function compareGarageSortText(valueA, valueB, direction) {
    const textA = String(valueA || '').trim();
    const textB = String(valueB || '').trim();
    const hasA = textA !== '';
    const hasB = textB !== '';

    if (!hasA && !hasB) {
        return 0;
    }
    if (!hasA) {
        return 1;
    }
    if (!hasB) {
        return -1;
    }

    const compared = textA.localeCompare(textB, undefined, { sensitivity: 'base', numeric: true });
    return direction === 'asc' ? compared : -compared;
}

function compareGarageSortNumber(valueA, valueB, direction) {
    const hasA = Number.isFinite(valueA);
    const hasB = Number.isFinite(valueB);

    if (!hasA && !hasB) {
        return 0;
    }
    if (!hasA) {
        return 1;
    }
    if (!hasB) {
        return -1;
    }

    const compared = valueA - valueB;
    return direction === 'asc' ? compared : -compared;
}

function sortGarageTunes(records) {
    if (!Array.isArray(records) || records.length <= 1) {
        return Array.isArray(records) ? [...records] : [];
    }

    const sortKey = normalizeGarageSortKey(garageSortState.key);
    const sortDirection = normalizeGarageSortDirection(garageSortState.direction);
    garageSortState = {
        key: sortKey,
        direction: sortDirection
    };

    const textSortKeys = new Set(['tuneName', 'car', 'driveType', 'surface', 'tuneType']);
    return [...records].sort((recordA, recordB) => {
        let compared = 0;
        if (textSortKeys.has(sortKey)) {
            compared = compareGarageSortText(
                getGarageSortTextValue(recordA, sortKey),
                getGarageSortTextValue(recordB, sortKey),
                sortDirection
            );
        } else {
            compared = compareGarageSortNumber(
                getGarageSortNumberValue(recordA, sortKey),
                getGarageSortNumberValue(recordB, sortKey),
                sortDirection
            );
        }

        if (compared !== 0) {
            return compared;
        }

        const savedCompared = compareGarageSortNumber(
            getGarageSortNumberValue(recordA, 'savedAt'),
            getGarageSortNumberValue(recordB, 'savedAt'),
            'desc'
        );
        if (savedCompared !== 0) {
            return savedCompared;
        }

        return String(recordA?.id || '').localeCompare(String(recordB?.id || ''), undefined, { numeric: true, sensitivity: 'base' });
    });
}

function normalizeGaragePageSize(value) {
    const numeric = Math.round(Number(value));
    if (GARAGE_PAGE_SIZE_OPTIONS.includes(numeric)) {
        return numeric;
    }
    return GARAGE_DEFAULT_PAGE_SIZE;
}

function getGarageEffectivePageSize() {
    const requestedSize = normalizeGaragePageSize(garagePageSize);
    const rowCap = isWindowMaximized ? GARAGE_MAX_VISIBLE_ROWS_FULLSCREEN : GARAGE_MAX_VISIBLE_ROWS;
    return Math.min(requestedSize, rowCap);
}

function applyGarageFullscreenRowPreference() {
    if (!isWindowMaximized) {
        return;
    }

    const preferredSize = normalizeGaragePageSize(GARAGE_FULLSCREEN_PREFERRED_PAGE_SIZE);
    if (garagePageSize === GARAGE_DEFAULT_PAGE_SIZE) {
        setGaragePageSize(preferredSize);
    }
}

function normalizeGaragePage(value, totalPages = 1) {
    const maxPages = Math.max(1, Math.round(Number(totalPages)) || 1);
    const numeric = Math.round(Number(value));
    if (!Number.isFinite(numeric)) {
        return 1;
    }
    return clampNumber(numeric, 1, maxPages);
}

function pruneGarageSelectionIds() {
    const existingIds = new Set(
        (garageTunes || [])
            .map((record) => String(record?.id || '').trim())
            .filter(Boolean)
    );

    const nextSelected = new Set();
    garageSelectedTuneIds.forEach((recordId) => {
        const normalizedId = String(recordId || '').trim();
        if (normalizedId && existingIds.has(normalizedId)) {
            nextSelected.add(normalizedId);
        }
    });
    garageSelectedTuneIds = nextSelected;
}

function updateGarageDeleteSelectedButton() {
    const selectedCount = garageSelectedTuneIds.size;
    const totalCount = Array.isArray(garageTunes) ? garageTunes.length : 0;

    if (garageSelectAllBtn) {
        const shouldShowSelectAll = selectedCount > 0;
        const canToggleSelectAll = totalCount > 0;
        const shouldSelectAll = selectedCount < totalCount;
        garageSelectAllBtn.classList.toggle('is-visible', shouldShowSelectAll);
        garageSelectAllBtn.disabled = !canToggleSelectAll;
        garageSelectAllBtn.setAttribute('aria-hidden', shouldShowSelectAll ? 'false' : 'true');
        const label = garageSelectAllBtn.querySelector('.garage-select-all-label');
        if (label) {
            label.textContent = shouldSelectAll
                ? `${getSettingsLanguageText('garageSelectAllLabel')} (${totalCount})`
                : getSettingsLanguageText('garageClearAllLabel');
        }
    }

    if (!garageDeleteSelectedBtn) {
        return;
    }

    const shouldShowDeleteMarked = selectedCount > 2;
    garageDeleteSelectedBtn.classList.toggle('is-visible', shouldShowDeleteMarked);
    garageDeleteSelectedBtn.setAttribute('aria-hidden', shouldShowDeleteMarked ? 'false' : 'true');
    garageDeleteSelectedBtn.disabled = selectedCount <= 2;
    const label = garageDeleteSelectedBtn.querySelector('.garage-delete-selected-label');
    if (label) {
        label.textContent = selectedCount > 0
            ? formatLocalizedText('garageDeleteMarkedCount', { count: selectedCount })
            : getSettingsLanguageText('garageDeleteMarkedLabel');
    }
}

function selectAllGarageTunes() {
    if (!Array.isArray(garageTunes) || garageTunes.length === 0) {
        return;
    }

    const totalCount = garageTunes.length;
    if (garageSelectedTuneIds.size >= totalCount) {
        garageSelectedTuneIds.clear();
        renderGarageList();
        return;
    }

    const nextSelected = new Set();
    garageTunes.forEach((record) => {
        const id = String(record?.id || '').trim();
        if (id) {
            nextSelected.add(id);
        }
    });

    garageSelectedTuneIds = nextSelected;
    renderGarageList();
}

function toggleGarageSelection(recordId) {
    const normalizedId = String(recordId || '').trim();
    if (!normalizedId) {
        return;
    }

    if (garageSelectedTuneIds.has(normalizedId)) {
        garageSelectedTuneIds.delete(normalizedId);
    } else {
        garageSelectedTuneIds.add(normalizedId);
    }
    renderGarageList();
}

function setGaragePage(nextPage) {
    const pageSize = getGarageEffectivePageSize();
    const totalPages = Math.max(1, Math.ceil((garageTunes.length || 0) / pageSize));
    const normalizedPage = normalizeGaragePage(nextPage, totalPages);
    if (garageCurrentPage === normalizedPage) {
        return;
    }

    garagePageTransitionDirection = normalizedPage > garageCurrentPage ? 'next' : 'prev';
    garageCurrentPage = normalizedPage;
    renderGarageList();
}

function setGaragePageSize(nextPageSize) {
    const normalizedSize = normalizeGaragePageSize(nextPageSize);
    if (garagePageSize === normalizedSize) {
        if (garagePageSizeSelect) {
            garagePageSizeSelect.value = String(normalizedSize);
        }
        return;
    }

    garagePageSize = normalizedSize;
    garageCurrentPage = 1;
    if (garagePageSizeSelect) {
        garagePageSizeSelect.value = String(normalizedSize);
    }
    renderGarageList();
}

function clearGarageDeleteModalHideTimer() {
    if (garageDeleteModalHideTimer) {
        clearTimeout(garageDeleteModalHideTimer);
        garageDeleteModalHideTimer = null;
    }
}

function isGarageDeleteModalOpen() {
    return Boolean(garageDeleteModal && !garageDeleteModal.classList.contains('hidden') && garageDeleteModal.classList.contains('is-open'));
}

function resolveGarageDeleteModal(decision) {
    if (typeof garageDeleteModalResolver === 'function') {
        const resolver = garageDeleteModalResolver;
        garageDeleteModalResolver = null;
        resolver(Boolean(decision));
    }
}

function openGarageDeleteModal(selectedCount) {
    if (!garageDeleteModal) {
        return Promise.resolve(confirm(
            formatLocalizedText('garageDeleteFallbackConfirm', {
                count: selectedCount,
                plural: selectedCount === 1 ? '' : 's'
            })
        ));
    }

    resolveGarageDeleteModal(false);
    clearGarageDeleteModalHideTimer();
    if (garageDeleteModalMessage) {
        garageDeleteModalMessage.textContent = formatLocalizedText('garageDeleteModalMessage', {
            count: selectedCount,
            plural: selectedCount === 1 ? '' : 's'
        });
    }

    garageDeleteModal.classList.remove('hidden');
    garageDeleteModal.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => {
        garageDeleteModal.classList.add('is-open');
    });

    return new Promise((resolve) => {
        garageDeleteModalResolver = resolve;
    });
}

function closeGarageDeleteModal({ immediate = false, decision = false } = {}) {
    if (!garageDeleteModal) {
        resolveGarageDeleteModal(decision);
        return;
    }

    clearGarageDeleteModalHideTimer();
    garageDeleteModal.classList.remove('is-open');

    const hideModal = () => {
        garageDeleteModal.classList.add('hidden');
        garageDeleteModal.setAttribute('aria-hidden', 'true');
        resolveGarageDeleteModal(decision);
    };

    if (immediate) {
        hideModal();
        return;
    }

    garageDeleteModalHideTimer = setTimeout(() => {
        hideModal();
        garageDeleteModalHideTimer = null;
    }, GARAGE_DELETE_MODAL_TRANSITION_MS);
}

async function removeSelectedGarageTunes() {
    pruneGarageSelectionIds();
    const selectedCount = garageSelectedTuneIds.size;
    if (selectedCount <= 0) {
        return;
    }

    const confirmed = await openGarageDeleteModal(selectedCount);
    if (!confirmed) {
        return;
    }

    const selectedIds = new Set(garageSelectedTuneIds);
    if (activeOverlayTune && selectedIds.has(activeOverlayTune.id)) {
        setActiveOverlayTune(null);
    }
    if (activeGarageViewRecordId && selectedIds.has(activeGarageViewRecordId)) {
        closeGarageViewModal({ immediate: true });
    }

    garageTunes = garageTunes.filter((record) => !selectedIds.has(record.id));
    garageSelectedTuneIds.clear();
    persistGarageTunes();
    renderGarageList();
}

function buildGaragePaginationMarkup(totalRecords, pageSize, currentPage, totalPages) {
    if (totalRecords <= 0) {
        return '';
    }

    const safeCurrentPage = normalizeGaragePage(currentPage, totalPages);
    const safeTotalPages = Math.max(1, Math.round(Number(totalPages)) || 1);
    if (safeTotalPages <= 1) {
        return '';
    }

    const pageSet = new Set([
        1,
        safeTotalPages,
        safeCurrentPage - 1,
        safeCurrentPage,
        safeCurrentPage + 1
    ]);
    const orderedPages = Array.from(pageSet)
        .filter((value) => value >= 1 && value <= safeTotalPages)
        .sort((a, b) => a - b);

    let pageButtonsMarkup = '';
    orderedPages.forEach((pageNumber, index) => {
        const previous = orderedPages[index - 1];
        if (previous && pageNumber - previous > 1) {
            pageButtonsMarkup += '<span class="garage-page-ellipsis" aria-hidden="true">...</span>';
        }

        pageButtonsMarkup += `
            <button class="garage-page-number no-drag${pageNumber === safeCurrentPage ? ' is-active' : ''}" type="button" data-garage-page="${pageNumber}" ${pageNumber === safeCurrentPage ? 'aria-current="page"' : ''}>
                ${pageNumber}
            </button>
        `;
    });

    return `
        <div class="garage-pagination">
            <div class="garage-pagination-controls" role="navigation" aria-label="${escapeHtml(getSettingsLanguageText('garagePaginationAria'))}">
                <button class="garage-page-btn no-drag" type="button" data-garage-page="${safeCurrentPage - 1}" ${safeCurrentPage <= 1 ? 'disabled' : ''} aria-label="${escapeHtml(getSettingsLanguageText('garagePrevPageAria'))}">
                    <span class="material-symbols-outlined" aria-hidden="true">chevron_left</span>
                </button>
                ${pageButtonsMarkup}
                <button class="garage-page-btn no-drag" type="button" data-garage-page="${safeCurrentPage + 1}" ${safeCurrentPage >= safeTotalPages ? 'disabled' : ''} aria-label="${escapeHtml(getSettingsLanguageText('garageNextPageAria'))}">
                    <span class="material-symbols-outlined" aria-hidden="true">chevron_right</span>
                </button>
            </div>
        </div>
    `;
}

function buildGaragePiBadgeMarkup(piValue) {
    const pi = toOptionalPi(piValue);
    const tier = getPiTierConfig(pi);
    const ariaLabel = pi === null ? getSettingsLanguageText('garagePiUnavailable') : `PI ${pi}`;

    if (!tier || pi === null) {
        return `
            <span class="garage-pi-badge pi-badge is-empty" title="${escapeHtml(ariaLabel)}" aria-label="${escapeHtml(ariaLabel)}">
                <span class="pi-chip">--</span>
            </span>
        `;
    }

    const lightClass = tier.lightTier ? ' is-light-tier' : '';
    return `
        <span class="garage-pi-badge pi-badge${lightClass}" style="--pi-tier-color:${tier.color};" title="${escapeHtml(ariaLabel)}" aria-label="${escapeHtml(ariaLabel)}">
            <span class="pi-chip">${escapeHtml(tier.label)}</span>
        </span>
    `;
}

function buildGarageViewPiBadgeMarkup(piValue) {
    const pi = toOptionalPi(piValue);
    const tier = getPiTierConfig(pi);
    const ariaLabel = pi === null ? getSettingsLanguageText('garagePiUnavailable') : `${tier.label} ${pi}`;

    if (!tier || pi === null) {
        return `
            <span class="garage-view-pi-badge pi-badge is-empty" title="${escapeHtml(ariaLabel)}" aria-label="${escapeHtml(ariaLabel)}">
                <span class="pi-chip">--</span>
            </span>
        `;
    }

    const lightClass = tier.lightTier ? ' is-light-tier' : '';
    return `
        <span class="garage-view-pi-badge pi-badge${lightClass}" style="--pi-tier-color:${tier.color};" title="${escapeHtml(ariaLabel)}" aria-label="${escapeHtml(ariaLabel)}">
            <span class="pi-chip">
                <span class="garage-view-pi-tier">${escapeHtml(tier.label)}</span>
                <span class="garage-view-pi-number">${escapeHtml(String(pi))}</span>
            </span>
        </span>
    `;
}

function buildGarageRecordFromPayload(payload, { tuneName = '', shareCode = '' } = {}) {
    const meta = payload?.meta || {};
    const normalizedShareCode = sanitizeShareCode(shareCode);
    const unknownLabel = getSettingsLanguageText('genericUnknown');
    const unknownBrandLabel = getSettingsLanguageText('genericUnknownBrand');
    const unknownModelLabel = getSettingsLanguageText('genericUnknownModel');
    const resolvedTuneName = sanitizeTuneName(tuneName)
        || `${String(meta.brand || unknownLabel)} ${String(meta.model || '').trim()} ${String(meta.tuneType || 'Tune')}`.trim();

    return {
        id: `tune_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        savedAt: new Date().toISOString(),
        meta: {
            brand: String(meta.brand || unknownBrandLabel),
            model: String(meta.model || unknownModelLabel),
            tuneName: resolvedTuneName,
            shareCode: normalizedShareCode,
            unitSystem: normalizeUnitSystem(settingsState.unitSystem),
            driveType: normalizeDriveType(meta.driveType) || '--',
            surface: normalizeSurfaceSegmentKey(meta.surface || '--') || '--',
            tuneType: normalizeTuneTypeSegmentKey(meta.tuneType || '--') || '--',
            pi: Number.isFinite(Number(meta.pi)) ? Number(meta.pi) : null,
            topSpeedKmh: Number.isFinite(Number(meta.topSpeedKmh)) ? Number(meta.topSpeedKmh) : null,
            weightKg: Number.isFinite(Number(meta.weightKg)) ? Number(meta.weightKg) : null,
            frontDistributionPercent: Number.isFinite(Number(meta.frontDistributionPercent)) ? Number(meta.frontDistributionPercent) : null,
            maxTorqueNm: Number.isFinite(Number(meta.maxTorqueNm)) ? Number(meta.maxTorqueNm) : null,
            gears: Number.isFinite(Number(meta.gears)) ? Number(meta.gears) : null,
            tireWidth: Number.isFinite(Number(meta.tireWidth)) ? Number(meta.tireWidth) : null,
            tireAspect: Number.isFinite(Number(meta.tireAspect)) ? Number(meta.tireAspect) : null,
            tireRim: Number.isFinite(Number(meta.tireRim)) ? Number(meta.tireRim) : null,
            powerBand: meta.powerBand ? normalizePowerBandState(meta.powerBand) : null
        },
        cards: Array.isArray(payload?.cards) ? payload.cards : [],
        subtitle: String(payload?.subtitle || '')
    };
}

function removeGarageTuneById(recordId) {
    if (!recordId) {
        return;
    }
    garageSelectedTuneIds.delete(recordId);
    if (activeOverlayTune && activeOverlayTune.id === recordId) {
        setActiveOverlayTune(null);
    }
    if (activeGarageViewRecordId === recordId) {
        closeGarageViewModal({ immediate: true });
    }
    garageTunes = garageTunes.filter((record) => record.id !== recordId);
    persistGarageTunes();
    renderGarageList();
}

function findGarageTuneById(recordId) {
    if (!recordId) {
        return null;
    }
    return garageTunes.find((record) => record.id === recordId) || null;
}

function clearGarageViewHideTimer() {
    if (garageViewHideTimer) {
        clearTimeout(garageViewHideTimer);
        garageViewHideTimer = null;
    }
}

function isGarageViewModalOpen() {
    return Boolean(garageViewModal && !garageViewModal.classList.contains('hidden') && garageViewModal.classList.contains('is-open'));
}

function setGarageViewPreviewPlaceholder(message = getSettingsLanguageText('vehiclePreviewUnavailable')) {
    if (garageViewPreviewPlaceholder) {
        garageViewPreviewPlaceholder.textContent = message;
        garageViewPreviewPlaceholder.classList.remove('is-hidden');
    }
    if (garageViewPreviewImage) {
        garageViewPreviewImage.classList.remove('is-visible');
        garageViewPreviewImage.removeAttribute('src');
        garageViewPreviewImage.alt = '';
    }
}

function setGarageViewPreviewImage(src, label) {
    if (!garageViewPreviewImage || !garageViewPreviewPlaceholder) {
        return;
    }

    garageViewPreviewImage.src = src;
    garageViewPreviewImage.alt = `${label} ${getSettingsLanguageText('vehiclePreviewAlt')}`;
    garageViewPreviewImage.classList.add('is-visible');
    garageViewPreviewPlaceholder.classList.add('is-hidden');
}

async function resolveGarageVehiclePreviewUrl(brand, model) {
    const previewKey = buildVehiclePreviewCacheKey(brand, model);
    const cachedUrl = vehiclePreviewResolvedUrlCache.get(previewKey);
    if (cachedUrl) {
        return cachedUrl;
    }

    const sourceUrls = await fetchVehiclePreviewIngameUrls(brand, model);
    const previewCandidates = sourceUrls.length ? sourceUrls : FORZA_INGAME_FALLBACK_URLS;

    for (let index = 0; index < previewCandidates.length; index += 1) {
        const candidateUrl = previewCandidates[index];
        const canLoad = await probeVehiclePreviewImage(candidateUrl);
        if (!canLoad) {
            continue;
        }
        vehiclePreviewResolvedUrlCache.set(previewKey, candidateUrl);
        return candidateUrl;
    }

    return null;
}

async function updateGarageViewPreview(record) {
    if (!record || !garageViewPreviewImage || !garageViewPreviewPlaceholder) {
        return;
    }

    const brand = String(record.meta?.brand || '').trim();
    const model = String(record.meta?.model || '').trim();
    const label = `${brand} ${model}`.trim() || getSettingsLanguageText('vehiclePreviewLabel');
    const requestToken = ++garageViewPreviewRequestToken;

    if (!brand || !model) {
        setGarageViewPreviewPlaceholder(getSettingsLanguageText('vehiclePreviewUnavailable'));
        return;
    }

    setGarageViewPreviewPlaceholder(formatLocalizedText('vehiclePreviewLoadingLabel', { label }));
    const resolvedUrl = await resolveGarageVehiclePreviewUrl(brand, model);
    if (requestToken !== garageViewPreviewRequestToken || activeGarageViewRecordId !== record.id) {
        return;
    }

    if (!resolvedUrl) {
        setGarageViewPreviewPlaceholder(getSettingsLanguageText('vehiclePreviewLoadFailed'));
        return;
    }

    setGarageViewPreviewImage(resolvedUrl, label);
}

function renderGarageViewModalContent(record) {
    if (!record) {
        return;
    }

    const meta = record.meta || {};
    const unknownLabel = getSettingsLanguageText('genericUnknown');
    const unknownVehicleLabel = getSettingsLanguageText('genericUnknownVehicle');
    const tuneName = sanitizeTuneName(meta.tuneName) || `${String(meta.brand || unknownLabel)} ${String(meta.model || '').trim()}`.trim();
    const carLabel = `${meta.brand || unknownLabel} ${meta.model || ''}`.trim();
    const driveLabel = normalizeDriveType(meta.driveType) || '--';
    const surfaceLabel = meta.surface ? formatSurfaceDisplayLabel(meta.surface) : '--';
    const tuneTypeLabel = meta.tuneType ? formatTuneTypeDisplayLabel(meta.tuneType) : '--';
    const unitSystem = normalizeUnitSystem(meta.unitSystem || settingsState.unitSystem);
    const subtitle = formatGarageSavedAt(record.savedAt);

    if (garageViewSubtitle) {
        garageViewSubtitle.textContent = subtitle;
    }
    if (garageViewName) {
        garageViewName.textContent = tuneName || getSettingsLanguageText('genericUntitledTune');
    }
    if (garageViewCar) {
        garageViewCar.textContent = carLabel || unknownVehicleLabel;
    }
    if (garageViewPi) {
        garageViewPi.innerHTML = buildGarageViewPiBadgeMarkup(meta.pi);
    }
    if (garageViewSpeed) {
        garageViewSpeed.textContent = formatTopSpeedMeta(meta.topSpeedKmh, unitSystem) || '--';
    }
    if (garageViewWeight) {
        garageViewWeight.textContent = formatWeightMeta(meta.weightKg, unitSystem) || '--';
    }
    if (garageViewDrive) {
        garageViewDrive.textContent = driveLabel;
    }
    if (garageViewShare) {
        garageViewShare.textContent = meta.shareCode ? String(meta.shareCode) : '--';
    }
    if (garageViewSaved) {
        garageViewSaved.textContent = formatGarageRpmMeta(meta, record.subtitle);
    }

    if (garageViewBrandLogoSlot) {
        garageViewBrandLogoSlot.innerHTML = getBrandLogoMarkup(meta.brand || '');
        bindBrandLogoFallbacks(garageViewBrandLogoSlot);
    }

    if (garageViewChips) {
        const chipItems = [
            driveLabel,
            surfaceLabel,
            tuneTypeLabel,
            meta.shareCode ? `SC ${meta.shareCode}` : null
        ].filter(Boolean);
        garageViewChips.innerHTML = chipItems
            .map((chip) => `<span class="garage-view-chip">${escapeHtml(chip)}</span>`)
            .join('');
    }

}

function openGarageViewModal(record) {
    if (!garageViewModal || !record) {
        return;
    }

    activeGarageViewRecordId = record.id;
    clearGarageViewHideTimer();
    renderGarageViewModalContent(record);
    setGarageViewPreviewPlaceholder(getSettingsLanguageText('vehiclePreviewLoadingGeneric'));
    garageViewModal.classList.remove('hidden');
    garageViewModal.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => {
        if (!garageViewModal) {
            return;
        }
        garageViewModal.classList.add('is-open');
    });
    updateGarageViewPreview(record);
}

function closeGarageViewModal({ immediate = false } = {}) {
    if (!garageViewModal) {
        return;
    }

    activeGarageViewRecordId = null;
    garageViewPreviewRequestToken += 1;
    clearGarageViewHideTimer();
    garageViewModal.classList.remove('is-open');

    const hideModal = () => {
        garageViewModal.classList.add('hidden');
        garageViewModal.setAttribute('aria-hidden', 'true');
    };

    if (immediate) {
        hideModal();
        return;
    }

    garageViewHideTimer = setTimeout(() => {
        hideModal();
        garageViewHideTimer = null;
    }, GARAGE_VIEW_MODAL_TRANSITION_MS);
}

function openGarageViewById(recordId) {
    const targetRecord = findGarageTuneById(recordId);
    if (!targetRecord) {
        return;
    }
    openGarageViewModal(targetRecord);
}

function renderGarageList() {
    if (!garageList || !garageEmpty) {
        garagePageTransitionDirection = '';
        return;
    }

    pruneGarageSelectionIds();
    const count = garageTunes.length;
    const selectedCount = garageSelectedTuneIds.size;
    if (garageCountBadge) {
        const plural = count === 1 ? '' : 's';
        garageCountBadge.textContent = selectedCount > 0
            ? formatLocalizedText('garageCountSummaryMarked', { count, selected: selectedCount, plural })
            : formatLocalizedText('garageCountSummary', { count, plural });
    }
    updateGarageDeleteSelectedButton();
    if (garagePageSizeSelect) {
        garagePageSizeSelect.value = String(normalizeGaragePageSize(garagePageSize));
    }
    const hasTunes = count > 0;
    garageEmpty.classList.toggle('hidden', hasTunes);
    garageList.classList.toggle('hidden', !hasTunes);
    garageList.setAttribute('aria-hidden', hasTunes ? 'false' : 'true');

    if (!hasTunes) {
        garageCurrentPage = 1;
        garageList.replaceChildren();
        garageList.style.display = 'none';
        garagePageTransitionDirection = '';
        return;
    }

    garageList.style.removeProperty('display');

    const sortedRecords = sortGarageTunes(garageTunes);
    const pageSize = getGarageEffectivePageSize();
    const totalPages = Math.max(1, Math.ceil(sortedRecords.length / pageSize));
    garageCurrentPage = normalizeGaragePage(garageCurrentPage, totalPages);
    const pageStart = (garageCurrentPage - 1) * pageSize;
    const pageRecords = sortedRecords.slice(pageStart, pageStart + pageSize);

    const rowsMarkup = pageRecords.map((record) => {
        const meta = record.meta || {};
        const brand = String(meta.brand || getSettingsLanguageText('genericUnknown'));
        const model = String(meta.model || '');
        const carLabel = `${brand} ${model}`.trim();
        const title = sanitizeTuneName(meta.tuneName) || carLabel || getSettingsLanguageText('genericUntitledTune');
        const unitSystem = normalizeUnitSystem(meta.unitSystem || settingsState.unitSystem);
        const topSpeedLabel = formatTopSpeedMeta(meta.topSpeedKmh, unitSystem) || '--';
        const shareCodeLabel = meta.shareCode ? `SC ${meta.shareCode}` : '--';
        const driveLabel = normalizeDriveType(meta.driveType) || '--';
        const surfaceLabel = meta.surface ? formatSurfaceDisplayLabel(meta.surface) : '--';
        const tuneTypeLabel = meta.tuneType ? formatTuneTypeDisplayLabel(meta.tuneType) : '--';
        const logoMarkup = getBrandLogoMarkup(brand);
        const piBadgeMarkup = buildGaragePiBadgeMarkup(meta.pi);
        const recordId = escapeHtml(record.id);
        const isSelected = garageSelectedTuneIds.has(record.id);
        const selectedClass = isSelected ? ' is-selected' : '';
        const rowAriaLabel = `${isSelected ? `${getSettingsLanguageText('garageMarkedPrefix')} ` : ''}${formatLocalizedText('garageOpenTuneDetails', { title })}`;
        const checkAriaLabel = isSelected
            ? getSettingsLanguageText('garageUnmarkTune')
            : getSettingsLanguageText('garageMarkTune');
        const editTitle = getSettingsLanguageText('garageActionEditTitle');
        const overlayTitle = getSettingsLanguageText('garageActionOverlayTitle');
        const deleteTitle = getSettingsLanguageText('garageActionDeleteTitle');

        return `
            <tr class="garage-row${selectedClass}" data-garage-open="${recordId}" tabindex="0" role="button" aria-label="${escapeHtml(rowAriaLabel)}" aria-selected="${isSelected ? 'true' : 'false'}">
                <td class="garage-cell garage-cell-select">
                    <button class="garage-row-check no-drag${selectedClass}" type="button" data-garage-select="${recordId}" aria-label="${escapeHtml(checkAriaLabel)}" aria-pressed="${isSelected ? 'true' : 'false'}">
                        <span class="material-symbols-outlined" aria-hidden="true">check</span>
                    </button>
                </td>
                <td class="garage-cell garage-cell-tune">
                    <p class="garage-cell-title">${escapeHtml(title)}</p>
                    <span class="garage-cell-sub">${escapeHtml(shareCodeLabel)}</span>
                </td>
                <td class="garage-cell garage-cell-car">
                    <div class="garage-car-cell">
                        ${logoMarkup}
                        <div class="garage-car-copy">
                            <p class="garage-cell-title">${escapeHtml(carLabel)}</p>
                        </div>
                    </div>
                </td>
                <td class="garage-cell garage-cell-drive"><span class="garage-pill">${escapeHtml(driveLabel)}</span></td>
                <td class="garage-cell garage-cell-surface"><span class="garage-pill">${escapeHtml(surfaceLabel)}</span></td>
                <td class="garage-cell garage-cell-type"><span class="garage-pill">${escapeHtml(tuneTypeLabel)}</span></td>
                <td class="garage-cell garage-cell-pi">${piBadgeMarkup}</td>
                <td class="garage-cell garage-cell-speed">${escapeHtml(topSpeedLabel)}</td>
                <td class="garage-cell garage-cell-time">${escapeHtml(formatGarageSavedAt(record.savedAt))}</td>
                <td class="garage-cell garage-cell-actions">
                    <button class="garage-action-btn garage-action-icon garage-action-edit no-drag" type="button" data-garage-edit="${recordId}" aria-label="${escapeHtml(getSettingsLanguageText('garageEditTune'))}" title="${escapeHtml(editTitle)}">
                        <span class="material-symbols-outlined" aria-hidden="true">edit</span>
                    </button>
                    <button class="garage-action-btn garage-action-icon garage-action-overlay no-drag" type="button" data-garage-overlay="${recordId}" aria-label="${escapeHtml(getSettingsLanguageText('garageOverlayTune'))}" title="${escapeHtml(overlayTitle)}">
                        <span class="material-symbols-outlined" aria-hidden="true">picture_in_picture_alt</span>
                    </button>
                    <button class="garage-action-btn garage-action-icon garage-action-delete no-drag" type="button" data-garage-delete="${recordId}" aria-label="${escapeHtml(getSettingsLanguageText('garageDeleteTune'))}" title="${escapeHtml(deleteTitle)}">
                        <span class="material-symbols-outlined" aria-hidden="true">delete</span>
                    </button>
                </td>
            </tr>
        `;
    }).join('');

    const paginationMarkup = buildGaragePaginationMarkup(sortedRecords.length, pageSize, garageCurrentPage, totalPages);

    const pageTransitionClass = garagePageTransitionDirection
        ? ` is-page-switching is-page-switching-${garagePageTransitionDirection}`
        : '';
    const garageLanguageClass = normalizeAppLanguage(settingsState.language) === 'vi'
        ? ' garage-table-lang-vi'
        : ' garage-table-lang-en';

    garageList.innerHTML = `
        <div class="garage-table-wrap${pageTransitionClass}">
            <table class="garage-table${garageLanguageClass}" role="table" aria-label="${escapeHtml(getSettingsLanguageText('garageTableAria'))}">
                <colgroup>
                    <col class="garage-col-select" />
                    <col class="garage-col-tune" />
                    <col class="garage-col-vehicle" />
                    <col class="garage-col-drive" />
                    <col class="garage-col-surface" />
                    <col class="garage-col-type" />
                    <col class="garage-col-pi" />
                    <col class="garage-col-speed" />
                    <col class="garage-col-saved" />
                    <col class="garage-col-actions" />
                </colgroup>
                <thead>
                    <tr>
                        <th class="garage-head-select">${escapeHtml(getSettingsLanguageText('garageHeadMark'))}</th>
                        <th class="garage-head-tune">${buildGarageSortHeaderMarkup('tuneName')}</th>
                        <th class="garage-head-car">${buildGarageSortHeaderMarkup('car')}</th>
                        <th class="garage-head-drive">${buildGarageSortHeaderMarkup('driveType')}</th>
                        <th class="garage-head-surface">${buildGarageSortHeaderMarkup('surface')}</th>
                        <th class="garage-head-type">${buildGarageSortHeaderMarkup('tuneType')}</th>
                        <th class="garage-head-pi">${buildGarageSortHeaderMarkup('pi')}</th>
                        <th class="garage-head-speed">${buildGarageSortHeaderMarkup('topSpeed')}</th>
                        <th class="garage-head-saved">${buildGarageSortHeaderMarkup('savedAt')}</th>
                        <th class="garage-head-actions">${escapeHtml(getSettingsLanguageText('garageHeadActions'))}</th>
                    </tr>
                </thead>
                <tbody>
                    ${rowsMarkup}
                </tbody>
            </table>
        </div>
        ${paginationMarkup}
    `;
    bindBrandLogoFallbacks(garageList);
    garagePageTransitionDirection = '';
}

function saveTuneResultToGarage(payload, options = {}) {
    const record = buildGarageRecordFromPayload(payload, options);
    const targetRecordId = typeof options.recordId === 'string' ? options.recordId.trim() : '';
    if (targetRecordId) {
        const existingIndex = garageTunes.findIndex((item) => item.id === targetRecordId);
        if (existingIndex !== -1) {
            garageTunes.splice(existingIndex, 1);
            record.id = targetRecordId;
            record.savedAt = new Date().toISOString();
        }
    }

    garageTunes.unshift(record);
    if (garageTunes.length > MAX_GARAGE_TUNES) {
        garageTunes = garageTunes.slice(0, MAX_GARAGE_TUNES);
    }
    persistGarageTunes();
    renderGarageList();
    return record;
}

function buildOverlayTuneRecordFromPayload(payload, { tuneName = '', shareCode = '' } = {}) {
    return buildGarageRecordFromPayload(payload, {
        tuneName: sanitizeTuneName(tuneName) || buildDefaultTuneName(payload),
        shareCode: sanitizeShareCode(shareCode)
    });
}

function encodeTextToBase64(text) {
    try {
        if (typeof Buffer !== 'undefined') {
            return Buffer.from(String(text || ''), 'utf8').toString('base64');
        }
        return btoa(unescape(encodeURIComponent(String(text || ''))));
    } catch (_) {
        return '';
    }
}

function decodeBase64ToText(value) {
    try {
        if (typeof Buffer !== 'undefined') {
            return Buffer.from(String(value || ''), 'base64').toString('utf8');
        }
        return decodeURIComponent(escape(atob(String(value || ''))));
    } catch (_) {
        return '';
    }
}

function buildGarageExportFileName() {
    const now = new Date();
    const pad = (num) => String(num).padStart(2, '0');
    const stamp = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    return `f_tuning_garage_${stamp}.tune`;
}

function triggerTextFileDownload(fileName, content) {
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const objectUrl = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = objectUrl;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    setTimeout(() => {
        URL.revokeObjectURL(objectUrl);
    }, 0);
}

function exportGarageTunes() {
    if (!Array.isArray(garageTunes) || garageTunes.length === 0) {
        showAppToast(getSettingsLanguageText('garageExportNoTunes'), { type: 'error' });
        return;
    }

    pruneGarageSelectionIds();
    const selectedRecords = garageTunes.filter((record) => garageSelectedTuneIds.has(record.id));
    if (!selectedRecords.length) {
        showAppToast(getSettingsLanguageText('garageExportSelectAtLeast'), { type: 'error' });
        return;
    }

    const payload = {
        magic: GARAGE_EXPORT_PREFIX,
        version: 1,
        exportedAt: new Date().toISOString(),
        tuneCount: selectedRecords.length,
        tunes: selectedRecords
    };
    const encodedPayload = encodeTextToBase64(JSON.stringify(payload));
    if (!encodedPayload) {
        showAppToast(getSettingsLanguageText('garageExportFailed'), { type: 'error' });
        return;
    }

    const fileContent = `${GARAGE_EXPORT_PREFIX}\n${encodedPayload}`;
    triggerTextFileDownload(buildGarageExportFileName(), fileContent);
    showAppToast(formatLocalizedText('garageExportSuccess', {
        count: selectedRecords.length,
        plural: selectedRecords.length === 1 ? '' : 's'
    }), { type: 'success' });
}

function parseGarageImportText(content) {
    const text = String(content || '').trim();
    if (!text) {
        return [];
    }

    if (!text.startsWith(GARAGE_EXPORT_PREFIX)) {
        return [];
    }

    const encoded = text.slice(GARAGE_EXPORT_PREFIX.length).trim();
    const decoded = decodeBase64ToText(encoded);
    if (!decoded) {
        return [];
    }

    const parsed = JSON.parse(decoded);

    if (Array.isArray(parsed)) {
        return parsed;
    }

    if (parsed && Array.isArray(parsed.tunes)) {
        return parsed.tunes;
    }

    return [];
}

function cloneGarageRecordWithUniqueId(record, usedIds) {
    const baseId = typeof record.id === 'string' && record.id ? record.id : `tune_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    let nextId = baseId;
    while (usedIds.has(nextId)) {
        nextId = `tune_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    }

    usedIds.add(nextId);
    return {
        ...record,
        id: nextId
    };
}

function importGarageTunesFromRecords(records) {
    const normalizedRecords = Array.isArray(records)
        ? records.map((record) => parseGarageTuneRecord(record)).filter(Boolean)
        : [];

    if (normalizedRecords.length === 0) {
        return 0;
    }

    const usedIds = new Set(garageTunes.map((record) => record.id));
    const importedRecords = normalizedRecords.map((record) => cloneGarageRecordWithUniqueId(record, usedIds));
    garageTunes = [...importedRecords, ...garageTunes].slice(0, MAX_GARAGE_TUNES);
    persistGarageTunes();
    renderGarageList();
    return importedRecords.length;
}

function persistActiveOverlayTune() {
    try {
        if (!activeOverlayTune) {
            localStorage.removeItem(GARAGE_ACTIVE_OVERLAY_KEY);
            return;
        }
        localStorage.setItem(GARAGE_ACTIVE_OVERLAY_KEY, JSON.stringify(activeOverlayTune));
    } catch (_) {
        // Ignore storage write failures for overlay tune cache.
    }
}

function buildOverlayLineSummary(card, unitSystem) {
    const displayCard = buildDisplayTuneCards([card], unitSystem)[0];
    if (!displayCard) {
        return '';
    }
    const sliders = Array.isArray(displayCard.sliders) ? displayCard.sliders : [];
    return sliders
        .map((slider) => `${slider.side} ${formatTuneCalcSliderValue(slider)}`)
        .join(' \u00b7 ');
}

function buildEstimatedGearRatios(gearCount, finalDrive) {
    const clampedGearCount = clampNumber(Math.round(Number(gearCount) || 6), 2, 10);
    const topGearRatio = getTopGearRatioByGearCount(clampedGearCount);
    const firstGearRatioByCount = {
        2: 2.2,
        3: 2.65,
        4: 2.95,
        5: 3.1,
        6: 3.25,
        7: 3.35,
        8: 3.45,
        9: 3.52,
        10: 3.58
    };
    const firstGearRatio = Math.max(firstGearRatioByCount[clampedGearCount] || 3.2, topGearRatio + 0.35);
    const resolvedFinalDrive = Number.isFinite(Number(finalDrive)) ? Number(finalDrive) : 3.5;
    const ratios = [];

    for (let index = 0; index < clampedGearCount; index += 1) {
        const progress = clampedGearCount <= 1 ? 0 : (index / (clampedGearCount - 1));
        const ratio = firstGearRatio * Math.pow(topGearRatio / firstGearRatio, progress);
        ratios.push(Number(ratio.toFixed(2)));
    }

    return {
        finalDrive: Number(resolvedFinalDrive.toFixed(2)),
        ratios
    };
}

function buildOverlayGearingLine(card, meta, unitSystem) {
    const displayCard = buildDisplayTuneCards([card], unitSystem)[0];
    const sliders = Array.isArray(displayCard?.sliders) ? displayCard.sliders : [];
    const finalSlider = sliders.find((slider) => normalizeSegmentKey(slider.side) === 'final') || sliders[0] || null;
    const finalDrive = Number(finalSlider?.value);
    const gearCount = clampNumber(Math.round(Number(meta?.gears) || 6), 2, 10);
    const estimated = buildEstimatedGearRatios(gearCount, finalDrive);
    const finalDriveLabel = getSettingsLanguageText('overlayFinalDriveLabel');
    const gearsLabel = getSettingsLanguageText('overlayGearsLabel');
    const detailLines = [
        `${finalDriveLabel} ${estimated.finalDrive.toFixed(2)}`,
        ...estimated.ratios.map((ratio, index) => `G${index + 1} ${ratio.toFixed(2)}`)
    ];
    const detailItems = detailLines.map((line) => {
        const parts = String(line).split(' ');
        const label = parts.shift() || '';
        const value = parts.join(' ') || '--';
        return { label, value };
    });

    return {
        title: String(convertTuneCalcCardTitleForUnit(card.title, unitSystem) || 'Gearing'),
        value: `FD ${estimated.finalDrive.toFixed(2)} \u00b7 ${gearCount} ${gearsLabel}`,
        detail: detailLines.join('\n'),
        detailItems
    };
}

function normalizeOverlayOpacity(value) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return 0.88;
    }

    if (numeric > 1) {
        return clampNumber(numeric / 100, 0.35, 1);
    }
    return clampNumber(numeric, 0.35, 1);
}

function normalizeOverlayTextScale(value) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return 1;
    }
    if (numeric > 3) {
        return clampNumber(numeric / 100, 0.8, 1.4);
    }
    return clampNumber(numeric, 0.8, 1.4);
}

function normalizeOverlayLayoutPreset(value) {
    const normalized = normalizeSegmentKey(value);
    if (normalized === 'grid' || normalized === 'compact' || normalized === 'vertical') {
        return normalized;
    }
    return 'vertical';
}

function formatOverlayOpacityPercent(value) {
    return `${Math.round(normalizeOverlayOpacity(value) * 100)}%`;
}

function buildOverlayWindowPayload() {
    const ui = {
        headTitle: getSettingsLanguageText('overlayHeadTitle'),
        controlsAria: getSettingsLanguageText('overlayControlsAria'),
        onTopLabel: getSettingsLanguageText('overlayOnTopLabel'),
        opacityLabel: getSettingsLanguageText('overlayOpacityLabel'),
        textSizeLabel: getSettingsLanguageText('overlayTextSizeLabel'),
        layoutLabel: getSettingsLanguageText('overlayLayoutLabel'),
        layoutVertical: getSettingsLanguageText('overlayLayoutVertical'),
        layoutGrid: getSettingsLanguageText('overlayLayoutGrid'),
        layoutCompact: getSettingsLanguageText('overlayLayoutCompact'),
        onTopAria: getSettingsLanguageText('overlayOnTopAria'),
        opacityAria: getSettingsLanguageText('overlayOpacityAria'),
        textSizeAria: getSettingsLanguageText('overlayTextSizeAria'),
        layoutAria: getSettingsLanguageText('overlayLayoutAria'),
        lockTitle: getSettingsLanguageText('overlayLockTitle'),
        unlockTitle: getSettingsLanguageText('overlayUnlockTitle'),
        settingsTitle: getSettingsLanguageText('overlaySettingsTitle'),
        closeTitle: getSettingsLanguageText('overlayCloseTitle'),
        noData: getSettingsLanguageText('overlayNoData'),
        cardFallback: getSettingsLanguageText('overlayCardFallbackTitle')
    };

    if (!activeOverlayTune) {
        return {
            title: getSettingsLanguageText('garageNoTuneSelected'),
            subtitle: getSettingsLanguageText('garageOverlayHint'),
            lines: [],
            ui
        };
    }

    const meta = activeOverlayTune.meta || {};
    const unknownLabel = getSettingsLanguageText('genericUnknown');
    const tuneName = sanitizeTuneName(meta.tuneName) || `${meta.brand || unknownLabel} ${meta.model || ''}`.trim();
    const shareCodeLabel = meta.shareCode ? ` \u2022 SC ${meta.shareCode}` : '';
    const subtitle = `${meta.brand || unknownLabel} ${meta.model || ''}${shareCodeLabel}`.trim();
    const unitSystem = normalizeUnitSystem(settingsState.unitSystem || meta.unitSystem);
    const lines = (activeOverlayTune.cards || []).map((card) => {
        const cardKey = normalizeSegmentKey(card?.title);
        if (cardKey.includes('gearing')) {
            return buildOverlayGearingLine(card, meta, unitSystem);
        }

        return {
            title: String(convertTuneCalcCardTitleForUnit(card.title, unitSystem) || getSettingsLanguageText('overlayCardFallbackTitle')),
            value: buildOverlayLineSummary(card, unitSystem) || '--'
        };
    });

    return {
        title: tuneName || getSettingsLanguageText('genericUntitledTune'),
        subtitle,
        lines,
        ui
    };
}

function syncOverlayWindowState() {
    const shouldShow = settingsState.overlayMode && !overlayDismissed && Boolean(activeOverlayTune);
    if (!shouldShow) {
        ipcRenderer.send('overlay-window-state', { visible: false });
        if (tuneOverlay) {
            tuneOverlay.classList.add('hidden');
        }
        return;
    }

    const data = buildOverlayWindowPayload();
    ipcRenderer.send('overlay-window-state', {
        visible: true,
        opacity: normalizeOverlayOpacity(settingsState.overlayOpacity),
        textScale: normalizeOverlayTextScale(settingsState.overlayTextScale),
        layoutPreset: normalizeOverlayLayoutPreset(settingsState.overlayLayout),
        alwaysOnTop: Boolean(settingsState.overlayOnTop),
        lockPosition: Boolean(settingsState.overlayLocked),
        data
    });
    if (tuneOverlay) {
        tuneOverlay.classList.add('hidden');
    }
}

function renderTuneOverlay() {
    syncOverlayWindowState();
}

function syncOverlaySettingsUi() {
    const overlayEnabled = Boolean(settingsState.overlayMode);
    if (toggleOverlayMode) {
        toggleOverlayMode.checked = overlayEnabled;
    }
    if (toggleOverlayOnTop) {
        toggleOverlayOnTop.checked = Boolean(settingsState.overlayOnTop);
    }
    if (overlayOpacitySlider) {
        overlayOpacitySlider.value = String(Math.round(normalizeOverlayOpacity(settingsState.overlayOpacity) * 100));
    }
    if (overlayOpacityValue) {
        overlayOpacityValue.textContent = formatOverlayOpacityPercent(settingsState.overlayOpacity);
    }
    if (settingsOverlayOnTopItem) {
        settingsOverlayOnTopItem.hidden = !overlayEnabled;
    }
    if (settingsOverlayOpacityItem) {
        settingsOverlayOpacityItem.hidden = !overlayEnabled;
    }
    syncTuneCalcOverlayButtonUi();
}

function setOverlayModeEnabled(isEnabled) {
    const enabled = Boolean(isEnabled);
    settingsState.overlayMode = enabled;
    overlayDismissed = false;

    syncOverlaySettingsUi();
    renderTuneOverlay();
}

function setOverlayOnTopEnabled(isEnabled) {
    settingsState.overlayOnTop = Boolean(isEnabled);
    syncOverlaySettingsUi();
    renderTuneOverlay();
}

function setOverlayOpacity(nextValue) {
    settingsState.overlayOpacity = normalizeOverlayOpacity(nextValue);
    syncOverlaySettingsUi();
    renderTuneOverlay();
}

function setOverlayLocked(isLocked) {
    settingsState.overlayLocked = Boolean(isLocked);
    syncOverlaySettingsUi();
    renderTuneOverlay();
}

function setActiveOverlayTune(record, { forceShow = false, persist = true } = {}) {
    activeOverlayTune = parseGarageTuneRecord(record);
    if (forceShow) {
        overlayDismissed = false;
    }
    if (persist) {
        persistActiveOverlayTune();
    } else {
        try {
            localStorage.removeItem(GARAGE_ACTIVE_OVERLAY_KEY);
        } catch (_) {
            // Ignore storage errors for non-persistent overlay state.
        }
    }
    renderTuneOverlay();
}

function loadActiveOverlayTune() {
    // Overlay now starts empty and follows Tune Results unless user pins a tune in-session.
    activeOverlayTune = null;
    try {
        localStorage.removeItem(GARAGE_ACTIVE_OVERLAY_KEY);
    } catch (_) {
        // Ignore storage cleanup errors on startup.
    }
}

ipcRenderer.on('overlay-window-closed', () => {
    overlayDismissed = true;
    syncOverlayWindowState();
});

ipcRenderer.on('overlay-controls-updated', (event, payload) => {
    const nextPayload = payload && typeof payload === 'object' ? payload : {};
    if (Object.prototype.hasOwnProperty.call(nextPayload, 'opacity')) {
        settingsState.overlayOpacity = normalizeOverlayOpacity(nextPayload.opacity);
    }
    if (Object.prototype.hasOwnProperty.call(nextPayload, 'textScale')) {
        settingsState.overlayTextScale = normalizeOverlayTextScale(nextPayload.textScale);
    }
    if (Object.prototype.hasOwnProperty.call(nextPayload, 'alwaysOnTop')) {
        settingsState.overlayOnTop = Boolean(nextPayload.alwaysOnTop);
    }
    if (Object.prototype.hasOwnProperty.call(nextPayload, 'layoutPreset')) {
        settingsState.overlayLayout = normalizeOverlayLayoutPreset(nextPayload.layoutPreset);
    }
    if (Object.prototype.hasOwnProperty.call(nextPayload, 'lockPosition')) {
        settingsState.overlayLocked = Boolean(nextPayload.lockPosition);
    }
    syncOverlaySettingsUi();

    if (nextPayload.commit) {
        saveSettings(false);
    }
});

function initGarageControls() {
    if (garageList) {
        garageList.addEventListener('click', (event) => {
            const pageButton = event.target.closest('[data-garage-page]');
            if (pageButton) {
                if (pageButton.disabled) {
                    return;
                }

                const nextPage = Number(pageButton.getAttribute('data-garage-page'));
                if (!Number.isFinite(nextPage)) {
                    return;
                }

                setGaragePage(nextPage);
                return;
            }

            const selectionButton = event.target.closest('[data-garage-select]');
            if (selectionButton) {
                const recordId = selectionButton.getAttribute('data-garage-select');
                if (!recordId) {
                    return;
                }
                toggleGarageSelection(recordId);
                return;
            }

            const sortButton = event.target.closest('[data-garage-sort]');
            if (sortButton) {
                const sortKey = sortButton.getAttribute('data-garage-sort');
                if (!sortKey) {
                    return;
                }
                setGarageSort(sortKey);
                return;
            }

            const editButton = event.target.closest('[data-garage-edit]');
            if (editButton) {
                const recordId = editButton.getAttribute('data-garage-edit');
                if (!recordId) {
                    return;
                }
                openGarageEditById(recordId);
                return;
            }

            const overlayButton = event.target.closest('[data-garage-overlay]');
            if (overlayButton) {
                const recordId = overlayButton.getAttribute('data-garage-overlay');
                if (!recordId) {
                    return;
                }

                const targetRecord = garageTunes.find((record) => record.id === recordId);
                if (!targetRecord) {
                    return;
                }

                setActiveOverlayTune(targetRecord, { forceShow: true });
                return;
            }

            const deleteButton = event.target.closest('[data-garage-delete]');
            if (!deleteButton) {
                return;
            }

            const recordId = deleteButton.getAttribute('data-garage-delete');
            if (!recordId) {
                return;
            }

            if (activeOverlayTune && activeOverlayTune.id === recordId) {
                setActiveOverlayTune(null);
            }
            removeGarageTuneById(recordId);
            return;
        });

        garageList.addEventListener('click', (event) => {
            if (
                event.target.closest('.garage-action-btn')
                || event.target.closest('[data-garage-sort]')
                || event.target.closest('[data-garage-select]')
                || event.target.closest('[data-garage-page]')
            ) {
                return;
            }

            const row = event.target.closest('[data-garage-open]');
            if (!row) {
                return;
            }

            const recordId = row.getAttribute('data-garage-open');
            if (!recordId) {
                return;
            }
            openGarageViewById(recordId);
        });

        garageList.addEventListener('keydown', (event) => {
            if (event.key !== 'Enter' && event.key !== ' ') {
                return;
            }
            if (
                event.target.closest('.garage-action-btn')
                || event.target.closest('[data-garage-sort]')
                || event.target.closest('[data-garage-select]')
                || event.target.closest('[data-garage-page]')
            ) {
                return;
            }

            const row = event.target.closest('[data-garage-open]');
            if (!row) {
                return;
            }

            event.preventDefault();
            const recordId = row.getAttribute('data-garage-open');
            if (!recordId) {
                return;
            }
            openGarageViewById(recordId);
        });
    }

    if (garagePageSizeSelect) {
        garagePageSizeSelect.value = String(normalizeGaragePageSize(garagePageSize));
        garagePageSizeSelect.addEventListener('change', () => {
            setGaragePageSize(garagePageSizeSelect.value);
        });
    }

    if (garageDeleteSelectedBtn) {
        garageDeleteSelectedBtn.addEventListener('click', () => {
            removeSelectedGarageTunes();
        });
    }

    if (garageSelectAllBtn) {
        garageSelectAllBtn.addEventListener('click', () => {
            selectAllGarageTunes();
        });
    }

    if (btnGarageDeleteNo) {
        btnGarageDeleteNo.addEventListener('click', () => {
            closeGarageDeleteModal({ decision: false });
        });
    }

    if (btnGarageDeleteYes) {
        btnGarageDeleteYes.addEventListener('click', () => {
            closeGarageDeleteModal({ decision: true });
        });
    }

    if (garageDeleteModalBackdrop) {
        garageDeleteModalBackdrop.addEventListener('click', () => {
            closeGarageDeleteModal({ decision: false });
        });
    }

    if (garageViewCloseBtn) {
        garageViewCloseBtn.addEventListener('click', () => {
            closeGarageViewModal();
        });
    }

    if (garageViewModalBackdrop) {
        garageViewModalBackdrop.addEventListener('click', () => {
            closeGarageViewModal();
        });
    }

    if (garageExportBtn) {
        garageExportBtn.addEventListener('click', () => {
            exportGarageTunes();
        });
    }

    if (garageImportBtn && garageImportInput) {
        garageImportBtn.addEventListener('click', () => {
            garageImportInput.click();
        });

        garageImportInput.addEventListener('change', async () => {
            const targetFile = garageImportInput.files && garageImportInput.files[0];
            garageImportInput.value = '';
            if (!targetFile) {
                return;
            }

            const fileName = String(targetFile.name || '').toLowerCase();
            if (!fileName.endsWith('.tune')) {
                showAppToast(getSettingsLanguageText('garageImportOnlyTune'), { type: 'error' });
                return;
            }

            try {
                const fileContent = await targetFile.text();
                const importRecords = parseGarageImportText(fileContent);
                const importCount = importGarageTunesFromRecords(importRecords);
                if (importCount <= 0) {
                    showAppToast(getSettingsLanguageText('garageImportNoValid'), { type: 'error' });
                    return;
                }
                showAppToast(formatLocalizedText('garageImportSuccess', {
                    count: importCount,
                    plural: importCount === 1 ? '' : 's'
                }), { type: 'success' });
            } catch (_) {
                showAppToast(getSettingsLanguageText('garageImportFailed'), { type: 'error' });
            }
        });
    }

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && isGarageDeleteModalOpen()) {
            event.preventDefault();
            closeGarageDeleteModal({ decision: false });
            return;
        }

        if (event.key === 'Escape' && isGarageViewModalOpen()) {
            event.preventDefault();
            closeGarageViewModal();
        }
    });

    renderGarageList();
}

function getTuneCalcSurfaceProfile(surfaceKey) {
    if (surfaceKey === 'dirt') {
        return {
            gripMultiplier: 0.78,
            basePressure: 1.8,
            rideFrequency: 1.58,
            rideHeightFront: 28,
            rideHeightRear: 31,
            reboundRatio: 0.68,
            bumpToReboundRatio: 0.54
        };
    }

    if (surfaceKey === 'offroad') {
        return {
            gripMultiplier: 0.7,
            basePressure: 1.72,
            rideFrequency: 1.46,
            rideHeightFront: 34,
            rideHeightRear: 38,
            reboundRatio: 0.64,
            bumpToReboundRatio: 0.52
        };
    }

    return {
        gripMultiplier: 1,
        basePressure: 2.12,
        rideFrequency: 2.16,
        rideHeightFront: 7,
        rideHeightRear: 10,
        reboundRatio: 0.78,
        bumpToReboundRatio: 0.58
    };
}

function getTuneCalcTireGripMultiplier(tireType) {
    const tireKey = normalizeSegmentKey(tireType);
    if (tireKey.includes('slick') && !tireKey.includes('semi')) {
        return 1.2;
    }
    if (tireKey.includes('semislick')) {
        return 1.12;
    }
    if (tireKey.includes('sport')) {
        return 1.03;
    }
    if (tireKey.includes('offroad') || tireKey.includes('rally')) {
        return 0.88;
    }
    if (tireKey.includes('drag')) {
        return 0.92;
    }
    if (tireKey.includes('drift')) {
        return 0.96;
    }
    return 0.95;
}

function getTuneCalcDifferentialTier(differentialType) {
    const diffKey = normalizeSegmentKey(differentialType);
    if (diffKey.includes('race')) {
        return 1;
    }
    if (diffKey.includes('sport')) {
        return 0.68;
    }
    return 0.42;
}

function getTopGearRatioByGearCount(gearCount) {
    const ratios = {
        2: 1,
        3: 0.86,
        4: 0.77,
        5: 0.7,
        6: 0.64,
        7: 0.58,
        8: 0.53,
        9: 0.49,
        10: 0.45
    };
    return ratios[gearCount] || 0.64;
}

function getTireCircumferenceMeters(tireWidthMm, tireAspectPercent, tireRimInches) {
    const width = Number(tireWidthMm);
    const aspect = Number(tireAspectPercent);
    const rim = Number(tireRimInches);
    if (!Number.isFinite(width) || !Number.isFinite(aspect) || !Number.isFinite(rim)) {
        return 2.05;
    }

    const sidewallHeightMeters = (width * (aspect / 100)) / 1000;
    const rimDiameterMeters = rim * 0.0254;
    const tireDiameterMeters = rimDiameterMeters + (2 * sidewallHeightMeters);
    if (!Number.isFinite(tireDiameterMeters) || tireDiameterMeters <= 0) {
        return 2.05;
    }

    return Math.PI * tireDiameterMeters;
}

function buildTuneCalculationPayload() {
    const selectedBrand = vehicleBrowserState.selectedBrand || getSettingsLanguageText('genericUnknownBrand');
    const selectedModel = vehicleBrowserState.selectedModel || getSettingsLanguageText('genericUnknownModel');
    const selectedSpecs = getVehicleSpecs(selectedBrand, selectedModel) || null;
    const tireType = selectedSpecs?.tireType || 'Street';
    const differentialType = selectedSpecs?.differential || 'Street Differential';
    const driveType = normalizeDriveType(getActiveCapsuleOptionKey(createDriveTypeGroup, 'fwd')) || 'FWD';
    const drivingSurface = getActiveCapsuleOptionKey(createDrivingSurfaceGroup, 'street');
    const tuneType = getActiveCapsuleOptionKey(createTuneTypeGroup, 'race');
    const surfaceKey = getTuneSurfaceKeyFromLabel(drivingSurface);
    const tuneKey = normalizeSegmentKey(tuneType);
    const surfaceProfile = getTuneCalcSurfaceProfile(surfaceKey);

    const weightKg = clampNumber(readCreateInputAsMetric(createWeightInput, 1400, 'weight'), 600, 2600);
    const frontDistributionPercent = clampNumber(readNumericFieldValue(createFrontDistributionInput, 50), 35, 65);
    const currentPi = clampNumber(readNumericFieldValue(createCurrentPiInput, selectedSpecs?.pi ?? 800), 100, 999);
    const topSpeedKmh = clampNumber(readCreateInputAsMetric(createTopSpeedInput, selectedSpecs?.topSpeedKmh ?? 280, 'speed'), 80, 500);
    const maxTorqueNm = clampNumber(readCreateInputAsMetric(createMaxTorqueInput, 600, 'torque'), 100, 2000);
    const gears = clampNumber(readNumericFieldValue(createGearsSelect, 6), 2, 10);
    const tireWidth = clampNumber(readNumericFieldValue(createTireWidthInput, 255), 120, 500);
    const tireAspect = clampNumber(readNumericFieldValue(createTireAspectInput, 35), 20, 80);
    const tireRim = clampNumber(readNumericFieldValue(createTireRimInput, 19), 13, 24);

    const powerBand = normalizePowerBandState(powerBandState);
    const redlineRpm = powerBand.redlineRpm;
    const torquePeakRpm = powerBand.maxTorqueRpm;

    const weightN = clampNumber((weightKg - 900) / 1200, 0, 1);
    const piN = clampNumber((currentPi - 100) / 899, 0, 1);
    const speedN = clampNumber((topSpeedKmh - 120) / 300, 0, 1);
    const torqueN = clampNumber((maxTorqueNm - 150) / 1150, 0, 1);
    const frontBias = clampNumber(frontDistributionPercent / 100, 0.35, 0.65);
    const rearBias = 1 - frontBias;
    const tireGripMultiplier = getTuneCalcTireGripMultiplier(tireType);
    const differentialTier = getTuneCalcDifferentialTier(differentialType);
    const totalGrip = clampNumber(surfaceProfile.gripMultiplier * tireGripMultiplier, 0.55, 1.35);
    const looseSurfaceFactor = 1 - surfaceProfile.gripMultiplier;
    const tireWidthFactor = clampNumber((tireWidth - 255) / 220, -0.5, 0.5);
    const powerBandShape = clampNumber(torquePeakRpm / Math.max(redlineRpm, 1), 0.35, 0.95);
    const isLooseSurface = surfaceKey !== 'race';
    const isDriftTune = tuneKey === 'drift';
    const isDragTune = tuneKey === 'drag';
    const isRaceTune = tuneKey === 'race' || tuneKey === 'rain';
    const isRallyLikeTune = tuneKey === 'rally' || tuneKey === 'buggy' || tuneKey === 'truck';

    const topSpeedMps = topSpeedKmh / 3.6;
    const tireCircumferenceM = getTireCircumferenceMeters(tireWidth, tireAspect, tireRim);
    const wheelRpmAtTopSpeed = clampNumber((topSpeedMps / Math.max(tireCircumferenceM, 0.1)) * 60, 100, 8000);
    const topGearRatio = getTopGearRatioByGearCount(Math.round(gears));
    const tractionSlipAllowance = isDragTune ? 0.98 : (surfaceKey === 'race' ? 0.96 : 0.92);
    let gearingFinal = redlineRpm / Math.max(wheelRpmAtTopSpeed * topGearRatio * tractionSlipAllowance, 1);
    if (isDriftTune) {
        gearingFinal *= 1.05;
    }
    if (isLooseSurface || isRallyLikeTune) {
        gearingFinal *= 1.07;
    }
    if (isDragTune) {
        gearingFinal *= 0.93;
    }
    gearingFinal *= 1 + ((1 - powerBandShape) * 0.08);
    gearingFinal = clampNumber(gearingFinal, 2.2, 5.8);

    const peakPowerHp = (maxTorqueNm * Math.max(torquePeakRpm, 1000)) / 7127;
    const powerToWeightHpPerTon = peakPowerHp / Math.max(weightKg / 1000, 0.7);
    const powerToWeightN = clampNumber((powerToWeightHpPerTon - 90) / 820, 0, 1.2);
    const targetLatG = clampNumber(
        (totalGrip * (0.82 + (0.3 * piN) + (0.08 * speedN) + (0.06 * powerToWeightN)))
        + (isRaceTune ? 0.05 : 0)
        - (isLooseSurface ? 0.04 : 0),
        0.65,
        1.85
    );

    const vehicleWeightN = weightKg * 9.81;
    const frontLoadPerTireN = (vehicleWeightN * frontBias) / 2;
    const rearLoadPerTireN = (vehicleWeightN * rearBias) / 2;
    const contactPatchFactor = clampNumber(1 + ((tireWidth - 245) / 520), 0.72, 1.35);

    let pressureFront = surfaceProfile.basePressure
        + ((frontLoadPerTireN / (2750 * contactPatchFactor)) - 1)
        + (0.16 * speedN)
        + (isRaceTune && tireGripMultiplier >= 1.1 ? 0.05 : 0)
        + (isDragTune ? -0.04 : 0)
        + (isLooseSurface ? -0.09 : 0);
    let pressureRear = surfaceProfile.basePressure
        + ((rearLoadPerTireN / (2750 * contactPatchFactor)) - 1)
        + (0.18 * speedN)
        + (isRaceTune && tireGripMultiplier >= 1.1 ? 0.04 : 0)
        + (isDragTune ? 0.11 : 0)
        + (isLooseSurface ? -0.12 : 0);
    pressureFront = clampNumber(pressureFront, 1.2, 2.8);
    pressureRear = clampNumber(pressureRear, 1.2, 2.8);

    const camberLoadFactor = clampNumber((targetLatG - 0.7) / 1.05, 0, 1.2);
    let camberFront = -(0.5 + (1.9 * camberLoadFactor) + (0.2 * speedN) + (isDriftTune ? 0.45 : 0));
    let camberRear = -(0.28 + (1.45 * camberLoadFactor) + (driveType === 'RWD' ? 0.12 : 0) + (isDriftTune ? 0.3 : 0) - (isDragTune ? 0.25 : 0));
    if (isLooseSurface) {
        camberFront += 0.18;
        camberRear += 0.2;
    }
    if (isDriftTune) {
        camberFront -= 0.12;
        camberRear -= 0.08;
    }
    camberFront = clampNumber(camberFront, -5, 5);
    camberRear = clampNumber(camberRear, -5, 5);

    let toeFront = isDriftTune ? 0.22 : (isLooseSurface ? 0.08 : 0.03);
    let toeRear = isDriftTune ? 0.34 : (isLooseSurface ? 0.1 : -0.03);
    if (driveType === 'FWD') {
        toeFront += 0.02;
    }
    if (driveType === 'RWD') {
        toeRear += 0.04;
    }
    if (isDragTune) {
        toeFront = -0.02;
        toeRear = 0.18;
    }
    toeFront = clampNumber(toeFront, -1, 1);
    toeRear = clampNumber(toeRear, -1, 1);

    let casterFront = 4.7 + (2.1 * speedN) + (1.1 * piN) + (isDriftTune ? 0.9 : 0) - (isLooseSurface ? 0.45 : 0);
    let casterRear = 3.6 + (1.6 * speedN) + (0.75 * piN) + (isDriftTune ? 0.7 : 0) - (isLooseSurface ? 0.55 : 0);
    casterFront = clampNumber(casterFront, 0, 10);
    casterRear = clampNumber(casterRear, 0, 10);

    const frontAxleMass = weightKg * frontBias;
    const rearAxleMass = weightKg * rearBias;
    const frontCornerMass = Math.max((frontAxleMass * 0.9) / 2, 100);
    const rearCornerMass = Math.max((rearAxleMass * 0.9) / 2, 100);

    const baseRideFrequency = surfaceProfile.rideFrequency + (0.26 * piN) + (0.16 * speedN);
    let rideFrequencyFront = baseRideFrequency + ((frontBias - 0.5) * 0.45) + (driveType === 'FWD' ? 0.06 : 0) + (isDriftTune ? 0.1 : 0) + (isDragTune ? -0.2 : 0);
    let rideFrequencyRear = baseRideFrequency - ((frontBias - 0.5) * 0.45) + (driveType === 'RWD' ? 0.08 : 0) + (isDriftTune ? 0.12 : 0) + (isDragTune ? 0.24 : 0);
    rideFrequencyFront = clampNumber(rideFrequencyFront, 1.2, 3.2);
    rideFrequencyRear = clampNumber(rideFrequencyRear, 1.2, 3.2);

    const springFrontNPerM = Math.pow((2 * Math.PI * rideFrequencyFront), 2) * frontCornerMass;
    const springRearNPerM = Math.pow((2 * Math.PI * rideFrequencyRear), 2) * rearCornerMass;
    let springFront = clampNumber(springFrontNPerM / 1000, 20, 260);
    let springRear = clampNumber(springRearNPerM / 1000, 20, 260);

    const totalArbTarget = clampNumber((springFront + springRear) * (0.24 + (0.14 * targetLatG)), 10, 120);
    let arbFrontShare = frontBias
        + (driveType === 'FWD' ? -0.05 : driveType === 'RWD' ? 0.04 : 0)
        + (isDriftTune ? -0.05 : 0)
        + (isLooseSurface ? -0.02 : 0);
    arbFrontShare = clampNumber(arbFrontShare, 0.35, 0.65);
    let antiRollFront = totalArbTarget * arbFrontShare;
    let antiRollRear = totalArbTarget * (1 - arbFrontShare);
    antiRollFront = clampNumber(antiRollFront, 1, 65);
    antiRollRear = clampNumber(antiRollRear, 1, 65);

    let rideHeightFront = surfaceProfile.rideHeightFront
        + (2.3 * weightN)
        + (isDriftTune ? 1.4 : 0)
        + (isLooseSurface ? 1.6 : 0)
        - (isRaceTune ? 2.2 * speedN : 0);
    let rideHeightRear = surfaceProfile.rideHeightRear
        + (2 * weightN)
        + (isDriftTune ? 1.1 : 0)
        + (isLooseSurface ? 1.9 : 0)
        - (isRaceTune ? 1.5 * speedN : 0);
    if (isDragTune) {
        rideHeightFront = 5.5;
        rideHeightRear = 8.5;
    }
    rideHeightFront = clampNumber(rideHeightFront, 0, 100);
    rideHeightRear = clampNumber(rideHeightRear, 0, 100);

    const frontCriticalDamping = 2 * Math.sqrt(springFrontNPerM * frontCornerMass);
    const rearCriticalDamping = 2 * Math.sqrt(springRearNPerM * rearCornerMass);
    const frontReboundRatio = surfaceProfile.reboundRatio + (0.06 * piN) + (0.05 * speedN) + (isDriftTune ? 0.05 : 0);
    const rearReboundRatio = surfaceProfile.reboundRatio + (0.06 * piN) + (0.04 * speedN) + (driveType === 'RWD' ? 0.03 : 0) + (isDriftTune ? 0.06 : 0);
    let reboundFront = (frontCriticalDamping * frontReboundRatio) / 520;
    let reboundRear = (rearCriticalDamping * rearReboundRatio) / 520;
    reboundFront = clampNumber(reboundFront, 1, 20);
    reboundRear = clampNumber(reboundRear, 1, 20);

    let bumpFront = reboundFront * surfaceProfile.bumpToReboundRatio;
    let bumpRear = reboundRear * surfaceProfile.bumpToReboundRatio;
    bumpFront = clampNumber(bumpFront, 1, 20);
    bumpRear = clampNumber(bumpRear, 1, 20);

    let aeroDemand = speedN
        + ((targetLatG - 1) * 0.55)
        + (isRaceTune ? 0.24 : 0)
        + (isDriftTune ? 0.05 : 0)
        - (isLooseSurface ? 0.24 : 0)
        - (isDragTune ? 0.6 : 0);
    aeroDemand = clampNumber(aeroDemand, 0, 1.3);
    let aeroFront = isDragTune ? 0 : (aeroDemand >= 1 ? 2 : (aeroDemand >= 0.55 ? 1 : 0));
    let aeroRear = isDragTune ? 0 : (aeroDemand >= 0.72 ? 1 : 0);
    aeroFront = clampNumber(Math.round(aeroFront), 0, 2);
    aeroRear = clampNumber(Math.round(aeroRear), 0, 1);

    const dynamicFrontBrakeShare = clampNumber(
        frontBias
        + 0.06
        + (0.05 * speedN)
        - (driveType === 'RWD' ? 0.02 : 0)
        - (isLooseSurface ? 0.02 : 0),
        0.35,
        0.65
    );
    let brakeBalance = dynamicFrontBrakeShare * 100;
    let brakeForce = 58
        + (55 * totalGrip)
        + (18 * speedN)
        + (12 * piN)
        + (isDragTune ? 8 : 0)
        - (isLooseSurface ? 14 : 0);
    brakeBalance = clampNumber(brakeBalance, 35, 65);
    brakeForce = clampNumber(brakeForce, 50, 150);

    let frontDifferential = 0;
    let rearDifferential = 0;
    let centerDifferential = 0;

    const diffAggression = clampNumber(
        0.35
        + (0.45 * differentialTier)
        + (0.25 * torqueN)
        + (isDriftTune ? 0.2 : 0)
        + (isDragTune ? 0.15 : 0),
        0,
        1.4
    );

    if (driveType === 'FWD') {
        frontDifferential = clampNumber(
            22
            + (48 * diffAggression)
            + (isDragTune ? 6 : 0)
            - (isLooseSurface ? 8 : 0),
            0,
            100
        );
    } else if (driveType === 'RWD') {
        rearDifferential = clampNumber(
            28
            + (52 * diffAggression)
            + (isDriftTune ? 10 : 0)
            + (isDragTune ? 8 : 0)
            - (isLooseSurface ? 6 : 0),
            0,
            100
        );
    } else {
        frontDifferential = clampNumber(
            14
            + (32 * diffAggression)
            + (isDriftTune ? 8 : 0)
            - (isLooseSurface ? 6 : 0),
            0,
            100
        );
        rearDifferential = clampNumber(
            26
            + (42 * diffAggression)
            + (isDriftTune ? 12 : 0)
            + (isDragTune ? 6 : 0)
            - (isLooseSurface ? 5 : 0),
            0,
            100
        );
        centerDifferential = clampNumber(
            40
            + (36 * diffAggression)
            + (isDriftTune ? 16 : 0)
            + (isDragTune ? 10 : 0)
            - (isLooseSurface ? 10 : 0),
            0,
            100
        );
    }

    const cards = [
        {
            title: 'Pressure (bar)',
            sliders: [
                { side: 'F', value: pressureFront, min: 1, max: 3, step: 0.01, decimals: 2, suffix: ' bar' },
                { side: 'R', value: pressureRear, min: 1, max: 3, step: 0.01, decimals: 2, suffix: ' bar' }
            ]
        },
        {
            title: 'Camber',
            sliders: [
                { side: 'F', value: camberFront, min: -5, max: 5, step: 0.01, decimals: 2, suffix: '\u00b0' },
                { side: 'R', value: camberRear, min: -5, max: 5, step: 0.01, decimals: 2, suffix: '\u00b0' }
            ]
        },
        {
            title: 'Gearing',
            sliders: [
                { side: 'Final', value: gearingFinal, min: 2.2, max: 5.8, step: 0.01, decimals: 2 }
            ]
        },
        {
            title: 'Toe',
            sliders: [
                { side: 'F', value: toeFront, min: -1, max: 1, step: 0.01, decimals: 2, suffix: '\u00b0' },
                { side: 'R', value: toeRear, min: -1, max: 1, step: 0.01, decimals: 2, suffix: '\u00b0' }
            ]
        },
        {
            title: 'Caster',
            sliders: [
                { side: 'F', value: casterFront, min: 0, max: 10, step: 0.01, decimals: 2, suffix: '\u00b0' },
                { side: 'R', value: casterRear, min: 0, max: 10, step: 0.01, decimals: 2, suffix: '\u00b0' }
            ]
        },
        {
            title: 'Anti-roll Bars',
            sliders: [
                { side: 'F', value: antiRollFront, min: 1, max: 65, step: 0.1, decimals: 1 },
                { side: 'R', value: antiRollRear, min: 1, max: 65, step: 0.1, decimals: 1 }
            ]
        },
        {
            title: 'Springs (N/mm)',
            sliders: [
                { side: 'F', value: springFront, min: 20, max: 260, step: 0.1, decimals: 1, suffix: ' N/mm' },
                { side: 'R', value: springRear, min: 20, max: 260, step: 0.1, decimals: 1, suffix: ' N/mm' }
            ]
        },
        {
            title: 'Ride Height (Min)',
            sliders: [
                { side: 'F', value: rideHeightFront, min: 0, max: 100, step: 1, decimals: 0, suffix: ' min' },
                { side: 'R', value: rideHeightRear, min: 0, max: 100, step: 1, decimals: 0, suffix: ' min' }
            ]
        },
        {
            title: 'Rebound',
            sliders: [
                { side: 'F', value: reboundFront, min: 1, max: 20, step: 0.1, decimals: 1 },
                { side: 'R', value: reboundRear, min: 1, max: 20, step: 0.1, decimals: 1 }
            ]
        },
        {
            title: 'Bump',
            sliders: [
                { side: 'F', value: bumpFront, min: 1, max: 20, step: 0.1, decimals: 1 },
                { side: 'R', value: bumpRear, min: 1, max: 20, step: 0.1, decimals: 1 }
            ]
        },
        {
            title: 'Aero Downforce (Optional)',
            sliders: [
                { side: 'F', value: aeroFront, min: 0, max: 2, step: 1, labels: ['Low', 'Med', 'High'] },
                { side: 'R', value: aeroRear, min: 0, max: 1, step: 1, labels: ['Low', 'Med'] }
            ]
        },
        {
            title: 'Braking',
            sliders: [
                { side: 'Balance', value: brakeBalance, min: 35, max: 65, step: 0.1, decimals: 1, suffix: '%' },
                { side: 'Force', value: brakeForce, min: 50, max: 150, step: 0.1, decimals: 1, suffix: '%' }
            ]
        },
        {
            title: 'Front Differential',
            sliders: [
                { side: 'Front', value: frontDifferential, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%' }
            ]
        },
        {
            title: 'Rear Differential',
            sliders: [
                { side: 'Rear', value: rearDifferential, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%' }
            ]
        },
        {
            title: 'Center (%)',
            sliders: [
                { side: 'Center', value: centerDifferential, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%' }
            ]
        }
    ];

    const drivingSurfaceLabel = resolveLocalizedSegmentLabel('create-driving-surface-group', drivingSurface, drivingSurface);
    const tuneTypeLabel = resolveLocalizedSegmentLabel('create-tune-type-group', tuneType, tuneType);
    const subtitle = `${selectedBrand} ${selectedModel} \u2022 ${driveType} \u2022 ${drivingSurfaceLabel} \u2022 ${tuneTypeLabel} \u2022 PI ${Math.round(currentPi)}`;
    const contextToken = `${Math.round(weightKg)}kg / ${Math.round(maxTorqueNm)}N-m / ${Math.round(topSpeedKmh)}km/h / ${Math.round(redlineRpm)}rpm / ${Math.round(torquePeakRpm)}rpm / ${Math.round(tireWidth)}-${Math.round(tireAspect)}R${Math.round(tireRim)} / ${tireType} / ${differentialType}`;

    return {
        meta: {
            brand: selectedBrand,
            model: selectedModel,
            driveType,
            surface: drivingSurface,
            tuneType,
            pi: Math.round(currentPi),
            topSpeedKmh: Number(topSpeedKmh),
            weightKg: Number(weightKg),
            frontDistributionPercent: Number(frontDistributionPercent),
            maxTorqueNm: Number(maxTorqueNm),
            gears: Number(gears),
            tireWidth: Number(tireWidth),
            tireAspect: Number(tireAspect),
            tireRim: Number(tireRim),
            powerBand: {
                scaleMax: Number(powerBand.scaleMax),
                redlineRpm: Number(powerBand.redlineRpm),
                maxTorqueRpm: Number(powerBand.maxTorqueRpm),
                isCustomScale: Boolean(powerBand.isCustomScale),
                customScaleMax: Number(powerBand.customScaleMax)
            }
        },
        subtitle: `${subtitle}\n${contextToken}`,
        cards
    };
}

function buildTuneCalcGearingDetails(card, payloadMeta = {}) {
    const cardKey = normalizeSegmentKey(card?.title);
    if (!cardKey.includes('gearing')) {
        return null;
    }

    const sliders = Array.isArray(card?.sliders) ? card.sliders : [];
    const finalSlider = sliders.find((slider) => normalizeSegmentKey(slider?.side) === 'final') || sliders[0] || null;
    const finalDrive = Number(finalSlider?.value);
    const gearCount = clampNumber(Math.round(Number(payloadMeta?.gears) || 6), 2, 10);
    const estimated = buildEstimatedGearRatios(gearCount, finalDrive);
    const gearsLabel = getSettingsLanguageText('overlayGearsLabel') || 'gears';
    const ratioMin = Math.min(...estimated.ratios, 0.35);
    const ratioMax = Math.max(...estimated.ratios, 4.2);
    const extraSliders = estimated.ratios.map((ratio, index) => ({
        side: `G${index + 1}`,
        value: Number(ratio),
        min: Number(ratioMin),
        max: Number(ratioMax),
        step: 0.01,
        decimals: 2,
        isDerived: true
    }));
    const graphData = buildTuneCalcGearingGraphData(estimated, payloadMeta);

    return {
        summary: `FD ${estimated.finalDrive.toFixed(2)} · ${gearCount} ${gearsLabel}`,
        extraSliders,
        graphData
    };
}

function buildTuneCalcGearingGraphData(estimated, payloadMeta = {}) {
    if (!estimated || !Array.isArray(estimated.ratios) || !estimated.ratios.length) {
        return null;
    }

    const redlineRpm = clampNumber(Number(payloadMeta?.powerBand?.redlineRpm) || 9000, 3000, 20000);
    const topSpeedKmh = clampNumber(Number(payloadMeta?.topSpeedKmh) || 280, 80, 540);
    const tireWidth = clampNumber(Number(payloadMeta?.tireWidth) || 255, 120, 500);
    const tireAspect = clampNumber(Number(payloadMeta?.tireAspect) || 35, 20, 80);
    const tireRim = clampNumber(Number(payloadMeta?.tireRim) || 19, 13, 24);
    const tireCircumferenceM = getTireCircumferenceMeters(tireWidth, tireAspect, tireRim);
    const finalDrive = clampNumber(Number(estimated.finalDrive) || 3.5, 2.2, 5.8);
    const safeRatios = estimated.ratios
        .map((ratio) => clampNumber(Number(ratio) || 0.1, 0.1, 8))
        .filter((ratio) => Number.isFinite(ratio));

    if (!safeRatios.length) {
        return null;
    }

    const gearTopSpeedsKmh = safeRatios.map((gearRatio) => {
        const wheelRpm = redlineRpm / Math.max(gearRatio * finalDrive, 0.12);
        const speedMps = (wheelRpm / 60) * tireCircumferenceM;
        return clampNumber(speedMps * 3.6, 6, 640);
    });

    const scaleMaxKmh = clampNumber(
        Math.ceil((Math.max(...gearTopSpeedsKmh, topSpeedKmh) + 5) / 10) * 10,
        120,
        680
    );

    const segments = safeRatios.map((gearRatio, index) => {
        const previousRatio = index > 0 ? safeRatios[index - 1] : null;
        const startRpm = previousRatio
            ? clampNumber(redlineRpm * (gearRatio / previousRatio), 0, redlineRpm)
            : 0;
        const startSpeedKmh = index > 0
            ? clampNumber(gearTopSpeedsKmh[index - 1], 0, scaleMaxKmh)
            : 0;
        const endSpeedKmh = clampNumber(gearTopSpeedsKmh[index], startSpeedKmh, scaleMaxKmh);
        return {
            gear: index + 1,
            startRpm,
            endRpm: redlineRpm,
            startSpeedKmh,
            endSpeedKmh
        };
    });

    return {
        finalDrive,
        gearCount: safeRatios.length,
        redlineRpm,
        scaleMaxKmh,
        segments
    };
}

function getTuneGearingGraphDisplaySettings(graphData) {
    const unitSystem = normalizeUnitSystem(settingsState.unitSystem || 'metric');
    const speedUnitLabel = UNIT_SYSTEMS[unitSystem]?.speedLabel || 'km/h';
    const scaleMaxDisplay = Math.max(
        10,
        Number(convertMetricToDisplay(graphData.scaleMaxKmh, 'speed', unitSystem)) || graphData.scaleMaxKmh
    );
    const yAxisMaxRpm = Math.max(Number(graphData.redlineRpm) || 0, 1000);
    return {
        unitSystem,
        speedUnitLabel,
        scaleMaxDisplay,
        yAxisMaxRpm
    };
}

function renderTuneGearingGraphModal(graphData) {
    if (!graphData || !tuneGearingGraphSvg) {
        return;
    }

    const display = getTuneGearingGraphDisplaySettings(graphData);
    const { unitSystem, speedUnitLabel, scaleMaxDisplay, yAxisMaxRpm } = display;

    const xMin = 0;
    const xMid = Math.round(scaleMaxDisplay / 2);
    const xMax = Math.round(scaleMaxDisplay);
    const yMax = yAxisMaxRpm;
    const yMid = yMax / 2;
    const chartWidth = 100;
    const chartHeight = 56;
    const chartTop = 1.2;
    const chartBottom = chartHeight - 1.2;
    const chartPlotHeight = chartBottom - chartTop;
    const toChartX = (speed) => clampNumber((Number(speed) / Math.max(scaleMaxDisplay, 1)) * chartWidth, 0, chartWidth);
    const toChartY = (rpm) => {
        const clamped = clampNumber(Number(rpm) || 0, 0, yMax);
        return clampNumber(chartBottom - ((clamped / Math.max(yMax, 1)) * chartPlotHeight), chartTop, chartBottom);
    };

    if (tuneGearingGraphTitle) {
        tuneGearingGraphTitle.textContent = getSettingsLanguageText('tuneResultsGearingModalTitle');
    }
    if (tuneGearingGraphYLabel) {
        tuneGearingGraphYLabel.textContent = getSettingsLanguageText('tuneResultsGearingRpmAxisLabel');
    }
    if (tuneGearingGraphMetaFinal) {
        tuneGearingGraphMetaFinal.textContent = `FD ${formatDisplayValue(graphData.finalDrive, 2)}`;
    }
    if (tuneGearingGraphMetaGears) {
        tuneGearingGraphMetaGears.textContent = `${graphData.gearCount} ${getSettingsLanguageText('overlayGearsLabel')}`;
    }
    if (tuneGearingGraphYMax) {
        tuneGearingGraphYMax.textContent = formatDisplayValue(yMax / 1000, 1);
    }
    if (tuneGearingGraphYMid) {
        tuneGearingGraphYMid.textContent = formatDisplayValue(yMid / 1000, 1);
    }
    if (tuneGearingGraphYMin) {
        tuneGearingGraphYMin.textContent = '0';
    }
    if (tuneGearingGraphXMin) {
        tuneGearingGraphXMin.textContent = String(xMin);
    }
    if (tuneGearingGraphXMid) {
        tuneGearingGraphXMid.textContent = String(xMid);
    }
    if (tuneGearingGraphXMax) {
        tuneGearingGraphXMax.textContent = String(xMax);
    }
    if (tuneGearingGraphXLabel) {
        tuneGearingGraphXLabel.textContent = String(speedUnitLabel || 'km/h').toLowerCase();
    }
    tuneGearingGraphSvg.setAttribute(
        'aria-label',
        `${getSettingsLanguageText('tuneResultsGearingModalTitle')} · ${speedUnitLabel}`
    );

    const horizontalDivisions = 8;
    const verticalDivisions = 12;
    const gridLines = [];
    for (let i = 0; i <= horizontalDivisions; i += 1) {
        const y = chartTop + ((i / horizontalDivisions) * chartPlotHeight);
        gridLines.push(`<line x1="0" y1="${y.toFixed(2)}" x2="100" y2="${y.toFixed(2)}" class="tune-gearing-graph-grid-line" />`);
    }
    for (let i = 0; i <= verticalDivisions; i += 1) {
        const x = (i / verticalDivisions) * chartWidth;
        gridLines.push(`<line x1="${x.toFixed(2)}" y1="${chartTop.toFixed(2)}" x2="${x.toFixed(2)}" y2="${chartBottom.toFixed(2)}" class="tune-gearing-graph-grid-line" />`);
    }

    const gearSegments = Array.isArray(graphData.segments) ? graphData.segments : [];
    const segmentLines = [];
    for (let index = 0; index < gearSegments.length; index += 1) {
        const segment = gearSegments[index];
        const startDisplaySpeed = Number(convertMetricToDisplay(segment.startSpeedKmh, 'speed', unitSystem));
        const endDisplaySpeed = Number(convertMetricToDisplay(segment.endSpeedKmh, 'speed', unitSystem));
        const x1 = toChartX(startDisplaySpeed);
        const x2 = clampNumber(toChartX(endDisplaySpeed), x1, chartWidth);
        const y1 = toChartY(segment.startRpm);
        const y2 = toChartY(segment.endRpm);
        segmentLines.push(`
            <line
                x1="${x1.toFixed(2)}"
                y1="${y1.toFixed(2)}"
                x2="${x2.toFixed(2)}"
                y2="${y2.toFixed(2)}"
                class="tune-gearing-graph-line"
            />
        `);
    }

    const redlineY = toChartY(graphData.redlineRpm);
    const frame = `<rect x="0.2" y="${chartTop.toFixed(2)}" width="99.6" height="${chartPlotHeight.toFixed(2)}" class="tune-gearing-graph-frame" />`;
    const redline = `<line x1="0" y1="${redlineY.toFixed(2)}" x2="100" y2="${redlineY.toFixed(2)}" class="tune-gearing-graph-redline" />`;

    tuneGearingGraphSvg.innerHTML = `
        ${frame}
        <g class="tune-gearing-graph-grid">${gridLines.join('')}</g>
        ${redline}
        <g class="tune-gearing-graph-lines">${segmentLines.join('')}</g>
    `;
    if (tuneGearingGraphLegend) {
        tuneGearingGraphLegend.innerHTML = '';
        tuneGearingGraphLegend.hidden = true;
    }
}

function renderTuneCalcModalContent(payload) {
    if (!tuneCalcList) {
        return;
    }

    if (tuneCalcSubtitle) {
        tuneCalcSubtitle.textContent = getSettingsLanguageText('tuneResultsSubtitle');
    }

    const unitSystem = normalizeUnitSystem(settingsState.unitSystem);
    const payloadMeta = payload?.meta || {};
    const displayCards = buildDisplayTuneCards(payload.cards || [], unitSystem);
    tuneCalcGearingGraphCache.clear();
    activeTuneGearingGraphKey = '';

    tuneCalcList.innerHTML = displayCards.map((card, cardIndex) => {
        const cardKey = normalizeSegmentKey(card?.title);
        const baseSliders = Array.isArray(card.sliders) ? card.sliders : [];
        const gearingDetails = buildTuneCalcGearingDetails(card, payloadMeta);
        const graphKey = gearingDetails?.graphData ? `gearing-${cardIndex}` : '';
        if (graphKey) {
            tuneCalcGearingGraphCache.set(graphKey, gearingDetails.graphData);
        }
        const sliders = gearingDetails?.extraSliders
            ? [...baseSliders, ...gearingDetails.extraSliders]
            : baseSliders;
        const pairClass = sliders.length > 1 ? ' has-pair' : '';
        const pressureClass = cardKey.includes('pressure') ? ' tune-calc-card--pressure' : '';
        const camberClass = cardKey.includes('camber') ? ' tune-calc-card--camber' : '';
        const gearingClass = cardKey.includes('gearing') ? ' tune-calc-card--gearing' : '';
        const graphButtonMarkup = graphKey
            ? `
                <button
                    class="tune-calc-graph-btn no-drag"
                    type="button"
                    data-gearing-graph-key="${escapeHtml(graphKey)}"
                    aria-label="${escapeHtml(getSettingsLanguageText('tuneResultsGearingChartTitle'))}"
                    title="${escapeHtml(getSettingsLanguageText('tuneResultsGearingChartTitle'))}"
                >
                    <span class="material-symbols-outlined">query_stats</span>
                </button>
            `
            : '';
        const sliderMarkup = sliders.map((slider) => {
            const progress = getTuneCalcSliderProgress(slider).toFixed(2);
            const valueLabel = formatTuneCalcSliderValue(slider);
            return `
                <div class="tune-calc-slider-item${slider.isDerived ? ' is-derived' : ''}">
                    <div class="tune-calc-slider-meta">
                        <span class="tune-calc-slider-side">${escapeHtml(String(slider.side || 'Value'))}</span>
                        <span class="tune-calc-slider-value">${escapeHtml(valueLabel)}</span>
                    </div>
                    <input
                        class="tune-calc-slider no-drag"
                        type="range"
                        min="${Number(slider.min)}"
                        max="${Number(slider.max)}"
                        step="${Number(slider.step)}"
                        value="${Number(slider.value)}"
                        style="--calc-progress:${progress}%"
                        disabled
                    />
                </div>
            `;
        }).join('');

        return `
            <section class="tune-calc-card${gearingDetails ? ' is-gearing' : ''}${pressureClass}${camberClass}${gearingClass}">
                <div class="tune-calc-card-head${graphButtonMarkup ? ' has-action' : ''}">
                    <p class="tune-calc-card-title">${escapeHtml(String(card.title || 'Tune'))}</p>
                    ${graphButtonMarkup}
                </div>
                <div class="tune-calc-sliders${pairClass}">
                    ${sliderMarkup}
                </div>
            </section>
        `;
    }).join('');
}

function normalizeTuneCalcLayoutMode(mode) {
    return mode === 'expanded' ? 'expanded' : 'compact';
}

function syncTuneCalcLayoutUi() {
    tuneCalcLayoutMode = normalizeTuneCalcLayoutMode(tuneCalcLayoutMode);
    const isExpanded = tuneCalcLayoutMode === 'expanded';

    if (tuneCalcModalPanel) {
        tuneCalcModalPanel.classList.toggle('is-layout-expanded', isExpanded);
    }

    if (tuneCalcLayoutIcon) {
        tuneCalcLayoutIcon.textContent = isExpanded ? 'view_agenda' : 'view_comfy_alt';
    }

    if (tuneCalcLayoutBtn) {
        const titleKey = isExpanded ? 'tuneResultsLayoutCompactTitle' : 'tuneResultsLayoutExpandedTitle';
        const buttonTitle = getSettingsLanguageText(titleKey);
        tuneCalcLayoutBtn.setAttribute('title', buttonTitle);
        tuneCalcLayoutBtn.setAttribute('aria-label', buttonTitle);
    }
}

function syncTuneCalcOverlayButtonUi() {
    if (!tuneCalcOverlayBtn || !tuneCalcOverlayIcon) {
        return;
    }

    const overlayEnabled = Boolean(settingsState.overlayMode);
    tuneCalcOverlayBtn.classList.toggle('is-active', overlayEnabled);
    tuneCalcOverlayIcon.textContent = overlayEnabled ? 'picture_in_picture' : 'picture_in_picture_alt';
    const titleKey = overlayEnabled ? 'tuneResultsOverlayDisableTitle' : 'tuneResultsOverlayEnableTitle';
    const title = getSettingsLanguageText(titleKey);
    tuneCalcOverlayBtn.setAttribute('title', title);
    tuneCalcOverlayBtn.setAttribute('aria-label', title);
}

function toggleTuneCalcLayoutMode() {
    tuneCalcLayoutMode = tuneCalcLayoutMode === 'expanded' ? 'compact' : 'expanded';
    syncTuneCalcLayoutUi();
}

function clearTuneCalcHideTimer() {
    if (tuneCalcHideTimer) {
        clearTimeout(tuneCalcHideTimer);
        tuneCalcHideTimer = null;
    }
}

function isTuneCalcModalOpen() {
    return Boolean(tuneCalcModal && !tuneCalcModal.classList.contains('hidden') && tuneCalcModal.classList.contains('is-open'));
}

function sanitizeTuneName(value) {
    return String(value || '')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 64);
}

function extractShareCodeDigits(value) {
    return String(value || '')
        .replace(/\D/g, '')
        .slice(0, 9);
}

function formatShareCodeInGame(value) {
    const digits = extractShareCodeDigits(value);
    if (!digits) {
        return '';
    }
    return digits.replace(/(\d{3})(?=\d)/g, '$1 ').trim();
}

function sanitizeShareCode(value) {
    return formatShareCodeInGame(value);
}

function buildDefaultTuneName(payload) {
    const meta = payload?.meta || {};
    const brand = String(meta.brand || '').trim();
    const model = String(meta.model || '').trim();
    const tuneType = String(meta.tuneType || 'Tune').trim();
    return `${brand} ${model} ${tuneType}`.replace(/\s+/g, ' ').trim() || getSettingsLanguageText('genericUntitledTune');
}

function syncTuneSaveInputs(payload) {
    const editingRecord = isCreateTuneEditMode() ? findGarageTuneById(createTuneEditRecordId) : null;
    const editingMeta = editingRecord?.meta || null;

    if (tuneSaveNameInput) {
        tuneSaveNameInput.value = editingMeta?.tuneName
            ? sanitizeTuneName(editingMeta.tuneName)
            : buildDefaultTuneName(payload);
    }
    if (tuneSaveShareInput) {
        tuneSaveShareInput.value = editingMeta?.shareCode
            ? sanitizeShareCode(editingMeta.shareCode)
            : '';
    }
}

function openTuneCalcModal() {
    if (!tuneCalcModal || !createCalcBtn || createCalcBtn.disabled) {
        return;
    }

    closeTuneGearingGraphModal({ immediate: true });
    clearTuneCalcHideTimer();
    const payload = buildTuneCalculationPayload();
    lastTuneCalculationPayload = payload;
    syncTuneSaveInputs(payload);
    renderTuneCalcModalContent(payload);
    syncTuneCalcLayoutUi();
    setActiveOverlayTune(buildOverlayTuneRecordFromPayload(payload), { forceShow: true, persist: false });
    tuneCalcModal.classList.remove('hidden');
    tuneCalcModal.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => {
        if (!tuneCalcModal) {
            return;
        }
        tuneCalcModal.classList.add('is-open');
    });
}

function closeTuneCalcModal({ immediate = false } = {}) {
    if (!tuneCalcModal) {
        return;
    }

    closeTuneGearingGraphModal({ immediate: true });
    clearTuneCalcHideTimer();
    tuneCalcModal.classList.remove('is-open');

    const hideModal = () => {
        tuneCalcModal.classList.add('hidden');
        tuneCalcModal.setAttribute('aria-hidden', 'true');
    };

    if (immediate) {
        hideModal();
        return;
    }

    tuneCalcHideTimer = setTimeout(() => {
        hideModal();
        tuneCalcHideTimer = null;
    }, 240);
}

function clearTuneGearingGraphHideTimer() {
    if (tuneGearingGraphHideTimer) {
        clearTimeout(tuneGearingGraphHideTimer);
        tuneGearingGraphHideTimer = null;
    }
}

function isTuneGearingGraphModalOpen() {
    return Boolean(
        tuneGearingGraphModal
        && !tuneGearingGraphModal.classList.contains('hidden')
        && tuneGearingGraphModal.classList.contains('is-open')
    );
}

function openTuneGearingGraphModal(graphKey) {
    if (!tuneGearingGraphModal || !graphKey) {
        return;
    }

    const graphData = tuneCalcGearingGraphCache.get(String(graphKey));
    if (!graphData) {
        return;
    }

    activeTuneGearingGraphKey = String(graphKey);
    clearTuneGearingGraphHideTimer();
    renderTuneGearingGraphModal(graphData);
    tuneGearingGraphModal.classList.remove('hidden');
    tuneGearingGraphModal.setAttribute('aria-hidden', 'false');

    requestAnimationFrame(() => {
        if (!tuneGearingGraphModal) {
            return;
        }
        tuneGearingGraphModal.classList.add('is-open');
    });
}

function closeTuneGearingGraphModal({ immediate = false } = {}) {
    if (!tuneGearingGraphModal) {
        return;
    }

    clearTuneGearingGraphHideTimer();
    tuneGearingGraphModal.classList.remove('is-open');
    activeTuneGearingGraphKey = '';

    const hideModal = () => {
        tuneGearingGraphModal.classList.add('hidden');
        tuneGearingGraphModal.setAttribute('aria-hidden', 'true');
    };

    if (immediate) {
        hideModal();
        return;
    }

    tuneGearingGraphHideTimer = setTimeout(() => {
        hideModal();
        tuneGearingGraphHideTimer = null;
    }, 220);
}

function initTuneCalcControls() {
    if (createCalcBtn) {
        createCalcBtn.addEventListener('click', () => {
            if (createCalcBtn.disabled) {
                return;
            }
            closePowerBandModal({ immediate: true });
            openTuneCalcModal();
        });
    }

    if (tuneCalcLayoutBtn) {
        tuneCalcLayoutBtn.addEventListener('click', () => {
            toggleTuneCalcLayoutMode();
        });
    }

    if (tuneCalcOverlayBtn) {
        tuneCalcOverlayBtn.addEventListener('click', () => {
            setOverlayModeEnabled(!settingsState.overlayMode);
            saveSettings(false);
        });
    }

    if (tuneCalcList) {
        tuneCalcList.addEventListener('click', (event) => {
            const graphTrigger = event.target.closest('[data-gearing-graph-key]');
            if (!graphTrigger) {
                return;
            }
            const graphKey = graphTrigger.getAttribute('data-gearing-graph-key');
            openTuneGearingGraphModal(graphKey);
        });
    }

    if (tuneCalcModalCloseBtn) {
        tuneCalcModalCloseBtn.addEventListener('click', () => {
            closeTuneCalcModal();
        });
    }

    if (tuneGearingGraphCloseBtn) {
        tuneGearingGraphCloseBtn.addEventListener('click', () => {
            closeTuneGearingGraphModal();
        });
    }

    if (tuneGearingGraphBackdrop) {
        tuneGearingGraphBackdrop.addEventListener('click', () => {
            closeTuneGearingGraphModal();
        });
    }

    if (tuneCalcSaveBtn) {
        tuneCalcSaveBtn.addEventListener('click', () => {
            const payload = lastTuneCalculationPayload || buildTuneCalculationPayload();
            const tuneName = sanitizeTuneName(tuneSaveNameInput?.value) || buildDefaultTuneName(payload);
            const shareCode = sanitizeShareCode(tuneSaveShareInput?.value);
            const saveOptions = {
                tuneName,
                shareCode,
                recordId: isCreateTuneEditMode() ? createTuneEditRecordId : ''
            };
            saveTuneResultToGarage(payload, saveOptions);
            setActiveOverlayTune(buildOverlayTuneRecordFromPayload(payload, { tuneName, shareCode }), {
                forceShow: true,
                persist: false
            });
            setCreateTuneEditRecord(null);
            navigateToGaragePage();
        });
    }

    if (tuneSaveShareInput) {
        tuneSaveShareInput.addEventListener('input', () => {
            const sanitized = sanitizeShareCode(tuneSaveShareInput.value);
            if (sanitized !== tuneSaveShareInput.value) {
                tuneSaveShareInput.value = sanitized;
            }
        });
    }

    if (tuneCalcModalBackdrop) {
        tuneCalcModalBackdrop.addEventListener('click', () => {
            closeTuneCalcModal();
        });
    }

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && isTuneGearingGraphModalOpen()) {
            event.preventDefault();
            closeTuneGearingGraphModal();
            return;
        }
        if (event.key === 'Escape' && isTuneCalcModalOpen()) {
            event.preventDefault();
            closeTuneCalcModal();
        }
    });
}

function normalizeBrandLogoKey(value) {
    return String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '');
}

function toBrandLogoSlug(value) {
    return String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/&/g, 'and')
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
}

function getBrandLogoFallbackText(brand) {
    const normalized = String(brand || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '');
    const tokens = normalized.split(/[^a-zA-Z0-9]+/).filter(Boolean);

    if (!tokens.length) {
        return '--';
    }
    if (tokens.length === 1) {
        return tokens[0].slice(0, 2).toUpperCase();
    }
    return `${tokens[0].charAt(0)}${tokens[1].charAt(0)}`.toUpperCase();
}

function getBrandLogoUrlCandidates(brand) {
    const logoKey = normalizeBrandLogoKey(brand);
    const defaultSlug = toBrandLogoSlug(brand);
    const primarySlug = BRAND_LOGO_CARLOGO_SLUG_OVERRIDES[logoKey] || defaultSlug;
    const secondarySlug = BRAND_LOGO_GITHUB_SLUG_OVERRIDES[logoKey] || primarySlug;
    const slugCandidates = Array.from(new Set([primarySlug, secondarySlug, defaultSlug].filter(Boolean)));
    const urlCandidates = [];

    slugCandidates.forEach((slug) => {
        urlCandidates.push(`https://www.carlogos.org/car-logos/${encodeURIComponent(slug)}-logo.png`);
        urlCandidates.push(`https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/optimized/${encodeURIComponent(slug)}.png`);
    });

    return urlCandidates;
}

function getBrandLogoUrl(brand) {
    const candidates = getBrandLogoUrlCandidates(brand);
    if (!candidates.length) {
        return null;
    }
    return candidates[0];
}

function getBrandLogoMarkup(brand) {
    const logoKey = normalizeBrandLogoKey(brand);
    const logoUrl = vehicleBrandLogoResolvedUrlCache.get(logoKey) || getBrandLogoUrl(brand);
    const fallbackText = escapeHtml(getBrandLogoFallbackText(brand));
    const logoImageMarkup = logoUrl
        ? `<img class="vehicle-brand-logo-img" src="${logoUrl}" data-logo-key="${escapeHtml(logoKey)}" alt="" loading="lazy" referrerpolicy="no-referrer" />`
        : '';

    return `
        <span class="vehicle-brand-logo${logoUrl ? '' : ' is-fallback'}" aria-hidden="true">
            ${logoImageMarkup}
            <span class="vehicle-brand-logo-fallback">${fallbackText}</span>
        </span>
    `;
}

function bindBrandLogoFallbacks(container) {
    if (!container) {
        return;
    }

    container.querySelectorAll('.vehicle-brand-logo-img').forEach((img) => {
        const logoNode = img.closest('.vehicle-brand-logo');
        const logoKey = String(img.dataset.logoKey || '').trim();

        const applyFallback = () => {
            if (logoNode) {
                logoNode.classList.add('is-fallback');
            }
        };

        const clearFallback = () => {
            if (logoNode) {
                logoNode.classList.remove('is-fallback');
            }
        };

        img.addEventListener('load', () => {
            clearFallback();
            if (logoKey) {
                vehicleBrandLogoResolvedUrlCache.set(logoKey, img.currentSrc || img.src);
            }
        });
        img.addEventListener('error', applyFallback);

        if (img.complete) {
            if (img.naturalWidth > 0) {
                clearFallback();
                if (logoKey) {
                    vehicleBrandLogoResolvedUrlCache.set(logoKey, img.currentSrc || img.src);
                }
            } else {
                applyFallback();
            }
        }
    });
}

function setVehiclePreviewCaptionLogoState(brand = '') {
    if (!vehiclePreviewCaptionLogo || !vehiclePreviewCaptionLogoFallback) {
        return;
    }

    const fallbackText = getBrandLogoFallbackText(brand);
    vehiclePreviewCaptionLogoFallback.textContent = fallbackText;

    const logoKey = normalizeBrandLogoKey(brand);
    const cachedLogoUrl = vehicleBrandLogoResolvedUrlCache.get(logoKey);
    const logoUrls = getBrandLogoUrlCandidates(brand);
    if (cachedLogoUrl) {
        logoUrls.unshift(cachedLogoUrl);
    }
    const uniqueLogoUrls = Array.from(new Set(logoUrls));

    if (!vehiclePreviewCaptionLogoImg || !uniqueLogoUrls.length) {
        vehiclePreviewCaptionLogo.classList.add('is-fallback');
        if (vehiclePreviewCaptionLogoImg) {
            vehiclePreviewCaptionLogoImg.removeAttribute('src');
        }
        return;
    }

    const requestToken = ++vehiclePreviewLogoRequestToken;
    vehiclePreviewCaptionLogo.classList.add('is-fallback');

    const loadLogoCandidate = (index) => {
        if (requestToken !== vehiclePreviewLogoRequestToken) {
            return;
        }
        if (index >= uniqueLogoUrls.length) {
            vehiclePreviewCaptionLogo.classList.add('is-fallback');
            return;
        }

        const logoUrl = uniqueLogoUrls[index];
        const currentSrc = vehiclePreviewCaptionLogoImg.getAttribute('src');
        if (currentSrc === logoUrl && vehiclePreviewCaptionLogoImg.complete) {
            if (vehiclePreviewCaptionLogoImg.naturalWidth > 0) {
                vehicleBrandLogoResolvedUrlCache.set(logoKey, logoUrl);
                vehiclePreviewCaptionLogo.classList.remove('is-fallback');
                return;
            }
            loadLogoCandidate(index + 1);
            return;
        }

        vehiclePreviewCaptionLogoImg.onload = () => {
            if (requestToken !== vehiclePreviewLogoRequestToken) {
                return;
            }
            vehicleBrandLogoResolvedUrlCache.set(logoKey, logoUrl);
            vehiclePreviewCaptionLogo.classList.remove('is-fallback');
        };
        vehiclePreviewCaptionLogoImg.onerror = () => {
            if (requestToken !== vehiclePreviewLogoRequestToken) {
                return;
            }
            loadLogoCandidate(index + 1);
        };
        vehiclePreviewCaptionLogoImg.src = logoUrl;
    };

    loadLogoCandidate(0);
}

function escapeHtml(value) {
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function normalizeWikiSearchValue(value) {
    return normalizeSearchValue(
        String(value || '')
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
    );
}

function buildVehiclePreviewCacheKey(brand, model) {
    return `${normalizeSearchValue(brand)}|||${normalizeSearchValue(model)}`;
}

function probeVehiclePreviewImage(url) {
    if (!url) {
        return Promise.resolve(false);
    }

    const cachedProbe = vehiclePreviewImageProbeCache.get(url);
    if (cachedProbe) {
        return cachedProbe;
    }

    const probePromise = new Promise((resolve) => {
        const tester = new Image();
        tester.referrerPolicy = 'no-referrer';
        tester.onload = () => {
            resolve(true);
        };
        tester.onerror = () => {
            resolve(false);
        };
        tester.src = url;
    });

    vehiclePreviewImageProbeCache.set(url, probePromise);
    return probePromise;
}

function setVehiclePreviewPlaceholderState(message, caption = '', brand = '') {
    if (!vehiclePreviewWrap || !vehiclePreviewPlaceholder || !vehiclePreviewImage || !vehiclePreviewCaption) {
        return;
    }

    vehiclePreviewWrap.classList.remove('has-image');
    vehiclePreviewPlaceholder.textContent = message;
    vehiclePreviewPlaceholder.classList.remove('is-hidden');
    vehiclePreviewImage.classList.remove('is-visible');
    vehiclePreviewImage.removeAttribute('src');
    vehiclePreviewImage.alt = '';
    setVehiclePreviewCaptionState(caption, false, brand);
}

function setVehiclePreviewVisibility(isVisible) {
    if (!vehiclePreviewWrap) {
        return;
    }

    vehiclePreviewWrap.classList.toggle('is-visible', Boolean(isVisible));
    if (!isVisible) {
        vehiclePreviewWrap.classList.remove('has-image');
        if (vehiclePreviewPiBadge) {
            vehiclePreviewPiBadge.classList.remove('is-visible');
            vehiclePreviewPiBadge.classList.add('is-empty');
        }
        if (vehiclePreviewSpecs) {
            vehiclePreviewSpecs.classList.remove('is-visible');
        }
    }
}

function setVehiclePreviewCaptionState(text = '', isVisible = false, brand = '') {
    if (!vehiclePreviewCaption) {
        return;
    }

    const captionText = String(text || '');
    const captionValue = `${String(brand || '')}|||${captionText}`;
    vehiclePreviewCaption.dataset.captionValue = captionValue;
    setVehiclePreviewCaptionLogoState(brand);
    if (vehiclePreviewCaptionText) {
        vehiclePreviewCaptionText.textContent = captionText;
    } else {
        vehiclePreviewCaption.textContent = captionText;
    }
    vehiclePreviewCaption.classList.remove('is-visible');
    vehiclePreviewCaption.classList.add('is-hidden');

    if (!isVisible || !captionText) {
        return;
    }

    requestAnimationFrame(() => {
        if (!vehiclePreviewCaption || vehiclePreviewCaption.dataset.captionValue !== captionValue) {
            return;
        }
        vehiclePreviewCaption.classList.remove('is-hidden');
        vehiclePreviewCaption.classList.add('is-visible');
    });
}

function setVehiclePreviewImageState(src, label, brand = '') {
    if (!vehiclePreviewWrap || !vehiclePreviewPlaceholder || !vehiclePreviewImage || !vehiclePreviewCaption) {
        return;
    }

    vehiclePreviewWrap.classList.add('has-image');
    vehiclePreviewImage.src = src;
    vehiclePreviewImage.alt = `${label} ${getSettingsLanguageText('vehiclePreviewAlt')}`;
    vehiclePreviewImage.classList.add('is-visible');
    vehiclePreviewPlaceholder.classList.add('is-hidden');
    setVehiclePreviewCaptionState(label, true, brand);
}

function buildForzaWikiSearchQueries(brand, model) {
    const fullName = `${brand} ${model}`.trim();
    const modelName = String(model || '').trim();
    const fullNameAscii = `${normalizeWikiSearchValue(brand)} ${normalizeWikiSearchValue(model)}`.trim();
    const modelNameAscii = normalizeWikiSearchValue(model);

    const candidates = [
        `"${fullName}"`,
        `"${modelName}"`,
        `"${fullNameAscii}"`,
        `"${modelNameAscii}"`,
        `${fullName} Forza Horizon 5`,
        `${modelName} Forza Horizon 5`
    ];

    return Array.from(new Set(candidates.filter(Boolean)));
}

function scoreForzaWikiPage(page, brand, model) {
    const title = normalizeWikiSearchValue(page?.title || '');
    const brandToken = normalizeWikiSearchValue(brand);
    const modelToken = normalizeWikiSearchValue(model);
    let score = 0;

    if (modelToken && title.includes(modelToken)) {
        score += 7;
    }
    if (brandToken && title.includes(brandToken)) {
        score += 4;
    }
    if (title.includes('forza horizon 5') || title.includes('fh5')) {
        score += 2;
    }
    if (title.includes('forza edition')) {
        score += 1;
    }
    if (title.includes('series') || title.includes('season') || title.includes('festival') || title.includes('playlist')) {
        score -= 6;
    }
    if (title.includes('update') || title.includes('patch notes')) {
        score -= 4;
    }

    return score;
}

async function fetchForzaWikiUrlsByQuery(query, brand, model) {
    const endpoint = `https://forza.fandom.com/api.php?action=query&format=json&origin=*&generator=search&gsrnamespace=0&gsrsearch=${encodeURIComponent(query)}&gsrlimit=8&prop=pageimages|info&piprop=original|thumbnail&pithumbsize=960&inprop=url`;
    const response = await fetch(endpoint, { cache: 'default' });
    if (!response.ok) {
        return [];
    }

    const payload = await response.json();
    const pages = Object.values(payload?.query?.pages || {})
        .filter((page) => page?.ns === 0)
        .filter((page) => !String(page.title || '').includes('/'))
        .filter((page) => Boolean(page?.original?.source || page?.thumbnail?.source))
        .sort((a, b) => {
            const scoreDiff = scoreForzaWikiPage(b, brand, model) - scoreForzaWikiPage(a, brand, model);
            if (scoreDiff !== 0) {
                return scoreDiff;
            }
            return (a.index || Number.MAX_SAFE_INTEGER) - (b.index || Number.MAX_SAFE_INTEGER);
        });

    return pages
        .map((page) => page.thumbnail?.source || page.original?.source)
        .filter(Boolean);
}

async function fetchVehiclePreviewIngameUrls(brand, model) {
    const previewKey = buildVehiclePreviewCacheKey(brand, model);
    if (vehiclePreviewSourceUrlCache.has(previewKey)) {
        return vehiclePreviewSourceUrlCache.get(previewKey) || [];
    }

    const pendingRequest = vehiclePreviewSourceRequestCache.get(previewKey);
    if (pendingRequest) {
        return pendingRequest;
    }

    const searchQueries = buildForzaWikiSearchQueries(brand, model);
    const fetchPromise = Promise.allSettled(
        searchQueries.map((query) => fetchForzaWikiUrlsByQuery(query, brand, model))
    )
        .then((results) => {
            const collectedUrls = [];
            results.forEach((result) => {
                if (result.status === 'fulfilled' && Array.isArray(result.value) && result.value.length) {
                    collectedUrls.push(...result.value);
                }
            });

            const uniqueUrls = Array.from(new Set(collectedUrls)).slice(0, MAX_PREVIEW_CANDIDATES);
            vehiclePreviewSourceUrlCache.set(previewKey, uniqueUrls);
            return uniqueUrls;
        })
        .catch(() => [])
        .finally(() => {
            vehiclePreviewSourceRequestCache.delete(previewKey);
        });

    vehiclePreviewSourceRequestCache.set(previewKey, fetchPromise);
    return fetchPromise;
}

async function loadVehiclePreviewWithFallback(urls, label, brand, model, token) {
    if (token !== vehiclePreviewRequestToken) {
        return;
    }

    const previewKey = buildVehiclePreviewCacheKey(brand, model);

    for (let index = 0; index < urls.length; index += 1) {
        if (token !== vehiclePreviewRequestToken) {
            return;
        }

        const candidateUrl = urls[index];
        const canLoad = await probeVehiclePreviewImage(candidateUrl);
        if (token !== vehiclePreviewRequestToken) {
            return;
        }

        if (!canLoad) {
            continue;
        }

        vehiclePreviewResolvedUrlCache.set(previewKey, candidateUrl);
        setVehiclePreviewImageState(candidateUrl, label, brand);
        return;
    }

    setVehiclePreviewPlaceholderState(getSettingsLanguageText('vehiclePreviewIngameFailed'), label, brand);
}

async function updateVehiclePreview() {
    if (!vehiclePreviewWrap || !vehiclePreviewImage || !vehiclePreviewPlaceholder || !vehiclePreviewCaption) {
        return;
    }

    const token = ++vehiclePreviewRequestToken;

    if (isCreateTuneVehicleListUpdating()) {
        setVehiclePreviewVisibility(false);
        setVehiclePreviewPlaceholderState(getSettingsLanguageText('createVehicleListUpdating'));
        return;
    }

    const hasSelectedModel = Boolean(vehicleBrowserState.selectedBrand && vehicleBrowserState.selectedModel);
    if (!hasSelectedModel) {
        setVehiclePreviewVisibility(false);
        setVehiclePreviewPlaceholderState(getSettingsLanguageText('createVehiclePreviewPlaceholder'));
        return;
    }

    setVehiclePreviewVisibility(true);
    const brand = vehicleBrowserState.selectedBrand;
    const model = vehicleBrowserState.selectedModel;
    const label = `${brand} ${model}`;
    const previewKey = buildVehiclePreviewCacheKey(brand, model);
    const cachedPreviewUrl = vehiclePreviewResolvedUrlCache.get(previewKey);
    if (cachedPreviewUrl) {
        setVehiclePreviewImageState(cachedPreviewUrl, label, brand);
        return;
    }

    setVehiclePreviewPlaceholderState(
        formatLocalizedText('vehiclePreviewLoadingLabel', { label }),
        label,
        brand
    );

    const sourceUrls = await fetchVehiclePreviewIngameUrls(brand, model);
    if (token !== vehiclePreviewRequestToken) {
        return;
    }

    const previewCandidates = sourceUrls.length ? sourceUrls : FORZA_INGAME_FALLBACK_URLS;
    loadVehiclePreviewWithFallback(previewCandidates, label, brand, model, token);
}

function updateVehicleSelectionLabel() {
    const hasSelectedModel = Boolean(vehicleBrowserState.selectedBrand && vehicleBrowserState.selectedModel);
    if (selectedVehicleInline) {
        selectedVehicleInline.textContent = hasSelectedModel
            ? ` - ${vehicleBrowserState.selectedModel}`
            : '';
    }

    if (selectedVehicleLabel) {
        selectedVehicleLabel.textContent = '';
    }

    updateVehiclePreview();
    updateSelectedVehicleSpecFields();
    updateCreateCalcButtonState();
}

function toOptionalNumber(value) {
    if (value === null || value === undefined || value === '') {
        return null;
    }

    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : null;
}

function toOptionalPi(value) {
    const numeric = toOptionalNumber(value);
    if (numeric === null) {
        return null;
    }
    return Math.round(numeric);
}

function toOptionalTopSpeed(value) {
    const numeric = toOptionalNumber(value);
    if (numeric === null) {
        return null;
    }
    return Number(numeric.toFixed(1));
}

function formatTopSpeedMeta(value, unitSystem = settingsState.unitSystem) {
    const speed = toOptionalTopSpeed(value);
    if (speed === null) {
        return null;
    }

    const normalizedUnit = normalizeUnitSystem(unitSystem);
    const convertedSpeed = convertMetricToDisplay(speed, 'speed', normalizedUnit);
    const speedLabel = UNIT_SYSTEMS[normalizedUnit]?.speedLabel || 'km/h';
    return `${formatDisplayValue(convertedSpeed, 1)} ${speedLabel}`;
}

function formatWeightMeta(value, unitSystem = settingsState.unitSystem) {
    const numeric = toOptionalNumber(value);
    if (numeric === null) {
        return null;
    }

    const normalizedUnit = normalizeUnitSystem(unitSystem);
    const convertedWeight = convertMetricToDisplay(numeric, 'weight', normalizedUnit);
    const weightLabel = UNIT_SYSTEMS[normalizedUnit]?.weightLabel || 'kg';
    return `${formatDisplayValue(convertedWeight, 0)} ${weightLabel}`;
}

function formatPiMeta(value) {
    const pi = toOptionalPi(value);
    return pi === null ? null : `PI ${pi}`;
}

function getVehicleModelTireScore(tireType) {
    const normalized = normalizeSegmentKey(tireType);
    if (normalized.includes('slick') && !normalized.includes('semi')) {
        return 93;
    }
    if (normalized.includes('semi')) {
        return 86;
    }
    if (normalized.includes('sport')) {
        return 77;
    }
    if (normalized.includes('offroad') || normalized.includes('rally')) {
        return 64;
    }
    if (normalized.includes('drag')) {
        return 70;
    }
    return 68;
}

function getVehicleModelDifferentialScore(differentialType) {
    const normalized = normalizeSegmentKey(differentialType);
    if (normalized.includes('race')) {
        return 92;
    }
    if (normalized.includes('sport')) {
        return 78;
    }
    if (normalized.includes('drift')) {
        return 84;
    }
    if (normalized.includes('drag')) {
        return 82;
    }
    return 66;
}

function getVehicleModelInfoCard(cards, token) {
    const normalizedToken = normalizeSegmentKey(token);
    if (!normalizedToken || !Array.isArray(cards)) {
        return null;
    }
    return cards.find((card) => normalizeSegmentKey(card?.title).includes(normalizedToken)) || null;
}

function getVehicleModelInfoSlider(card, sideToken) {
    const normalizedSide = normalizeSegmentKey(sideToken);
    if (!normalizedSide || !card || !Array.isArray(card.sliders)) {
        return null;
    }

    return card.sliders.find((slider) => {
        const normalized = normalizeSegmentKey(slider?.side);
        return normalized === normalizedSide || normalized.includes(normalizedSide);
    }) || null;
}

function buildVehicleModelInfoRow(label, slider, fallback = null) {
    const source = slider || fallback;
    if (!source) {
        return { label, value: '--', progress: 0 };
    }

    return {
        label,
        value: formatTuneCalcSliderValue(source),
        progress: getTuneCalcSliderProgress(source)
    };
}

function buildVehicleModelDetailSections() {
    const buildFallbackSections = () => ([
        {
            key: 'tires',
            title: getSettingsLanguageText('createModelInfoSectionTiresAlignment') || 'Tires & Alignment',
            color: '#3b82f6',
            rows: [
                { label: 'Front Pressure', value: '--', progress: 0 },
                { label: 'Rear Pressure', value: '--', progress: 0 },
                { label: 'Front Camber', value: '--', progress: 0 },
                { label: 'Rear Camber', value: '--', progress: 0 },
                { label: 'Front Toe', value: '--', progress: 0 },
                { label: 'Rear Toe', value: '--', progress: 0 }
            ]
        },
        {
            key: 'springs',
            title: getSettingsLanguageText('createModelInfoSectionSpringsDampers') || 'Springs & Dampers',
            color: '#f59e0b',
            rows: [
                { label: 'Front Stiffness', value: '--', progress: 0 },
                { label: 'Rear Stiffness', value: '--', progress: 0 },
                { label: 'Front Height', value: '--', progress: 0 },
                { label: 'Rear Height', value: '--', progress: 0 },
                { label: 'Front Rebound', value: '--', progress: 0 },
                { label: 'Rear Rebound', value: '--', progress: 0 },
                { label: 'Front Bump', value: '--', progress: 0 },
                { label: 'Rear Bump', value: '--', progress: 0 }
            ]
        },
        {
            key: 'aero',
            title: getSettingsLanguageText('createModelInfoSectionAero') || 'Aerodynamics',
            color: '#8b5cf6',
            rows: [
                { label: 'Front Downforce', value: '--', progress: 0 },
                { label: 'Rear Downforce', value: '--', progress: 0 }
            ]
        },
        {
            key: 'drivetrain',
            title: getSettingsLanguageText('createModelInfoSectionDrivetrain') || 'Drivetrain & Diff',
            color: '#22c55e',
            rows: [
                { label: 'Differential Front Accel', value: '--', progress: 0 },
                { label: 'Differential Front Decel', value: '--', progress: 0 },
                { label: 'Differential Rear Accel', value: '--', progress: 0 },
                { label: 'Differential Rear Decel', value: '--', progress: 0 }
            ]
        },
        {
            key: 'brakes',
            title: getSettingsLanguageText('createModelInfoSectionBrakes') || 'Brakes',
            color: '#f43f5e',
            rows: [
                { label: 'Front Balance', value: '--', progress: 0 },
                { label: 'Rear Balance', value: '--', progress: 0 },
                { label: 'Pressure', value: '--', progress: 0 }
            ]
        }
    ]);

    const payload = buildTuneCalculationPayload();
    const displayCards = buildDisplayTuneCards(payload?.cards, settingsState.unitSystem);
    if (!Array.isArray(displayCards) || !displayCards.length) {
        return buildFallbackSections();
    }

    const pressureCard = getVehicleModelInfoCard(displayCards, 'pressure');
    const camberCard = getVehicleModelInfoCard(displayCards, 'camber');
    const toeCard = getVehicleModelInfoCard(displayCards, 'toe');
    const springsCard = getVehicleModelInfoCard(displayCards, 'springs');
    const rideHeightCard = getVehicleModelInfoCard(displayCards, 'rideheight');
    const reboundCard = getVehicleModelInfoCard(displayCards, 'rebound');
    const bumpCard = getVehicleModelInfoCard(displayCards, 'bump');
    const aeroCard = getVehicleModelInfoCard(displayCards, 'aerodownforce');
    const frontDiffCard = getVehicleModelInfoCard(displayCards, 'frontdifferential');
    const rearDiffCard = getVehicleModelInfoCard(displayCards, 'reardifferential');
    const brakingCard = getVehicleModelInfoCard(displayCards, 'braking');

    const frontDiffAccel = getVehicleModelInfoSlider(frontDiffCard, 'front');
    const rearDiffAccel = getVehicleModelInfoSlider(rearDiffCard, 'rear');
    const frontDiffDecelValue = frontDiffAccel
        ? clampNumber((Number(frontDiffAccel.value) || 0) * 0.36, 0, 100)
        : 0;
    const rearDiffDecelValue = rearDiffAccel
        ? clampNumber((Number(rearDiffAccel.value) || 0) * 0.42, 0, 100)
        : 0;
    const frontDiffDecel = { value: frontDiffDecelValue, min: 0, max: 100, decimals: 1, suffix: '%' };
    const rearDiffDecel = { value: rearDiffDecelValue, min: 0, max: 100, decimals: 1, suffix: '%' };

    const brakeBalanceSlider = getVehicleModelInfoSlider(brakingCard, 'balance');
    const brakeForceSlider = getVehicleModelInfoSlider(brakingCard, 'force');
    const rearBalanceValue = brakeBalanceSlider
        ? clampNumber(100 - (Number(brakeBalanceSlider.value) || 50), 35, 65)
        : null;
    const rearBalanceSlider = rearBalanceValue === null
        ? null
        : { value: rearBalanceValue, min: 35, max: 65, decimals: 1, suffix: '%' };

    return [
        {
            key: 'tires',
            title: getSettingsLanguageText('createModelInfoSectionTiresAlignment') || 'Tires & Alignment',
            color: '#3b82f6',
            rows: [
                buildVehicleModelInfoRow('Front Pressure', getVehicleModelInfoSlider(pressureCard, 'f')),
                buildVehicleModelInfoRow('Rear Pressure', getVehicleModelInfoSlider(pressureCard, 'r')),
                buildVehicleModelInfoRow('Front Camber', getVehicleModelInfoSlider(camberCard, 'f')),
                buildVehicleModelInfoRow('Rear Camber', getVehicleModelInfoSlider(camberCard, 'r')),
                buildVehicleModelInfoRow('Front Toe', getVehicleModelInfoSlider(toeCard, 'f')),
                buildVehicleModelInfoRow('Rear Toe', getVehicleModelInfoSlider(toeCard, 'r'))
            ]
        },
        {
            key: 'springs',
            title: getSettingsLanguageText('createModelInfoSectionSpringsDampers') || 'Springs & Dampers',
            color: '#f59e0b',
            rows: [
                buildVehicleModelInfoRow('Front Stiffness', getVehicleModelInfoSlider(springsCard, 'f')),
                buildVehicleModelInfoRow('Rear Stiffness', getVehicleModelInfoSlider(springsCard, 'r')),
                buildVehicleModelInfoRow('Front Height', getVehicleModelInfoSlider(rideHeightCard, 'f')),
                buildVehicleModelInfoRow('Rear Height', getVehicleModelInfoSlider(rideHeightCard, 'r')),
                buildVehicleModelInfoRow('Front Rebound', getVehicleModelInfoSlider(reboundCard, 'f')),
                buildVehicleModelInfoRow('Rear Rebound', getVehicleModelInfoSlider(reboundCard, 'r')),
                buildVehicleModelInfoRow('Front Bump', getVehicleModelInfoSlider(bumpCard, 'f')),
                buildVehicleModelInfoRow('Rear Bump', getVehicleModelInfoSlider(bumpCard, 'r'))
            ]
        },
        {
            key: 'aero',
            title: getSettingsLanguageText('createModelInfoSectionAero') || 'Aerodynamics',
            color: '#8b5cf6',
            rows: [
                buildVehicleModelInfoRow('Front Downforce', getVehicleModelInfoSlider(aeroCard, 'f')),
                buildVehicleModelInfoRow('Rear Downforce', getVehicleModelInfoSlider(aeroCard, 'r'))
            ]
        },
        {
            key: 'drivetrain',
            title: getSettingsLanguageText('createModelInfoSectionDrivetrain') || 'Drivetrain & Diff',
            color: '#22c55e',
            rows: [
                buildVehicleModelInfoRow('Differential Front Accel', frontDiffAccel, { value: 0, min: 0, max: 100, decimals: 1, suffix: '%' }),
                buildVehicleModelInfoRow('Differential Front Decel', null, frontDiffDecel),
                buildVehicleModelInfoRow('Differential Rear Accel', rearDiffAccel, { value: 0, min: 0, max: 100, decimals: 1, suffix: '%' }),
                buildVehicleModelInfoRow('Differential Rear Decel', null, rearDiffDecel)
            ]
        },
        {
            key: 'brakes',
            title: getSettingsLanguageText('createModelInfoSectionBrakes') || 'Brakes',
            color: '#f43f5e',
            rows: [
                buildVehicleModelInfoRow('Front Balance', brakeBalanceSlider),
                buildVehicleModelInfoRow('Rear Balance', rearBalanceSlider),
                buildVehicleModelInfoRow('Pressure', brakeForceSlider)
            ]
        }
    ];
}

function deriveVehicleModelPerformance(specs) {
    if (!specs) {
        return null;
    }

    const pi = toOptionalPi(specs.pi);
    const topSpeedKmh = toOptionalTopSpeed(specs.topSpeedKmh);
    const selectedDriveTypeKey = getActiveCapsuleOptionKey(createDriveTypeGroup, specs.driveType || 'fwd');
    const driveType = normalizeDriveType(selectedDriveTypeKey) || toPreviewDriveType(specs.driveType);
    const tireType = toPreviewSpecText(specs.tireType);
    const differentialType = toPreviewSpecText(specs.differential);
    const compactTireType = tireType === '--'
        ? '--'
        : tireType.replace(/\s*tire$/i, '').trim() || tireType;
    const compactDifferentialType = differentialType === '--'
        ? '--'
        : differentialType.replace(/\s*differential$/i, '').trim() || differentialType;

    const piNormalized = pi === null ? 0.52 : clampNumber((pi - 100) / 899, 0, 1);
    const speedNormalized = topSpeedKmh === null ? 0.5 : clampNumber((topSpeedKmh - 120) / 320, 0, 1);
    const frontDistributionPercent = clampNumber(readNumericFieldValue(createFrontDistributionInput, 50), 30, 70);
    const frontBiasNormalized = clampNumber((frontDistributionPercent - 50) / 20, -1, 1);
    const tireScore = getVehicleModelTireScore(tireType);
    const differentialScore = getVehicleModelDifferentialScore(differentialType);
    const driveLaunchBonus = driveType === 'AWD' ? 14 : driveType === 'RWD' ? 9 : driveType === 'FWD' ? 6 : 8;
    const driveHandlingBonus = driveType === 'AWD' ? 8 : driveType === 'RWD' ? 6 : driveType === 'FWD' ? 4 : 5;

    const activeSurfaceKey = normalizeSurfaceSegmentKey(getActiveCapsuleOptionKey(createDrivingSurfaceGroup, 'street'));
    const activeTuneTypeKey = normalizeTuneTypeSegmentKey(getActiveCapsuleOptionKey(createTuneTypeGroup, 'race'));

    const normalizedTireKey = normalizeSegmentKey(tireType);
    const isDragTire = normalizedTireKey.includes('drag');
    const isOffroadTire = normalizedTireKey.includes('offroad') || normalizedTireKey.includes('rally');
    const isSlickTire = normalizedTireKey.includes('slick') && !normalizedTireKey.includes('semi');
    const isSemiSlickTire = normalizedTireKey.includes('semi');

    const gripBiasByTire = isSlickTire ? 1.08 : isSemiSlickTire ? 1.05 : isDragTire ? 0.9 : isOffroadTire ? 0.95 : 1;
    const launchBiasByTire = isDragTire ? 1.16 : isSlickTire ? 1.04 : isOffroadTire ? 0.92 : 1;
    const speedBiasByTire = isOffroadTire ? 0.9 : isDragTire ? 0.97 : 1;

    const driveLaunchBias = driveType === 'AWD' ? 1.12 : driveType === 'RWD' ? 1.04 : driveType === 'FWD' ? 0.95 : 1;
    const driveGripBias = driveType === 'AWD' ? 1.08 : driveType === 'RWD' ? 1.01 : driveType === 'FWD' ? 0.96 : 1;
    const driveSpeedBonus = driveType === 'RWD' ? 3.5 : driveType === 'AWD' ? 1.6 : driveType === 'FWD' ? -1 : 0;

    const surfaceGripBias = activeSurfaceKey === 'street' ? 1.04
        : activeSurfaceKey === 'dirt' ? 1.1
            : activeSurfaceKey === 'cross' ? 1.06
                : activeSurfaceKey === 'offroad' ? 1.12
                    : 1;
    const surfaceSpeedBias = activeSurfaceKey === 'street' ? 1.04
        : activeSurfaceKey === 'cross' ? 0.97
            : activeSurfaceKey === 'dirt' ? 0.94
                : activeSurfaceKey === 'offroad' ? 0.9
                    : 1;
    const surfaceLaunchBias = activeSurfaceKey === 'street' ? 1.03
        : activeSurfaceKey === 'cross' ? 1.05
            : activeSurfaceKey === 'dirt' ? 1.08
                : activeSurfaceKey === 'offroad' ? 1.1
                    : 1;

    const tuneGripBias = activeTuneTypeKey === 'race' ? 1.06
        : activeTuneTypeKey === 'rain' ? 1.09
            : activeTuneTypeKey === 'rally' || activeTuneTypeKey === 'truck' || activeTuneTypeKey === 'buggy' ? 1.07
                : activeTuneTypeKey === 'drift' ? 1.02
                    : 1;
    const tuneSpeedBias = activeTuneTypeKey === 'drag' ? 1.1
        : activeTuneTypeKey === 'race' ? 1.04
            : activeTuneTypeKey === 'rain' ? 0.96
                : activeTuneTypeKey === 'rally' || activeTuneTypeKey === 'truck' || activeTuneTypeKey === 'buggy' ? 0.95
                    : 1;
    const tuneLaunchBias = activeTuneTypeKey === 'drag' ? 1.17
        : activeTuneTypeKey === 'drift' ? 1.07
            : activeTuneTypeKey === 'rally' || activeTuneTypeKey === 'truck' || activeTuneTypeKey === 'buggy' ? 1.11
                : activeTuneTypeKey === 'race' ? 1.05
                    : 1;
    const brakingContextBias = activeTuneTypeKey === 'rain' ? 1.08
        : activeTuneTypeKey === 'drag' ? 0.94
            : activeSurfaceKey === 'offroad' ? 0.9
                : activeSurfaceKey === 'dirt' ? 0.93
                    : 1;
    const balanceHandlingModifier = clampNumber((-frontBiasNormalized) * 7, -6, 6);
    const balanceLaunchModifier = driveType === 'FWD'
        ? clampNumber(frontBiasNormalized * 8, -6, 6)
        : driveType === 'RWD'
            ? clampNumber((-frontBiasNormalized) * 4, -4, 4)
            : clampNumber(frontBiasNormalized * 2, -2, 2);
    const balanceBrakingModifier = clampNumber(frontBiasNormalized * 6, -6, 6);

    const rawGripScore =
        (tireScore * 0.58)
        + (differentialScore * 0.16)
        + (piNormalized * 20)
        + (speedNormalized * 6)
        + (driveHandlingBonus * 1.2)
        + balanceHandlingModifier;
    const handlingScore = Math.round(
        clampNumber(rawGripScore * gripBiasByTire * driveGripBias * surfaceGripBias * tuneGripBias, 16, 99)
    );

    const rawLaunchScore =
        (tireScore * 0.34)
        + (differentialScore * 0.24)
        + (piNormalized * 26)
        + (speedNormalized * 8)
        + (driveLaunchBonus * 2.2)
        + balanceLaunchModifier;
    const launchScore = Math.round(
        clampNumber(rawLaunchScore * launchBiasByTire * driveLaunchBias * surfaceLaunchBias * tuneLaunchBias, 12, 99)
    );

    const rawSpeedScore = (speedNormalized * 82) + (piNormalized * 20) + (differentialScore * 0.06) + driveSpeedBonus;
    const speedScore = Math.round(
        clampNumber(rawSpeedScore * speedBiasByTire * surfaceSpeedBias * tuneSpeedBias, 12, 99)
    );

    const accelScore = Math.round(
        clampNumber((launchScore * 0.48) + (speedScore * 0.36) + (handlingScore * 0.16), 14, 99)
    );

    const rawBrakingScore =
        (tireScore * 0.62)
        + (differentialScore * 0.1)
        + (piNormalized * 18)
        + (driveHandlingBonus * 1.1)
        + (isSlickTire ? 2 : 0)
        + balanceBrakingModifier;
    const brakingScore = Math.round(clampNumber(rawBrakingScore * brakingContextBias, 16, 99));

    const unitSystem = normalizeUnitSystem(settingsState.unitSystem);
    const speedUnit = UNIT_SYSTEMS[unitSystem]?.speedLabel || 'km/h';
    const convertedTopSpeed = topSpeedKmh === null
        ? null
        : convertMetricToDisplay(topSpeedKmh, 'speed', unitSystem);
    const topSpeedDisplay = convertedTopSpeed === null
        ? '--'
        : `${formatDisplayValue(convertedTopSpeed, 1)} ${speedUnit}`;

    return {
        pi,
        topSpeedDisplay,
        driveType,
        tireType: compactTireType,
        differentialType: compactDifferentialType,
        detailSections: buildVehicleModelDetailSections(),
        metrics: [
            {
                key: 'speed',
                label: getSettingsLanguageText('createModelInfoSpeed') || 'Speed',
                color: '#ff6a1f',
                score: speedScore,
                value: convertedTopSpeed === null ? '--' : String(Math.round(convertedTopSpeed))
            },
            {
                key: 'handling',
                label: getSettingsLanguageText('createModelInfoHandling') || 'Handling',
                color: '#13d9c6',
                score: handlingScore,
                value: String(handlingScore)
            },
            {
                key: 'accel',
                label: getSettingsLanguageText('createModelInfoAccel') || 'Accel',
                color: '#ffb020',
                score: accelScore,
                value: String(accelScore)
            },
            {
                key: 'launch',
                label: getSettingsLanguageText('createModelInfoLaunch') || 'Launch',
                color: '#a66bff',
                score: launchScore,
                value: String(launchScore)
            },
            {
                key: 'braking',
                label: getSettingsLanguageText('createModelInfoBraking') || 'Braking',
                color: '#2d86ff',
                score: brakingScore,
                value: String(brakingScore)
            }
        ]
    };
}

function setVehicleModelInfoState(modelInfo) {
    if (!vehicleModelInfo || !vehicleModelStats || !vehicleModelMetrics) {
        return;
    }

    if (!modelInfo || !Array.isArray(modelInfo.metrics) || !modelInfo.metrics.length) {
        vehicleModelStats.innerHTML = '';
        vehicleModelMetrics.innerHTML = '';
        vehicleModelInfo.classList.remove('is-visible');
        createCardModelInfo?.classList.remove('has-model-info');
        createTuneGrid?.classList.remove('has-model-info');
        scheduleCreateLayoutStabilize();
        return;
    }

    vehicleModelStats.innerHTML = modelInfo.metrics
        .map((metric) => {
            const score = clampNumber(Number(metric.score) || 0, 0, 100);
            return `
                <article class="vehicle-model-stat" style="--model-stat-color:${escapeHtml(metric.color)}; --model-stat-value:${score};">
                    <span class="vehicle-model-stat-label">${escapeHtml(metric.label)}</span>
                    <span class="vehicle-model-stat-ring">
                        <span class="vehicle-model-stat-value">${escapeHtml(String(metric.value))}</span>
                    </span>
                </article>
            `;
        })
        .join('');

    const summaryItems = [
        {
            label: getSettingsLanguageText('createModelInfoTire') || 'Tire',
            value: modelInfo.tireType || '--'
        },
        {
            label: getSettingsLanguageText('createModelInfoDifferential') || 'Differential',
            value: modelInfo.differentialType || '--'
        }
    ];

    const summaryMarkup = summaryItems
        .map((item) => `
            <span class="vehicle-model-summary-chip">
                <span class="vehicle-model-summary-key">${escapeHtml(item.label)}</span>
                <span class="vehicle-model-summary-value">${escapeHtml(item.value)}</span>
            </span>
        `)
        .join('');

    const detailSections = Array.isArray(modelInfo.detailSections) ? modelInfo.detailSections : [];
    const detailMarkup = detailSections
        .map((section) => {
            const rows = Array.isArray(section.rows) ? section.rows : [];
            const rowsMarkup = rows
                .map((row) => {
                    const progress = clampNumber(Number(row.progress) || 0, 0, 100);
                    return `
                        <div class="vehicle-model-detail-row">
                            <div class="vehicle-model-detail-row-meta">
                                <span class="vehicle-model-detail-row-label">${escapeHtml(String(row.label || '--'))}</span>
                                <span class="vehicle-model-detail-row-value">${escapeHtml(String(row.value || '--'))}</span>
                            </div>
                            <span class="vehicle-model-detail-row-track">
                                <span class="vehicle-model-detail-row-fill" style="width:${progress}%"></span>
                            </span>
                        </div>
                    `;
                })
                .join('');

            return `
                <article class="vehicle-model-detail-card" style="--vehicle-model-detail-color:${escapeHtml(section.color || '#ff6a1f')}">
                    <header class="vehicle-model-detail-head">
                        <span class="vehicle-model-detail-dot" aria-hidden="true"></span>
                        <h4 class="vehicle-model-detail-title">${escapeHtml(String(section.title || '--'))}</h4>
                    </header>
                    <div class="vehicle-model-detail-rows">
                        ${rowsMarkup}
                    </div>
                </article>
            `;
        })
        .join('');

    vehicleModelMetrics.innerHTML = `
        <div class="vehicle-model-summary">${summaryMarkup}</div>
        <div class="vehicle-model-detail-grid">${detailMarkup}</div>
    `;

    vehicleModelInfo.classList.add('is-visible');
    createCardModelInfo?.classList.add('has-model-info');
    createTuneGrid?.classList.add('has-model-info');
    scheduleCreateLayoutStabilize();
}

function buildVehicleListPiBadgeMarkup(piValue) {
    const pi = toOptionalPi(piValue);
    const tier = getPiTierConfig(pi);
    if (!tier || pi === null) {
        return '';
    }

    const lightClass = tier.lightTier ? ' is-light-tier' : '';
    const ariaLabel = `${tier.label} ${pi}`;
    return `
        <span class="vehicle-item-pi-badge pi-badge${lightClass}" style="--pi-tier-color:${tier.color};" title="${escapeHtml(ariaLabel)}" aria-label="${escapeHtml(ariaLabel)}">
            <span class="pi-chip">${escapeHtml(tier.label)}</span>
        </span>
    `;
}

function toPreviewSpecText(value) {
    if (typeof value !== 'string') {
        return '--';
    }

    const normalizedValue = value.trim();
    return normalizedValue || '--';
}

function toPreviewDriveType(value) {
    return normalizeDriveType(value) || '--';
}

const PREVIEW_ICON_SVGS = {
    driveUnknown: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="7" cy="7" r="2.2"/><circle cx="17" cy="7" r="2.2"/><circle cx="7" cy="17" r="2.2"/><circle cx="17" cy="17" r="2.2"/><path d="M9.2 7h5.6M9.2 17h5.6M7 9.2v5.6M17 9.2v5.6"/></svg>',
    driveAwd: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="6.5" cy="6.5" r="2.1"/><circle cx="17.5" cy="6.5" r="2.1"/><circle cx="6.5" cy="17.5" r="2.1"/><circle cx="17.5" cy="17.5" r="2.1"/><path d="M8.6 6.5h6.8M8.6 17.5h6.8M6.5 8.6v6.8M17.5 8.6v6.8M8.8 8.8l6.4 6.4M15.2 8.8l-6.4 6.4"/></svg>',
    driveFwd: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="7" cy="8" r="2.1"/><circle cx="17" cy="8" r="2.1"/><path d="M7 10.2v6.1M17 10.2v6.1M7 16.3h10"/><path d="M12 17V7.8"/><path d="M9.8 10l2.2-2.2 2.2 2.2"/></svg>',
    driveRwd: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="7" cy="16" r="2.1"/><circle cx="17" cy="16" r="2.1"/><path d="M7 8v5.8M17 8v5.8M7 8h10"/><path d="M12 7v9.1"/><path d="M9.8 13.9 12 16.1l2.2-2.2"/></svg>',
    tireUnknown: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.4"/><circle cx="12" cy="12" r="3.2"/></svg>',
    tireSlick: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.4"/><circle cx="12" cy="12" r="3.2"/><circle cx="12" cy="12" r="0.8"/></svg>',
    tireSemi: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.4"/><circle cx="12" cy="12" r="3.2"/><path d="M12 4.6v2M12 17.4v2M4.6 12h2M17.4 12h2"/></svg>',
    tireSport: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.4"/><circle cx="12" cy="12" r="3.2"/><path d="M7.6 7.6 9 9M15 15l1.4 1.4M15 9l1.4-1.4M7.6 16.4 9 15"/></svg>',
    tireStreet: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="7.4"/><circle cx="12" cy="12" r="3.2"/><path d="M12 4.6v2M12 17.4v2M4.6 12h2M17.4 12h2M7.6 7.6 9 9M15 15l1.4 1.4M15 9l1.4-1.4M7.6 16.4 9 15"/></svg>'
};

function getPreviewDriveIconMeta(value) {
    const driveType = toPreviewDriveType(value);
    const drivePrefix = getSettingsLanguageText('vehiclePreviewDrivePrefix') || 'Drive Type';

    if (driveType === '--') {
        return { icon: 'driveUnknown', code: '--', variant: 'unknown', label: `${drivePrefix}: --` };
    }

    if (driveType === 'AWD') {
        return { icon: 'driveAwd', code: 'AWD', variant: 'awd', label: `${drivePrefix}: AWD` };
    }

    if (driveType === 'FWD') {
        return { icon: 'driveFwd', code: 'FWD', variant: 'fwd', label: `${drivePrefix}: FWD` };
    }

    return { icon: 'driveRwd', code: 'RWD', variant: 'rwd', label: `${drivePrefix}: RWD` };
}

function getPreviewTireIconMeta(value) {
    const normalized = toPreviewSpecText(value);
    const lower = normalized.toLowerCase();
    const tirePrefix = getSettingsLanguageText('vehiclePreviewTirePrefix') || 'Tire Type';

    if (normalized === '--') {
        return { icon: 'tireUnknown', code: '--', variant: 'unknown', label: `${tirePrefix}: --` };
    }

    if (lower.includes('slick') && !lower.includes('semi')) {
        return { icon: 'tireSlick', code: 'SLK', variant: 'slick', label: `${tirePrefix}: ${normalized}` };
    }

    if (lower.includes('semi')) {
        return { icon: 'tireSemi', code: 'S-S', variant: 'semi', label: `${tirePrefix}: ${normalized}` };
    }

    if (lower.includes('sport')) {
        return { icon: 'tireSport', code: 'SPT', variant: 'sport', label: `${tirePrefix}: ${normalized}` };
    }

    return { icon: 'tireStreet', code: 'STR', variant: 'street', label: `${tirePrefix}: ${normalized}` };
}

function updateVehiclePreviewSpecIcon(element, meta) {
    if (!element || !meta) {
        return;
    }

    const glyphElement = element.querySelector('.vehicle-preview-spec-glyph');
    if (glyphElement) {
        const fallbackSvg = element.id === 'vehicle-preview-tire'
            ? PREVIEW_ICON_SVGS.tireUnknown
            : PREVIEW_ICON_SVGS.driveUnknown;
        glyphElement.innerHTML = PREVIEW_ICON_SVGS[meta.icon] || fallbackSvg;
    }

    const codeElement = element.querySelector('.vehicle-preview-spec-code');
    if (codeElement) {
        codeElement.textContent = meta.code || '--';
    }

    element.dataset.variant = meta.variant;
    element.setAttribute('title', meta.label);
    element.setAttribute('aria-label', meta.label);
}

function updateVehiclePreviewSpecs(specs) {
    if (!vehiclePreviewSpecs || !vehiclePreviewDrive || !vehiclePreviewTire) {
        return;
    }

    const driveType = toPreviewDriveType(specs?.driveType);
    const tireType = toPreviewSpecText(specs?.tireType);
    const hasData = driveType !== '--' || tireType !== '--';

    updateVehiclePreviewSpecIcon(vehiclePreviewDrive, getPreviewDriveIconMeta(driveType));
    updateVehiclePreviewSpecIcon(vehiclePreviewTire, getPreviewTireIconMeta(tireType));
    vehiclePreviewSpecs.classList.toggle('is-visible', hasData);
}

function getVehicleSpecs(brand, model) {
    if (!brand || !model) {
        return null;
    }
    const specKey = buildVehicleSpecKey(brand, model);
    return FH5_CAR_SPEC_MAP.get(specKey) || null;
}

function getPiTierConfig(piValue) {
    const pi = toOptionalPi(piValue);
    if (pi === null) {
        return null;
    }

    if (pi >= 999) {
        return { label: 'X', color: '#44c64a', lightTier: false };
    }
    if (pi >= 901) {
        return { label: 'S2', color: '#2c5ec7', lightTier: false };
    }
    if (pi >= 801) {
        return { label: 'S1', color: '#9f57c2', lightTier: false };
    }
    if (pi >= 701) {
        return { label: 'A', color: '#ee2a52', lightTier: false };
    }
    if (pi >= 601) {
        return { label: 'B', color: '#f2791d', lightTier: false };
    }
    if (pi >= 501) {
        return { label: 'C', color: '#f3c638', lightTier: true };
    }
    return { label: 'D', color: '#7ec9ea', lightTier: true };
}

function updatePiBadgeElement(element, piValue, { animate = false } = {}) {
    if (!element) {
        return;
    }

    const pi = toOptionalPi(piValue);
    const tier = getPiTierConfig(pi);

    if (!tier || pi === null) {
        element.style.removeProperty('--pi-tier-color');
        element.classList.remove('is-light-tier');
        element.innerHTML = '<span class="pi-chip">--</span>';
    } else {
        element.style.setProperty('--pi-tier-color', tier.color);
        element.classList.toggle('is-light-tier', Boolean(tier.lightTier));
        element.innerHTML = `<span class="pi-chip">${tier.label}</span>`;
    }

    element.classList.toggle('is-empty', pi === null);

    if (animate) {
        element.classList.toggle('is-visible', pi !== null);
    }
}

function toInputNumberString(value) {
    if (value === null || value === undefined || value === '') {
        return '';
    }

    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return '';
    }

    return Number.isInteger(numeric) ? String(numeric) : String(Number(numeric.toFixed(2)));
}

function convertFieldValueToUnit(field, kind, fromUnit, toUnit, decimals = 1) {
    if (!field || typeof field.value !== 'string') {
        return;
    }

    const rawValue = field.value.trim();
    if (!rawValue) {
        return;
    }

    const numericValue = Number(rawValue);
    if (!Number.isFinite(numericValue)) {
        return;
    }

    const metricValue = convertDisplayToMetric(numericValue, kind, fromUnit);
    const convertedValue = convertMetricToDisplay(metricValue, kind, toUnit);
    if (!Number.isFinite(convertedValue)) {
        return;
    }

    const roundedValue = Number(convertedValue.toFixed(Math.max(0, decimals)));
    field.value = toInputNumberString(roundedValue);
}

function syncCreateTuneUnitUi(unitSystem) {
    const normalizedUnit = normalizeUnitSystem(unitSystem);
    const unitConfig = UNIT_SYSTEMS[normalizedUnit];
    if (!unitConfig) {
        return;
    }

    if (createWeightLabel) {
        createWeightLabel.textContent = formatLocalizedText('createWeightLabelTemplate', { unit: unitConfig.weightLabel });
    }
    if (createWeightInput) {
        createWeightInput.placeholder = formatLocalizedText('createWeightPlaceholderTemplate', { unit: unitConfig.weightLabel });
    }

    if (createTopSpeedLabel) {
        createTopSpeedLabel.textContent = formatLocalizedText('createTopSpeedLabelTemplate', { unit: unitConfig.speedLabel });
    }
    if (createTopSpeedInput) {
        createTopSpeedInput.placeholder = formatLocalizedText('createTopSpeedPlaceholderTemplate', { unit: unitConfig.speedLabel });
    }

    if (createMaxTorqueLabel) {
        createMaxTorqueLabel.textContent = formatLocalizedText('createMaxTorqueLabelTemplate', { unit: unitConfig.torqueLabel });
    }
    if (createMaxTorqueInput) {
        createMaxTorqueInput.placeholder = formatLocalizedText('createMaxTorquePlaceholderTemplate', { unit: unitConfig.torqueLabel });
    }

    if (createUnitGroup) {
        createUnitGroup.querySelectorAll('[data-unit-system]').forEach((option) => {
            const isActive = option.dataset.unitSystem === normalizedUnit;
            option.classList.toggle('is-active', isActive);
        });
        updateCapsuleGroupIndicator(createUnitGroup, false);
    }
}

function setCreateTuneUnitSystem(nextUnitSystem, { persist = true, convertFieldValues = true } = {}) {
    const normalizedNextUnit = normalizeUnitSystem(nextUnitSystem);
    const currentUnit = normalizeUnitSystem(settingsState.unitSystem);

    if (convertFieldValues && currentUnit !== normalizedNextUnit) {
        convertFieldValueToUnit(createWeightInput, 'weight', currentUnit, normalizedNextUnit, 0);
        convertFieldValueToUnit(createTopSpeedInput, 'speed', currentUnit, normalizedNextUnit, 1);
        convertFieldValueToUnit(createMaxTorqueInput, 'torque', currentUnit, normalizedNextUnit, 1);
    }

    settingsState.unitSystem = normalizedNextUnit;
    syncCreateTuneUnitUi(normalizedNextUnit);
    if (vehicleBrowserState.selectedBrand && vehicleBrowserState.selectedModel && !isCreateTuneVehicleListUpdating()) {
        refreshSelectedVehicleModelInfo();
    }
    updateCreateCalcButtonState();
    renderTuneOverlay();

    if (persist) {
        saveSettings(false);
    }
}

function clearVehicleSpecFields() {
    if (createCurrentPiInput) {
        createCurrentPiInput.value = '';
    }
    if (createTopSpeedInput) {
        createTopSpeedInput.value = '';
    }
    updateVehiclePreviewSpecs(null);
    updatePiBadgeElement(createCurrentPiBadge, null);
    updatePiBadgeElement(vehiclePreviewPiBadge, null, { animate: true });
    setVehicleModelInfoState(null);
}

function refreshSelectedVehicleModelInfo() {
    if (isCreateTuneVehicleListUpdating()) {
        setVehicleModelInfoState(null);
        return;
    }
    if (!vehicleBrowserState.selectedBrand || !vehicleBrowserState.selectedModel) {
        setVehicleModelInfoState(null);
        return;
    }
    const selectedSpecs = getVehicleSpecs(vehicleBrowserState.selectedBrand, vehicleBrowserState.selectedModel);
    setVehicleModelInfoState(deriveVehicleModelPerformance(selectedSpecs));
}

function setCreateModelPresetActiveState(presetKey = '') {
    activeCreateModelPreset = String(presetKey || '');
    if (!createModelPresetButtons.length) {
        return;
    }
    createModelPresetButtons.forEach((button) => {
        const key = String(button.dataset.modelPreset || '');
        const isActive = Boolean(activeCreateModelPreset) && key === activeCreateModelPreset;
        button.classList.toggle('is-active', isActive);
        button.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    });
}

function clearCreateModelPresetActiveState() {
    setCreateModelPresetActiveState('');
}

function applyCreateModelPreset(presetKey) {
    const preset = CREATE_MODEL_INFO_PRESETS[presetKey];
    if (!preset) {
        return;
    }

    setCapsuleGroupOptionByLabel(createDriveTypeGroup, preset.driveType, { animate: true });
    setCapsuleGroupOptionByLabel(createDrivingSurfaceGroup, preset.surface, { animate: true });
    setCapsuleGroupOptionByLabel(createTuneTypeGroup, preset.tuneType, { animate: true });

    if (createFrontDistributionInput && Number.isFinite(preset.frontDistributionPercent)) {
        createFrontDistributionInput.value = toInputNumberString(preset.frontDistributionPercent);
    }

    setCreateModelPresetActiveState(presetKey);
    refreshSelectedVehicleModelInfo();
    updateCreateCalcButtonState();
}

function initCreateModelPresetControls() {
    if (!createModelPresetBar || !createModelPresetButtons.length) {
        return;
    }

    createModelPresetButtons.forEach((button) => {
        button.setAttribute('aria-pressed', 'false');
        button.addEventListener('click', () => {
            const presetKey = String(button.dataset.modelPreset || '');
            if (!presetKey) {
                return;
            }
            applyCreateModelPreset(presetKey);
        });
    });
}

function syncDriveTypeSelectionFromSpecs(driveType, { animate = false } = {}) {
    if (!createDriveTypeGroup) {
        return;
    }

    const normalizedDriveType = normalizeDriveType(driveType);
    if (!normalizedDriveType) {
        return;
    }

    const options = Array.from(createDriveTypeGroup.querySelectorAll('.capsule-option'));
    const targetOption = options.find((option) => getCapsuleOptionSegmentKey(option, option.textContent) === normalizedDriveType.toLowerCase());
    if (!targetOption) {
        return;
    }

    options.forEach((option) => option.classList.remove('is-active'));
    targetOption.classList.add('is-active');
    updateCapsuleGroupIndicator(createDriveTypeGroup, animate);
}

function updateSelectedVehicleSpecFields() {
    if (!createCurrentPiInput && !createTopSpeedInput) {
        return;
    }

    const hasSelectedModel = Boolean(vehicleBrowserState.selectedBrand && vehicleBrowserState.selectedModel);
    if (isCreateTuneVehicleListUpdating() || !hasSelectedModel) {
        clearVehicleSpecFields();
        return;
    }

    const specs = getVehicleSpecs(vehicleBrowserState.selectedBrand, vehicleBrowserState.selectedModel);
    if (!specs) {
        clearVehicleSpecFields();
        return;
    }

    if (createCurrentPiInput) {
        createCurrentPiInput.value = toInputNumberString(specs.pi);
    }

    if (createTopSpeedInput) {
        const displayTopSpeed = convertMetricToDisplay(specs.topSpeedKmh, 'speed', settingsState.unitSystem);
        createTopSpeedInput.value = toInputNumberString(displayTopSpeed);
    }

    syncDriveTypeSelectionFromSpecs(specs.driveType, { animate: true });
    updateVehiclePreviewSpecs(specs);
    updatePiBadgeElement(createCurrentPiBadge, specs.pi);
    updatePiBadgeElement(vehiclePreviewPiBadge, specs.pi, { animate: true });
    refreshSelectedVehicleModelInfo();
}

function isCreateTuneFormComplete() {
    if (!pageCreateTune) {
        return false;
    }

    const vehicleReady = Boolean(vehicleBrowserState.selectedBrand && vehicleBrowserState.selectedModel);
    const powerBandReady = !createPowerBandValue || createPowerBandValue.value.trim() !== '';

    const requiredFields = Array.from(
        pageCreateTune.querySelectorAll('.create-tune-grid .capsule-input')
    ).filter((field) => field.id !== 'vehicle-filter-input' && field.id !== 'create-power-band-trigger');

    const fieldsReady = requiredFields.every((field) => {
        if (field instanceof HTMLInputElement || field instanceof HTMLSelectElement || field instanceof HTMLTextAreaElement) {
            return field.value.trim() !== '';
        }
        return true;
    });

    const segmentGroups = Array.from(pageCreateTune.querySelectorAll('.create-tune-grid .js-capsule-group'));
    const segmentsReady = segmentGroups.every((group) => Boolean(group.querySelector('.capsule-option.is-active')));

    return vehicleReady && fieldsReady && segmentsReady && powerBandReady;
}

function updateCreateCalcButtonState() {
    if (!createCalcBtn) {
        return;
    }

    const isReady = isCreateTuneFormComplete();
    createCalcBtn.disabled = !isReady;
    createCalcBtn.classList.toggle('is-ready', isReady);
    createCalcBtn.classList.toggle('is-incomplete', !isReady);
}

function parseCreateTuneContextToken(subtitle) {
    const contextLine = String(subtitle || '')
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
        .slice(1)
        .join(' ');
    if (!contextLine) {
        return null;
    }

    const contextMatch = contextLine.match(
        /([0-9]+(?:\.[0-9]+)?)kg\s*\/\s*([0-9]+(?:\.[0-9]+)?)N-m\s*\/\s*([0-9]+(?:\.[0-9]+)?)km\/h\s*\/\s*([0-9]+(?:\.[0-9]+)?)rpm\s*\/\s*([0-9]+(?:\.[0-9]+)?)rpm\s*\/\s*([0-9]+)\s*-\s*([0-9]+)\s*R\s*([0-9]+)/i
    );
    if (!contextMatch) {
        return null;
    }

    return {
        weightKg: Number(contextMatch[1]),
        maxTorqueNm: Number(contextMatch[2]),
        topSpeedKmh: Number(contextMatch[3]),
        redlineRpm: Number(contextMatch[4]),
        maxTorqueRpm: Number(contextMatch[5]),
        tireWidth: Number(contextMatch[6]),
        tireAspect: Number(contextMatch[7]),
        tireRim: Number(contextMatch[8])
    };
}

function toFiniteOrFallback(value, fallback) {
    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : fallback;
}

function setMetricInputValue(field, metricValue, kind) {
    if (!field) {
        return;
    }
    const metricNumeric = Number(metricValue);
    if (!Number.isFinite(metricNumeric)) {
        field.value = '';
        return;
    }

    const displayValue = convertMetricToDisplay(metricNumeric, kind, settingsState.unitSystem);
    field.value = toInputNumberString(displayValue);
}

function resolvePowerBandStateFromRecord(meta, context) {
    if (meta?.powerBand) {
        return normalizePowerBandState(meta.powerBand);
    }

    const redlineRpm = roundToStep(toFiniteOrFallback(context?.redlineRpm, DEFAULT_POWER_BAND_STATE.redlineRpm));
    const maxTorqueRpm = roundToStep(toFiniteOrFallback(context?.maxTorqueRpm, redlineRpm));
    const presetScale = POWER_BAND_PRESET_SCALE_OPTIONS.find((scale) => redlineRpm <= scale) || null;
    const resolvedScale = presetScale || toCustomScaleValue(redlineRpm);
    const isCustomScale = !presetScale;

    return normalizePowerBandState({
        scaleMax: resolvedScale,
        redlineRpm,
        maxTorqueRpm,
        isCustomScale,
        customScaleMax: isCustomScale ? resolvedScale : DEFAULT_POWER_BAND_STATE.customScaleMax
    });
}

function populateCreateTuneFormFromGarageRecord(record) {
    if (!record || !record.meta) {
        return;
    }

    const meta = record.meta;
    const context = parseCreateTuneContextToken(record.subtitle);

    if (createGameVersionGroup) {
        createGameVersionGroup.querySelectorAll('[data-create-game-version]').forEach((option) => {
            option.classList.toggle('is-active', option.dataset.createGameVersion === 'fh5');
        });
        updateCapsuleGroupIndicator(createGameVersionGroup, false);
    }
    syncCreateTuneGameVersion('fh5');

    vehicleBrowserState.selectedBrand = String(meta.brand || getSettingsLanguageText('genericUnknownBrand'));
    vehicleBrowserState.selectedModel = String(meta.model || getSettingsLanguageText('genericUnknownModel'));
    vehicleBrowserState.filter = '';
    if (vehicleFilterInput) {
        vehicleFilterInput.value = '';
    }

    renderBrandList();
    renderModelList();
    setVehicleBrowserMode('model');
    updateVehicleSelectionLabel();

    const weightKg = toFiniteOrFallback(meta.weightKg, toFiniteOrFallback(context?.weightKg, 1400));
    const currentPi = Math.round(toFiniteOrFallback(meta.pi, 800));
    const topSpeedKmh = toFiniteOrFallback(meta.topSpeedKmh, toFiniteOrFallback(context?.topSpeedKmh, 280));
    const maxTorqueNm = toFiniteOrFallback(meta.maxTorqueNm, toFiniteOrFallback(context?.maxTorqueNm, 600));
    const frontDistribution = toFiniteOrFallback(meta.frontDistributionPercent, 50);
    const gears = Math.round(clampNumber(toFiniteOrFallback(meta.gears, 6), 2, 10));
    const tireWidth = Math.round(toFiniteOrFallback(meta.tireWidth, toFiniteOrFallback(context?.tireWidth, 255)));
    const tireAspect = Math.round(toFiniteOrFallback(meta.tireAspect, toFiniteOrFallback(context?.tireAspect, 35)));
    const tireRim = Math.round(toFiniteOrFallback(meta.tireRim, toFiniteOrFallback(context?.tireRim, 19)));

    setMetricInputValue(createWeightInput, weightKg, 'weight');
    if (createFrontDistributionInput) {
        createFrontDistributionInput.value = toInputNumberString(frontDistribution);
    }
    if (createCurrentPiInput) {
        createCurrentPiInput.value = toInputNumberString(currentPi);
    }
    setMetricInputValue(createTopSpeedInput, topSpeedKmh, 'speed');
    setMetricInputValue(createMaxTorqueInput, maxTorqueNm, 'torque');
    if (createGearsSelect) {
        createGearsSelect.value = String(gears);
    }
    if (createTireWidthInput) {
        createTireWidthInput.value = toInputNumberString(tireWidth);
    }
    if (createTireAspectInput) {
        createTireAspectInput.value = toInputNumberString(tireAspect);
    }
    if (createTireRimInput) {
        createTireRimInput.value = toInputNumberString(tireRim);
    }

    setCapsuleGroupOptionByLabel(createDriveTypeGroup, normalizeDriveType(meta.driveType) || 'FWD', { animate: false });
    setCapsuleGroupOptionByLabel(createDrivingSurfaceGroup, String(meta.surface || 'Street'), { animate: false });
    setCapsuleGroupOptionByLabel(createTuneTypeGroup, String(meta.tuneType || 'Race'), { animate: false });

    powerBandState = resolvePowerBandStateFromRecord(meta, context);
    powerBandDraftState = { ...powerBandState };
    syncPowerBandFieldsFromState();

    updatePiBadgeElement(createCurrentPiBadge, createCurrentPiInput?.value);
    updatePiBadgeElement(vehiclePreviewPiBadge, createCurrentPiInput?.value, { animate: true });
    syncCapsuleGroupIndicators(pageCreateTune);
    clearCreateModelPresetActiveState();
    refreshSelectedVehicleModelInfo();
    updateCreateCalcButtonState();
}

function openGarageEditById(recordId) {
    const targetRecord = findGarageTuneById(recordId);
    if (!targetRecord) {
        return;
    }

    ensureVehicleBrowserInitialized();
    setCreateTuneEditRecord(targetRecord.id);
    populateCreateTuneFormFromGarageRecord(targetRecord);
    openCreateTunePage(pageGarage);
}

function normalizeVehicleSortMode(mode) {
    return Object.prototype.hasOwnProperty.call(VEHICLE_SORT_LABELS, mode) ? mode : 'name';
}

function normalizeVehicleSortDirection(direction) {
    return direction === 'desc' ? 'desc' : 'asc';
}

function getVehicleSortDefaultDirection(mode) {
    const normalizedMode = normalizeVehicleSortMode(mode);
    return VEHICLE_SORT_DEFAULT_DIRECTION[normalizedMode] || 'asc';
}

function getVehicleSortLabel(mode, direction) {
    const normalizedMode = normalizeVehicleSortMode(mode);
    const normalizedDirection = normalizeVehicleSortDirection(direction);
    if (normalizedMode === 'name') {
        return normalizedDirection === 'asc'
            ? getSettingsLanguageText('vehicleSortNameAsc')
            : getSettingsLanguageText('vehicleSortNameDesc');
    }
    if (normalizedMode === 'topSpeed') {
        return normalizedDirection === 'desc'
            ? getSettingsLanguageText('vehicleSortTopSpeedDesc')
            : getSettingsLanguageText('vehicleSortTopSpeedAsc');
    }
    return normalizedDirection === 'desc'
        ? getSettingsLanguageText('vehicleSortPiDesc')
        : getSettingsLanguageText('vehicleSortPiAsc');
}

function getVehicleSortTriggerIconMarkup(mode, direction) {
    const normalizedMode = normalizeVehicleSortMode(mode);
    const normalizedDirection = normalizeVehicleSortDirection(direction);

    if (normalizedMode === 'name') {
        return normalizedDirection === 'asc'
            ? '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 17L5.4 7h1.2L9 17"/><path d="M4 13h4"/><path d="M13 7h8l-8 10h8"/><path d="M10 19h3"/><path d="M11.5 19V5"/><path d="M10.2 6.8 11.5 5l1.3 1.8"/></svg>'
            : '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 17L5.4 7h1.2L9 17"/><path d="M4 13h4"/><path d="M13 7h8l-8 10h8"/><path d="M10 5h3"/><path d="M11.5 5v14"/><path d="M10.2 17.2 11.5 19l1.3-1.8"/></svg>';
    }

    if (normalizedMode === 'topSpeed') {
        return normalizedDirection === 'desc'
            ? '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 16a8 8 0 0 1 16 0"/><path d="M12 12l4-3"/><path d="M18 7v4"/><path d="M16 9h4"/></svg>'
            : '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 16a8 8 0 0 1 16 0"/><path d="M12 12l4-3"/><path d="M6 17h6"/><path d="M10 13l2 4 2-2 2 2"/></svg>';
    }

    return normalizedDirection === 'desc'
        ? '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="5" width="11" height="14" rx="2"/><path d="M6.3 9.2h5.4"/><path d="M6.3 12h5.4"/><path d="M16 8h4"/><path d="M18 6v4"/></svg>'
        : '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="5" width="11" height="14" rx="2"/><path d="M6.3 9.2h5.4"/><path d="M6.3 12h5.4"/><path d="M16 16h4"/><path d="M18 14v4"/></svg>';
}

function closeVehicleSortMenu() {
    if (!vehicleSortMenu || !vehicleSortTrigger) {
        return;
    }

    vehicleSortMenu.classList.remove('is-open');
    vehicleSortTrigger.classList.remove('is-active');
    vehicleSortTrigger.setAttribute('aria-expanded', 'false');
}

function openVehicleSortMenu() {
    if (!vehicleSortMenu || !vehicleSortTrigger || vehicleSortTrigger.disabled) {
        return;
    }

    vehicleSortMenu.classList.add('is-open');
    vehicleSortTrigger.classList.add('is-active');
    vehicleSortTrigger.setAttribute('aria-expanded', 'true');
}

function updateVehicleSortUi() {
    const sortMode = normalizeVehicleSortMode(vehicleBrowserState.sort);
    const sortDirection = normalizeVehicleSortDirection(
        vehicleBrowserState.sortDirection || getVehicleSortDefaultDirection(sortMode)
    );
    vehicleBrowserState.sort = sortMode;
    vehicleBrowserState.sortDirection = sortDirection;

    if (vehicleSortTrigger) {
        const sortLabel = getVehicleSortLabel(sortMode, sortDirection);
        const sortTriggerPrefix = getSettingsLanguageText('createVehicleSortTriggerPrefix');
        const sortTriggerAriaPrefix = getSettingsLanguageText('createVehicleSortTriggerAriaPrefix');
        vehicleSortTrigger.title = `${sortTriggerPrefix}: ${sortLabel}`;
        vehicleSortTrigger.setAttribute('aria-label', `${sortTriggerAriaPrefix}: ${sortLabel}`);
        vehicleSortTrigger.dataset.sortMode = sortMode;
        vehicleSortTrigger.dataset.sortDirection = sortDirection;
    }

    if (vehicleSortTriggerIcon) {
        vehicleSortTriggerIcon.innerHTML = getVehicleSortTriggerIconMarkup(sortMode, sortDirection);
    }

    if (!vehicleSortMenu) {
        return;
    }

    vehicleSortMenu.querySelectorAll('[data-sort-mode]').forEach((item) => {
        const itemMode = normalizeVehicleSortMode(item.dataset.sortMode || 'name');
        const isActive = itemMode === sortMode;
        item.classList.toggle('is-active', isActive);
        item.setAttribute('aria-checked', isActive ? 'true' : 'false');

        if (isActive) {
            item.textContent = getVehicleSortLabel(sortMode, sortDirection);
            return;
        }

        item.textContent = getVehicleSortLabel(itemMode, getVehicleSortDefaultDirection(itemMode));
    });
}

function setVehicleSortMode(mode) {
    const normalizedMode = normalizeVehicleSortMode(mode);
    const currentMode = normalizeVehicleSortMode(vehicleBrowserState.sort);
    const currentDirection = normalizeVehicleSortDirection(
        vehicleBrowserState.sortDirection || getVehicleSortDefaultDirection(currentMode)
    );

    vehicleBrowserState.sort = normalizedMode;
    vehicleBrowserState.sortDirection = normalizedMode === currentMode
        ? (currentDirection === 'asc' ? 'desc' : 'asc')
        : getVehicleSortDefaultDirection(normalizedMode);

    updateVehicleSortUi();
    renderBrandList();
    renderModelList();
    updateCreateCalcButtonState();
}

function updateVehicleListEdgeFade(listElement) {
    if (!listElement) {
        return;
    }

    const pageElement = listElement.closest('.vehicle-page');
    if (!pageElement) {
        return;
    }

    const scrollHeight = Number(listElement.scrollHeight) || 0;
    const clientHeight = Number(listElement.clientHeight) || 0;
    const scrollTop = Number(listElement.scrollTop) || 0;
    const hasOverflow = (scrollHeight - clientHeight) > 2;
    updateVehicleListScaleByCenter(listElement);

    if (!hasOverflow) {
        pageElement.classList.remove('has-fade-top', 'has-fade-bottom');
        return;
    }

    const isAtTop = scrollTop <= 1;
    const isAtBottom = (scrollTop + clientHeight) >= (scrollHeight - 1);
    pageElement.classList.toggle('has-fade-top', !isAtTop);
    pageElement.classList.toggle('has-fade-bottom', !isAtBottom);
}

function updateVehicleListScaleByCenter(listElement) {
    if (!listElement) {
        return;
    }

    const items = listElement.querySelectorAll('.vehicle-item');
    if (!items.length) {
        return;
    }
    items.forEach((item) => {
        item.style.setProperty('--vehicle-row-scale', '1');
    });
}

function refreshVehicleListEdgeFade() {
    updateVehicleListEdgeFade(vehicleBrandList);
    updateVehicleListEdgeFade(vehicleModelList);
}

function renderBrandList() {
    if (!vehicleBrandList) {
        return;
    }

    if (isCreateTuneVehicleListUpdating()) {
        vehicleBrandList.innerHTML = `<p class="vehicle-empty">${getSettingsLanguageText('createVehicleListUpdating')}</p>`;
        updateVehicleListEdgeFade(vehicleBrandList);
        return;
    }

    const query = normalizeSearchValue(vehicleBrowserState.filter);
    const sortMode = normalizeVehicleSortMode(vehicleBrowserState.sort);
    const sortDirection = normalizeVehicleSortDirection(
        vehicleBrowserState.sortDirection || getVehicleSortDefaultDirection(sortMode)
    );
    const directionFactor = sortDirection === 'asc' ? 1 : -1;
    const matchedBrands = Object.keys(BRAND_MODEL_DATA)
        .map((brand) => {
            const models = BRAND_MODEL_DATA[brand];
            const brandMatches = brand.toLowerCase().includes(query);
            const modelMatchCount = models.reduce((count, model) => (
                model.toLowerCase().includes(query) ? count + 1 : count
            ), 0);
            const hasMatch = query === '' || brandMatches || modelMatchCount > 0;

            if (!hasMatch) {
                return null;
            }

            let maxPi = null;
            let maxTopSpeed = null;
            models.forEach((model) => {
                const specs = getVehicleSpecs(brand, model);
                const pi = toOptionalPi(specs?.pi);
                const topSpeed = toOptionalTopSpeed(specs?.topSpeedKmh);
                if (pi !== null && (maxPi === null || pi > maxPi)) {
                    maxPi = pi;
                }
                if (topSpeed !== null && (maxTopSpeed === null || topSpeed > maxTopSpeed)) {
                    maxTopSpeed = topSpeed;
                }
            });

            return {
                brand,
                totalModelCount: models.length,
                modelMatchCount,
                brandMatches,
                maxPi,
                maxTopSpeed
            };
        })
        .filter(Boolean);

    matchedBrands.sort((a, b) => {
        if (sortMode === 'pi') {
            const aPi = a.maxPi;
            const bPi = b.maxPi;
            if (aPi !== null || bPi !== null) {
                if (aPi === null) {
                    return 1;
                }
                if (bPi === null) {
                    return -1;
                }
                if (aPi !== bPi) {
                    return directionFactor * (aPi - bPi);
                }
            }
        }

        if (sortMode === 'topSpeed') {
            const aSpeed = a.maxTopSpeed;
            const bSpeed = b.maxTopSpeed;
            if (aSpeed !== null || bSpeed !== null) {
                if (aSpeed === null) {
                    return 1;
                }
                if (bSpeed === null) {
                    return -1;
                }
                if (aSpeed !== bSpeed) {
                    return directionFactor * (aSpeed - bSpeed);
                }
            }
        }

        const brandCompared = a.brand.localeCompare(b.brand, undefined, { sensitivity: 'base', numeric: true });
        if (sortMode === 'name') {
            return directionFactor * brandCompared;
        }
        return brandCompared;
    });

    if (!matchedBrands.length) {
        vehicleBrandList.innerHTML = `<p class="vehicle-empty">${getSettingsLanguageText('createNoBrandOrModelFound')}</p>`;
        updateVehicleListEdgeFade(vehicleBrandList);
        return;
    }

    vehicleBrandList.innerHTML = matchedBrands
        .map(({ brand, totalModelCount, modelMatchCount, brandMatches, maxPi, maxTopSpeed }) => {
            const isActive = vehicleBrowserState.selectedBrand === brand;
            const activeClass = isActive ? ' is-active' : '';
            const encodedBrand = encodeURIComponent(brand);
            const logoMarkup = getBrandLogoMarkup(brand);
            let metaText = query !== '' && !brandMatches && modelMatchCount > 0
                ? formatLocalizedText('createMatchingModelsCount', { count: modelMatchCount })
                : formatLocalizedText('createModelsCount', { count: totalModelCount });
            if (sortMode === 'pi') {
                metaText = formatPiMeta(maxPi) || metaText;
            } else if (sortMode === 'topSpeed') {
                metaText = formatTopSpeedMeta(maxTopSpeed) || metaText;
            }
            const checkMarkup = isActive
                ? '<span class="material-symbols-outlined vehicle-item-check" aria-hidden="true">check</span>'
                : '';
            return `
                <button class="vehicle-item no-drag${activeClass}" type="button" data-brand="${encodedBrand}">
                    <span class="vehicle-item-main">
                        ${logoMarkup}
                        <span class="vehicle-item-label">${escapeHtml(brand)}</span>
                    </span>
                    <span class="vehicle-item-right">
                        <span class="vehicle-item-meta">${metaText}</span>
                        ${checkMarkup}
                    </span>
                </button>
            `;
        })
        .join('');

    bindBrandLogoFallbacks(vehicleBrandList);
    updateVehicleListEdgeFade(vehicleBrandList);
}

function renderModelList() {
    if (!vehicleModelList) {
        return;
    }

    if (isCreateTuneVehicleListUpdating()) {
        vehicleModelList.innerHTML = `<p class="vehicle-empty">${getSettingsLanguageText('createVehicleListUpdating')}</p>`;
        updateVehicleListEdgeFade(vehicleModelList);
        return;
    }

    if (!vehicleBrowserState.selectedBrand) {
        vehicleModelList.innerHTML = `<p class="vehicle-empty">${getSettingsLanguageText('createSelectBrandFirst')}</p>`;
        updateVehicleListEdgeFade(vehicleModelList);
        return;
    }

    const query = normalizeSearchValue(vehicleBrowserState.filter);
    const sortMode = normalizeVehicleSortMode(vehicleBrowserState.sort);
    const sortDirection = normalizeVehicleSortDirection(
        vehicleBrowserState.sortDirection || getVehicleSortDefaultDirection(sortMode)
    );
    const directionFactor = sortDirection === 'asc' ? 1 : -1;
    const selectedBrandName = vehicleBrowserState.selectedBrand || '';
    const isBrandQuery = query !== '' && selectedBrandName.toLowerCase().includes(query);
    const modelEntries = BRAND_MODEL_DATA[selectedBrandName]
        .filter((model) => isBrandQuery || model.toLowerCase().includes(query))
        .map((model) => {
            const specs = getVehicleSpecs(selectedBrandName, model);
            return {
                model,
                pi: toOptionalPi(specs?.pi),
                topSpeed: toOptionalTopSpeed(specs?.topSpeedKmh),
                driveType: normalizeDriveType(specs?.driveType)
            };
        });

    modelEntries.sort((a, b) => {
        if (sortMode === 'pi') {
            if (a.pi !== null || b.pi !== null) {
                if (a.pi === null) {
                    return 1;
                }
                if (b.pi === null) {
                    return -1;
                }
                if (a.pi !== b.pi) {
                    return directionFactor * (a.pi - b.pi);
                }
            }
        }

        if (sortMode === 'topSpeed') {
            if (a.topSpeed !== null || b.topSpeed !== null) {
                if (a.topSpeed === null) {
                    return 1;
                }
                if (b.topSpeed === null) {
                    return -1;
                }
                if (a.topSpeed !== b.topSpeed) {
                    return directionFactor * (a.topSpeed - b.topSpeed);
                }
            }
        }

        const modelCompared = a.model.localeCompare(b.model, undefined, { sensitivity: 'base', numeric: true });
        if (sortMode === 'name') {
            return directionFactor * modelCompared;
        }
        return modelCompared;
    });

    if (!modelEntries.length) {
        vehicleModelList.innerHTML = `<p class="vehicle-empty">${getSettingsLanguageText('createNoModelFound')}</p>`;
        updateVehicleListEdgeFade(vehicleModelList);
        return;
    }

    vehicleModelList.innerHTML = modelEntries
        .map(({ model, pi, topSpeed, driveType }) => {
            const isActive = vehicleBrowserState.selectedModel === model;
            const activeClass = isActive ? ' is-active' : '';
            const encodedModel = encodeURIComponent(model);
            const driveMeta = driveType || null;
            const piBadgeMarkup = buildVehicleListPiBadgeMarkup(pi);
            const speedMeta = sortMode === 'topSpeed' ? formatTopSpeedMeta(topSpeed) : null;
            const checkMarkup = isActive
                ? '<span class="material-symbols-outlined vehicle-item-check" aria-hidden="true">check</span>'
                : '';
            return `
                <button class="vehicle-item vehicle-item-model no-drag${activeClass}" type="button" data-model="${encodedModel}">
                    <span class="vehicle-item-main">
                        <span class="vehicle-item-label vehicle-item-label-model">${escapeHtml(model)}</span>
                    </span>
                    <span class="vehicle-item-right">
                        ${driveMeta ? `<span class="vehicle-item-meta vehicle-item-drive-meta">${escapeHtml(driveMeta)}</span>` : ''}
                        ${speedMeta ? `<span class="vehicle-item-meta vehicle-item-speed-meta">${escapeHtml(speedMeta)}</span>` : ''}
                        ${piBadgeMarkup}
                        ${checkMarkup}
                    </span>
                </button>
            `;
        })
        .join('');
    updateVehicleListEdgeFade(vehicleModelList);
}

function setVehicleBrowserMode(mode) {
    if (!vehiclePagesSlider) {
        return;
    }

    const canShowModel = Boolean(vehicleBrowserState.selectedBrand) && !isCreateTuneVehicleListUpdating();
    const nextMode = mode === 'model' && canShowModel ? 'model' : 'brand';
    vehicleBrowserState.mode = nextMode;

    vehiclePagesSlider.classList.toggle('mode-brand', nextMode === 'brand');
    vehiclePagesSlider.classList.toggle('mode-model', nextMode === 'model');
    if (vehicleFilterRow) {
        vehicleFilterRow.classList.toggle('is-model', nextMode === 'model');
    }
    refreshVehicleListEdgeFade();
}

function syncCreateTuneGameVersion(version) {
    createTuneGameVersion = version === 'fh6' ? 'fh6' : 'fh5';

    const isUpdating = isCreateTuneVehicleListUpdating();
    if (isUpdating) {
        vehicleBrowserState.selectedBrand = null;
        vehicleBrowserState.selectedModel = null;
        vehicleBrowserState.filter = '';
    }

    if (vehicleFilterInput) {
        vehicleFilterInput.disabled = isUpdating;
        vehicleFilterInput.value = vehicleBrowserState.filter;
        vehicleFilterInput.placeholder = isUpdating
            ? getSettingsLanguageText('createVehicleListUpdating')
            : getSettingsLanguageText('createVehicleFilterPlaceholder') || DEFAULT_VEHICLE_FILTER_PLACEHOLDER;
    }

    if (vehicleSortTrigger) {
        vehicleSortTrigger.disabled = isUpdating;
        if (isUpdating) {
            closeVehicleSortMenu();
        }
    }

    updateVehicleSortUi();

    if (!isVehicleBrowserInitialized) {
        updateCreateCalcButtonState();
        return;
    }

    setVehicleBrowserMode(isUpdating ? 'brand' : vehicleBrowserState.mode);
    renderBrandList();
    renderModelList();
    updateVehicleSelectionLabel();
    updateCreateCalcButtonState();
}

function initVehicleBrowser() {
    if (!vehicleBrandList || !vehicleModelList) {
        return;
    }

    renderBrandList();
    renderModelList();
    setVehicleBrowserMode('brand');
    updateVehicleSortUi();
    updateVehicleSelectionLabel();
    refreshVehicleListEdgeFade();

    [vehicleBrandList, vehicleModelList].forEach((listElement) => {
        if (!listElement) {
            return;
        }
        listElement.addEventListener('scroll', () => {
            updateVehicleListEdgeFade(listElement);
        }, { passive: true });
    });
    window.addEventListener('resize', refreshVehicleListEdgeFade);

    vehicleBrandList.addEventListener('click', (event) => {
        if (isCreateTuneVehicleListUpdating()) {
            return;
        }

        const target = event.target.closest('[data-brand]');
        if (!target) {
            return;
        }

        const clickedBrand = decodeURIComponent(target.dataset.brand || '');
        const isToggleOff = vehicleBrowserState.selectedBrand === clickedBrand;

        if (isToggleOff) {
            vehicleBrowserState.selectedBrand = null;
            vehicleBrowserState.selectedModel = null;
            setVehicleBrowserMode('brand');
            renderBrandList();
            renderModelList();
            updateVehicleSelectionLabel();
            updateCreateCalcButtonState();
            return;
        }

        vehicleBrowserState.selectedBrand = clickedBrand;
        vehicleBrowserState.selectedModel = null;

        renderBrandList();
        renderModelList();
        setVehicleBrowserMode('model');
        updateVehicleSelectionLabel();
        updateCreateCalcButtonState();
    });

    vehicleModelList.addEventListener('click', (event) => {
        if (isCreateTuneVehicleListUpdating()) {
            return;
        }

        const target = event.target.closest('[data-model]');
        if (!target) {
            return;
        }

        const clickedModel = decodeURIComponent(target.dataset.model || '');
        const isToggleOff = vehicleBrowserState.selectedModel === clickedModel;
        vehicleBrowserState.selectedModel = isToggleOff ? null : clickedModel;
        renderModelList();
        updateVehicleSelectionLabel();
        updateCreateCalcButtonState();
    });

    if (vehicleModelBack) {
        vehicleModelBack.addEventListener('click', () => {
            if (isCreateTuneVehicleListUpdating()) {
                return;
            }

            vehicleBrowserState.filter = '';
            if (vehicleFilterInput) {
                vehicleFilterInput.value = '';
            }
            setVehicleBrowserMode('brand');
            renderBrandList();
            updateCreateCalcButtonState();
        });
    }

    if (vehicleFilterInput) {
        vehicleFilterInput.addEventListener('input', (event) => {
            if (isCreateTuneVehicleListUpdating()) {
                return;
            }

            vehicleBrowserState.filter = event.target.value;
            if (vehicleBrowserState.mode === 'brand') {
                renderBrandList();
            } else {
                renderModelList();
            }
            updateCreateCalcButtonState();
        });
    }

    if (vehicleSortTrigger) {
        vehicleSortTrigger.addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();

            if (vehicleSortTrigger.disabled) {
                return;
            }

            const isOpen = vehicleSortMenu?.classList.contains('is-open');
            if (isOpen) {
                closeVehicleSortMenu();
            } else {
                openVehicleSortMenu();
            }
        });
    }

    if (vehicleSortMenu) {
        vehicleSortMenu.addEventListener('click', (event) => {
            const target = event.target.closest('[data-sort-mode]');
            if (!target) {
                return;
            }

            event.preventDefault();
            event.stopPropagation();
            setVehicleSortMode(target.dataset.sortMode || 'name');
            closeVehicleSortMenu();
        });
    }

    document.addEventListener('click', (event) => {
        if (!vehicleSortMenu || !vehicleSortTrigger) {
            return;
        }

        const withinMenu = vehicleSortMenu.contains(event.target);
        const withinTrigger = vehicleSortTrigger.contains(event.target);
        if (!withinMenu && !withinTrigger) {
            closeVehicleSortMenu();
        }
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            closeVehicleSortMenu();
        }
    });

    if (vehicleFilterInput) {
        vehicleFilterInput.addEventListener('focus', () => {
            closeVehicleSortMenu();
        });
    }
}

function ensureVehicleBrowserInitialized() {
    if (isVehicleBrowserInitialized) {
        return;
    }

    initVehicleBrowser();
    isVehicleBrowserInitialized = true;
}

function initCapsuleGroups() {
    document.querySelectorAll('.js-capsule-group').forEach((group) => {
        ensureCapsuleIndicator(group);

        group.addEventListener('click', (event) => {
            const target = event.target.closest('.capsule-option');
            if (!target || !group.contains(target)) {
                return;
            }

            group.querySelectorAll('.capsule-option').forEach((option) => {
                option.classList.remove('is-active');
            });
            target.classList.add('is-active');
            updateCapsuleGroupIndicator(group, true);

            const nextCreateTuneVersion = target.dataset.createGameVersion;
            if (nextCreateTuneVersion) {
                syncCreateTuneGameVersion(nextCreateTuneVersion);
            }

            const nextUnitSystem = target.dataset.unitSystem;
            if (nextUnitSystem) {
                setCreateTuneUnitSystem(nextUnitSystem, { persist: true, convertFieldValues: true });
            }

            if (group === createDrivingSurfaceGroup) {
                const selectedSurface = getCapsuleOptionSegmentKey(target, target.textContent.trim());
                syncTuneTypeOptionsByDrivingSurface(selectedSurface, { animate: true });
            }

            if (group === createDriveTypeGroup || group === createDrivingSurfaceGroup || group === createTuneTypeGroup) {
                clearCreateModelPresetActiveState();
                refreshSelectedVehicleModelInfo();
            }

            updateCreateCalcButtonState();
        });

        updateCapsuleGroupIndicator(group, false);
    });

    let resizeRafId = null;
    window.addEventListener('resize', () => {
        if (resizeRafId !== null) {
            cancelAnimationFrame(resizeRafId);
        }

        resizeRafId = requestAnimationFrame(() => {
            syncResponsiveWindowMode();
            syncCapsuleGroupIndicators();
            updateCreateCalcButtonState();
            resizeRafId = null;
        });
    });
}

function ensureCapsuleIndicator(group) {
    let indicator = group.querySelector('.capsule-active-indicator');
    if (!indicator) {
        indicator = document.createElement('span');
        indicator.className = 'capsule-active-indicator';
        group.prepend(indicator);
    }
    return indicator;
}

function updateCapsuleGroupIndicator(group, animate = false) {
    if (!group) {
        return;
    }

    const indicator = ensureCapsuleIndicator(group);
    const activeOption = group.querySelector('.capsule-option.is-active');

    if (!activeOption) {
        group.classList.remove('has-active-indicator');
        return;
    }

    const groupRect = group.getBoundingClientRect();
    const optionRect = activeOption.getBoundingClientRect();
    if (groupRect.width === 0 || groupRect.height === 0 || optionRect.width === 0 || optionRect.height === 0) {
        return;
    }

    const offsetX = optionRect.left - groupRect.left;
    const offsetY = optionRect.top - groupRect.top;

    indicator.style.width = `${optionRect.width}px`;
    indicator.style.height = `${optionRect.height}px`;
    indicator.style.transform = `translate3d(${offsetX}px, ${offsetY}px, 0)`;
    group.classList.add('has-active-indicator');

    if (!indicator.classList.contains('is-ready')) {
        requestAnimationFrame(() => {
            indicator.classList.add('is-ready');
        });
    }

    if (animate) {
        indicator.classList.remove('is-pulse');
        void indicator.offsetWidth;
        indicator.classList.add('is-pulse');
    }
}

function syncCapsuleGroupIndicators(root = document) {
    if (!root || !root.querySelectorAll) {
        return;
    }

    root.querySelectorAll('.js-capsule-group').forEach((group) => {
        updateCapsuleGroupIndicator(group, false);
    });
}

function clearVideoBackground() {
    if (!customBgVideo) {
        return;
    }

    customBgVideo.pause();
    customBgVideo.removeAttribute('src');
    customBgVideo.load();
}

function applyCustomBackground(backgroundDataUrl, backgroundType = 'image') {
    if (!backgroundDataUrl) {
        document.body.classList.remove('has-custom-video', 'has-custom-image');
        document.body.style.backgroundImage = '';
        document.body.style.backgroundSize = '';
        document.body.style.backgroundPosition = '';
        document.body.style.backgroundAttachment = '';
        document.body.style.backgroundRepeat = '';
        clearVideoBackground();
        return;
    }

    if (backgroundType === 'video') {
        document.body.classList.add('has-custom-video');
        document.body.classList.remove('has-custom-image');
        document.body.style.backgroundImage = '';
        document.body.style.backgroundSize = '';
        document.body.style.backgroundPosition = '';
        document.body.style.backgroundAttachment = '';
        document.body.style.backgroundRepeat = '';

        if (customBgVideo) {
            customBgVideo.src = backgroundDataUrl;
            customBgVideo.currentTime = 0;
            const playPromise = customBgVideo.play();
            if (playPromise && typeof playPromise.catch === 'function') {
                playPromise.catch(() => {
                    // Autoplay can fail on some environments.
                });
            }
        }

        return;
    }

    document.body.classList.remove('has-custom-video');
    document.body.classList.add('has-custom-image');
    clearVideoBackground();

    document.body.style.backgroundImage = `url("${backgroundDataUrl}")`;
    document.body.style.backgroundSize = 'cover';
    document.body.style.backgroundPosition = 'center';
    document.body.style.backgroundAttachment = 'fixed';
    document.body.style.backgroundRepeat = 'no-repeat';
}

function applyDarkMode(isDark) {
    if (isDark) {
        document.body.classList.add('dark-mode');
    } else {
        document.body.classList.remove('dark-mode');
    }
}

function clearDonateModalHideTimer() {
    if (donateModalHideTimer) {
        clearTimeout(donateModalHideTimer);
        donateModalHideTimer = null;
    }
}

function isDonateModalOpen() {
    return Boolean(donateModal && !donateModal.classList.contains('hidden') && donateModal.classList.contains('is-open'));
}

function openDonateModal() {
    if (!donateModal) {
        return;
    }

    closeFeedbackModal({ immediate: true });
    closeUpdateLogModal({ immediate: true });
    closeUiDemoModal({ immediate: true });
    clearDonateModalHideTimer();
    donateModal.classList.remove('hidden');
    donateModal.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => {
        donateModal.classList.add('is-open');
    });
}

function closeDonateModal({ immediate = false } = {}) {
    if (!donateModal) {
        return;
    }

    clearDonateModalHideTimer();
    donateModal.classList.remove('is-open');

    const hideModal = () => {
        donateModal.classList.add('hidden');
        donateModal.setAttribute('aria-hidden', 'true');
    };

    if (immediate) {
        hideModal();
        return;
    }

    donateModalHideTimer = setTimeout(() => {
        hideModal();
        donateModalHideTimer = null;
    }, DONATE_MODAL_TRANSITION_MS);
}

function clearUpdateLogModalHideTimer() {
    if (updateLogModalHideTimer) {
        clearTimeout(updateLogModalHideTimer);
        updateLogModalHideTimer = null;
    }
}

function getSeenUpdateLogVersion() {
    try {
        return String(localStorage.getItem(UPDATE_LOG_SEEN_KEY) || '').trim();
    } catch (_) {
        return '';
    }
}

function markUpdateLogSeenForCurrentVersion() {
    try {
        localStorage.setItem(UPDATE_LOG_SEEN_KEY, APP_BUILD_VERSION);
    } catch (_) {
        // Ignore storage errors to avoid interrupting UX.
    }
    pendingStartupUpdateLog = false;
}

function shouldShowStartupUpdateLog() {
    return getSeenUpdateLogVersion() !== APP_BUILD_VERSION;
}

function queueStartupUpdateLogIfNeeded() {
    if (!shouldShowStartupUpdateLog()) {
        pendingStartupUpdateLog = false;
        return;
    }

    if (isWelcomeModalOpen()) {
        pendingStartupUpdateLog = true;
        return;
    }

    pendingStartupUpdateLog = false;
    openUpdateLogModal();
}

function isUpdateLogModalOpen() {
    return Boolean(updateLogModal && !updateLogModal.classList.contains('hidden') && updateLogModal.classList.contains('is-open'));
}

function openUpdateLogModal() {
    if (!updateLogModal) {
        return;
    }

    markUpdateLogSeenForCurrentVersion();
    closeDonateModal({ immediate: true });
    closeFeedbackModal({ immediate: true });
    closeUiDemoModal({ immediate: true });
    clearUpdateLogModalHideTimer();
    updateLogModal.classList.remove('hidden');
    updateLogModal.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => {
        updateLogModal.classList.add('is-open');
    });
}

function closeUpdateLogModal({ immediate = false } = {}) {
    if (!updateLogModal) {
        return;
    }

    const wasOpen = isUpdateLogModalOpen();
    clearUpdateLogModalHideTimer();
    updateLogModal.classList.remove('is-open');

    const hideModal = () => {
        updateLogModal.classList.add('hidden');
        updateLogModal.setAttribute('aria-hidden', 'true');
    };

    if (immediate) {
        hideModal();
        if (wasOpen) {
            markUpdateLogSeenForCurrentVersion();
        }
        return;
    }

    updateLogModalHideTimer = setTimeout(() => {
        hideModal();
        if (wasOpen) {
            markUpdateLogSeenForCurrentVersion();
        }
        updateLogModalHideTimer = null;
    }, UPDATE_LOG_MODAL_TRANSITION_MS);
}

function waitRenderFrames(frameCount = 1) {
    const totalFrames = Math.max(1, Number(frameCount) || 1);
    return new Promise((resolve) => {
        let remainingFrames = totalFrames;
        const step = () => {
            remainingFrames -= 1;
            if (remainingFrames <= 0) {
                resolve();
                return;
            }
            requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
    });
}

function getWelcomeCapturePanels() {
    return [pageDashboard, pageCreateTune, pageGarage, pageSettings].filter(Boolean);
}

function snapshotWelcomeCapturePanelClasses() {
    return getWelcomeCapturePanels().map((panel) => ({
        panel,
        className: panel.className
    }));
}

function restoreWelcomeCapturePanelClasses(snapshot = []) {
    snapshot.forEach((entry) => {
        if (!entry || !entry.panel || typeof entry.className !== 'string') {
            return;
        }
        entry.panel.className = entry.className;
    });
}

function showOnlyPanelForWelcomeCapture(targetPanel) {
    const panels = getWelcomeCapturePanels();
    panels.forEach((panel) => {
        if (panel === targetPanel) {
            panel.classList.remove('hidden', 'is-closing');
            panel.classList.add('is-open');
            return;
        }
        panel.classList.remove('is-open', 'is-closing');
        panel.classList.add('hidden');
    });
}

function normalizeWelcomeCaptureRect(rawRect, { padding = 16, aspectRatio = (WELCOME_CAPTURE_OUTPUT_WIDTH / WELCOME_CAPTURE_OUTPUT_HEIGHT) } = {}) {
    if (!rawRect || typeof rawRect !== 'object') {
        return null;
    }

    const rawLeft = Number(rawRect.left);
    const rawTop = Number(rawRect.top);
    const rawRight = Number.isFinite(Number(rawRect.right))
        ? Number(rawRect.right)
        : (rawLeft + Number(rawRect.width || 0));
    const rawBottom = Number.isFinite(Number(rawRect.bottom))
        ? Number(rawRect.bottom)
        : (rawTop + Number(rawRect.height || 0));

    if (!Number.isFinite(rawLeft) || !Number.isFinite(rawTop) || !Number.isFinite(rawRight) || !Number.isFinite(rawBottom)) {
        return null;
    }

    const rawWidth = rawRight - rawLeft;
    const rawHeight = rawBottom - rawTop;
    if (rawWidth < 12 || rawHeight < 12) {
        return null;
    }

    const viewportWidth = Math.max(1, Number(window.innerWidth) || Number(document.documentElement?.clientWidth) || 1);
    const viewportHeight = Math.max(1, Number(window.innerHeight) || Number(document.documentElement?.clientHeight) || 1);
    let left = Math.max(0, rawLeft - padding);
    let top = Math.max(0, rawTop - padding);
    let right = Math.min(viewportWidth, rawRight + padding);
    let bottom = Math.min(viewportHeight, rawBottom + padding);
    let width = Math.max(1, right - left);
    let height = Math.max(1, bottom - top);
    const targetAspect = Math.max(0.2, Number(aspectRatio) || 2);

    if ((width / height) > targetAspect) {
        const desiredHeight = width / targetAspect;
        const delta = desiredHeight - height;
        top -= delta / 2;
        bottom += delta / 2;
    } else {
        const desiredWidth = height * targetAspect;
        const delta = desiredWidth - width;
        left -= delta / 2;
        right += delta / 2;
    }

    if (left < 0) {
        right -= left;
        left = 0;
    }
    if (right > viewportWidth) {
        left -= (right - viewportWidth);
        right = viewportWidth;
    }
    if (top < 0) {
        bottom -= top;
        top = 0;
    }
    if (bottom > viewportHeight) {
        top -= (bottom - viewportHeight);
        bottom = viewportHeight;
    }

    left = clampNumber(left, 0, viewportWidth - 1);
    top = clampNumber(top, 0, viewportHeight - 1);
    width = clampNumber(right - left, 1, viewportWidth);
    height = clampNumber(bottom - top, 1, viewportHeight);

    if (width < 2 || height < 2) {
        return null;
    }

    return { left, top, width, height };
}

function getWelcomeCaptureRect(element, options = {}) {
    if (!element) {
        return null;
    }
    return normalizeWelcomeCaptureRect(element.getBoundingClientRect(), options);
}

function getWelcomeCaptureRectFromElements(elements = [], options = {}) {
    const rects = (Array.isArray(elements) ? elements : [])
        .filter(Boolean)
        .map((element) => element.getBoundingClientRect())
        .filter((rect) => Number.isFinite(rect.width) && Number.isFinite(rect.height) && rect.width >= 12 && rect.height >= 12);

    if (rects.length === 0) {
        return null;
    }

    const left = Math.min(...rects.map((rect) => rect.left));
    const top = Math.min(...rects.map((rect) => rect.top));
    const right = Math.max(...rects.map((rect) => rect.right));
    const bottom = Math.max(...rects.map((rect) => rect.bottom));
    return normalizeWelcomeCaptureRect({ left, top, right, bottom }, options);
}

async function captureMainWindowFrameDataUrl() {
    try {
        const response = await ipcRenderer.invoke('capture-main-window');
        if (!response || response.ok !== true || typeof response.dataUrl !== 'string' || !response.dataUrl) {
            return null;
        }
        return response.dataUrl;
    } catch (_) {
        return null;
    }
}

function cropWindowDataUrlToRect(windowDataUrl, cropRect) {
    return new Promise((resolve) => {
        if (typeof windowDataUrl !== 'string' || !windowDataUrl || !cropRect) {
            resolve(null);
            return;
        }

        const img = new Image();
        img.decoding = 'async';
        img.onload = () => {
            const viewportWidth = Math.max(1, Number(window.innerWidth) || Number(document.documentElement?.clientWidth) || 1);
            const viewportHeight = Math.max(1, Number(window.innerHeight) || Number(document.documentElement?.clientHeight) || 1);
            const naturalWidth = Number(img.naturalWidth) || Number(img.width) || 1;
            const naturalHeight = Number(img.naturalHeight) || Number(img.height) || 1;
            const scaleX = naturalWidth / viewportWidth;
            const scaleY = naturalHeight / viewportHeight;

            const sx = clampNumber(Math.round(cropRect.left * scaleX), 0, naturalWidth - 1);
            const sy = clampNumber(Math.round(cropRect.top * scaleY), 0, naturalHeight - 1);
            const sw = clampNumber(Math.round(cropRect.width * scaleX), 1, naturalWidth - sx);
            const sh = clampNumber(Math.round(cropRect.height * scaleY), 1, naturalHeight - sy);

            const canvas = document.createElement('canvas');
            canvas.width = WELCOME_CAPTURE_OUTPUT_WIDTH;
            canvas.height = WELCOME_CAPTURE_OUTPUT_HEIGHT;
            const context = canvas.getContext('2d');
            if (!context) {
                resolve(null);
                return;
            }

            context.drawImage(
                img,
                sx, sy, sw, sh,
                0, 0, canvas.width, canvas.height
            );
            resolve(canvas.toDataURL('image/jpeg', 0.9));
        };
        img.onerror = () => {
            resolve(null);
        };
        img.src = windowDataUrl;
    });
}

async function captureWelcomeSlideImageFromRect(cropRect, targetImageElement) {
    if (!cropRect || !targetImageElement) {
        return false;
    }

    const fullWindowDataUrl = await captureMainWindowFrameDataUrl();
    if (!fullWindowDataUrl) {
        return false;
    }

    const croppedDataUrl = await cropWindowDataUrlToRect(fullWindowDataUrl, cropRect);
    if (!croppedDataUrl) {
        return false;
    }

    targetImageElement.src = croppedDataUrl;
    return true;
}

async function captureWelcomeSlideImageFromElement(targetElement, targetImageElement, options = {}) {
    if (!targetElement || !targetImageElement) {
        return false;
    }

    const cropRect = getWelcomeCaptureRect(targetElement, options);
    if (!cropRect) {
        return false;
    }

    return captureWelcomeSlideImageFromRect(cropRect, targetImageElement);
}

function loadWelcomeCaptureCache() {
    try {
        const rawCache = localStorage.getItem(WELCOME_CAPTURE_CACHE_KEY);
        if (!rawCache) {
            return null;
        }
        const parsed = JSON.parse(rawCache);
        if (!parsed || typeof parsed !== 'object') {
            return null;
        }
        return parsed;
    } catch (_) {
        return null;
    }
}

function saveWelcomeCaptureCache(cachePayload = {}) {
    try {
        localStorage.setItem(WELCOME_CAPTURE_CACHE_KEY, JSON.stringify(cachePayload));
    } catch (_) {
        // Ignore storage errors and keep runtime flow smooth.
    }
}

function applyWelcomeCaptureCache(cachePayload = null) {
    if (!cachePayload || typeof cachePayload !== 'object') {
        return false;
    }

    let appliedCount = 0;
    const createDataUrl = typeof cachePayload.create === 'string' ? cachePayload.create : '';
    const calcDataUrl = typeof cachePayload.calc === 'string' ? cachePayload.calc : '';
    const garageDataUrl = typeof cachePayload.garage === 'string' ? cachePayload.garage : '';
    const overlayDataUrl = typeof cachePayload.overlay === 'string' ? cachePayload.overlay : '';

    if (welcomeSlideCreateImage && createDataUrl.startsWith('data:image/')) {
        welcomeSlideCreateImage.src = createDataUrl;
        appliedCount += 1;
    }
    if (welcomeSlideCalcImage && calcDataUrl.startsWith('data:image/')) {
        welcomeSlideCalcImage.src = calcDataUrl;
        appliedCount += 1;
    }
    if (welcomeSlideGarageImage && garageDataUrl.startsWith('data:image/')) {
        welcomeSlideGarageImage.src = garageDataUrl;
        appliedCount += 1;
    }
    if (welcomeSlideOverlayImage && overlayDataUrl.startsWith('data:image/')) {
        welcomeSlideOverlayImage.src = overlayDataUrl;
        appliedCount += 1;
    }

    return appliedCount > 0;
}

function syncWelcomeFallbackSlideImages() {
    const createCardImageSrc = btnCreateTune?.querySelector('.card-img')?.currentSrc || btnCreateTune?.querySelector('.card-img')?.getAttribute('src') || '';
    const garageCardImageSrc = btnGarage?.querySelector('.card-img')?.currentSrc || btnGarage?.querySelector('.card-img')?.getAttribute('src') || '';
    const settingsCardImageSrc = btnSettings?.querySelector('.card-img')?.currentSrc || btnSettings?.querySelector('.card-img')?.getAttribute('src') || '';

    if (welcomeSlideCreateImage && createCardImageSrc) {
        welcomeSlideCreateImage.src = createCardImageSrc;
    }

    if (welcomeSlideGarageImage && garageCardImageSrc) {
        welcomeSlideGarageImage.src = garageCardImageSrc;
    }

    if (welcomeSlideOverlayImage && settingsCardImageSrc) {
        welcomeSlideOverlayImage.src = settingsCardImageSrc;
    }
}

function buildWelcomeCalcPreviewPayload() {
    const generatedPayload = buildTuneCalculationPayload();
    if (generatedPayload && Array.isArray(generatedPayload.cards) && generatedPayload.cards.length > 0) {
        return generatedPayload;
    }

    return {
        subtitle: 'Sample tune results preview',
        cards: buildSampleTuneCards()
    };
}

function buildWelcomeSampleGarageRecords() {
    const now = Date.now();
    const presets = [
        {
            tuneName: 'Road Sprint S2',
            shareCode: '123 456 789',
            brand: 'Ferrari',
            model: '488 Pista',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'race',
            pi: 985,
            topSpeedKmh: 352,
            weightKg: 1385,
            frontDistributionPercent: 44,
            maxTorqueNm: 770,
            gears: 7,
            tireWidth: 305,
            tireAspect: 30,
            tireRim: 20,
            redlineRpm: 9000,
            maxTorqueRpm: 6100,
            cardValues: { pressureF: 2.06, pressureR: 2.12, finalDrive: 3.52, springF: 132, springR: 128 }
        },
        {
            tuneName: 'Touge Attack A',
            shareCode: '424 190 775',
            brand: 'Honda',
            model: 'S2000 CR',
            driveType: 'RWD',
            surface: 'street',
            tuneType: 'drift',
            pi: 800,
            topSpeedKmh: 289,
            weightKg: 1210,
            frontDistributionPercent: 49,
            maxTorqueNm: 332,
            gears: 6,
            tireWidth: 255,
            tireAspect: 35,
            tireRim: 18,
            redlineRpm: 9400,
            maxTorqueRpm: 7400,
            cardValues: { pressureF: 1.95, pressureR: 2.08, finalDrive: 3.90, springF: 110, springR: 104 }
        },
        {
            tuneName: 'Rally Trail S1',
            shareCode: '806 227 114',
            brand: 'Subaru',
            model: 'Impreza WRX STI',
            driveType: 'AWD',
            surface: 'dirt',
            tuneType: 'rally',
            pi: 892,
            topSpeedKmh: 274,
            weightKg: 1320,
            frontDistributionPercent: 58,
            maxTorqueNm: 470,
            gears: 6,
            tireWidth: 285,
            tireAspect: 45,
            tireRim: 17,
            redlineRpm: 8200,
            maxTorqueRpm: 5400,
            cardValues: { pressureF: 1.86, pressureR: 1.92, finalDrive: 4.12, springF: 124, springR: 132 }
        },
        {
            tuneName: 'Drag Launch X',
            shareCode: '990 041 662',
            brand: 'Nissan',
            model: 'GT-R NISMO',
            driveType: 'AWD',
            surface: 'street',
            tuneType: 'drag',
            pi: 998,
            topSpeedKmh: 401,
            weightKg: 1720,
            frontDistributionPercent: 46,
            maxTorqueNm: 980,
            gears: 7,
            tireWidth: 315,
            tireAspect: 30,
            tireRim: 20,
            redlineRpm: 7800,
            maxTorqueRpm: 5000,
            cardValues: { pressureF: 2.00, pressureR: 2.24, finalDrive: 2.98, springF: 140, springR: 134 }
        }
    ];

    return presets.map((preset, index) => {
        const payload = {
            subtitle: 'Welcome sample garage record',
            meta: {
                brand: preset.brand,
                model: preset.model,
                driveType: preset.driveType,
                surface: preset.surface,
                tuneType: preset.tuneType,
                pi: preset.pi,
                topSpeedKmh: preset.topSpeedKmh,
                weightKg: preset.weightKg,
                frontDistributionPercent: preset.frontDistributionPercent,
                maxTorqueNm: preset.maxTorqueNm,
                gears: preset.gears,
                tireWidth: preset.tireWidth,
                tireAspect: preset.tireAspect,
                tireRim: preset.tireRim,
                powerBand: normalizePowerBandState({
                    scaleMax: 10,
                    redlineRpm: preset.redlineRpm,
                    maxTorqueRpm: preset.maxTorqueRpm
                })
            },
            cards: buildSampleTuneCards(preset.cardValues)
        };
        const record = buildGarageRecordFromPayload(payload, {
            tuneName: preset.tuneName,
            shareCode: preset.shareCode
        });
        record.id = `welcome_capture_${index + 1}`;
        record.savedAt = new Date(now - (index * 14 * 60 * 1000)).toISOString();
        return record;
    });
}

async function hydrateWelcomeFeatureSlides() {
    if (welcomeFeatureSlidesHydrated) {
        return;
    }

    const cachedSlides = loadWelcomeCaptureCache();
    if (applyWelcomeCaptureCache(cachedSlides)) {
        welcomeFeatureSlidesHydrated = true;
        return;
    }

    welcomeFeatureSlidesHydrated = true;
    syncWelcomeFallbackSlideImages();

    if (!welcomeSlideCreateImage && !welcomeSlideCalcImage && !welcomeSlideGarageImage && !welcomeSlideOverlayImage) {
        return;
    }

    const panelSnapshot = snapshotWelcomeCapturePanelClasses();
    const hadBlurBackground = Boolean(mainElement?.classList.contains('blur-background'));
    const hadCreateBlur = document.body.classList.contains('create-tune-open');
    const capturedSlides = {};
    const garageCaptureSnapshot = {
        tunes: Array.isArray(garageTunes) ? garageTunes.slice() : [],
        selectedIds: Array.from(garageSelectedTuneIds || []),
        currentPage: garageCurrentPage,
        pageSize: garagePageSize,
        sortState: {
            key: normalizeGarageSortKey(garageSortState?.key),
            direction: normalizeGarageSortDirection(garageSortState?.direction)
        }
    };

    try {
        closePowerBandModal({ immediate: true });
        closeTuneCalcModal({ immediate: true });
        closeUiDemoModal({ immediate: true });
        closeDonateModal({ immediate: true });
        closeFeedbackModal({ immediate: true });
        closeUpdateLogModal({ immediate: true });
        closeGarageViewModal({ immediate: true });
        closeGarageDeleteModal({ immediate: true, decision: false });
        document.body.classList.add('welcome-capture-mode');

        if (pageCreateTune) {
            showOnlyPanelForWelcomeCapture(pageCreateTune);
            await waitRenderFrames(3);
            const createFocusElements = [
                pageCreateTune.querySelector('.create-card-vehicle .vehicle-pages-wrap'),
                pageCreateTune.querySelector('.create-card-performance'),
                pageCreateTune.querySelector('.create-card-advanced'),
                pageCreateTune.querySelector('.create-card-config')
            ].filter(Boolean);
            const createFocusedRect = getWelcomeCaptureRectFromElements(createFocusElements, { padding: 20 });
            const createCaptured = createFocusedRect
                ? await captureWelcomeSlideImageFromRect(createFocusedRect, welcomeSlideCreateImage)
                : await captureWelcomeSlideImageFromElement(pageCreateTune, welcomeSlideCreateImage, { padding: 18 });
            if (createCaptured && welcomeSlideCreateImage?.src) {
                capturedSlides.create = welcomeSlideCreateImage.src;
            }
        }

        if (tuneCalcModal) {
            const calcPayload = buildWelcomeCalcPreviewPayload();
            renderTuneCalcModalContent(calcPayload);
            if (tuneCalcSubtitle) {
                tuneCalcSubtitle.textContent = getSettingsLanguageText('tuneResultsSubtitle');
            }
            tuneCalcModal.classList.remove('hidden');
            tuneCalcModal.setAttribute('aria-hidden', 'false');
            tuneCalcModal.classList.add('is-open');
            await waitRenderFrames(3);
            const tuneCalcPanel = tuneCalcModal.querySelector('.tune-calc-modal-panel') || tuneCalcModal;
            const calcCaptured = await captureWelcomeSlideImageFromElement(tuneCalcPanel, welcomeSlideCalcImage, { padding: 14 });
            if (calcCaptured && welcomeSlideCalcImage?.src) {
                capturedSlides.calc = welcomeSlideCalcImage.src;
            }
            closeTuneCalcModal({ immediate: true });
        }

        if (pageGarage) {
            showOnlyPanelForWelcomeCapture(pageGarage);
            garageTunes = buildWelcomeSampleGarageRecords();
            garageSelectedTuneIds = new Set();
            garageCurrentPage = 1;
            garagePageSize = GARAGE_DEFAULT_PAGE_SIZE;
            garageSortState = {
                key: 'savedAt',
                direction: 'desc'
            };
            renderGarageList();
            await waitRenderFrames(3);
            const garageCaptureTarget = pageGarage.querySelector('.garage-content') || pageGarage;
            const garageCaptured = await captureWelcomeSlideImageFromElement(garageCaptureTarget, welcomeSlideGarageImage, { padding: 18 });
            if (garageCaptured && welcomeSlideGarageImage?.src) {
                capturedSlides.garage = welcomeSlideGarageImage.src;
            }
        }

        if (welcomeSlideOverlayImage && tuneOverlay && tuneOverlayTitle && tuneOverlaySubtitle && tuneOverlayLines) {
            const isVietnameseWelcome = normalizeAppLanguage(settingsState.language) === 'vi';
            const samplePressureTitle = isVietnameseWelcome ? 'Áp suất' : 'Pressure';
            const sampleGearingTitle = isVietnameseWelcome ? 'Tỷ số truyền' : 'Gearing';
            const sampleBrakingTitle = isVietnameseWelcome ? 'Phanh' : 'Braking';
            const previousOverlayState = {
                hidden: tuneOverlay.classList.contains('hidden'),
                title: tuneOverlayTitle.textContent,
                subtitle: tuneOverlaySubtitle.textContent,
                lines: tuneOverlayLines.innerHTML
            };

            tuneOverlayTitle.textContent = getSettingsLanguageText('overlayHeadTitle');
            tuneOverlaySubtitle.textContent = getSettingsLanguageText('garageOverlayHint');
            tuneOverlayLines.innerHTML = `
                <article class="tune-overlay-line">
                    <div class="tune-overlay-line-top">
                        <span class="tune-overlay-line-title">${samplePressureTitle}</span>
                        <span class="tune-overlay-line-value">F 1.95 · R 2.02</span>
                    </div>
                </article>
                <article class="tune-overlay-line">
                    <div class="tune-overlay-line-top">
                        <span class="tune-overlay-line-title">${sampleGearingTitle}</span>
                        <span class="tune-overlay-line-value">FD 3.62 · 7 Gears</span>
                    </div>
                </article>
                <article class="tune-overlay-line">
                    <div class="tune-overlay-line-top">
                        <span class="tune-overlay-line-title">${sampleBrakingTitle}</span>
                        <span class="tune-overlay-line-value">Balance 51% · Force 114%</span>
                    </div>
                </article>
            `;
            tuneOverlay.classList.remove('hidden');
            await waitRenderFrames(3);
            const overlayCaptured = await captureWelcomeSlideImageFromElement(tuneOverlay, welcomeSlideOverlayImage, { padding: 14 });
            if (overlayCaptured && welcomeSlideOverlayImage?.src) {
                capturedSlides.overlay = welcomeSlideOverlayImage.src;
            }

            tuneOverlayTitle.textContent = previousOverlayState.title;
            tuneOverlaySubtitle.textContent = previousOverlayState.subtitle;
            tuneOverlayLines.innerHTML = previousOverlayState.lines;
            if (previousOverlayState.hidden) {
                tuneOverlay.classList.add('hidden');
            }
        }

        if (Object.keys(capturedSlides).length > 0) {
            saveWelcomeCaptureCache(capturedSlides);
        }
    } catch (_) {
        // Keep fallback slide images if capture fails.
    } finally {
        closeTuneCalcModal({ immediate: true });
        garageTunes = Array.isArray(garageCaptureSnapshot.tunes) ? garageCaptureSnapshot.tunes : [];
        garageSelectedTuneIds = new Set(Array.isArray(garageCaptureSnapshot.selectedIds) ? garageCaptureSnapshot.selectedIds : []);
        garagePageSize = normalizeGaragePageSize(garageCaptureSnapshot.pageSize);
        garageCurrentPage = normalizeGaragePage(Number(garageCaptureSnapshot.currentPage) || 1, Math.max(1, Math.ceil(Math.max(1, garageTunes.length) / Math.max(1, getGarageEffectivePageSize()))));
        garageSortState = {
            key: normalizeGarageSortKey(garageCaptureSnapshot.sortState?.key),
            direction: normalizeGarageSortDirection(garageCaptureSnapshot.sortState?.direction)
        };
        renderGarageList();
        restoreWelcomeCapturePanelClasses(panelSnapshot);
        document.body.classList.remove('welcome-capture-mode');
        if (mainElement) {
            mainElement.classList.toggle('blur-background', hadBlurBackground);
        }
        toggleCreateTuneBackgroundBlur(hadCreateBlur);
        syncCapsuleGroupIndicators();
        updateCreateCalcButtonState();
    }
}

function clearWelcomeHideTimer() {
    if (welcomeHideTimer) {
        clearTimeout(welcomeHideTimer);
        welcomeHideTimer = null;
    }
}

function isWelcomeModalOpen() {
    return Boolean(welcomeModal && !welcomeModal.classList.contains('hidden') && welcomeModal.classList.contains('is-open'));
}

function hasWelcomeBeenSeen() {
    try {
        return String(localStorage.getItem(WELCOME_STORAGE_KEY) || '').trim() === APP_BUILD_VERSION;
    } catch (_) {
        return false;
    }
}

function setWelcomeSeen() {
    try {
        localStorage.setItem(WELCOME_STORAGE_KEY, APP_BUILD_VERSION);
    } catch (_) {
        // Ignore storage errors and continue runtime flow.
    }
}

function getWelcomeSetupSelectedLanguage() {
    const activeButton = welcomeSetupLanguageGroup?.querySelector('.welcome-setup-choice.is-active');
    return normalizeAppLanguage(activeButton?.dataset?.welcomeLanguage || settingsState.language);
}

function getWelcomeSetupSelectedUnit() {
    const activeButton = welcomeSetupUnitGroup?.querySelector('.welcome-setup-choice.is-active');
    return normalizeUnitSystem(activeButton?.dataset?.welcomeUnit || settingsState.unitSystem);
}

function normalizeWelcomeTheme(value) {
    return String(value || '').toLowerCase() === 'dark' ? 'dark' : 'light';
}

function getWelcomeSetupSelectedTheme() {
    const activeButton = welcomeSetupThemeGroup?.querySelector('.welcome-setup-choice.is-active');
    const fallbackTheme = resolveDarkModeFromThemeMode(settingsState.themeMode) ? 'dark' : 'light';
    return normalizeWelcomeTheme(activeButton?.dataset?.welcomeTheme || fallbackTheme);
}

function setWelcomeSetupSelectedLanguage(language) {
    if (!welcomeSetupLanguageGroup) {
        return;
    }
    const normalized = normalizeAppLanguage(language);
    welcomeSetupLanguageGroup.querySelectorAll('.welcome-setup-choice').forEach((button) => {
        button.classList.toggle('is-active', normalizeAppLanguage(button.dataset.welcomeLanguage) === normalized);
    });
}

function setWelcomeSetupSelectedUnit(unitSystem) {
    if (!welcomeSetupUnitGroup) {
        return;
    }
    const normalized = normalizeUnitSystem(unitSystem);
    welcomeSetupUnitGroup.querySelectorAll('.welcome-setup-choice').forEach((button) => {
        button.classList.toggle('is-active', normalizeUnitSystem(button.dataset.welcomeUnit) === normalized);
    });
}

function setWelcomeSetupSelectedTheme(theme) {
    if (!welcomeSetupThemeGroup) {
        return;
    }
    const normalized = normalizeWelcomeTheme(theme);
    welcomeSetupThemeGroup.querySelectorAll('.welcome-setup-choice').forEach((button) => {
        button.classList.toggle('is-active', normalizeWelcomeTheme(button.dataset.welcomeTheme) === normalized);
    });
}

function syncWelcomeSetupSelectionUi() {
    setWelcomeSetupSelectedLanguage(settingsState.language);
    setWelcomeSetupSelectedUnit(settingsState.unitSystem);
    setWelcomeSetupSelectedTheme(resolveDarkModeFromThemeMode(settingsState.themeMode) ? 'dark' : 'light');
}

function applyWelcomeSetupSelections({ persist = true } = {}) {
    const selectedLanguage = getWelcomeSetupSelectedLanguage();
    const selectedUnitSystem = getWelcomeSetupSelectedUnit();
    const selectedTheme = getWelcomeSetupSelectedTheme();

    settingsState.language = selectedLanguage;
    settingsState.unitSystem = selectedUnitSystem;
    settingsState.themeMode = selectedTheme;
    if (settingsLanguageSelect) {
        settingsLanguageSelect.value = selectedLanguage;
    }
    syncThemeControlsUi();
    applySettingsLanguageUi();
    applyThemeMode(selectedTheme, { persist: false });
    setCreateTuneUnitSystem(selectedUnitSystem, { persist: false, convertFieldValues: false });

    if (persist) {
        saveSettings(false);
    }
}

function syncWelcomeModalUi() {
    if (!welcomeModal) {
        return;
    }

    if (welcomeInSetupStep) {
        welcomeModal.classList.add('is-setup');
        if (welcomeSlidesTrack) {
            welcomeSlidesTrack.style.transform = 'translateX(0%)';
        }
        if (welcomeFinalOptin) {
            welcomeFinalOptin.setAttribute('aria-hidden', 'true');
        }
        if (welcomeNextBtn) {
            welcomeNextBtn.disabled = false;
            welcomeNextBtn.setAttribute('aria-hidden', 'false');
            welcomeNextBtn.setAttribute('aria-label', getSettingsLanguageText('welcomeSetupContinueAria'));
        }
        if (welcomeCloseBtn) {
            welcomeCloseBtn.disabled = true;
            welcomeCloseBtn.classList.remove('is-ready');
        }
        if (welcomeDots.length > 0) {
            welcomeDots.forEach((dot) => dot.classList.remove('is-active'));
        }
        return;
    }

    welcomeModal.classList.remove('is-setup');

    const normalizedIndex = clampNumber(Math.round(Number(welcomeSlideIndex) || 0), 0, WELCOME_LAST_INDEX);
    welcomeSlideIndex = normalizedIndex;

    if (welcomeSlidesTrack) {
        welcomeSlidesTrack.style.transform = `translateX(-${normalizedIndex * 100}%)`;
    }

    if (welcomeDots.length > 0) {
        welcomeDots.forEach((dot, index) => {
            dot.classList.toggle('is-active', index === normalizedIndex);
        });
    }

    const isLastPage = normalizedIndex === WELCOME_LAST_INDEX;
    welcomeModal.classList.toggle('is-last-page', isLastPage);
    if (welcomeFinalOptin) {
        welcomeFinalOptin.setAttribute('aria-hidden', isLastPage ? 'false' : 'true');
    }

    if (welcomeNextBtn) {
        welcomeNextBtn.disabled = isLastPage;
        welcomeNextBtn.setAttribute('aria-hidden', isLastPage ? 'true' : 'false');
        welcomeNextBtn.setAttribute('aria-label', getSettingsLanguageText('welcomeNextAria'));
    }

    const canClose = isLastPage && Boolean(welcomeDontShowCheckbox?.checked);
    if (welcomeCloseBtn) {
        welcomeCloseBtn.disabled = !canClose;
        welcomeCloseBtn.classList.toggle('is-ready', canClose);
    }
}

function openWelcomeModal() {
    if (!welcomeModal || hasWelcomeBeenSeen()) {
        return;
    }

    setWelcomeSeen();
    clearWelcomeHideTimer();
    welcomeInSetupStep = true;
    welcomeSlideIndex = 0;
    syncWelcomeSetupSelectionUi();
    if (welcomeDontShowCheckbox) {
        welcomeDontShowCheckbox.checked = false;
    }
    syncWelcomeModalUi();

    welcomeModal.classList.remove('hidden');
    welcomeModal.setAttribute('aria-hidden', 'false');
    document.body.classList.add('welcome-open');

    requestAnimationFrame(() => {
        if (!welcomeModal) {
            return;
        }
        welcomeModal.classList.add('is-open');
    });
}

function closeWelcomeModal({ immediate = false } = {}) {
    if (!welcomeModal) {
        return;
    }

    clearWelcomeHideTimer();
    welcomeModal.classList.remove('is-open');
    document.body.classList.remove('welcome-open');

    const hideModal = () => {
        welcomeModal.classList.add('hidden');
        welcomeModal.setAttribute('aria-hidden', 'true');
        if (pendingStartupUpdateLog) {
            requestAnimationFrame(() => {
                queueStartupUpdateLogIfNeeded();
            });
        }
    };

    if (immediate) {
        hideModal();
        return;
    }

    welcomeHideTimer = setTimeout(() => {
        hideModal();
        welcomeHideTimer = null;
    }, WELCOME_MODAL_TRANSITION_MS);
}

function moveWelcomeToNextPage() {
    if (welcomeInSetupStep) {
        applyWelcomeSetupSelections({ persist: true });
        welcomeInSetupStep = false;
        welcomeSlideIndex = 0;
        syncWelcomeModalUi();
        return;
    }

    if (welcomeSlideIndex >= WELCOME_LAST_INDEX) {
        return;
    }

    welcomeSlideIndex += 1;
    syncWelcomeModalUi();
}

function tryCompleteWelcomeFlow() {
    if (!welcomeCloseBtn || welcomeCloseBtn.disabled) {
        return;
    }
    setWelcomeSeen();
    closeWelcomeModal();
}

function releaseStartupPendingState() {
    if (!document.body) {
        return;
    }
    document.body.classList.remove('startup-pending');
}

function clearFeedbackModalHideTimer() {
    if (feedbackModalHideTimer) {
        clearTimeout(feedbackModalHideTimer);
        feedbackModalHideTimer = null;
    }
}

function isFeedbackModalOpen() {
    return Boolean(feedbackModal && !feedbackModal.classList.contains('hidden') && feedbackModal.classList.contains('is-open'));
}

function openFeedbackModal() {
    if (!feedbackModal) {
        return;
    }

    closeDonateModal({ immediate: true });
    closeUpdateLogModal({ immediate: true });
    closeUiDemoModal({ immediate: true });
    clearFeedbackModalHideTimer();
    feedbackModal.classList.remove('hidden');
    feedbackModal.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => {
        feedbackModal.classList.add('is-open');
        if (feedbackTitleInput) {
            feedbackTitleInput.focus();
        }
    });
}

function closeFeedbackModal({ immediate = false } = {}) {
    if (!feedbackModal) {
        return;
    }

    clearFeedbackModalHideTimer();
    feedbackModal.classList.remove('is-open');

    const hideModal = () => {
        feedbackModal.classList.add('hidden');
        feedbackModal.setAttribute('aria-hidden', 'true');
    };

    if (immediate) {
        hideModal();
        return;
    }

    feedbackModalHideTimer = setTimeout(() => {
        hideModal();
        feedbackModalHideTimer = null;
    }, FEEDBACK_MODAL_TRANSITION_MS);
}

function enforcePrimaryPreviewStyle() {
    document.body.classList.add(PRIMARY_PREVIEW_STYLE_CLASS);
    LEGACY_PREVIEW_STYLE_CLASSES.forEach((className) => {
        document.body.classList.remove(className);
    });
}

function closeUiDemoModal() {
    // Legacy no-op: UI demo modal has been removed from the app.
}

function clearAppToastHideTimer() {
    if (appToastHideTimer) {
        clearTimeout(appToastHideTimer);
        appToastHideTimer = null;
    }
}

function showAppToast(message, options = {}) {
    if (!appToast || !appToastMessage) {
        return;
    }

    const normalizedMessage = String(message || '').trim();
    if (!normalizedMessage) {
        return;
    }

    const type = String(options.type || 'info').trim().toLowerCase();
    const duration = clampNumber(Number(options.duration) || 2800, 1400, 7000);
    const iconByType = {
        success: 'check_circle',
        error: 'error',
        info: 'info'
    };
    const icon = iconByType[type] || iconByType.info;
    const renderToken = Date.now() + Math.random();
    appToastRenderToken = renderToken;

    clearAppToastHideTimer();
    appToastMessage.textContent = normalizedMessage;
    if (appToastIcon) {
        appToastIcon.textContent = icon;
    }

    appToast.classList.remove('hidden', 'is-visible', 'is-success', 'is-error', 'is-info');
    appToast.classList.add(`is-${type}`);

    requestAnimationFrame(() => {
        if (appToastRenderToken !== renderToken) {
            return;
        }
        appToast.classList.add('is-visible');
    });

    appToastHideTimer = setTimeout(() => {
        if (appToastRenderToken !== renderToken) {
            return;
        }
        appToast.classList.remove('is-visible');
        setTimeout(() => {
            if (appToastRenderToken !== renderToken) {
                return;
            }
            appToast.classList.add('hidden');
            appToast.classList.remove('is-success', 'is-error', 'is-info');
            appToastHideTimer = null;
        }, 240);
    }, duration);
}

async function submitFeedback() {
    const title = String(feedbackTitleInput?.value || '').trim();
    const name = String(feedbackNameInput?.value || '').trim();
    const email = String(feedbackEmailInput?.value || '').trim();
    const message = String(feedbackMessageInput?.value || '').trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!title) {
        showAppToast(getSettingsLanguageText('feedbackTitleRequired'), { type: 'error' });
        if (feedbackTitleInput) {
            feedbackTitleInput.focus();
        }
        return;
    }
    if (!email || !emailRegex.test(email)) {
        showAppToast(getSettingsLanguageText('feedbackEmailRequired'), { type: 'error' });
        if (feedbackEmailInput) {
            feedbackEmailInput.focus();
        }
        return;
    }
    if (!message) {
        showAppToast(getSettingsLanguageText('feedbackMessageRequired'), { type: 'error' });
        if (feedbackMessageInput) {
            feedbackMessageInput.focus();
        }
        return;
    }

    if (btnFeedbackSend) {
        btnFeedbackSend.disabled = true;
        btnFeedbackSend.textContent = getSettingsLanguageText('feedbackSending');
    }

    try {
        const response = await ipcRenderer.invoke('submit-feedback', {
            title,
            name,
            email,
            message,
            build: APP_BUILD_VERSION
        });
        if (!response || !response.ok) {
            throw new Error(response?.error || getSettingsLanguageText('feedbackFailed'));
        }

        if (feedbackTitleInput) {
            feedbackTitleInput.value = '';
        }
        if (feedbackNameInput) {
            feedbackNameInput.value = '';
        }
        if (feedbackEmailInput) {
            feedbackEmailInput.value = '';
        }
        if (feedbackMessageInput) {
            feedbackMessageInput.value = '';
        }
        closeFeedbackModal();
        showAppToast(getSettingsLanguageText('feedbackSuccess'), { type: 'success' });
    } catch (error) {
        showAppToast(error?.message || getSettingsLanguageText('feedbackFailed'), { type: 'error', duration: 4200 });
    } finally {
        if (btnFeedbackSend) {
            btnFeedbackSend.disabled = false;
            btnFeedbackSend.innerHTML = `
                <span class="material-symbols-outlined" aria-hidden="true">send</span>
                <span id="feedback-send-label">${escapeHtml(getSettingsLanguageText('feedbackSendButton'))}</span>
            `;
        }
    }
}

function syncGameVersionUI() {
    document.querySelectorAll('.game-version-option').forEach((option) => {
        option.classList.toggle('active', option.dataset.version === settingsState.gameVersion);
    });
}

function loadSettings() {
    const autosaveToggle = document.getElementById('toggle-autosave');

    const savedSettings = localStorage.getItem('appSettings');
    if (savedSettings) {
        try {
            const parsed = JSON.parse(savedSettings);
            settingsState = {
                ...settingsState,
                ...parsed
            };
        } catch (_) {
            // Ignore malformed settings and keep defaults.
        }
    }

    if (settingsState.customBackground && !settingsState.customBackgroundType) {
        settingsState.customBackgroundType = settingsState.customBackground.startsWith('data:video/') ? 'video' : 'image';
    }

    settingsState.unitSystem = normalizeUnitSystem(settingsState.unitSystem);
    settingsState.language = normalizeAppLanguage(settingsState.language);
    settingsState.themeMode = normalizeThemeMode(
        settingsState.themeMode || (settingsState.darkMode ? 'dark' : 'light')
    );
    settingsState.darkMode = resolveDarkModeFromThemeMode(settingsState.themeMode);
    settingsState.overlayMode = Boolean(settingsState.overlayMode);
    settingsState.overlayOnTop = settingsState.overlayOnTop !== false;
    settingsState.overlayOpacity = normalizeOverlayOpacity(settingsState.overlayOpacity);
    settingsState.overlayTextScale = normalizeOverlayTextScale(settingsState.overlayTextScale);
    settingsState.overlayLayout = normalizeOverlayLayoutPreset(settingsState.overlayLayout);
    settingsState.overlayLocked = Boolean(settingsState.overlayLocked);

    if (settingsState.customBackground && !settingsState.customBackgroundName) {
        settingsState.customBackgroundName = settingsState.customBackgroundType === 'video'
            ? getSettingsLanguageText('backgroundFallbackVideoName')
            : getSettingsLanguageText('backgroundFallbackImageName');
    }

    if (autosaveToggle) {
        autosaveToggle.checked = settingsState.autosave;
    }
    if (settingsLanguageSelect) {
        settingsLanguageSelect.value = settingsState.language;
    }
    if (settingsThemeModeSelect) {
        settingsThemeModeSelect.value = settingsState.themeMode;
    }
    syncOverlaySettingsUi();

    syncGameVersionUI();
    enforcePrimaryPreviewStyle();
    applySettingsLanguageUi();
    applyThemeMode(settingsState.themeMode, { persist: false });
    applyCustomBackground(settingsState.customBackground, settingsState.customBackgroundType || 'image');
    setCreateTuneUnitSystem(settingsState.unitSystem, { persist: false, convertFieldValues: false });
    setOverlayModeEnabled(settingsState.overlayMode);
}

// Toggles
if (settingsThemeModeSelect) {
    settingsThemeModeSelect.addEventListener('change', (e) => {
        applyThemeMode(e.target.value, { persist: true });
    });
}

if (systemThemeMediaQuery) {
    const handleSystemThemeChange = () => {
        if (normalizeThemeMode(settingsState.themeMode) === 'system') {
            applyThemeMode('system', { persist: false });
        }
    };

    if (typeof systemThemeMediaQuery.addEventListener === 'function') {
        systemThemeMediaQuery.addEventListener('change', handleSystemThemeChange);
    } else if (typeof systemThemeMediaQuery.addListener === 'function') {
        systemThemeMediaQuery.addListener(handleSystemThemeChange);
    }
}

const autosaveToggle = document.getElementById('toggle-autosave');
autosaveToggle.addEventListener('change', (e) => {
    settingsState.autosave = e.target.checked;
    saveSettings(false);
});

if (settingsLanguageSelect) {
    settingsLanguageSelect.addEventListener('change', (e) => {
        settingsState.language = normalizeAppLanguage(e.target.value);
        applySettingsLanguageUi();
        saveSettings(false);
    });
}

if (toggleOverlayMode) {
    toggleOverlayMode.addEventListener('change', (e) => {
        setOverlayModeEnabled(e.target.checked);
        saveSettings(false);
    });
}

if (toggleOverlayOnTop) {
    toggleOverlayOnTop.addEventListener('change', (e) => {
        setOverlayOnTopEnabled(e.target.checked);
        saveSettings(false);
    });
}

if (overlayOpacitySlider) {
    bindRangeInteractionMotion(overlayOpacitySlider);
    const handleOverlayOpacityChange = () => {
        setOverlayOpacity(Number(overlayOpacitySlider.value));
        saveSettings(false);
    };

    overlayOpacitySlider.addEventListener('input', () => {
        setOverlayOpacity(Number(overlayOpacitySlider.value));
    });
    overlayOpacitySlider.addEventListener('change', handleOverlayOpacityChange);
}

// Game version

document.querySelectorAll('.game-version-option').forEach((option) => {
    option.addEventListener('click', () => {
        settingsState.gameVersion = option.dataset.version;
        syncGameVersionUI();
        saveSettings(false);
    });
});

if (btnOpenDonate) {
    btnOpenDonate.addEventListener('click', () => {
        openDonateModal();
    });
}

if (btnOpenFeedback) {
    btnOpenFeedback.addEventListener('click', () => {
        openFeedbackModal();
    });
}

if (btnDonateClose) {
    btnDonateClose.addEventListener('click', () => {
        closeDonateModal();
    });
}

if (donateModalBackdrop) {
    donateModalBackdrop.addEventListener('click', () => {
        closeDonateModal();
    });
}

if (btnUpdateLogClose) {
    btnUpdateLogClose.addEventListener('click', () => {
        closeUpdateLogModal();
    });
}

if (btnUpdateLogDone) {
    btnUpdateLogDone.addEventListener('click', () => {
        closeUpdateLogModal();
    });
}

if (updateLogModalBackdrop) {
    updateLogModalBackdrop.addEventListener('click', () => {
        closeUpdateLogModal();
    });
}

if (btnFeedbackClose) {
    btnFeedbackClose.addEventListener('click', () => {
        closeFeedbackModal();
    });
}

if (btnFeedbackCancel) {
    btnFeedbackCancel.addEventListener('click', () => {
        closeFeedbackModal();
    });
}

if (feedbackModalBackdrop) {
    feedbackModalBackdrop.addEventListener('click', () => {
        closeFeedbackModal();
    });
}

if (btnFeedbackSend) {
    btnFeedbackSend.addEventListener('click', () => {
        submitFeedback();
    });
}

if (welcomeNextBtn) {
    welcomeNextBtn.addEventListener('click', () => {
        moveWelcomeToNextPage();
    });
}

if (welcomeSetupLanguageGroup) {
    welcomeSetupLanguageGroup.addEventListener('click', (event) => {
        const target = event.target.closest('[data-welcome-language]');
        if (!target || !welcomeSetupLanguageGroup.contains(target)) {
            return;
        }

        const nextLanguage = normalizeAppLanguage(target.dataset.welcomeLanguage);
        if (settingsState.language === nextLanguage) {
            setWelcomeSetupSelectedLanguage(nextLanguage);
            return;
        }

        settingsState.language = nextLanguage;
        if (settingsLanguageSelect) {
            settingsLanguageSelect.value = nextLanguage;
        }
        applySettingsLanguageUi();
        saveSettings(false);
    });
}

if (welcomeSetupUnitGroup) {
    welcomeSetupUnitGroup.addEventListener('click', (event) => {
        const target = event.target.closest('[data-welcome-unit]');
        if (!target || !welcomeSetupUnitGroup.contains(target)) {
            return;
        }

        const nextUnitSystem = normalizeUnitSystem(target.dataset.welcomeUnit);
        if (settingsState.unitSystem === nextUnitSystem) {
            setWelcomeSetupSelectedUnit(nextUnitSystem);
            return;
        }

        settingsState.unitSystem = nextUnitSystem;
        setCreateTuneUnitSystem(nextUnitSystem, { persist: false, convertFieldValues: false });
        syncWelcomeSetupSelectionUi();
        saveSettings(false);
    });
}

if (welcomeSetupThemeGroup) {
    welcomeSetupThemeGroup.addEventListener('click', (event) => {
        const target = event.target.closest('[data-welcome-theme]');
        if (!target || !welcomeSetupThemeGroup.contains(target)) {
            return;
        }

        const nextTheme = normalizeWelcomeTheme(target.dataset.welcomeTheme);
        if (normalizeThemeMode(settingsState.themeMode) === nextTheme) {
            setWelcomeSetupSelectedTheme(nextTheme);
            return;
        }

        applyThemeMode(nextTheme, { persist: false });
        syncWelcomeSetupSelectionUi();
        saveSettings(false);
    });
}

if (welcomeCloseBtn) {
    welcomeCloseBtn.addEventListener('click', () => {
        tryCompleteWelcomeFlow();
    });
}

if (welcomeDontShowCheckbox) {
    welcomeDontShowCheckbox.addEventListener('change', () => {
        syncWelcomeModalUi();
    });
}

if (feedbackMessageInput) {
    feedbackMessageInput.addEventListener('keydown', (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
            event.preventDefault();
            submitFeedback();
        }
    });
}

if (feedbackTitleInput) {
    feedbackTitleInput.addEventListener('keydown', (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
            event.preventDefault();
            submitFeedback();
            return;
        }

        if (event.key === 'Enter') {
            event.preventDefault();
            if (feedbackNameInput) {
                feedbackNameInput.focus();
            } else if (feedbackEmailInput) {
                feedbackEmailInput.focus();
            }
        }
    });
}

if (feedbackNameInput) {
    feedbackNameInput.addEventListener('keydown', (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
            event.preventDefault();
            submitFeedback();
            return;
        }

        if (event.key === 'Enter') {
            event.preventDefault();
            if (feedbackEmailInput) {
                feedbackEmailInput.focus();
            }
        }
    });
}

if (feedbackEmailInput) {
    feedbackEmailInput.addEventListener('keydown', (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
            event.preventDefault();
            submitFeedback();
            return;
        }

        if (event.key === 'Enter') {
            event.preventDefault();
            if (feedbackMessageInput) {
                feedbackMessageInput.focus();
            }
        }
    });
}

document.addEventListener('keydown', (event) => {
    if (isWelcomeModalOpen()) {
        if (event.key === 'ArrowRight' || event.key === 'Enter') {
            event.preventDefault();
            if (welcomeSlideIndex < WELCOME_LAST_INDEX) {
                moveWelcomeToNextPage();
            } else {
                tryCompleteWelcomeFlow();
            }
            return;
        }
    }

    if (event.key === 'Escape' && isDonateModalOpen()) {
        event.preventDefault();
        closeDonateModal();
        return;
    }

    if (event.key === 'Escape' && isUpdateLogModalOpen()) {
        event.preventDefault();
        closeUpdateLogModal();
        return;
    }

    if (event.key === 'Escape' && isFeedbackModalOpen()) {
        event.preventDefault();
        closeFeedbackModal();
    }
});

// Upload handling
uploadArea.addEventListener('click', () => {
    fileInput.click();
});

uploadArea.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadArea.classList.add('drag-over');
});

uploadArea.addEventListener('dragleave', () => {
    uploadArea.classList.remove('drag-over');
});

uploadArea.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadArea.classList.remove('drag-over');

    const files = e.dataTransfer.files;
    if (files.length > 0) {
        handleFileSelect(files[0]);
    }
});

fileInput.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        handleFileSelect(e.target.files[0]);
    }
});

function handleFileSelect(file) {
    const isImage = ALLOWED_IMAGE_TYPES.includes(file.type);
    const isVideo = ALLOWED_VIDEO_TYPES.includes(file.type);

    if (!isImage && !isVideo) {
        alert(getSettingsLanguageText('settingsInvalidFileType'));
        return;
    }

    const maxSize = isVideo ? MAX_VIDEO_SIZE_BYTES : MAX_IMAGE_SIZE_BYTES;
    if (file.size > maxSize) {
        alert(getSettingsLanguageText(isVideo ? 'settingsFileTooLargeVideo' : 'settingsFileTooLargeImage'));
        return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
        const dataUrl = e.target.result;
        if (typeof dataUrl !== 'string') {
            return;
        }

        settingsState.customBackground = dataUrl;
        settingsState.customBackgroundType = isVideo ? 'video' : 'image';
        settingsState.customBackgroundName = file.name;

        applyCustomBackground(settingsState.customBackground, settingsState.customBackgroundType);
        updateBackgroundUploadUI(settingsState.customBackgroundName, settingsState.customBackgroundType);
        saveSettings();
    };

    reader.readAsDataURL(file);
}

// Reset
const btnResetSettings = document.getElementById('btn-reset-settings');
btnResetSettings.addEventListener('click', () => {
    closeUiDemoModal({ immediate: true });
    closeDonateModal({ immediate: true });
    closeFeedbackModal({ immediate: true });
    closeUpdateLogModal({ immediate: true });
    closeGarageViewModal({ immediate: true });
    closeGarageDeleteModal({ immediate: true, decision: false });
    if (!confirm(getSettingsLanguageText('settingsResetConfirm'))) {
        return;
    }

    settingsState = {
        darkMode: false,
        themeMode: 'light',
        autosave: true,
        language: 'en',
        unitSystem: 'metric',
        overlayMode: false,
        overlayOnTop: true,
        overlayOpacity: 0.88,
        overlayTextScale: 1,
        overlayLayout: 'vertical',
        overlayLocked: false,
        gameVersion: 'fh5',
        customBackground: null,
        customBackgroundType: null,
        customBackgroundName: null
    };

    localStorage.removeItem('appSettings');
    applyThemeMode('light', { persist: false });
    applyCustomBackground(null);

    if (settingsThemeModeSelect) {
        settingsThemeModeSelect.value = 'light';
    }
    if (autosaveToggle) {
        autosaveToggle.checked = true;
    }
    if (settingsLanguageSelect) {
        settingsLanguageSelect.value = 'en';
    }
    syncOverlaySettingsUi();
    fileInput.value = '';
    syncGameVersionUI();
    applySettingsLanguageUi();
    setCreateTuneUnitSystem('metric', { persist: false, convertFieldValues: true });
    setOverlayModeEnabled(false);

    alert(getSettingsLanguageText('settingsResetDone'));
});

// Initialize interactive UI blocks
syncResponsiveWindowMode();
requestAnimationFrame(() => {
    syncFunctionalPanelHeight();
});
window.addEventListener('load', syncFunctionalPanelHeight);
initCapsuleGroups();
initCreateModelPresetControls();
initPowerBandControls();
initTuneCalcControls();
syncTuneCalcLayoutUi();
loadGarageTunes();
loadActiveOverlayTune();
initGarageControls();
syncCreateTuneGameVersion(createGameVersionGroup?.querySelector('[data-create-game-version].is-active')?.dataset.createGameVersion || 'fh5');
syncTuneTypeOptionsByDrivingSurface(getActiveCapsuleOptionKey(createDrivingSurfaceGroup, 'street'), { animate: false });
updateCreateCalcButtonState();

if (pageCreateTune) {
    pageCreateTune.addEventListener('input', () => {
        updateCreateCalcButtonState();
    });

    pageCreateTune.addEventListener('change', () => {
        updateCreateCalcButtonState();
    });
}

if (createCurrentPiInput) {
    createCurrentPiInput.addEventListener('input', () => {
        updatePiBadgeElement(createCurrentPiBadge, createCurrentPiInput.value);

        if (vehicleBrowserState.selectedBrand && vehicleBrowserState.selectedModel) {
            updatePiBadgeElement(vehiclePreviewPiBadge, createCurrentPiInput.value, { animate: true });
        }
    });
}

if (createFrontDistributionInput) {
    createFrontDistributionInput.addEventListener('input', () => {
        clearCreateModelPresetActiveState();
        refreshSelectedVehicleModelInfo();
    });
}

// Load settings at startup
loadSettings();

if (!hasWelcomeBeenSeen()) {
    const cachedWelcomeSlides = loadWelcomeCaptureCache();
    const hasCachedWelcomeSlides = applyWelcomeCaptureCache(cachedWelcomeSlides);
    pendingStartupUpdateLog = shouldShowStartupUpdateLog();

    if (hasCachedWelcomeSlides) {
        welcomeFeatureSlidesHydrated = true;
        openWelcomeModal();
        releaseStartupPendingState();
    } else {
        hydrateWelcomeFeatureSlides()
            .catch(() => {
                // Keep fallback welcome slide images on capture errors.
                syncWelcomeFallbackSlideImages();
            })
            .finally(() => {
                openWelcomeModal();
                releaseStartupPendingState();
            });
    }
} else {
    releaseStartupPendingState();
    queueStartupUpdateLogIfNeeded();
}

// --- 4. Discord link (external URL) ---
const discordLink = document.getElementById('discord-link');
if (discordLink) {
    const openDiscordServer = () => {
        const discordUrl = 'https://discord.gg/dg7Enmek';
        ipcRenderer.send('open-external-url', discordUrl);
    };

    discordLink.addEventListener('click', openDiscordServer);
    discordLink.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            openDiscordServer();
        }
    });
}


