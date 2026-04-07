(function () {
  function mulberry32(seed) {
    return function () {
      let t = seed += 0x6D2B79F5;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  const rand = mulberry32(2026);
  const baseTime = new Date("2026-04-06T09:00:00+05:30");
  const phaseCycle = ["Pre-Heat", "Compression", "Cooling"];
  const telemetry = [];

  for (let i = 0; i < 96; i += 1) {
    const timestamp = new Date(baseTime.getTime() - (95 - i) * 30 * 60 * 1000);
    const phase = phaseCycle[Math.floor(i / 4) % phaseCycle.length];
    const hour = timestamp.getHours();
    const shiftBias = hour >= 14 && hour < 22 ? 1.1 : hour >= 6 && hour < 14 ? -0.6 : -0.2;
    const wave = Math.sin(i / 5.2) * 2.6;
    let temperature = 180 + wave + shiftBias + ((rand() - 0.5) * 4.8);
    let pressure = (phase === "Compression" ? 123 : phase === "Pre-Heat" ? 72 : 84) + ((rand() - 0.5) * 12);
    let vibration = 1.05 + (phase === "Compression" ? 0.55 : 0.12) + Math.abs((rand() - 0.5) * 0.9);
    let energy = 52 + (phase === "Compression" ? 4.4 : phase === "Pre-Heat" ? 2.8 : 1.7) + ((rand() - 0.5) * 3.4);

    if ([18, 19, 57].includes(i)) {
      temperature += 13 + rand() * 4;
    }
    if ([41, 66].includes(i)) {
      pressure += 20 + rand() * 8;
    }
    if ([72, 73, 74, 89].includes(i)) {
      vibration += 2.3 + rand() * 1.2;
    }

    temperature = clamp(temperature, 147, 202);
    pressure = clamp(pressure, 52, 152);
    vibration = clamp(vibration, 0.12, 5.2);
    energy = clamp(energy, 47, 62);

    const defectCount = Math.max(
      0,
      Math.round(
        1.2 +
        Math.abs(temperature - 180) * 0.09 +
        Math.abs(pressure - 100) * 0.04 +
        vibration * 0.95 +
        (rand() - 0.5) * 2.3
      )
    );

    const qualityScore = clamp(
      98.6 -
      Math.abs(temperature - 180) * 0.32 -
      Math.abs(pressure - 110) * 0.06 -
      vibration * 1.35 -
      defectCount * 0.65 +
      (rand() - 0.5) * 1.5,
      82,
      99.4
    );

    telemetry.push({
      timestamp: timestamp.toISOString(),
      sequence: 10400 + i,
      phase,
      temperature: Number(temperature.toFixed(2)),
      pressure: Number(pressure.toFixed(2)),
      vibration: Number(vibration.toFixed(2)),
      qualityScore: Number(qualityScore.toFixed(2)),
      defectCount,
      energy: Number(energy.toFixed(2))
    });
  }

  const alerts = telemetry
    .filter((point) => point.temperature > 195 || point.pressure > 140 || point.vibration > 4.0)
    .map((point, index) => {
      let type = "Quality Drift";
      let severity = "medium";
      let message = "Process deviation detected.";

      if (point.temperature > 195) {
        type = "High Temperature";
        severity = "high";
        message = "Mold temperature exceeded the recommended control ceiling.";
      } else if (point.pressure > 140) {
        type = "High Pressure";
        severity = "high";
        message = "Compression pressure spiked above the safe process band.";
      } else if (point.vibration > 4.0) {
        type = "Vibration Spike";
        severity = "critical";
        message = "Mechanical vibration suggests emerging wear or misalignment.";
      }

      return {
        id: `ALT-${String(index + 1).padStart(3, "0")}`,
        type,
        severity,
        timestamp: point.timestamp,
        message,
        value: point.temperature > 195 ? `${point.temperature} degC` : point.pressure > 140 ? `${point.pressure} bar` : `${point.vibration} mm/s`
      };
    })
    .slice(-8)
    .reverse();

  const batches = Array.from({ length: 8 }, (_, idx) => {
    const sliceEnd = 95 - idx * 8;
    const sliceStart = Math.max(0, sliceEnd - 7);
    const slice = telemetry.slice(sliceStart, sliceEnd + 1);
    const start = new Date(slice[0].timestamp);
    const end = new Date(slice[slice.length - 1].timestamp);
    const quantity = 438 + ((idx * 13) % 34) + Math.round(rand() * 12);
    const defects = slice.reduce((sum, item) => sum + item.defectCount, 0);
    const avgQuality = slice.reduce((sum, item) => sum + item.qualityScore, 0) / slice.length;
    const dominantPhase = slice.reduce((acc, item) => {
      acc[item.phase] = (acc[item.phase] || 0) + 1;
      return acc;
    }, {});
    const phaseLabel = Object.entries(dominantPhase).sort((a, b) => b[1] - a[1])[0][0];

    return {
      batchId: `BT-${String(208 + idx).padStart(3, "0")}`,
      start: start.toISOString(),
      end: end.toISOString(),
      quantity,
      defects,
      quality: Number(avgQuality.toFixed(2)),
      phaseLabel
    };
  }).reverse();

  const maintenance = [
    { component: "Hydraulic Pack", condition: 88, note: "Pressure hold is stable. Next seal check due in 11 days." },
    { component: "Heater Platens", condition: 91, note: "Thermal drift remains low. PID tuning still within tolerance." },
    { component: "Guide Pillars", condition: 84, note: "Lubrication window approaching. Plan grease inspection this week." },
    { component: "Pump Bearings", condition: 73, note: "Vibration signature is rising slightly under compression load." }
  ];

  window.SYNAPSE_SEED = {
    machine: {
      id: "M-07",
      name: "Rubber Press 07",
      subtitle: "Plant A / Line 2 · Model RPC-4P-220",
      plcIp: "192.168.10.21",
      brokerPort: "8883 / TLS",
      qos: "Telemetry QoS 1 · Alerts QoS 2"
    },
    telemetry,
    alerts,
    batches,
    maintenance
  };
}());
