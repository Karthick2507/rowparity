"""snowflake_auth.py: key-pair auth is the only supported mechanism. These
tests cover everything that's actually verifiable without a live Snowflake
account -- private key loading (path vs. env content vs. per-case override,
with and without a passphrase) and connection-arg resolution/precedence.
No network access, no real account needed.
"""
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from rowparity.snowflake_auth import _load_private_key, resolve_connection_args
from rowparity.sources import SourceError


def _generate_pem(passphrase: str = None) -> bytes:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    encryption = (
        serialization.BestAvailableEncryption(passphrase.encode("utf-8"))
        if passphrase else serialization.NoEncryption()
    )
    return key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=encryption,
    )


def _expected_der(pem_bytes: bytes, passphrase: str = None) -> bytes:
    key = serialization.load_pem_private_key(
        pem_bytes, password=passphrase.encode("utf-8") if passphrase else None
    )
    return key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def test_load_private_key_from_explicit_path(tmp_path):
    pem = _generate_pem()
    key_path = tmp_path / "rsa_key.p8"
    key_path.write_bytes(pem)

    der = _load_private_key({"private_key_path": str(key_path)})
    assert der == _expected_der(pem)


def test_load_private_key_from_env_path(tmp_path, monkeypatch):
    pem = _generate_pem()
    key_path = tmp_path / "rsa_key.p8"
    key_path.write_bytes(pem)
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY_PATH", str(key_path))

    der = _load_private_key({})
    assert der == _expected_der(pem)


def test_load_private_key_from_env_content(monkeypatch):
    pem = _generate_pem()
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY", pem.decode("utf-8"))

    der = _load_private_key({})
    assert der == _expected_der(pem)


def test_load_private_key_with_passphrase(monkeypatch):
    pem = _generate_pem(passphrase="s3cret")
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY", pem.decode("utf-8"))
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "s3cret")

    der = _load_private_key({})
    assert der == _expected_der(pem, passphrase="s3cret")


def test_load_private_key_wrong_passphrase_raises(monkeypatch):
    pem = _generate_pem(passphrase="s3cret")
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY", pem.decode("utf-8"))
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "wrong")

    with pytest.raises(Exception, match="."):
        _load_private_key({})


def test_load_private_key_none_available_raises(monkeypatch):
    monkeypatch.delenv("SNOWFLAKE_PRIVATE_KEY_PATH", raising=False)
    monkeypatch.delenv("SNOWFLAKE_PRIVATE_KEY", raising=False)

    with pytest.raises(SourceError, match="private key"):
        _load_private_key({})


def test_load_private_key_explicit_path_pops_from_conn_args(tmp_path):
    pem = _generate_pem()
    key_path = tmp_path / "rsa_key.p8"
    key_path.write_bytes(pem)

    conn_args = {"private_key_path": str(key_path), "account": "acct"}
    _load_private_key(conn_args)
    assert "private_key_path" not in conn_args  # not a real snowflake.connector.connect() kwarg


def test_resolve_connection_args_no_password_field(tmp_path, monkeypatch):
    pem = _generate_pem()
    key_path = tmp_path / "rsa_key.p8"
    key_path.write_bytes(pem)
    monkeypatch.setenv("SNOWFLAKE_ACCOUNT", "myaccount")
    monkeypatch.setenv("SNOWFLAKE_USER", "myuser")
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY_PATH", str(key_path))
    monkeypatch.delenv("SNOWFLAKE_PASSWORD", raising=False)

    args = resolve_connection_args({})
    assert args["account"] == "myaccount"
    assert args["user"] == "myuser"
    assert "password" not in args
    assert args["private_key"] == _expected_der(pem)


def test_resolve_connection_args_per_case_override_wins_over_env(tmp_path, monkeypatch):
    pem = _generate_pem()
    key_path = tmp_path / "rsa_key.p8"
    key_path.write_bytes(pem)
    monkeypatch.setenv("SNOWFLAKE_ACCOUNT", "env_account")
    monkeypatch.setenv("SNOWFLAKE_PRIVATE_KEY_PATH", str(key_path))

    spec = {"connection": {"account": "case_account", "schema": "QA"}}
    args = resolve_connection_args(spec)
    assert args["account"] == "case_account"  # explicit connection: wins
    assert args["schema"] == "QA"
