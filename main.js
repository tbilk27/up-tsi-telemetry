const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { fork } = require('child_process');

let mainWindow = null;
let workerProcess = null;
const isMockMode = process.argv.some(arg => arg.toLowerCase().includes('mock') || arg === '-m');

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 860,
    minWidth: 1024,
    minHeight: 700,
    backgroundColor: '#0a0d14',
    title: `Up! TSI Telemetry & Diagnostic Dashboard ${isMockMode ? '[MODO MOCK ATIVO]' : ''}`,
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
    trafficLightPosition: { x: 16, y: 16 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'));

  mainWindow.webContents.on('did-finish-load', () => {
    if (isMockMode) {
      mainWindow.webContents.send('init-mock', true);
      if (workerProcess && workerProcess.connected) {
        workerProcess.send({ command: 'connect', simulation: true });
      }
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function startWorker() {
  const workerPath = path.join(__dirname, 'obd-worker.js');
  workerProcess = fork(workerPath, [], { stdio: ['pipe', 'pipe', 'pipe', 'ipc'] });

  workerProcess.on('message', (msg) => {
    if (!mainWindow || mainWindow.isDestroyed()) return;

    if (msg.type === 'telemetry') {
      mainWindow.webContents.send('telemetry', msg.payload);
    } else if (msg.type === 'status') {
      mainWindow.webContents.send('status', msg.payload);
    } else if (msg.type === 'dtc-result') {
      mainWindow.webContents.send('dtc-result', msg.payload);
    } else if (msg.type === 'log-status') {
      mainWindow.webContents.send('log-status', msg.payload);
    } else if (msg.type === 'ports-list') {
      mainWindow.webContents.send('ports-list', msg.payload);
    }
  });

  workerProcess.on('error', (err) => {
    console.error('OBD Worker Error:', err);
  });

  workerProcess.on('exit', (code) => {
    console.log(`OBD Worker exited with code ${code}`);
  });
}

// IPC communication from renderer
ipcMain.handle('get-ports', async () => {
  if (workerProcess && workerProcess.connected) {
    workerProcess.send({ command: 'get-ports' });
  }
  return [];
});

ipcMain.on('connect', (event, options) => {
  if (workerProcess && workerProcess.connected) {
    workerProcess.send({ command: 'connect', ...options });
  }
});

ipcMain.on('disconnect', () => {
  if (workerProcess && workerProcess.connected) {
    workerProcess.send({ command: 'disconnect' });
  }
});

ipcMain.on('scan-dtc', () => {
  if (workerProcess && workerProcess.connected) {
    workerProcess.send({ command: 'scan-dtc' });
  }
});

ipcMain.on('clear-dtc', () => {
  if (workerProcess && workerProcess.connected) {
    workerProcess.send({ command: 'clear-dtc' });
  }
});

ipcMain.on('toggle-logging', (event, enable) => {
  if (workerProcess && workerProcess.connected) {
    workerProcess.send({ command: 'toggle-logging', enable });
  }
});

ipcMain.on('sim-input', (event, input) => {
  if (workerProcess && workerProcess.connected) {
    workerProcess.send({ command: 'sim-input', input });
  }
});

app.whenReady().then(() => {
  startWorker();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (workerProcess) {
    workerProcess.kill();
  }
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
