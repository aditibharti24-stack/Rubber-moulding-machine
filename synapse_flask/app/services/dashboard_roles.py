from __future__ import annotations

from copy import deepcopy


ROLE_DASHBOARD_VIEWS = {
    "admin": {
        "workspace_label": "Enterprise Oversight",
        "workspace_title": "Plant Intelligence Control",
        "workspace_summary": (
            "Track uptime, energy efficiency, alert governance, and digital-system health "
            "across the connected molding operation."
        ),
        "attention_title": "Administrator Briefing",
        "attention_note": (
            "Focus on availability risk, network resilience, and whether the machine is staying "
            "inside its quality and energy guardrails."
        ),
        "priority_kpis": [
            "Machine health and network continuity",
            "Energy intensity per batch",
            "Alert escalation and resolution flow",
        ],
        "focus_tiles": [
            {
                "label": "Primary Decision",
                "value": "Keep uptime above target",
                "note": "Watch machine health, broker status, and alert bursts together.",
            },
            {
                "label": "Operational Lens",
                "value": "Energy + quality governance",
                "note": "Balance throughput without allowing thermal or pressure drift.",
            },
            {
                "label": "Escalation Trigger",
                "value": "Repeated critical events",
                "note": "Investigate if high-severity alerts cluster within one shift window.",
            },
        ],
        "action_queue": [
            {
                "title": "Review digital continuity",
                "owner": "Admin priority",
                "body": "Confirm MQTT acknowledgments, buffered frames, and broker latency remain inside normal operating bands.",
            },
            {
                "title": "Protect energy performance",
                "owner": "Operations governance",
                "body": "Check energy intensity against machine phase and batch quality before approving longer runs.",
            },
            {
                "title": "Validate alert workflow",
                "owner": "Control escalation",
                "body": "Ensure unresolved threshold events are acknowledged and routed before the next production cycle closes.",
            },
        ],
        "strip_cards": [
            {
                "label": "Admin Focus",
                "title": "Availability and governance",
                "body": "You are looking for downtime risk, security posture, and plant-level operational consistency.",
            },
            {
                "label": "Immediate Question",
                "title": "Is the stack trustworthy right now?",
                "body": "Treat broker state, sequence acknowledgments, and alert density as your trust signal.",
            },
            {
                "label": "Recommended Move",
                "title": "Escalate only on repeated drift",
                "body": "Single anomalies matter less than sustained instability across telemetry and alerts.",
            },
        ],
        "section_notes": {
            "telemetry": "Use telemetry to validate that process stability and energy performance support plant-level uptime goals.",
            "alerts": "Prioritize unresolved high-severity events and alert clustering that could indicate broader control risk.",
            "batches": "Check whether throughput and quality remain aligned before scaling production duration.",
            "maintenance": "Maintenance view should confirm that reliability issues are not building into downtime exposure.",
            "analytics": "Use analytics to support intervention timing, not just retrospective reporting.",
        },
    },
    "supervisor": {
        "workspace_label": "Production Supervision",
        "workspace_title": "Shift Quality Command",
        "workspace_summary": (
            "Control cycle consistency, product quality, and defect reduction while keeping the "
            "compression press inside its operating window."
        ),
        "attention_title": "Supervisor Briefing",
        "attention_note": (
            "Your quickest read comes from quality score, defect risk, phase stability, and how "
            "temperature and pressure behave during compression."
        ),
        "priority_kpis": [
            "Batch quality and defect trend",
            "Compression-phase temperature and pressure stability",
            "Shift-to-shift process consistency",
        ],
        "focus_tiles": [
            {
                "label": "Primary Decision",
                "value": "Protect batch quality",
                "note": "Use quality score, defect risk, and phase signature together when assessing runs.",
            },
            {
                "label": "Operational Lens",
                "value": "Cycle consistency",
                "note": "Compression pressure and mold temperature should stay aligned with the active phase.",
            },
            {
                "label": "Escalation Trigger",
                "value": "Defect trend rises",
                "note": "Intervene when drift appears across consecutive batches rather than isolated outliers.",
            },
        ],
        "action_queue": [
            {
                "title": "Watch the active cycle",
                "owner": "Shift control",
                "body": "Use the phase tracker and live telemetry to confirm the process is behaving as expected for the current run.",
            },
            {
                "title": "Inspect batch quality drift",
                "owner": "Quality response",
                "body": "Cross-check recent defect counts with temperature and pressure behavior before releasing the next batch window.",
            },
            {
                "title": "Coordinate with maintenance",
                "owner": "Escalate if needed",
                "body": "If vibration starts affecting quality, flag it early instead of waiting for a hard fault or reject spike.",
            },
        ],
        "strip_cards": [
            {
                "label": "Supervisor Focus",
                "title": "Quality and throughput",
                "body": "You are optimizing for stable cycle output, low defects, and predictable shift performance.",
            },
            {
                "label": "Immediate Question",
                "title": "Should the next batch continue unchanged?",
                "body": "Base that decision on quality score, defect trend, and current process stability.",
            },
            {
                "label": "Recommended Move",
                "title": "Act on trend, not noise",
                "body": "Small variation is expected; repeated compression-phase drift is what should drive intervention.",
            },
        ],
        "section_notes": {
            "telemetry": "Focus on the parts of the signal that explain quality variation during the active cycle.",
            "alerts": "Treat alerts as early warnings for quality loss, especially during compression and heater imbalance.",
            "batches": "Recent batches are your strongest evidence for whether the shift is remaining under control.",
            "maintenance": "Condition data helps explain whether mechanical wear is beginning to affect output quality.",
            "analytics": "Use SPC and forecast signals to decide whether to hold, adjust, or continue the run.",
        },
    },
    "maintenance": {
        "workspace_label": "Predictive Maintenance",
        "workspace_title": "Reliability Intervention Deck",
        "workspace_summary": (
            "Prioritize mechanical health, anomaly escalation, and maintenance timing before "
            "equipment degradation turns into downtime."
        ),
        "attention_title": "Maintenance Briefing",
        "attention_note": (
            "Vibration, alert severity, reliability score, and sequence continuity should tell you "
            "whether intervention can stay planned or needs to happen now."
        ),
        "priority_kpis": [
            "Vibration severity and bearing condition",
            "Reliability trend and anomaly score",
            "Maintenance window timing",
        ],
        "focus_tiles": [
            {
                "label": "Primary Decision",
                "value": "Prevent failure before downtime",
                "note": "Use vibration and reliability cues to decide whether the machine can stay online safely.",
            },
            {
                "label": "Operational Lens",
                "value": "Condition-based maintenance",
                "note": "Mechanical wear matters most when it aligns with alert spikes and instability.",
            },
            {
                "label": "Escalation Trigger",
                "value": "Rising wear signature",
                "note": "Repeated vibration anomalies indicate a stronger intervention case than one isolated spike.",
            },
        ],
        "action_queue": [
            {
                "title": "Validate bearing condition",
                "owner": "Maintenance priority",
                "body": "Compare live vibration against pump-bearing condition and anomaly score before deferring inspection.",
            },
            {
                "title": "Plan the service window",
                "owner": "Intervention timing",
                "body": "Use reliability and maintenance cards to decide whether service can wait for the planned window.",
            },
            {
                "title": "Preserve data integrity",
                "owner": "Diagnosis support",
                "body": "Keep sequence acknowledgments and broker continuity healthy so maintenance decisions are based on trustworthy signals.",
            },
        ],
        "strip_cards": [
            {
                "label": "Maintenance Focus",
                "title": "Reliability and wear signals",
                "body": "You are looking for early evidence that the machine is moving from stable operation into degradation.",
            },
            {
                "label": "Immediate Question",
                "title": "Can this machine safely stay online?",
                "body": "Judge that from vibration trend, component condition, and anomaly escalation rather than one reading alone.",
            },
            {
                "label": "Recommended Move",
                "title": "Intervene before compounding faults",
                "body": "A planned inspection is cheaper than waiting for wear to affect output and uptime together.",
            },
        ],
        "section_notes": {
            "telemetry": "Watch vibration most closely, but always interpret it alongside phase behavior and pressure load.",
            "alerts": "The alert feed helps separate routine variation from reliability-threatening events that need action.",
            "batches": "Production history shows whether mechanical degradation is already creating downstream quality losses.",
            "maintenance": "This is your primary action area for choosing inspection order and timing.",
            "analytics": "Reliability and anomaly indicators should drive maintenance timing and escalation confidence.",
        },
    },
}


def get_dashboard_view(user: dict | None) -> dict:
    if not user:
        return deepcopy(ROLE_DASHBOARD_VIEWS["admin"])

    return deepcopy(ROLE_DASHBOARD_VIEWS.get(user.get("key", ""), ROLE_DASHBOARD_VIEWS["admin"]))
