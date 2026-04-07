from flask import Blueprint, flash, jsonify, redirect, render_template, request, session, url_for

from .services.auth import get_current_user, login_required
from .services.dashboard_data import build_dashboard_payload
from .services.dashboard_roles import get_dashboard_view
from .services.users import authenticate_user, get_demo_users, get_user_by_key

main_bp = Blueprint("main", __name__)


@main_bp.get("/")
def index():
    if get_current_user() is not None:
        return redirect(url_for("main.dashboard"))
    return redirect(url_for("main.login"))


@main_bp.route("/login", methods=["GET", "POST"])
def login():
    if get_current_user() is not None:
        return redirect(url_for("main.dashboard"))

    if request.method == "POST":
        user = authenticate_user(
            request.form.get("email", ""),
            request.form.get("password", ""),
        )
        if user is None:
            flash("Invalid credentials. Use one of the three demo accounts below.", "error")
        else:
            session["user_key"] = user["key"]
            return redirect(url_for("main.dashboard"))

    return render_template("login.html", demo_users=get_demo_users())


@main_bp.post("/demo-login/<user_key>")
def demo_login(user_key: str):
    user = get_user_by_key(user_key)
    if user is None:
        flash("That demo account was not found.", "error")
        return redirect(url_for("main.login"))

    session["user_key"] = user["key"]
    return redirect(url_for("main.dashboard"))


@main_bp.get("/logout")
def logout():
    session.clear()
    return redirect(url_for("main.login"))


@main_bp.get("/dashboard")
@login_required
def dashboard():
    payload = build_dashboard_payload()
    current_user = get_current_user()
    dashboard_view = get_dashboard_view(current_user)
    return render_template(
        "dashboard_v2.html",
        seed_data=payload,
        current_user=current_user,
        dashboard_view=dashboard_view,
    )


@main_bp.get("/health")
def health():
    payload = build_dashboard_payload()
    return jsonify(
        {
            "status": "ok",
            "service": "synapse-2026-dashboard",
            "machine_id": payload["machine"]["id"],
            "telemetry_points": len(payload["telemetry"]),
        }
    )


@main_bp.get("/api/dashboard")
@login_required
def dashboard_payload():
    return jsonify(build_dashboard_payload())


@main_bp.get("/api/telemetry")
@login_required
def telemetry_payload():
    payload = build_dashboard_payload()
    limit = request.args.get("limit", default=48, type=int)
    limit = max(1, min(limit, len(payload["telemetry"])))
    return jsonify(
        {
            "telemetry": payload["telemetry"][-limit:],
            "count": limit,
        }
    )


@main_bp.get("/api/alerts")
@login_required
def alerts_payload():
    payload = build_dashboard_payload()
    return jsonify(
        {
            "alerts": payload["alerts"],
            "count": len(payload["alerts"]),
        }
    )


@main_bp.get("/api/batches")
@login_required
def batches_payload():
    payload = build_dashboard_payload()
    return jsonify(
        {
            "batches": payload["batches"],
            "count": len(payload["batches"]),
        }
    )


@main_bp.get("/api/maintenance")
@login_required
def maintenance_payload():
    payload = build_dashboard_payload()
    return jsonify(
        {
            "maintenance": payload["maintenance"],
            "count": len(payload["maintenance"]),
        }
    )
