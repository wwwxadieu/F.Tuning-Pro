const { app, BrowserWindow, Menu } = require("electron");
const path = require("path");
const http = require("http");
const { spawn } = require("child_process");

const PORT = 47821;
const HOST = "127.0.0.1";

let serverProcess = null;
let mainWindow = null;

function getServerPath() {
  return app.isPackaged
    ? path.join(process.resourcesPath, "standalone", "server.js")
    : path.join(__dirname, "..", ".next", "standalone", "server.js");
}

function waitForServer(attempt = 0) {
  return new Promise((resolve, reject) => {
    const req = http.get({ host: HOST, port: PORT, path: "/", timeout: 2000 }, (res) => {
      res.resume();
      resolve();
    });
    req.on("error", () => {
      if (attempt > 80) return reject(new Error("TechWave server did not start in time"));
      setTimeout(() => waitForServer(attempt + 1).then(resolve, reject), 500);
    });
    req.on("timeout", () => req.destroy());
  });
}

function startServer() {
  const serverPath = getServerPath();
  serverProcess = spawn(process.execPath, [serverPath], {
    cwd: path.dirname(serverPath),
    env: {
      ...process.env,
      ELECTRON_RUN_AS_NODE: "1",
      PORT: String(PORT),
      HOSTNAME: HOST,
      NODE_ENV: "production",
    },
    stdio: "ignore",
  });
  return waitForServer();
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1024,
    minHeight: 700,
    backgroundColor: "#0a0a0c",
    title: "TechWave",
    autoHideMenuBar: true,
    titleBarStyle: process.platform === "darwin" ? "hiddenInset" : "default",
    icon: path.join(__dirname, "icon.png"),
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.loadURL(`http://${HOST}:${PORT}/`);
  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.whenReady().then(async () => {
  Menu.setApplicationMenu(null);
  try {
    await startServer();
  } catch (err) {
    console.error("[electron] failed to start TechWave server:", err);
  }
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("before-quit", () => {
  if (serverProcess) {
    serverProcess.kill();
    serverProcess = null;
  }
});
