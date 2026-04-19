const { app, BrowserWindow, ipcMain, shell, screen } = require('electron');
const https = require('https');
const path = require('path');
const fs = require('fs');

let mainWindow;
let overlayWindow = null;
let overlayWindowReady = false;
let overlayPendingState = null;
let overlayWindowBounds = null;
let overlayBoundsSaveTimer = null;
let overlayControlState = {
    opacity: 0.88,
    textScale: 1,
    layoutPreset: 'vertical',
    alwaysOnTop: true,
    lockPosition: false
};
const FEEDBACK_EMAIL_ADDRESS = 'contact.vndrift@gmail.com';
const FEEDBACK_AUTO_RESPONSE_MESSAGE = 'C\u00E1m \u01A1n b\u1EA1n \u0111\u00E3 \u0111\u00F3ng g\u00F3p \u00FD ki\u1EBFn, T\u00F4i s\u1EBD xem x\u00E9t, s\u1EEDa \u0111\u1ED5i v\u00E0 c\u1EADp nh\u1EADt \u1EE9ng d\u1EE5ng trong c\u00E1c b\u1EA3n ti\u1EBFp theo.';
const OVERLAY_DEFAULT_BOUNDS = Object.freeze({
    width: 430,
    height: 620
});
const OVERLAY_MIN_WIDTH = 340;
const OVERLAY_MIN_HEIGHT = 320;
const OVERLAY_MAX_WIDTH = 680;
const OVERLAY_BOUNDS_FILE_NAME = 'overlay-window-bounds.json';

function clampNumber(value, min, max) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
        return min;
    }
    return Math.min(max, Math.max(min, numeric));
}

function normalizeOverlayLayoutPreset(value) {
    const normalized = String(value || '').trim().toLowerCase();
    if (normalized === 'grid' || normalized === 'compact' || normalized === 'vertical') {
        return normalized;
    }
    return 'vertical';
}

function getOverlayBoundsFilePath() {
    return path.join(app.getPath('userData'), OVERLAY_BOUNDS_FILE_NAME);
}

function normalizeOverlayWindowBounds(rawBounds = {}) {
    const fallbackWidth = OVERLAY_DEFAULT_BOUNDS.width;
    const fallbackHeight = OVERLAY_DEFAULT_BOUNDS.height;
    const width = Math.round(clampNumber(rawBounds.width, OVERLAY_MIN_WIDTH, OVERLAY_MAX_WIDTH));
    const workArea = screen.getPrimaryDisplay().workArea;
    const maxHeight = Math.max(OVERLAY_MIN_HEIGHT, workArea.height);
    const height = Math.round(clampNumber(rawBounds.height, OVERLAY_MIN_HEIGHT, maxHeight));

    const numericX = Number(rawBounds.x);
    const numericY = Number(rawBounds.y);
    const hasPosition = Number.isFinite(numericX) && Number.isFinite(numericY);
    const targetRect = {
        x: hasPosition ? Math.round(numericX) : workArea.x,
        y: hasPosition ? Math.round(numericY) : workArea.y,
        width,
        height
    };

    const matchingDisplay = screen.getDisplayMatching(targetRect) || screen.getPrimaryDisplay();
    const boundsArea = matchingDisplay.workArea || workArea;
    const maxX = boundsArea.x + Math.max(0, boundsArea.width - width);
    const maxY = boundsArea.y + Math.max(0, boundsArea.height - height);
    const x = hasPosition
        ? Math.round(clampNumber(numericX, boundsArea.x, maxX))
        : Math.round(boundsArea.x + Math.max(0, Math.floor((boundsArea.width - width) / 2)));
    const y = hasPosition
        ? Math.round(clampNumber(numericY, boundsArea.y, maxY))
        : Math.round(boundsArea.y + Math.max(0, Math.floor((boundsArea.height - height) / 2)));

    return {
        width: Number.isFinite(width) ? width : fallbackWidth,
        height: Number.isFinite(height) ? height : fallbackHeight,
        x,
        y
    };
}

function loadOverlayWindowBounds() {
    if (!app.isReady()) {
        return null;
    }

    if (overlayWindowBounds) {
        return overlayWindowBounds;
    }

    try {
        const filePath = getOverlayBoundsFilePath();
        if (!fs.existsSync(filePath)) {
            return null;
        }
        const rawText = fs.readFileSync(filePath, 'utf8');
        const parsed = JSON.parse(rawText);
        overlayWindowBounds = normalizeOverlayWindowBounds(parsed);
        return overlayWindowBounds;
    } catch (_) {
        return null;
    }
}

function saveOverlayWindowBounds(bounds = null) {
    if (!app.isReady()) {
        return;
    }

    const targetBounds = bounds || overlayWindowBounds;
    if (!targetBounds) {
        return;
    }

    try {
        const normalized = normalizeOverlayWindowBounds(targetBounds);
        overlayWindowBounds = normalized;
        fs.writeFileSync(getOverlayBoundsFilePath(), JSON.stringify(normalized), 'utf8');
    } catch (_) {
        // Ignore storage errors to keep overlay runtime stable.
    }
}

function scheduleOverlayBoundsSave(bounds = null) {
    if (overlayBoundsSaveTimer) {
        clearTimeout(overlayBoundsSaveTimer);
        overlayBoundsSaveTimer = null;
    }

    overlayBoundsSaveTimer = setTimeout(() => {
        saveOverlayWindowBounds(bounds);
        overlayBoundsSaveTimer = null;
    }, 180);
}

function updateOverlayBoundsFromWindow() {
    if (!overlayWindow || overlayWindow.isDestroyed()) {
        return;
    }

    const nextBounds = normalizeOverlayWindowBounds(overlayWindow.getBounds());
    overlayWindowBounds = nextBounds;
    scheduleOverlayBoundsSave(nextBounds);
}

function closeOverlayWindow() {
    if (!overlayWindow || overlayWindow.isDestroyed()) {
        overlayWindow = null;
        overlayWindowReady = false;
        overlayPendingState = null;
        return;
    }

    try {
        const currentBounds = overlayWindow.getBounds();
        saveOverlayWindowBounds(currentBounds);
    } catch (_) {
        // Ignore bounds read errors during close.
    }
    overlayWindow.close();
}

function normalizeOverlayControlState(nextState = {}) {
    const payload = nextState && typeof nextState === 'object' ? nextState : {};
    const hasOpacity = Object.prototype.hasOwnProperty.call(payload, 'opacity');
    const hasTextScale = Object.prototype.hasOwnProperty.call(payload, 'textScale');
    const hasLayoutPreset = Object.prototype.hasOwnProperty.call(payload, 'layoutPreset');
    const hasAlwaysOnTop = Object.prototype.hasOwnProperty.call(payload, 'alwaysOnTop');
    const hasLockPosition = Object.prototype.hasOwnProperty.call(payload, 'lockPosition');
    return {
        ...overlayControlState,
        opacity: hasOpacity ? clampNumber(payload.opacity, 0.35, 1) : overlayControlState.opacity,
        textScale: hasTextScale ? clampNumber(payload.textScale, 0.8, 1.4) : overlayControlState.textScale,
        layoutPreset: hasLayoutPreset ? normalizeOverlayLayoutPreset(payload.layoutPreset) : normalizeOverlayLayoutPreset(overlayControlState.layoutPreset),
        alwaysOnTop: hasAlwaysOnTop ? Boolean(payload.alwaysOnTop) : overlayControlState.alwaysOnTop,
        lockPosition: hasLockPosition ? Boolean(payload.lockPosition) : overlayControlState.lockPosition
    };
}

function syncOverlayControlsToOverlayWindow() {
    if (!overlayWindow || overlayWindow.isDestroyed() || !overlayWindowReady) {
        return;
    }
    overlayWindow.webContents.send('overlay-controls-state', overlayControlState);
}

function applyOverlayWindowControls(nextControlState = {}) {
    if (!overlayWindow || overlayWindow.isDestroyed()) {
        return;
    }

    overlayControlState = normalizeOverlayControlState(nextControlState);
    const { opacity, alwaysOnTop, lockPosition } = overlayControlState;

    overlayWindow.setOpacity(opacity);
    overlayWindow.setAlwaysOnTop(alwaysOnTop, alwaysOnTop ? 'screen-saver' : 'normal');
    if (typeof overlayWindow.setMovable === 'function') {
        overlayWindow.setMovable(!lockPosition);
    }

    if (alwaysOnTop) {
        overlayWindow.moveTop();
    }

    syncOverlayControlsToOverlayWindow();
}

function applyOverlayWindowState(state = {}) {
    if (!overlayWindow || overlayWindow.isDestroyed()) {
        return;
    }

    const mergedControlState = normalizeOverlayControlState(state);
    const payload = state.data && typeof state.data === 'object' ? state.data : null;

    applyOverlayWindowControls(mergedControlState);

    if (payload) {
        if (overlayWindowReady) {
            overlayWindow.webContents.send('overlay-data', payload);
        } else {
            overlayPendingState = state;
        }
    }
}

function ensureOverlayWindow() {
    if (overlayWindow && !overlayWindow.isDestroyed()) {
        return overlayWindow;
    }

    overlayWindowReady = false;
    overlayPendingState = null;
    const savedBounds = loadOverlayWindowBounds();
    const startupBounds = savedBounds || normalizeOverlayWindowBounds({
        width: OVERLAY_DEFAULT_BOUNDS.width,
        height: OVERLAY_DEFAULT_BOUNDS.height
    });

    overlayWindow = new BrowserWindow({
        width: startupBounds.width,
        height: startupBounds.height,
        x: startupBounds.x,
        y: startupBounds.y,
        minWidth: OVERLAY_MIN_WIDTH,
        minHeight: OVERLAY_MIN_HEIGHT,
        maxWidth: OVERLAY_MAX_WIDTH,
        frame: false,
        transparent: true,
        resizable: true,
        show: false,
        skipTaskbar: true,
        backgroundColor: '#00000000',
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        }
    });

    overlayWindow.loadFile(path.join(__dirname, 'overlay.html'));

    overlayWindow.webContents.on('did-finish-load', () => {
        overlayWindowReady = true;
        if (overlayPendingState) {
            applyOverlayWindowState(overlayPendingState);
            overlayPendingState = null;
        } else {
            applyOverlayWindowControls(overlayControlState);
        }
    });

    overlayWindow.on('move', () => {
        updateOverlayBoundsFromWindow();
    });

    overlayWindow.on('resize', () => {
        updateOverlayBoundsFromWindow();
    });

    overlayWindow.on('closed', () => {
        if (overlayBoundsSaveTimer) {
            clearTimeout(overlayBoundsSaveTimer);
            overlayBoundsSaveTimer = null;
        }
        saveOverlayWindowBounds(overlayWindowBounds);
        overlayWindow = null;
        overlayWindowReady = false;
        overlayPendingState = null;
        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('overlay-window-closed');
        }
    });

    return overlayWindow;
}

function postJson(url, payload) {
    return new Promise((resolve, reject) => {
        const serializedPayload = JSON.stringify(payload || {});
        const request = https.request(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
                Origin: 'https://f-tuning-pro.app',
                Referer: 'https://f-tuning-pro.app/',
                'User-Agent': 'F.Tuning Pro Desktop',
                'Content-Length': Buffer.byteLength(serializedPayload, 'utf8')
            }
        }, (response) => {
            let body = '';
            response.setEncoding('utf8');
            response.on('data', (chunk) => {
                body += chunk;
            });
            response.on('end', () => {
                const status = Number(response.statusCode) || 0;
                let parsedBody = null;
                try {
                    parsedBody = body ? JSON.parse(body) : null;
                } catch (_) {
                    parsedBody = null;
                }

                if (status >= 200 && status < 300) {
                    if (parsedBody && parsedBody.success === false) {
                        reject(new Error(parsedBody.message || 'Feedback service rejected the request.'));
                        return;
                    }
                    resolve({
                        status,
                        data: parsedBody,
                        raw: body
                    });
                    return;
                }

                const errorMessage = parsedBody?.message
                    || parsedBody?.error
                    || body
                    || 'Request failed';
                reject(new Error(`HTTP ${status}: ${errorMessage}`));
            });
        });

        request.on('error', (error) => {
            reject(error);
        });
        request.write(serializedPayload);
        request.end();
    });
}

async function submitFeedbackEmail(payload = {}) {
    const title = String(payload.title || '').trim();
    const name = String(payload.name || '').trim();
    const email = String(payload.email || '').trim().toLowerCase();
    const message = String(payload.message || '').trim();
    const buildTag = String(payload.build || 'Beta 1.0.2').trim() || 'Beta 1.0.2';
    const senderName = name || 'F.Tuning Pro User';
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!title || !message) {
        throw new Error('Feedback title and message are required.');
    }
    if (!emailRegex.test(email)) {
        throw new Error('A valid sender email is required.');
    }

    const requestPayload = {
        name: senderName,
        email,
        _replyto: email,
        _subject: `[F.Tuning Pro] ${title}`,
        message: `${message}\n\n---\nSender name: ${senderName}\nSender email: ${email}\nBuild: ${buildTag}\nTime: ${new Date().toLocaleString()}`,
        _autoresponse: FEEDBACK_AUTO_RESPONSE_MESSAGE,
        _captcha: 'false',
        _template: 'table'
    };

    const response = await postJson(`https://formsubmit.co/ajax/${encodeURIComponent(FEEDBACK_EMAIL_ADDRESS)}`, requestPayload);
    if (response?.data && response.data.success === false) {
        throw new Error(response.data.message || 'Feedback service rejected the request.');
    }
}

function createWindow() {
    const primaryDisplay = screen.getPrimaryDisplay();
    const workAreaSize = primaryDisplay?.workAreaSize || { width: 1200, height: 800 };
    const defaultWidth = 1280;
    const defaultHeight = 820;
    const safeWidth = Math.max(960, (Number(workAreaSize.width) || 1200) - 120);
    const safeHeight = Math.max(700, (Number(workAreaSize.height) || 800) - 120);
    const startupWidth = Math.min(defaultWidth, safeWidth);
    const startupHeight = Math.min(defaultHeight, safeHeight);

    mainWindow = new BrowserWindow({
        width: startupWidth,
        height: startupHeight,
        center: true,
        frame: false,
        show: false,
        backgroundColor: '#f4f4f7',
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        }
    });

    mainWindow.loadFile('index.html');
    mainWindow.once('ready-to-show', () => {
        if (!mainWindow || mainWindow.isDestroyed()) {
            return;
        }
        mainWindow.show();
        mainWindow.webContents.send('window-maximize-changed', mainWindow.isMaximized());
    });

    mainWindow.on('maximize', () => {
        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('window-maximize-changed', true);
        }
    });

    mainWindow.on('unmaximize', () => {
        if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('window-maximize-changed', false);
        }
    });

    mainWindow.on('closed', () => {
        closeOverlayWindow();
        mainWindow = null;
    });
}

app.whenReady().then(createWindow);

ipcMain.on('minimize-app', () => mainWindow.minimize());
ipcMain.on('toggle-maximize-app', () => {
    if (!mainWindow || mainWindow.isDestroyed()) {
        return;
    }
    if (mainWindow.isMaximized()) {
        mainWindow.unmaximize();
    } else {
        mainWindow.maximize();
    }
    mainWindow.webContents.send('window-maximize-changed', mainWindow.isMaximized());
});
ipcMain.on('close-app', () => app.quit());

ipcMain.on('open-external-url', (event, url) => {
    shell.openExternal(url);
});

ipcMain.on('overlay-window-state', (event, state) => {
    if (!mainWindow || mainWindow.isDestroyed()) {
        return;
    }

    const normalizedState = state && typeof state === 'object' ? state : {};
    const shouldShow = Boolean(normalizedState.visible);

    if (!shouldShow) {
        closeOverlayWindow();
        return;
    }

    const nextOverlayWindow = ensureOverlayWindow();
    applyOverlayWindowState(normalizedState);
    if (nextOverlayWindow && !nextOverlayWindow.isDestroyed()) {
        nextOverlayWindow.show();
    }
});

ipcMain.on('overlay-window-close-request', () => {
    closeOverlayWindow();
});

ipcMain.on('overlay-control-update', (event, payload) => {
    if (!overlayWindow || overlayWindow.isDestroyed()) {
        return;
    }

    if (event.sender !== overlayWindow.webContents) {
        return;
    }

    const normalizedPayload = payload && typeof payload === 'object' ? payload : {};
    const shouldToggleLock = Boolean(normalizedPayload.toggleLock);
    const hasExplicitLock = Object.prototype.hasOwnProperty.call(normalizedPayload, 'lockPosition');
    const nextLockState = shouldToggleLock
        ? !overlayControlState.lockPosition
        : (hasExplicitLock ? Boolean(normalizedPayload.lockPosition) : overlayControlState.lockPosition);

    const mergedControlState = normalizeOverlayControlState({
        ...overlayControlState,
        ...normalizedPayload,
        lockPosition: nextLockState
    });
    applyOverlayWindowControls(mergedControlState);

    if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('overlay-controls-updated', {
            ...overlayControlState,
            commit: Boolean(normalizedPayload.commit)
        });
    }
});

ipcMain.on('overlay-window-drag', (event, { deltaX, deltaY }) => {
    if (!overlayWindow || overlayWindow.isDestroyed()) {
        return;
    }

    if (event.sender !== overlayWindow.webContents) {
        return;
    }

    const currentBounds = overlayWindow.getBounds();
    overlayWindow.setBounds({
        x: Math.round(currentBounds.x + deltaX),
        y: Math.round(currentBounds.y + deltaY),
        width: currentBounds.width,
        height: currentBounds.height
    });
});

ipcMain.handle('submit-feedback', async (event, payload) => {
    try {
        await submitFeedbackEmail(payload);
        return { ok: true };
    } catch (error) {
        return {
            ok: false,
            error: error && error.message ? error.message : 'Unable to send feedback.'
        };
    }
});

ipcMain.handle('capture-main-window', async () => {
    if (!mainWindow || mainWindow.isDestroyed()) {
        return {
            ok: false,
            error: 'Main window is not ready.'
        };
    }

    try {
        const image = await mainWindow.webContents.capturePage();
        return {
            ok: true,
            dataUrl: image.toDataURL()
        };
    } catch (error) {
        return {
            ok: false,
            error: error && error.message ? error.message : 'Unable to capture window.'
        };
    }
});

