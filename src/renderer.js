// VW Up! TSI Dashboard Renderer

// DOM Elements
const statusDot = document.getElementById('statusDot');
const statusText = document.getElementById('statusText');
const portSelect = document.getElementById('portSelect');
const btnConnect = document.getElementById('btnConnect');
const btnSimulation = document.getElementById('btnSimulation');
const btnDatalog = document.getElementById('btnDatalog');
const btnScanDtc = document.getElementById('btnScanDtc');
const btnClearDtc = document.getElementById('btnClearDtc');
const btnCloseDtc = document.getElementById('btnCloseDtc');
const dtcModal = document.getElementById('dtcModal');
const dtcBody = document.getElementById('dtcBody');

// Gauge values
const valRpm = document.getElementById('valRpm');
const valSpeed = document.getElementById('valSpeed');
const valGear = document.getElementById('valGear');
const valBoostBar = document.getElementById('valBoostBar');
const valBoostPsi = document.getElementById('valBoostPsi');
const valPeakBoost = document.getElementById('valPeakBoost');

// Sensor cards
const valCoolant = document.getElementById('valCoolant');
const barCoolant = document.getElementById('barCoolant');
const valIat = document.getElementById('valIat');
const barIat = document.getElementById('barIat');
const valMap = document.getElementById('valMap');
const barMap = document.getElementById('barMap');
const valTps = document.getElementById('valTps');
const barTps = document.getElementById('barTps');
const valLoad = document.getElementById('valLoad');
const barLoad = document.getElementById('barLoad');
const valTiming = document.getElementById('valTiming');
const barTiming = document.getElementById('barTiming');
const valFuelTrim = document.getElementById('valFuelTrim');
const barTrim = document.getElementById('barTrim');
const valVoltage = document.getElementById('valVoltage');
const barVoltage = document.getElementById('barVoltage');
const lblVoltStatus = document.getElementById('lblVoltStatus');

// Meta
const valVin = document.getElementById('valVin');
const valProto = document.getElementById('valProto');
const valLogStatus = document.getElementById('valLogStatus');
const flagIntercooler = document.getElementById('flagIntercooler');
const flagLambda = document.getElementById('flagLambda');

// Shift light leds
const shiftLeds = document.querySelectorAll('.shift-light-bar .led');
const shiftLightBar = document.getElementById('shiftLightBar');

// Canvas Contexts
const tachCanvas = document.getElementById('tachCanvas');
const tachCtx = tachCanvas.getContext('2d');
const boostCanvas = document.getElementById('boostCanvas');
const boostCtx = boostCanvas.getContext('2d');

// State
let isConnected = false;
let isSimulation = false;
let isLogging = false;
let peakBoost = 0.0;
let currentRpm = 0;
let targetRpm = 0;
let currentBoost = 0.0;
let targetBoost = 0.0;
let throttleKeyActive = false;
let throttleResumeTimer = null;

// Common VW TSI DTC Descriptions
const TSI_DTC_DB = {
  'P0299': 'Turbocharger/Supercharger "A" Underboost Condition (Pressão de turbo abaixo do esperado)',
  'P0234': 'Turbocharger/Supercharger "A" Overboost Condition (Pressão de turbo excessiva)',
  'P0300': 'Random/Multiple Cylinder Misfire Detected (Falha de combustão múltipla)',
  'P0301': 'Cylinder 1 Misfire Detected (Falha de combustão no cilindro 1)',
  'P0302': 'Cylinder 2 Misfire Detected (Falha de combustão no cilindro 2)',
  'P0303': 'Cylinder 3 Misfire Detected (Falha de combustão no cilindro 3 - EA211 3 Cil.)',
  'P0106': 'Manifold Absolute Pressure/Barometric Sensor Range/Performance (Sensor MAP)',
  'P0171': 'System Too Lean - Bank 1 (Mistura excessivamente pobre)',
  'P0172': 'System Too Rich - Bank 1 (Mistura excessivamente rica)',
  'P0420': 'Catalyst System Efficiency Below Threshold (Eficiência de catalisador/Downpipe)',
  'P0130': 'O2 Sensor Circuit Malfunction - Bank 1 Sensor 1 (Sonda Lambda Pré)',
  'P0136': 'O2 Sensor Circuit Malfunction - Bank 1 Sensor 2 (Sonda Lambda Pós)',
  'P0016': 'Crankshaft/Camshaft Position Correlation (Sincronismo de comando de válvulas)'
};

// Handle CLI `--mock` auto-start
if (window.api && window.api.onInitMock) {
  window.api.onInitMock(() => {
    isSimulation = true;
    btnSimulation.textContent = 'Parar Mock';
    btnSimulation.classList.remove('btn-secondary');
    btnSimulation.classList.add('btn-primary');
    statusText.textContent = 'Modo Mock Ativo (Dados Fictícios)';
    statusDot.className = 'status-dot connected';

    const opt = document.createElement('option');
    opt.value = 'MOCK';
    opt.textContent = 'MOCK (Dados Fictícios)';
    opt.selected = true;
    portSelect.prepend(opt);
  });
}

// Initialize Serial Ports list (Cross-platform Windows & macOS)
async function refreshPorts() {
  if (window.api && window.api.getPorts) {
    window.api.getPorts();
  }
}

if (window.api && window.api.onPortsList) {
  window.api.onPortsList((ports) => {
    portSelect.innerHTML = '';
    let hasSelected = false;

    if (isSimulation) {
      const mockOpt = document.createElement('option');
      mockOpt.value = 'MOCK';
      mockOpt.textContent = 'MOCK (Dados Fictícios)';
      mockOpt.selected = true;
      portSelect.appendChild(mockOpt);
      hasSelected = true;
    }

    ports.forEach(p => {
      const opt = document.createElement('option');
      opt.value = p.path;
      const label = p.friendlyName || (p.path.startsWith('/dev/') ? 'macOS Serial' : 'Serial');
      opt.textContent = `${p.path} (${label})`;

      if (!hasSelected) {
        if (p.path === 'COM8' || p.path.toLowerCase().includes('obd') || p.path.includes('cu.')) {
          opt.selected = true;
          hasSelected = true;
        }
      }
      portSelect.appendChild(opt);
    });

    if (!hasSelected && !isSimulation) {
      const isMac = navigator.userAgent.includes('Mac');
      const defaultPort = isMac ? '/dev/cu.Bluetooth-Incoming-Port' : 'COM8';
      const opt = document.createElement('option');
      opt.value = defaultPort;
      opt.textContent = `${defaultPort} (${isMac ? 'macOS Bluetooth' : 'OBDII Bluetooth'})`;
      opt.selected = true;
      portSelect.appendChild(opt);
    }
  });
}

// Button Events
btnConnect.addEventListener('click', () => {
  if (isConnected && !isSimulation) {
    window.api.disconnect();
  } else {
    isSimulation = false;
    const selectedPort = portSelect.value || (navigator.userAgent.includes('Mac') ? '/dev/cu.Bluetooth-Incoming-Port' : 'COM8');
    window.api.connect({ port: selectedPort, baudRate: 38400, simulation: false });
  }
});

btnSimulation.addEventListener('click', () => {
  if (isSimulation) {
    window.api.disconnect();
    isSimulation = false;
    btnSimulation.textContent = 'Simulação Demo';
    btnSimulation.classList.remove('btn-primary');
    btnSimulation.classList.add('btn-secondary');
  } else {
    isSimulation = true;
    window.api.connect({ simulation: true });
    btnSimulation.textContent = 'Parar Mock';
    btnSimulation.classList.remove('btn-secondary');
    btnSimulation.classList.add('btn-primary');
  }
});

btnDatalog.addEventListener('click', () => {
  isLogging = !isLogging;
  window.api.toggleLogging(isLogging);
  if (isLogging) {
    btnDatalog.classList.add('active');
  } else {
    btnDatalog.classList.remove('active');
  }
});

btnScanDtc.addEventListener('click', () => {
  dtcModal.classList.remove('hidden');
  dtcBody.innerHTML = '<div style="color: #ffd600;">Escanenado códigos de falha na ECU do motor...</div>';
  window.api.scanDtc();
});

btnClearDtc.addEventListener('click', () => {
  if (confirm('Deseja apagar os códigos de falha e reiniciar a luz da injeção (MIL)?')) {
    dtcModal.classList.remove('hidden');
    dtcBody.innerHTML = '<div style="color: #ffd600;">Enviando comando de limpeza (Mode 04)...</div>';
    window.api.clearDtc();
  }
});

btnCloseDtc.addEventListener('click', () => {
  dtcModal.classList.add('hidden');
});

// Interactive Keyboard Throttle for Mock Mode
window.addEventListener('keydown', (e) => {
  if (!isSimulation) return;
  if ((e.code === 'Space' || e.code === 'ArrowUp') && !throttleKeyActive) {
    throttleKeyActive = true;
    clearTimeout(throttleResumeTimer);
    if (window.api && window.api.sendSimInput) {
      window.api.sendSimInput({ throttle: 1.0 });
    }
  }
});

window.addEventListener('keyup', (e) => {
  if (!isSimulation) return;
  if (e.code === 'Space' || e.code === 'ArrowUp') {
    throttleKeyActive = false;
    if (window.api && window.api.sendSimInput) {
      window.api.sendSimInput({ throttle: 0.0 });
    }
    clearTimeout(throttleResumeTimer);
    throttleResumeTimer = setTimeout(() => {
      if (window.api && window.api.sendSimInput) {
        window.api.sendSimInput({ throttle: null });
      }
    }, 2000);
  }
});

// Telemetry Listener
if (window.api && window.api.onTelemetry) {
  window.api.onTelemetry((data) => {
    updateTelemetry(data);
  });
}

// Status Listener
if (window.api && window.api.onStatus) {
  window.api.onStatus((status) => {
    statusText.textContent = status.message || status.status;
    statusDot.className = `status-dot ${status.status}`;

    if (status.status === 'connected') {
      isConnected = true;
      if (!isSimulation) {
        btnConnect.textContent = 'Desconectar';
        btnConnect.classList.remove('btn-primary');
        btnConnect.classList.add('btn-secondary');
      }
    } else if (status.status === 'disconnected') {
      isConnected = false;
      isSimulation = false;
      btnConnect.textContent = 'Conectar';
      btnConnect.classList.remove('btn-secondary');
      btnConnect.classList.add('btn-primary');
      btnSimulation.textContent = 'Simulação Demo';
      btnSimulation.classList.remove('btn-primary');
      btnSimulation.classList.add('btn-secondary');
    }
  });
}

// DTC Result Listener
if (window.api && window.api.onDtcResult) {
  window.api.onDtcResult((res) => {
    dtcModal.classList.remove('hidden');
    if (res.cleared) {
      dtcBody.innerHTML = `<div class="dtc-clean">&#10004; ${res.message}</div>`;
      return;
    }
    if (res.error) {
      dtcBody.innerHTML = `<div style="color: #ff5252;">${res.error}</div>`;
      return;
    }
    if (!res.dtcs || res.dtcs.length === 0) {
      dtcBody.innerHTML = `
        <div class="dtc-clean">
          <span style="font-size: 24px;">&#10004;</span>
          <div>
            <strong>Nenhuma Falha Registrada!</strong>
            <p style="font-size: 12px; color: #8b9bb4; margin-top: 4px;">A central Bosch MED17 não reportou nenhum DTC ativo.</p>
          </div>
        </div>
      `;
    } else {
      let html = `<p style="margin-bottom: 12px; font-weight: 700; color: #ff5252;">${res.dtcs.length} código(s) de falha encontrado(s):</p>`;
      res.dtcs.forEach(code => {
        const desc = TSI_DTC_DB[code] || 'Código específico do fabricante/plataforma VAG';
        html += `
          <div class="dtc-item">
            <div class="dtc-code">${code}</div>
            <div class="dtc-desc">${desc}</div>
          </div>
        `;
      });
      dtcBody.innerHTML = html;
    }
  });
}

// Log Status Listener
if (window.api && window.api.onLogStatus) {
  window.api.onLogStatus((status) => {
    if (status.active) {
      valLogStatus.textContent = 'Gravando CSV...';
      valLogStatus.style.color = '#00e676';
    } else {
      valLogStatus.textContent = status.path ? `Salvo: ${status.path.split('\\').pop()}` : 'Inativo';
      valLogStatus.style.color = '#8b9bb4';
    }
  });
}

// Update UI with telemetry data
function updateTelemetry(data) {
  targetRpm = data.rpm || 0;
  targetBoost = data.boostBar || 0.0;

  valRpm.textContent = targetRpm.toLocaleString();
  valSpeed.textContent = data.speed || 0;
  valGear.textContent = data.gear || 'N';

  valBoostBar.textContent = (targetBoost >= 0 ? '+' : '') + targetBoost.toFixed(2);
  valBoostPsi.textContent = (data.boostPsi || 0).toFixed(1) + ' PSI';

  // Peak boost
  if (targetBoost > peakBoost) {
    peakBoost = targetBoost;
    valPeakBoost.textContent = (peakBoost >= 0 ? '+' : '') + peakBoost.toFixed(2) + ' bar';
  }

  // Sensors
  if (data.coolant !== undefined) {
    valCoolant.textContent = `${data.coolant} °C`;
    const pctCool = Math.min(100, Math.max(0, (data.coolant / 120) * 100));
    barCoolant.style.width = `${pctCool}%`;
    valCoolant.style.color = data.coolant > 102 ? '#ff5252' : '#fff';
  }

  if (data.iat !== undefined) {
    valIat.textContent = `${data.iat} °C`;
    const pctIat = Math.min(100, Math.max(0, (data.iat / 70) * 100));
    barIat.style.width = `${pctIat}%`;
    flagIntercooler.style.color = data.iat > 55 ? '#ff5252' : '#00e676';
  }

  if (data.map !== undefined) {
    valMap.textContent = `${data.map} kPa`;
    const pctMap = Math.min(100, Math.max(0, (data.map / 250) * 100));
    barMap.style.width = `${pctMap}%`;
  }

  if (data.tps !== undefined) {
    valTps.textContent = `${data.tps} %`;
    barTps.style.width = `${data.tps}%`;
  }

  if (data.load !== undefined) {
    valLoad.textContent = `${data.load} %`;
    barLoad.style.width = `${data.load}%`;
  }

  if (data.timing !== undefined) {
    valTiming.textContent = `${data.timing >= 0 ? '+' : ''}${data.timing} °`;
    const pctTiming = Math.min(100, Math.max(0, ((data.timing + 10) / 50) * 100));
    barTiming.style.width = `${pctTiming}%`;
  }

  if (data.stft !== undefined && data.ltft !== undefined) {
    valFuelTrim.textContent = `S: ${data.stft}% | L: ${data.ltft}%`;
    const avgTrim = Math.abs(data.stft);
    flagLambda.style.color = avgTrim > 18 ? '#ff5252' : '#00e676';
  }

  if (data.voltage) {
    valVoltage.textContent = `${data.voltage.toFixed(1)} V`;
    const pctVolt = Math.min(100, Math.max(0, ((data.voltage - 10) / 5) * 100));
    barVoltage.style.width = `${pctVolt}%`;
    lblVoltStatus.textContent = data.voltage >= 13.5 ? 'Alternador carregando (OK)' : 'Bateria (Ignição ligada)';
  }

  if (data.vin) valVin.textContent = data.vin;
  if (data.protocol) valProto.textContent = data.protocol;

  updateShiftLights(targetRpm);
}

// Shift Light Logic
function updateShiftLights(rpm) {
  const thresholds = [3800, 4400, 4900, 5300, 5600, 5800, 6000, 6200];

  shiftLeds.forEach((led, idx) => {
    if (rpm >= thresholds[idx]) {
      led.classList.add('active');
    } else {
      led.classList.remove('active');
    }
  });

  if (rpm >= 5900) {
    shiftLightBar.classList.add('shift-flash');
  } else {
    shiftLightBar.classList.remove('shift-flash');
  }
}

// Smooth Animation Loop for Gauges
function animate() {
  currentRpm += (targetRpm - currentRpm) * 0.25;
  currentBoost += (targetBoost - currentBoost) * 0.25;

  drawTachometer(currentRpm);
  drawBoostGauge(currentBoost);

  requestAnimationFrame(animate);
}

// Draw Tachometer Canvas
function drawTachometer(rpm) {
  const w = tachCanvas.width;
  const h = tachCanvas.height;
  const cx = w / 2;
  const cy = h / 2;
  const radius = 135;

  tachCtx.clearRect(0, 0, w, h);

  const startAngle = (135 * Math.PI) / 180;
  const endAngle = (405 * Math.PI) / 180;
  const totalSweep = endAngle - startAngle;

  // Background Track
  tachCtx.beginPath();
  tachCtx.arc(cx, cy, radius, startAngle, endAngle);
  tachCtx.lineWidth = 14;
  tachCtx.strokeStyle = '#182133';
  tachCtx.lineCap = 'round';
  tachCtx.stroke();

  // Redline Track (6000 - 7000 RPM)
  const redlineStart = startAngle + (6000 / 7000) * totalSweep;
  tachCtx.beginPath();
  tachCtx.arc(cx, cy, radius, redlineStart, endAngle);
  tachCtx.lineWidth = 14;
  tachCtx.strokeStyle = 'rgba(229, 26, 36, 0.5)';
  tachCtx.lineCap = 'round';
  tachCtx.stroke();

  // Active RPM Value Arc
  const clampedRpm = Math.max(0, Math.min(7000, rpm));
  const activeSweep = (clampedRpm / 7000) * totalSweep;
  if (activeSweep > 0) {
    const grad = tachCtx.createLinearGradient(0, h, w, 0);
    grad.addColorStop(0, '#00e676');
    grad.addColorStop(0.65, '#ffd600');
    grad.addColorStop(0.85, '#e51a24');

    tachCtx.beginPath();
    tachCtx.arc(cx, cy, radius, startAngle, startAngle + activeSweep);
    tachCtx.lineWidth = 14;
    tachCtx.strokeStyle = grad;
    tachCtx.lineCap = 'round';
    tachCtx.stroke();
  }

  // Ticks & Numbers (0 to 7)
  for (let i = 0; i <= 7; i++) {
    const angle = startAngle + (i / 7) * totalSweep;
    const isRedline = i >= 6;

    const x1 = cx + (radius - 16) * Math.cos(angle);
    const y1 = cy + (radius - 16) * Math.sin(angle);
    const x2 = cx + (radius - 28) * Math.cos(angle);
    const y2 = cy + (radius - 28) * Math.sin(angle);

    tachCtx.beginPath();
    tachCtx.moveTo(x1, y1);
    tachCtx.lineTo(x2, y2);
    tachCtx.lineWidth = 3;
    tachCtx.strokeStyle = isRedline ? '#ff4d58' : '#7387a8';
    tachCtx.stroke();

    if (i < 7) {
      for (let m = 1; m < 5; m++) {
        const minorAngle = angle + (m / 5) * (totalSweep / 7);
        const mx1 = cx + (radius - 16) * Math.cos(minorAngle);
        const my1 = cy + (radius - 16) * Math.sin(minorAngle);
        const mx2 = cx + (radius - 22) * Math.cos(minorAngle);
        const my2 = cy + (radius - 22) * Math.sin(minorAngle);

        tachCtx.beginPath();
        tachCtx.moveTo(mx1, my1);
        tachCtx.lineTo(mx2, my2);
        tachCtx.lineWidth = 1.5;
        tachCtx.strokeStyle = '#344563';
        tachCtx.stroke();
      }
    }

    const tx = cx + (radius - 45) * Math.cos(angle);
    const ty = cy + (radius - 45) * Math.sin(angle);
    tachCtx.font = 'bold 15px -apple-system, Roboto, sans-serif';
    tachCtx.textAlign = 'center';
    tachCtx.textBaseline = 'middle';
    tachCtx.fillStyle = isRedline ? '#ff5252' : '#a0b3d1';
    tachCtx.fillText(i.toString(), tx, ty);
  }

  // Needle
  const needleAngle = startAngle + (clampedRpm / 7000) * totalSweep;
  drawNeedle(tachCtx, cx, cy, radius - 20, needleAngle, '#e51a24');
}

// Draw Turbo Boost Canvas
function drawBoostGauge(boost) {
  const w = boostCanvas.width;
  const h = boostCanvas.height;
  const cx = w / 2;
  const cy = h / 2;
  const radius = 135;

  boostCtx.clearRect(0, 0, w, h);

  const startAngle = (135 * Math.PI) / 180;
  const endAngle = (405 * Math.PI) / 180;
  const totalSweep = endAngle - startAngle;

  // Background Track
  boostCtx.beginPath();
  boostCtx.arc(cx, cy, radius, startAngle, endAngle);
  boostCtx.lineWidth = 14;
  boostCtx.strokeStyle = '#182133';
  boostCtx.lineCap = 'round';
  boostCtx.stroke();

  // Zero Boost Position (-1.0 to +2.0 bar)
  const zeroAngle = startAngle + (1.0 / 3.0) * totalSweep;

  // Vacuum Zone Track
  boostCtx.beginPath();
  boostCtx.arc(cx, cy, radius, startAngle, zeroAngle);
  boostCtx.lineWidth = 14;
  boostCtx.strokeStyle = 'rgba(0, 168, 255, 0.25)';
  boostCtx.stroke();

  // High Boost Warning Track (1.4 - 2.0 bar)
  const highBoostStart = startAngle + (2.4 / 3.0) * totalSweep;
  boostCtx.beginPath();
  boostCtx.arc(cx, cy, radius, highBoostStart, endAngle);
  boostCtx.lineWidth = 14;
  boostCtx.strokeStyle = 'rgba(255, 61, 0, 0.4)';
  boostCtx.stroke();

  // Active Value Arc
  const clampedBoost = Math.max(-1.0, Math.min(2.0, boost));
  const boostPos = (clampedBoost + 1.0) / 3.0;
  const activeSweep = boostPos * totalSweep;

  if (activeSweep > 0) {
    const grad = boostCtx.createLinearGradient(0, h, w, 0);
    grad.addColorStop(0, '#00a8ff');
    grad.addColorStop(0.35, '#00e676');
    grad.addColorStop(0.7, '#ff9100');
    grad.addColorStop(1, '#ff1744');

    boostCtx.beginPath();
    boostCtx.arc(cx, cy, radius, startAngle, startAngle + activeSweep);
    boostCtx.lineWidth = 14;
    boostCtx.strokeStyle = grad;
    boostCtx.lineCap = 'round';
    boostCtx.stroke();
  }

  // Ticks & Labels
  const ticks = [-1.0, -0.5, 0, 0.5, 1.0, 1.5, 2.0];
  ticks.forEach(val => {
    const pos = (val + 1.0) / 3.0;
    const angle = startAngle + pos * totalSweep;
    const isZero = val === 0;
    const isHigh = val >= 1.5;

    const x1 = cx + (radius - 16) * Math.cos(angle);
    const y1 = cy + (radius - 16) * Math.sin(angle);
    const x2 = cx + (radius - (isZero ? 30 : 26)) * Math.cos(angle);
    const y2 = cy + (radius - (isZero ? 30 : 26)) * Math.sin(angle);

    boostCtx.beginPath();
    boostCtx.moveTo(x1, y1);
    boostCtx.lineTo(x2, y2);
    boostCtx.lineWidth = isZero ? 3.5 : 2.5;
    boostCtx.strokeStyle = isZero ? '#00e676' : isHigh ? '#ff5252' : '#7387a8';
    boostCtx.stroke();

    const tx = cx + (radius - 44) * Math.cos(angle);
    const ty = cy + (radius - 44) * Math.sin(angle);
    boostCtx.font = (isZero ? 'bold 15px' : '13px') + ' -apple-system, Roboto, sans-serif';
    boostCtx.textAlign = 'center';
    boostCtx.textBaseline = 'middle';
    boostCtx.fillStyle = isZero ? '#00e676' : isHigh ? '#ff5252' : '#9cb1d4';
    boostCtx.fillText(val.toFixed(1), tx, ty);
  });

  // Peak Marker
  if (peakBoost > 0) {
    const peakPos = Math.max(0, Math.min(1.0, (peakBoost + 1.0) / 3.0));
    const peakAngle = startAngle + peakPos * totalSweep;
    const px1 = cx + (radius + 2) * Math.cos(peakAngle);
    const py1 = cy + (radius + 2) * Math.sin(peakAngle);
    const px2 = cx + (radius + 12) * Math.cos(peakAngle);
    const py2 = cy + (radius + 12) * Math.sin(peakAngle);

    boostCtx.beginPath();
    boostCtx.moveTo(px1, py1);
    boostCtx.lineTo(px2, py2);
    boostCtx.lineWidth = 4;
    boostCtx.strokeStyle = '#ffd600';
    boostCtx.stroke();
  }

  // Needle
  const needleAngle = startAngle + boostPos * totalSweep;
  drawNeedle(boostCtx, cx, cy, radius - 20, needleAngle, '#00a8ff');
}

// Draw Needle Helper
function drawNeedle(ctx, cx, cy, length, angle, color) {
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(angle);

  ctx.shadowColor = color;
  ctx.shadowBlur = 10;

  ctx.beginPath();
  ctx.moveTo(-16, -3);
  ctx.lineTo(length, 0);
  ctx.lineTo(-16, 3);
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.fill();

  ctx.shadowBlur = 0;
  ctx.beginPath();
  ctx.arc(0, 0, 14, 0, Math.PI * 2);
  ctx.fillStyle = '#0a0e17';
  ctx.fill();
  ctx.lineWidth = 3;
  ctx.strokeStyle = color;
  ctx.stroke();

  ctx.beginPath();
  ctx.arc(0, 0, 5, 0, Math.PI * 2);
  ctx.fillStyle = '#fff';
  ctx.fill();

  ctx.restore();
}

// Startup
refreshPorts();
animate();
