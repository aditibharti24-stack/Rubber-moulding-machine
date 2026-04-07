from __future__ import annotations

from copy import deepcopy


DEMO_USERS = {
    "admin": {
        "key": "admin",
        "email": "admin@synapse.local",
        "password": "Admin@123",
        "name": "Aditi Verma",
        "role": "Plant Administrator",
        "department": "Operations and Digital Systems",
        "focus": "Oversee machine availability, energy performance, and access control.",
    },
    "supervisor": {
        "key": "supervisor",
        "email": "supervisor@synapse.local",
        "password": "Supervisor@123",
        "name": "Rahul Singh",
        "role": "Production Supervisor",
        "department": "Molding Line Control",
        "focus": "Track cycle quality, batch output, and shift-level process stability.",
    },
    "maintenance": {
        "key": "maintenance",
        "email": "maintenance@synapse.local",
        "password": "Maintenance@123",
        "name": "Meera Joshi",
        "role": "Maintenance Engineer",
        "department": "Predictive Maintenance",
        "focus": "Monitor vibration, alerts, and maintenance due windows for intervention.",
    },
}


def get_demo_users() -> list[dict]:
    return [deepcopy(user) for user in DEMO_USERS.values()]


def get_user_by_key(user_key: str) -> dict | None:
    user = DEMO_USERS.get(user_key)
    return deepcopy(user) if user else None


def authenticate_user(email: str, password: str) -> dict | None:
    normalized_email = email.strip().lower()
    for user in DEMO_USERS.values():
        if user["email"].lower() == normalized_email and user["password"] == password:
            return deepcopy(user)
    return None
