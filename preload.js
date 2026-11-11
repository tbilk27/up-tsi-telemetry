const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getPorts: () => ipcRenderer.invoke('get-ports'),
  connect: (options) => ipcRenderer.send('connect', options),
  disconnect: () => ipcRenderer.send('disconnect'),
  scanDtc: () => ipcRenderer.send('scan-dtc'),
  clearDtc: () => ipcRenderer.send('clear-dtc'),
  toggleLogging: (enable) => ipcRenderer.send('toggle-logging', enable),
  sendSimInput: (input) => ipcRenderer.send('sim-input', input),
  
  onTelemetry: (callback) => ipcRenderer.on('telemetry', (event, data) => callback(data)),
  onStatus: (callback) => ipcRenderer.on('status', (event, data) => callback(data)),
  onDtcResult: (callback) => ipcRenderer.on('dtc-result', (event, data) => callback(data)),
  onLogStatus: (callback) => ipcRenderer.on('log-status', (event, data) => callback(data)),
  onPortsList: (callback) => ipcRenderer.on('ports-list', (event, data) => callback(data)),
  onInitMock: (callback) => ipcRenderer.on('init-mock', (event, data) => callback(data))
});
