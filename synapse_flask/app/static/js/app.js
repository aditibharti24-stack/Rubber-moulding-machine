(function () {
  let seed = window.SYNAPSE_SEED;
  if (!seed || !Array.isArray(seed.telemetry) || seed.telemetry.length === 0) {
    document.addEventListener("DOMContentLoaded", () => {
      document.body.innerHTML = "<main style=\"padding:2rem;font-family:Segoe UI,sans-serif;color:#edf1e5;background:#141617;min-height:100vh;\">Dashboard bootstrap data is unavailable.</main>";
    });
    return;
  }
  const state = {
    index: Math.min(47, seed.telemetry.length - 1),
    tick: 0,
    windowSize: 48,
    bufferCount: 0,
    liveMode: Boolean(window.SYNAPSE_API),
    connectedSocket: false
  };

  const thresholds = {
    temperature: { low: 150, high: 195, color: "#ff825f", unit: "degC" },
    pressure: { low: 55, high: 140, color: "#4cc9ff", unit: "bar" },
    vibration: { low: 0, high: 4.0, color: "#f7c75f", unit: "mm/s" }
  };

  const elements = {};

  function byId(id) {
    return document.getElementById(id);
  }

  function initElements() {
    [
      "machineTitle", "machineName", "machineSubtitle", "liveTimestamp", "qosMode",
      "plcIp", "brokerPort", "brokerStatus", "bufferedFrames", "ackSequence",
      "latencyValue", "packetLossValue", "networkNarrative", "connectionDot",
      "machineHealth", "tempValue", "tempDelta", "pressureValue", "pressureDelta",
      "vibrationValue", "vibrationDelta", "qualityValue", "defectRisk",
      "energyValue", "energyDelta", "phaseValue", "phaseClock",
      "tempChartValue", "tempChartTag", "pressureChartValue", "pressureChartTag",
      "vibrationChartValue", "vibrationChartTag", "alertList", "batchTableBody",
      "componentGrid", "recommendationList", "spcStatus", "spcNote",
      "anomalyScore", "anomalyNote", "reliabilityValue", "reliabilityNote",
      "qualityForecast", "qualityForecastNote"
    ].forEach((id) => {
      elements[id] = byId(id);
    });

    elements.signalCards = Array.from(document.querySelectorAll(".signal-card"));
    elements.windowButtons = Array.from(document.querySelectorAll(".window-button"));
    elements.phaseSegments = Array.from(document.querySelectorAll(".phase-segment"));
  }

  function formatTime(value) {
    return new Intl.DateTimeFormat("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit"
    }).format(new Date(value));
  }

  function getCurrentPoint() {
    return seed.telemetry[state.index];
  }

  function replaceSeed(payload) {
    if (!payload || !Array.isArray(payload.telemetry) || payload.telemetry.length === 0) {
      return;
    }
    seed = payload;
    state.index = seed.telemetry.length - 1;
    render();
  }

  function getWindowedSeries() {
    const start = Math.max(0, state.index - state.windowSize + 1);
    return seed.telemetry.slice(start, state.index + 1);
  }

  function updateWindowButtons() {
    elements.windowButtons.forEach((button) => {
      button.classList.toggle("is-active", Number(button.dataset.window) === state.windowSize);
    });
  }

  function getNetworkState(point) {
    if (state.liveMode) {
      return {
        offline: false,
        brokerStatus: state.connectedSocket ? "Broker Online" : "Broker Connecting",
        latency: 18 + ((state.tick * 3) % 12),
        packetLoss: "0.0",
        ackSequence: point.sequence,
        narrative: state.connectedSocket
          ? "Live updates are connected through the backend API and MQTT ingestion path."
          : "The dashboard is waiting for live backend updates. Seed data is still available."
      };
    }

    const outageWindow = state.tick % 20;
    const offline = outageWindow === 14 || outageWindow === 15;

    if (offline) {
      state.bufferCount += 6;
    } else if (state.bufferCount > 0) {
      state.bufferCount = Math.max(0, state.bufferCount - 9);
    }

    return {
      offline,
      brokerStatus: offline ? "Broker Reconnecting" : "Broker Online",
      latency: offline ? 0 : 28 + ((state.tick * 7) % 18),
      packetLoss: offline ? 12.8 : (0.1 + ((state.tick % 5) * 0.1)).toFixed(1),
      ackSequence: offline ? point.sequence - 2 : point.sequence,
      narrative: offline
        ? "Connectivity dipped. The controller is buffering readings locally and will flush them in timestamp order after MQTT reconnect."
        : state.bufferCount > 0
          ? "Connectivity recovered. Buffered telemetry is being replayed while live samples stay in sequence."
          : "Reliable transport. No buffered telemetry. MQTT acknowledgments are keeping the stream in sync."
    };
  }

  function summarizeTemperature(point) {
    const offset = point.temperature - 180;
    if (offset > 8) {
      return "Above thermal target";
    }
    if (offset < -8) {
      return "Below thermal target";
    }
    return `${offset >= 0 ? "+" : ""}${offset.toFixed(1)} vs target`;
  }

  function summarizePressure(point) {
    if (point.pressure > 140) {
      return "Over-compression detected";
    }
    if (point.phase === "Compression") {
      return "Stable under load";
    }
    return "Cycle-adjusted";
  }

  function summarizeVibration(point) {
    if (point.vibration > 4.0) {
      return "Critical mechanical spike";
    }
    if (point.vibration > 2.8) {
      return "Wear pattern rising";
    }
    return "Normal bearing signature";
  }

  function summarizeDefectRisk(point) {
    if (point.defectCount >= 6 || point.qualityScore < 92) {
      return "Elevated defect risk";
    }
    if (point.defectCount >= 4 || point.qualityScore < 95) {
      return "Monitor trim closely";
    }
    return "Low defect risk";
  }

  function updateTopline(point, network) {
    elements.machineTitle.textContent = seed.machine.id.replace("M-", "RPC-4P-");
    elements.machineName.textContent = seed.machine.name;
    elements.machineSubtitle.textContent = seed.machine.subtitle;
    elements.liveTimestamp.textContent = formatTime(point.timestamp);
    elements.qosMode.textContent = seed.machine.qos;
    elements.plcIp.textContent = seed.machine.plcIp;
    elements.brokerPort.textContent = seed.machine.brokerPort;
    elements.brokerStatus.textContent = network.brokerStatus;
    elements.bufferedFrames.textContent = String(state.bufferCount);
    elements.ackSequence.textContent = String(network.ackSequence);
    elements.latencyValue.textContent = network.offline ? "Offline" : `${network.latency} ms`;
    elements.packetLossValue.textContent = network.offline ? "Link lost" : `${network.packetLoss}%`;
    elements.networkNarrative.textContent = network.narrative;
    elements.connectionDot.classList.toggle("is-offline", network.offline);
  }

  function computeHealth(point, network) {
    let score = 100;
    score -= Math.abs(point.temperature - 180) * 0.7;
    score -= Math.max(0, point.pressure - 135) * 0.35;
    score -= Math.max(0, point.vibration - 2.0) * 9;
    score -= point.defectCount * 1.6;
    score -= network.offline ? 7 : 0;
    score -= Math.min(state.bufferCount, 12) * 0.35;
    return Math.max(58, Math.min(98, Math.round(score)));
  }

  function updateKpis(point, network) {
    const health = computeHealth(point, network);
    elements.machineHealth.textContent = `${health}%`;
    elements.tempValue.textContent = point.temperature.toFixed(1);
    elements.tempDelta.textContent = summarizeTemperature(point);
    elements.pressureValue.textContent = point.pressure.toFixed(1);
    elements.pressureDelta.textContent = summarizePressure(point);
    elements.vibrationValue.textContent = point.vibration.toFixed(2);
    elements.vibrationDelta.textContent = summarizeVibration(point);
    elements.qualityValue.textContent = point.qualityScore.toFixed(1);
    elements.defectRisk.textContent = summarizeDefectRisk(point);
    elements.energyValue.textContent = point.energy.toFixed(1);
    elements.energyDelta.textContent = point.energy > 57 ? "Energy drift detected" : "Within control band";
    elements.phaseValue.textContent = point.phase;
    elements.phaseClock.textContent = `Cycle minute ${((state.index % 4) * 8) + 5}`;

    elements.phaseSegments.forEach((segment) => {
      segment.classList.toggle("is-active", segment.dataset.phase === point.phase);
    });
  }

  function average(values) {
    return values.reduce((sum, value) => sum + value, 0) / values.length;
  }

  function standardDeviation(values) {
    const mean = average(values);
    const variance = average(values.map((value) => (value - mean) ** 2));
    return Math.sqrt(variance);
  }

  function computeQualityForecast(point) {
    const deviationPenalty = Math.abs(point.temperature - 180) * 0.29;
    const pressurePenalty = Math.abs(point.pressure - 110) * 0.05;
    const vibrationPenalty = point.vibration * 1.18;
    return Math.max(86, Math.min(99.3, 98.4 - deviationPenalty - pressurePenalty - vibrationPenalty));
  }

  function updateAnalytics(slice, point) {
    const temps = slice.map((entry) => entry.temperature);
    const tempMean = average(temps);
    const tempStd = standardDeviation(temps) || 1;
    const zScore = Math.abs((point.temperature - tempMean) / tempStd);
    const anomalyScore = Math.min(5, (zScore * 1.2) + Math.max(0, point.vibration - 2.5));
    const spcStatus = zScore > 2.6 || point.vibration > 4 ? "Out of Control" : zScore > 1.8 ? "Watch Zone" : "In Control";
    const reliability = Math.max(82, Math.min(98, 96 - Math.max(0, point.vibration - 1.5) * 3.2 - Math.max(0, state.bufferCount - 2) * 0.4));
    const qualityForecast = computeQualityForecast(point);

    elements.spcStatus.textContent = spcStatus;
    elements.spcNote.textContent = spcStatus === "In Control"
      ? "No special-cause variation on the current subgroup window."
      : spcStatus === "Watch Zone"
        ? "Temperature dispersion is widening. Review heater balance and next subgroup readings."
        : "Special-cause variation is visible. Investigate process drift before the next batch closes.";

    elements.anomalyScore.textContent = `${anomalyScore.toFixed(1)} / 5`;
    elements.anomalyNote.textContent = anomalyScore < 2
      ? "Z-score flags remain below action threshold."
      : anomalyScore < 3.5
        ? "Anomaly score is rising. Cross-check vibration and temperature drift."
        : "Anomaly score is elevated. Trigger a maintenance inspection window.";

    elements.reliabilityValue.textContent = `${reliability.toFixed(1)}%`;
    elements.reliabilityNote.textContent = point.vibration > 3.2
      ? "Short-term reliability is declining under load. Weibull-style wear behavior is becoming more likely."
      : "Weibull fit indicates healthy short-term availability.";

    elements.qualityForecast.textContent = qualityForecast.toFixed(1);
    elements.qualityForecastNote.textContent = qualityForecast > 96
      ? "Regression suggests stable product quality at present conditions."
      : "Forecast quality is softening. Tighten process control before defects rise.";
  }

  function renderChart(card, values, config, latestValue) {
    const svg = card.querySelector(".signal-svg");
    const width = 520;
    const height = 180;
    const padX = 16;
    const padY = 16;
    const min = Math.min(config.low, ...values) - (config.high - config.low) * 0.1;
    const max = Math.max(config.high, ...values) + (config.high - config.low) * 0.1;
    const range = max - min || 1;

    const points = values.map((value, index) => {
      const x = padX + (index / Math.max(values.length - 1, 1)) * (width - padX * 2);
      const y = height - padY - ((value - min) / range) * (height - padY * 2);
      return [x, y];
    });

    const linePath = points.map((point, index) => `${index === 0 ? "M" : "L"} ${point[0].toFixed(2)} ${point[1].toFixed(2)}`).join(" ");
    const areaPath = `${linePath} L ${points[points.length - 1][0].toFixed(2)} ${(height - padY).toFixed(2)} L ${points[0][0].toFixed(2)} ${(height - padY).toFixed(2)} Z`;
    const latestPoint = points[points.length - 1];

    const lowY = height - padY - ((config.low - min) / range) * (height - padY * 2);
    const highY = height - padY - ((config.high - min) / range) * (height - padY * 2);

    svg.innerHTML = `
      <defs>
        <linearGradient id="${card.dataset.series}-fill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stop-color="${config.color}" stop-opacity="0.34"></stop>
          <stop offset="100%" stop-color="${config.color}" stop-opacity="0"></stop>
        </linearGradient>
      </defs>
      <line x1="${padX}" y1="${lowY.toFixed(2)}" x2="${width - padX}" y2="${lowY.toFixed(2)}" class="threshold-line"></line>
      <line x1="${padX}" y1="${highY.toFixed(2)}" x2="${width - padX}" y2="${highY.toFixed(2)}" class="threshold-line"></line>
      <path d="${areaPath}" fill="url(#${card.dataset.series}-fill)"></path>
      <path d="${linePath}" class="trend-line" style="stroke:${config.color}"></path>
      <circle cx="${latestPoint[0].toFixed(2)}" cy="${latestPoint[1].toFixed(2)}" r="4.5" fill="${config.color}" class="pulse-dot"></circle>
      <text x="${width - padX}" y="24" text-anchor="end" class="chart-label">${latestValue.toFixed(2)} ${config.unit}</text>
    `;
  }

  function renderSignals(slice, point) {
    const seriesMap = {
      temperature: slice.map((entry) => entry.temperature),
      pressure: slice.map((entry) => entry.pressure),
      vibration: slice.map((entry) => entry.vibration)
    };

    elements.signalCards.forEach((card) => {
      const seriesName = card.dataset.series;
      renderChart(card, seriesMap[seriesName], thresholds[seriesName], point[seriesName]);
    });

    elements.tempChartValue.textContent = `${point.temperature.toFixed(1)} degC`;
    elements.tempChartTag.textContent = point.temperature > 195 ? "Thermal high" : point.temperature < 170 ? "Cooler than target" : "Centered";
    elements.pressureChartValue.textContent = `${point.pressure.toFixed(1)} bar`;
    elements.pressureChartTag.textContent = point.pressure > 140 ? "Over-pressure" : point.phase === "Compression" ? "Load stable" : "Phase shifted";
    elements.vibrationChartValue.textContent = `${point.vibration.toFixed(2)} mm/s`;
    elements.vibrationChartTag.textContent = point.vibration > 4 ? "Critical spike" : point.vibration > 2.8 ? "Watch bearing wear" : "Healthy signature";
  }

  function renderAlerts(point) {
    const recentAlerts = seed.alerts
      .filter((alert) => new Date(alert.timestamp) <= new Date(point.timestamp))
      .slice(0, 6);

    if (recentAlerts.length === 0) {
      elements.alertList.innerHTML = `
        <article class="alert-card severity-low">
          <div class="alert-type">No active alerts</div>
          <p>Current readings are within configured process bands.</p>
        </article>
      `;
      return;
    }

    elements.alertList.innerHTML = recentAlerts.map((alert) => `
      <article class="alert-card severity-${alert.severity}">
        <div class="alert-head">
          <strong class="alert-type">${alert.type}</strong>
          <span class="alert-value">${alert.value}</span>
        </div>
        <p>${alert.message}</p>
        <div class="alert-foot">
          <span>${alert.id}</span>
          <span>${formatTime(alert.timestamp)}</span>
        </div>
      </article>
    `).join("");
  }

  function renderBatches(point) {
    const availableBatches = seed.batches.filter((batch) => new Date(batch.end) <= new Date(point.timestamp)).slice(-6).reverse();
    elements.batchTableBody.innerHTML = availableBatches.map((batch) => `
      <tr>
        <td>${batch.batchId}</td>
        <td>${formatTime(batch.start)} to ${new Intl.DateTimeFormat("en-IN", { hour: "2-digit", minute: "2-digit" }).format(new Date(batch.end))}</td>
        <td>${batch.quantity}</td>
        <td>${batch.defects}</td>
        <td><span class="quality-chip ${batch.quality >= 96 ? "quality-high" : batch.quality >= 93 ? "quality-mid" : "quality-low"}">${batch.quality.toFixed(1)}</span></td>
        <td>${batch.phaseLabel}</td>
      </tr>
    `).join("");
  }

  function renderMaintenance(point) {
    const updatedComponents = seed.maintenance.map((item) => {
      let condition = item.condition;
      if (item.component === "Pump Bearings") {
        condition -= Math.max(0, point.vibration - 2.2) * 7;
      }
      if (item.component === "Heater Platens") {
        condition -= Math.abs(point.temperature - 180) * 0.7;
      }
      if (item.component === "Hydraulic Pack") {
        condition -= Math.max(0, point.pressure - 135) * 0.4;
      }
      return {
        ...item,
        condition: Math.max(52, Math.min(97, Math.round(condition)))
      };
    });

    elements.componentGrid.innerHTML = updatedComponents.map((item) => `
      <article class="component-card">
        <div class="component-head">
          <strong>${item.component}</strong>
          <span>${item.condition}%</span>
        </div>
        <div class="condition-bar">
          <span style="width:${item.condition}%"></span>
        </div>
        <p>${item.note}</p>
      </article>
    `).join("");

    const recommendations = [];
    if (point.vibration > 3.4) {
      recommendations.push("Inspect pump bearings and frame alignment before the next production shift.");
    }
    if (point.temperature > 192 || point.temperature < 170) {
      recommendations.push("Review heater platen balance and PID tuning to protect quality consistency.");
    }
    if (point.pressure > 138) {
      recommendations.push("Check hydraulic relief settings and mold closure resistance for over-compression.");
    }
    if (recommendations.length === 0) {
      recommendations.push("Machine condition is stable. Continue trend monitoring and planned preventive tasks.");
      recommendations.push("Next likely maintenance opportunity: lubrication and calibration window within the coming week.");
    }

    elements.recommendationList.innerHTML = recommendations.map((text) => `
      <article class="recommendation-card">
        <span class="recommendation-mark"></span>
        <p>${text}</p>
      </article>
    `).join("");
  }

  function render() {
    const point = getCurrentPoint();
    const slice = getWindowedSeries();
    const network = getNetworkState(point);

    updateWindowButtons();
    updateTopline(point, network);
    updateKpis(point, network);
    renderSignals(slice, point);
    renderAlerts(point);
    renderBatches(point);
    renderMaintenance(point);
    updateAnalytics(slice, point);
  }

  function bindEvents() {
    elements.windowButtons.forEach((button) => {
      button.addEventListener("click", () => {
        state.windowSize = Number(button.dataset.window);
        render();
      });
    });
  }

  async function refreshFromApi() {
    if (!window.SYNAPSE_API || !window.SYNAPSE_API.dashboard) {
      return;
    }

    try {
      const response = await window.fetch(window.SYNAPSE_API.dashboard, { headers: { Accept: "application/json" } });
      if (!response.ok) {
        return;
      }
      const payload = await response.json();
      replaceSeed(payload);
    } catch (error) {
      console.error("Failed to refresh dashboard payload", error);
    }
  }

  function setupRealtime() {
    if (!window.io) {
      return;
    }

    const socket = window.io();
    socket.on("connect", () => {
      state.connectedSocket = true;
      render();
    });
    socket.on("disconnect", () => {
      state.connectedSocket = false;
      render();
    });
    socket.on("dashboard_refresh", () => {
      refreshFromApi();
    });
  }

  function advanceTick() {
    if (state.liveMode) {
      return;
    }
    state.tick += 1;
    if (state.index < seed.telemetry.length - 1) {
      state.index += 1;
    } else {
      state.index = 47;
      state.bufferCount = 0;
    }
    render();
  }

  function init() {
    initElements();
    bindEvents();
    if (state.liveMode) {
      state.index = seed.telemetry.length - 1;
      setupRealtime();
      window.setInterval(() => {
        state.tick += 1;
        refreshFromApi();
      }, 15000);
    }
    render();
    if (!state.liveMode) {
      window.setInterval(advanceTick, 2200);
    }
  }

  document.addEventListener("DOMContentLoaded", init);
}());
