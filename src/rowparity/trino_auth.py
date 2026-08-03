"""Shared Trino connection builder.

Credentials come from TRINO_* environment variables or per-case
``connection:`` overrides. Three auth methods are supported:

    No auth     — default when neither password nor JWT token is present
                  (suitable for open dev/test clusters)
    Basic auth  — TRINO_USER + TRINO_PASSWORD
    JWT auth    — TRINO_JWT_TOKEN (service-account token, e.g. from a
                  Trino cluster fronted by an OAuth2 proxy)

The private-key / certificate flow used by Snowflake has no Trino
equivalent here; Trino's preferred production auth is either JWT or
LDAP/basic depending on the cluster's configured authenticator.

Minimum required: TRINO_HOST (or ``connection: {host: ...}`` in the
case). Everything else has a default (port 8080, http, current OS user
as the Trino username) that can be overridden.
"""
from __future__ import annotations

import os
from typing import Any, Dict

from .sources import SourceError


def resolve_connection_args(spec: Dict[str, Any]) -> Dict[str, Any]:
    """Merge ``connection:`` overrides from the case with TRINO_* env vars.

    Keys present in the case's ``connection:`` block take precedence over
    the corresponding environment variable, matching the Snowflake auth
    module's behaviour.
    """
    conn_args = dict(spec.get("connection", {}) or {})
    env_map = {
        "host": "TRINO_HOST",
        "port": "TRINO_PORT",
        "user": "TRINO_USER",
        "catalog": "TRINO_CATALOG",
        "schema": "TRINO_SCHEMA",
        "http_scheme": "TRINO_HTTP_SCHEME",
    }
    for key, env in env_map.items():
        if key not in conn_args and os.environ.get(env):
            conn_args[key] = os.environ[env]

    if "port" in conn_args:
        conn_args["port"] = int(conn_args["port"])

    if not conn_args.get("host"):
        raise SourceError(
            "no Trino host found — set TRINO_HOST or "
            "'connection: {host: ...}' in the case YAML."
        )
    return conn_args


def connect(spec: Dict[str, Any]):
    """Return a live Trino DBAPI connection for the given source spec."""
    try:
        import trino
        import trino.auth
    except ImportError as e:  # pragma: no cover
        raise SourceError(
            "trino source needs `pip install rowparity[trino]`"
        ) from e

    conn_args = resolve_connection_args(spec)

    jwt_token = os.environ.get("TRINO_JWT_TOKEN")
    password = os.environ.get("TRINO_PASSWORD")

    if jwt_token:
        conn_args["auth"] = trino.auth.JWTAuthentication(jwt_token)
    elif password:
        user = conn_args.get("user") or os.environ.get("TRINO_USER", "rowparity")
        conn_args["auth"] = trino.auth.BasicAuthentication(user, password)

    return trino.dbapi.connect(**conn_args)
