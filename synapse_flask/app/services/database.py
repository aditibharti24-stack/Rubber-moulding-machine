from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator

import psycopg
from flask import current_app
from psycopg.rows import dict_row


def get_database_url(app=None) -> str:
    if app is not None:
        return app.config["DATABASE_URL"]
    return current_app.config["DATABASE_URL"]


@contextmanager
def db_connection(app=None) -> Iterator[psycopg.Connection]:
    connection = psycopg.connect(
        get_database_url(app),
        autocommit=True,
        row_factory=dict_row,
    )
    try:
        yield connection
    finally:
        connection.close()


def database_available(app=None) -> bool:
    try:
        with db_connection(app) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        return True
    except Exception:
        return False
