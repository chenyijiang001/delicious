import pytest
from app.services.auth_service import hash_password, verify_password, create_access_token, decode_token


class TestAuthService:
    def test_hash_and_verify_password(self):
        pw = "mysecret123"
        hashed = hash_password(pw)
        assert hashed != pw
        assert verify_password(pw, hashed) is True
        assert verify_password("wrong", hashed) is False

    def test_jwt_token(self):
        token = create_access_token({"sub": "test-user-id"})
        payload = decode_token(token)
        assert payload is not None
        assert payload["sub"] == "test-user-id"

    def test_decode_invalid_token(self):
        assert decode_token("invalid.token.here") is None
