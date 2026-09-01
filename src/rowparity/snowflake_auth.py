"""Shared Snowflake connection builder — key-pair authentication only.

Every Snowflake touchpoint (``sources.py``'s ``snowflake`` source,
schema-only describe, ``snowflake_pushdown.py``'s
push-down engine) connects through :func:`connect` so there is exactly one
Snowflake auth mechanism in the codebase, not one per call site. Password
auth is deliberately not supported anywhere — key-pair (RSA private key) is
Snowflake's own recommended approach for service/CI accounts, and it's the
only path here.

The private key is never accepted inline in a YAML case (it's secret
material, same reasoning as never inlining a password); it comes from either
a file path or the raw PEM content of an environment variable:

    SNOWFLAKE_PRIVATE_KEY_PATH          path to a PEM-encoded private key file
    SNOWFLAKE_PRIVATE_KEY               raw PEM text (e.g. a CI secret injected as an env var)
    SNOWFLAKE_PRIVATE_KEY_PASSPHRASE    optional, only if the key is encrypted

``connection.private_key_path`` in a case's YAML can override the path
per-case (still just a path, never key material itself).
"""

from __future__ import annotations

import os
from typing import Any, Dict

from .sources import SourceError


def _load_private_key(conn_args: Dict[str, Any]) -> bytes:
    try:
        from cryptography.hazmat.primitives import serialization
    except ImportError as e:  # pragma: no cover
        raise SourceError(
            "key-pair auth needs the `cryptography` package (installed automatically "
            "with `pip install rowparity[snowflake]`)"
        ) from e

    path = conn_args.pop("private_key_path", None) or os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH")
    content = os.environ.get("SNOWFLAKE_PRIVATE_KEY")
    if path:
        with open(path, "rb") as fh:
            pem_bytes = fh.read()
    elif content:
        pem_bytes = content.encode("utf-8")
    else:
        raise SourceError(
            "no Snowflake private key found — set SNOWFLAKE_PRIVATE_KEY_PATH (a file path), "
            "SNOWFLAKE_PRIVATE_KEY (raw PEM text), or 'connection: {private_key_path: ...}' "
            "in the case. Password auth is not supported."
        )

    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE")
    key = serialization.load_pem_private_key(
        pem_bytes,
        password=passphrase.encode("utf-8") if passphrase else None,
    )
    return key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def resolve_connection_args(spec: Dict[str, Any]) -> Dict[str, Any]:
    """``connection:`` overrides in the case, filled in from SNOWFLAKE_* env
    vars, plus the key-pair private key. No 'password' field is ever set."""
    conn_args = dict(spec.get("connection", {}))
    env_map = {
        "account": "SNOWFLAKE_ACCOUNT",
        "user": "SNOWFLAKE_USER",
        "role": "SNOWFLAKE_ROLE",
        "warehouse": "SNOWFLAKE_WAREHOUSE",
        "database": "SNOWFLAKE_DATABASE",
        "schema": "SNOWFLAKE_SCHEMA",
    }
    for key, env in env_map.items():
        if key not in conn_args and os.environ.get(env):
            conn_args[key] = os.environ[env]
    conn_args["private_key"] = _load_private_key(conn_args)
    return conn_args


def connect(spec: Dict[str, Any]):
    try:
        import snowflake.connector as sf
    except ImportError as e:  # pragma: no cover
        raise SourceError("snowflake source needs `pip install rowparity[snowflake]`") from e
    return sf.connect(**resolve_connection_args(spec))
