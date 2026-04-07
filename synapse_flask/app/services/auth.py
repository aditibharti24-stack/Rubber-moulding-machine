from __future__ import annotations

from functools import wraps

from flask import redirect, session, url_for

from .users import get_user_by_key


def get_current_user() -> dict | None:
    user_key = session.get("user_key")
    if not user_key:
        return None
    return get_user_by_key(user_key)


def login_required(view_func):
    @wraps(view_func)
    def wrapped_view(*args, **kwargs):
        if get_current_user() is None:
            return redirect(url_for("main.login"))
        return view_func(*args, **kwargs)

    return wrapped_view
