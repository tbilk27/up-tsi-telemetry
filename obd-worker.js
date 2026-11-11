const { SerialPort } = require('serialport');
const fs = require('fs');
const path = require('path');

let port = null;
let isConnected = false;
let isSimulating = false;
let simInterval = null;
let pollLoopActive = false;
let loggingActive = false;
let logStream = null;
let logFilePath = null;

let manualThrottle = null; // for interactive keyboard control in mock mode

const telemetry = {
  connected: false,
  timestamp: Date.now(),
  rpm: 0,
  speed: 0,
  map: 101, // kPa
  boostBar: 0.0,
  boostPsi: 0.0,
  coolant: 0,
  iat: 0,
  tps: 0,
  load: 0,
  timing: 0,
  stft: 0,
  ltft: 0,
  voltage: 0.0,
  vin: '9BWAH4124HT516995',
  protocol: 'CAN 11/500',
  gear: 'N',
  dtcs: []
};

// Send message to parent process
function notify(type, payload) {
  if (process.send) {
    process.send({ type, payload });
  }
}

// Format DTC code from 2 hex bytes
function parseDtc(byte1Hex, byte2Hex) {
  const b1 = parseInt(byte1Hex, 16);
  const b2 = parseInt(byte2Hex, 16);
  if (b1 === 0 && b2 === 0) return null;

  const prefixMap = ['P', 'C', 'B', 'U'];
  const prefix = prefixMap[(b1 >> 6) & 0x03];
  const digit1 = (b1 >> 4) & 0x03;
  const digit2 = b1 & 0x0F;
  const digit34 = byte2Hex.toUpperCase().padStart(2, '0');
  return `${prefix}${digit1}${digit2.toString(16).toUpperCase()}${digit34}`;
}

// Parse AT and OBD responses
function cleanResponse(raw) {
  return raw.replace(/[\r\n\t> ]/g, '').toUpperCase();
}

function sendSerialCommand(cmd, timeoutMs = 800) {
  return new Promise((resolve, reject) => {
    if (!port || !port.isOpen) {
      return reject(new Error('Porta serial fechada'));
    }

    let buffer = '';
    const timer = setTimeout(() => {
      cleanup();
      resolve(buffer);
    }, timeoutMs);

    function onData(chunk) {
      buffer += chunk.toString('ascii');
      if (buffer.includes('>')) {
        cleanup();
        resolve(buffer);
      }
    }

    function onError(err) {
      cleanup();
      reject(err);
    }

    function cleanup() {
      clearTimeout(timer);
      if (port) {
        port.removeListener('data', onData);
        port.removeListener('error', onError);
      }
    }

    port.on('data', onData);
    port.on('error', onError);

    port.write(`${cmd}\r`, (err) => {
      if (err) {
        cleanup();
        reject(err);
      }
    });
  });
}

// Serial connection initializer (cross-platform Windows & macOS)
async function connectSerial(portPath, baudRate = 38400) {
  disconnect();

  if (!portPath) {
    if (process.platform === 'darwin') {
      try {
        const ports = await SerialPort.list();
        const macPort = ports.find(p => p.path.toLowerCase().includes('obd') || p.path.toLowerCase().includes('serial') || p.path.includes('cu.'));
        portPath = macPort ? macPort.path : '/dev/cu.Bluetooth-Incoming-Port';
      } catch (e) {
        portPath = '/dev/cu.Bluetooth-Incoming-Port';
      }
    } else {
      portPath = 'COM8';
    }
  }

  notify('status', { status: 'connecting', message: `Conectando a ${portPath}...` });

  return new Promise((resolve, reject) => {
    port = new SerialPort({ path: portPath, baudRate, autoOpen: false });

    port.open(async (err) => {
      if (err) {
        notify('status', { status: 'error', message: `Falha ao abrir ${portPath}: ${err.message}` });
        return reject(err);
      }

      try {
        notify('status', { status: 'initializing', message: 'Inicializando ELM327...' });

        // Reset and config
        await sendSerialCommand('ATZ', 1200);
        await sendSerialCommand('ATE0', 400); // Echo Off
        await sendSerialCommand('ATL0', 300); // Linefeeds Off
        await sendSerialCommand('ATH0', 300); // Headers Off
        await sendSerialCommand('ATSP0', 400); // Auto Protocol

        // Read Voltage
        const voltRaw = await sendSerialCommand('ATRV', 400);
        const voltMatch = voltRaw.match(/(\d+\.?\d*)V/i);
        if (voltMatch) telemetry.voltage = parseFloat(voltMatch[1]);

        // Protocol
        const protoRaw = await sendSerialCommand('ATDP', 400);
        telemetry.protocol = protoRaw.replace(/[\r\n>]/g, '').trim() || 'ISO 15765-4 (CAN 11/500)';

        // VIN
        const vinRaw = await sendSerialCommand('0902', 1200);
        decodeVin(vinRaw);

        isConnected = true;
        telemetry.connected = true;
        notify('status', { status: 'connected', port: portPath, message: 'Conectado ao Up! TSI' });
        notify('telemetry', telemetry);

        startPollingLoop();
        resolve(true);
      } catch (initErr) {
        notify('status', { status: 'error', message: `Erro ao inicializar ECU: ${initErr.message}` });
        disconnect();
        reject(initErr);
      }
    });
  });
}

function decodeVin(raw) {
  try {
    const clean = raw.replace(/[\r\n> ]/g, '');
    const hexes = clean.match(/490201([0-9A-F]+)/i);
    if (hexes && hexes[1]) {
      let str = '';
      for (let i = 0; i < hexes[1].length; i += 2) {
        const code = parseInt(hexes[1].substr(i, 2), 16);
        if (code >= 32 && code <= 126) str += String.fromCharCode(code);
      }
      if (str.length >= 10) telemetry.vin = str;
    }
  } catch (e) {}
}

// Continuous OBD-II Polling Loop
async function startPollingLoop() {
  pollLoopActive = true;
  let cycle = 0;

  while (pollLoopActive && isConnected && port && port.isOpen) {
    try {
      cycle++;

      // 1. RPM (010C) - High Priority
      const rpmResp = cleanResponse(await sendSerialCommand('010C', 350));
      const rpmMatch = rpmResp.match(/410C([0-9A-F]{4})/);
      if (rpmMatch) {
        const rawVal = parseInt(rpmMatch[1], 16);
        telemetry.rpm = Math.round(rawVal / 4);
      }

      // 2. MAP (010B) -> Turbo Boost
      const mapResp = cleanResponse(await sendSerialCommand('010B', 300));
      const mapMatch = mapResp.match(/410B([0-9A-F]{2})/);
      if (mapMatch) {
        telemetry.map = parseInt(mapMatch[1], 16);
        const relativeBar = (telemetry.map - 101) / 100;
        telemetry.boostBar = parseFloat(relativeBar.toFixed(2));
        telemetry.boostPsi = parseFloat((telemetry.boostBar * 14.5038).toFixed(1));
      }

      // 3. Speed (010D) & TPS (0111)
      const speedResp = cleanResponse(await sendSerialCommand('010D', 300));
      const speedMatch = speedResp.match(/410D([0-9A-F]{2})/);
      if (speedMatch) {
        telemetry.speed = parseInt(speedMatch[1], 16);
      }

      const tpsResp = cleanResponse(await sendSerialCommand('0111', 300));
      const tpsMatch = tpsResp.match(/4111([0-9A-F]{2})/);
      if (tpsMatch) {
        telemetry.tps = Math.round((parseInt(tpsMatch[1], 16) * 100) / 255);
      }

      // Medium Priority (Every 2 cycles)
      if (cycle % 2 === 0) {
        const loadResp = cleanResponse(await sendSerialCommand('0104', 300));
        const loadMatch = loadResp.match(/4104([0-9A-F]{2})/);
        if (loadMatch) {
          telemetry.load = Math.round((parseInt(loadMatch[1], 16) * 100) / 255);
        }

        const timingResp = cleanResponse(await sendSerialCommand('010E', 300));
        const timingMatch = timingResp.match(/410E([0-9A-F]{2})/);
        if (timingMatch) {
          telemetry.timing = parseFloat(((parseInt(timingMatch[1], 16) / 2) - 64).toFixed(1));
        }
      }

      // Low Priority (Every 5 cycles)
      if (cycle % 5 === 0) {
        const coolResp = cleanResponse(await sendSerialCommand('0105', 300));
        const coolMatch = coolResp.match(/4105([0-9A-F]{2})/);
        if (coolMatch) {
          telemetry.coolant = parseInt(coolMatch[1], 16) - 40;
        }

        const iatResp = cleanResponse(await sendSerialCommand('010F', 300));
        const iatMatch = iatResp.match(/410F([0-9A-F]{2})/);
        if (iatMatch) {
          telemetry.iat = parseInt(iatMatch[1], 16) - 40;
        }

        const voltRaw = await sendSerialCommand('ATRV', 300);
        const voltMatch = voltRaw.match(/(\d+\.?\d*)V/i);
        if (voltMatch) telemetry.voltage = parseFloat(voltMatch[1]);

        const stftResp = cleanResponse(await sendSerialCommand('0106', 300));
        const stftMatch = stftResp.match(/4106([0-9A-F]{2})/);
        if (stftMatch) {
          telemetry.stft = parseFloat((((parseInt(stftMatch[1], 16) - 128) * 100) / 128).toFixed(1));
        }

        const ltftResp = cleanResponse(await sendSerialCommand('0107', 300));
        const ltftMatch = ltftResp.match(/4107([0-9A-F]{2})/);
        if (ltftMatch) {
          telemetry.ltft = parseFloat((((parseInt(ltftMatch[1], 16) - 128) * 100) / 128).toFixed(1));
        }
      }

      telemetry.gear = estimateGear(telemetry.speed, telemetry.rpm);
      telemetry.timestamp = Date.now();

      if (loggingActive && logStream) {
        writeLogEntry(telemetry);
      }

      notify('telemetry', telemetry);
      await new Promise(r => setTimeout(r, 40));
    } catch (err) {
      await new Promise(r => setTimeout(r, 200));
    }
  }
}

// Gear estimation for Up! TSI (MQ200 5-speed gearbox)
function estimateGear(speed, rpm) {
  if (rpm < 500 || speed < 2) return 'N';
  const ratio = rpm / speed;
  if (ratio > 110) return '1';
  if (ratio > 65) return '2';
  if (ratio > 44) return '3';
  if (ratio > 32) return '4';
  if (ratio > 22) return '5';
  return 'N';
}

// Diagnostic DTC Scanning
async function scanDTCs() {
  if (isSimulating) {
    notify('dtc-result', { dtcs: [], count: 0, raw: 'Modo Mock: Nenhuma falha ativa.' });
    return;
  }

  if (!isConnected || !port) {
    notify('dtc-result', { error: 'Adaptador desconectado.' });
    return;
  }

  try {
    const raw = await sendSerialCommand('03', 1500);
    const clean = cleanResponse(raw);
    const dtcs = [];

    if (clean.includes('4300') || clean === '43') {
      notify('dtc-result', { dtcs: [], count: 0, raw: 'Nenhuma falha ativa registrada (43 00).' });
      return;
    }

    const match = clean.match(/43([0-9A-F]+)/);
    if (match && match[1]) {
      const hexData = match[1];
      for (let i = 0; i < hexData.length; i += 4) {
        if (i + 4 <= hexData.length) {
          const b1 = hexData.substr(i, 2);
          const b2 = hexData.substr(i + 2, 2);
          const code = parseDtc(b1, b2);
          if (code && !dtcs.includes(code)) dtcs.push(code);
        }
      }
    }

    telemetry.dtcs = dtcs;
    notify('dtc-result', { dtcs, count: dtcs.length, raw });
  } catch (err) {
    notify('dtc-result', { error: `Erro ao escanear DTCs: ${err.message}` });
  }
}

// Clear DTCs (Mode 04)
async function clearDTCs() {
  if (isSimulating) {
    telemetry.dtcs = [];
    notify('dtc-result', { cleared: true, message: 'Falhas apagadas em modo Mock.' });
    return;
  }

  if (!isConnected || !port) {
    notify('dtc-result', { error: 'Adaptador desconectado.' });
    return;
  }

  try {
    await sendSerialCommand('04', 1500);
    telemetry.dtcs = [];
    notify('dtc-result', { cleared: true, message: 'Comando de limpeza (Modo 04) enviado com sucesso!' });
  } catch (err) {
    notify('dtc-result', { error: `Erro ao limpar DTCs: ${err.message}` });
  }
}

// Datalogging management
function toggleLogging(enable) {
  if (enable) {
    try {
      const logsDir = path.join(__dirname, 'logs');
      if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, { recursive: true });

      const dateStr = new Date().toISOString().replace(/[:.]/g, '-');
      logFilePath = path.join(logsDir, `datalog_up_tsi_${dateStr}.csv`);
      logStream = fs.createWriteStream(logFilePath, { flags: 'a' });
      logStream.write('Timestamp,RPM,Speed_kmh,MAP_kPa,Boost_bar,Boost_psi,Coolant_C,IAT_C,TPS_pct,Load_pct,Timing_deg,STFT_pct,LTFT_pct,Battery_V,Gear\n');
      loggingActive = true;
      notify('log-status', { active: true, path: logFilePath });
    } catch (err) {
      notify('log-status', { active: false, error: err.message });
    }
  } else {
    loggingActive = false;
    if (logStream) {
      logStream.end();
      logStream = null;
    }
    notify('log-status', { active: false, path: logFilePath });
  }
}

function writeLogEntry(data) {
  if (!logStream) return;
  const line = `${new Date(data.timestamp).toISOString()},${data.rpm},${data.speed},${data.map},${data.boostBar},${data.boostPsi},${data.coolant},${data.iat},${data.tps},${data.load},${data.timing},${data.stft},${data.ltft},${data.voltage},${data.gear}\n`;
  logStream.write(line);
}

// Simulation / Mock Mode (Realistic VW Up! TSI test drive + interactive throttle)
function startSimulation() {
  disconnect();
  isSimulating = true;
  isConnected = true;
  telemetry.connected = true;
  telemetry.vin = '9BWAH4124HT516995';
  telemetry.protocol = 'CAN 11/500 (Modo Mock)';
  telemetry.voltage = 14.2;
  telemetry.coolant = 90;
  telemetry.iat = 35;

  notify('status', { status: 'connected', port: 'MOCK / DADOS FICTÍCIOS', message: 'Modo Mock Ativo (Dados Fictícios Up! TSI)' });

  let simTime = 0;
  let phase = 'idle';
  let phaseTimer = 0;

  simInterval = setInterval(() => {
    simTime += 0.05;
    phaseTimer += 0.05;

    if (manualThrottle !== null && manualThrottle > 0) {
      telemetry.tps = Math.round(manualThrottle * 100);
      telemetry.load = Math.round(20 + manualThrottle * 78);
      telemetry.rpm = Math.min(6500, telemetry.rpm + Math.round(manualThrottle * 180));
      telemetry.speed = Math.min(195, Math.round(telemetry.speed + manualThrottle * 1.5));
      const targetBoost = -0.6 + manualThrottle * 1.85;
      telemetry.boostBar = parseFloat(targetBoost.toFixed(2));
      telemetry.map = Math.round(101 + telemetry.boostBar * 100);
      telemetry.timing = parseFloat((8.0 + (telemetry.rpm / 6500) * 12).toFixed(1));
      telemetry.gear = estimateGear(telemetry.speed, telemetry.rpm);
    } else if (manualThrottle === 0) {
      telemetry.tps = 0;
      telemetry.boostBar = -0.68;
      telemetry.map = 32;
      telemetry.rpm = Math.max(850, telemetry.rpm - 150);
      telemetry.speed = Math.max(0, telemetry.speed - 1);
      telemetry.gear = estimateGear(telemetry.speed, telemetry.rpm);
    } else {
      if (phase === 'idle') {
        telemetry.rpm = Math.round(850 + Math.sin(simTime * 4) * 25);
        telemetry.speed = 0;
        telemetry.tps = 12;
        telemetry.map = 38;
        telemetry.boostBar = -0.63;
        telemetry.load = 18;
        telemetry.timing = 5.0;
        telemetry.gear = 'N';
        if (phaseTimer > 2.5) { phase = 'accel1'; phaseTimer = 0; }
      } else if (phase === 'accel1') {
        telemetry.tps = 100;
        telemetry.gear = '1';
        telemetry.rpm = Math.min(6200, Math.round(1400 + phaseTimer * 1700));
        telemetry.speed = Math.round((telemetry.rpm / 6200) * 48);
        telemetry.map = Math.round(100 + Math.min(125, phaseTimer * 65));
        telemetry.boostBar = parseFloat(((telemetry.map - 101) / 100).toFixed(2));
        telemetry.load = 96;
        telemetry.timing = 9.5;
        if (telemetry.rpm >= 6000) { phase = 'shift1'; phaseTimer = 0; }
      } else if (phase === 'shift1') {
        telemetry.tps = 0;
        telemetry.boostBar = -0.45;
        telemetry.rpm = 3800;
        telemetry.gear = '2';
        if (phaseTimer > 0.35) { phase = 'accel2'; phaseTimer = 0; }
      } else if (phase === 'accel2') {
        telemetry.tps = 100;
        telemetry.gear = '2';
        telemetry.rpm = Math.min(6100, Math.round(3800 + phaseTimer * 1150));
        telemetry.speed = Math.round(48 + (phaseTimer * 24));
        telemetry.map = Math.round(222 + Math.sin(simTime * 2) * 6);
        telemetry.boostBar = parseFloat(((telemetry.map - 101) / 100).toFixed(2));
        telemetry.load = 98;
        telemetry.timing = 11.0;
        if (telemetry.rpm >= 6000) { phase = 'cruise'; phaseTimer = 0; }
      } else if (phase === 'cruise') {
        telemetry.tps = 24;
        telemetry.gear = '4';
        telemetry.speed = 80;
        telemetry.rpm = 2100;
        telemetry.map = 62;
        telemetry.boostBar = -0.39;
        telemetry.load = 32;
        telemetry.timing = 24.5;
        if (phaseTimer > 4.5) { phase = 'idle'; phaseTimer = 0; }
      }
    }

    telemetry.boostPsi = parseFloat((telemetry.boostBar * 14.5038).toFixed(1));
    telemetry.stft = parseFloat((Math.sin(simTime * 1.5) * 2.5).toFixed(1));
    telemetry.ltft = 1.2;
    telemetry.voltage = parseFloat((14.1 + Math.sin(simTime) * 0.15).toFixed(1));
    telemetry.timestamp = Date.now();

    if (loggingActive && logStream) writeLogEntry(telemetry);
    notify('telemetry', telemetry);
  }, 50);
}

// Disconnect helper
function disconnect() {
  pollLoopActive = false;
  isConnected = false;
  isSimulating = false;
  manualThrottle = null;

  if (simInterval) {
    clearInterval(simInterval);
    simInterval = null;
  }

  if (port) {
    try {
      if (port.isOpen) port.close();
    } catch (e) {}
    port = null;
  }

  telemetry.connected = false;
  notify('status', { status: 'disconnected', message: 'Desconectado' });
  notify('telemetry', telemetry);
}

// Process IPC listener from Electron Main
process.on('message', async (msg) => {
  if (!msg || !msg.command) return;

  switch (msg.command) {
    case 'connect':
      if (msg.simulation) {
        startSimulation();
      } else {
        connectSerial(msg.port, msg.baudRate || 38400).catch(() => {});
      }
      break;

    case 'disconnect':
      disconnect();
      break;

    case 'sim-input':
      if (msg.input && msg.input.throttle !== undefined) {
        manualThrottle = msg.input.throttle;
      }
      break;

    case 'scan-dtc':
      scanDTCs();
      break;

    case 'clear-dtc':
      clearDTCs();
      break;

    case 'toggle-logging':
      toggleLogging(!!msg.enable);
      break;

    case 'get-ports':
      try {
        const ports = await SerialPort.list();
        notify('ports-list', ports);
      } catch (err) {
        notify('ports-list', []);
      }
      break;
  }
});

// Clean shutdown
process.on('SIGINT', () => {
  disconnect();
  process.exit(0);
});
