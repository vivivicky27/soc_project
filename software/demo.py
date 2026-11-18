"""Software-only ML-KEM -> HKDF -> AES-GCM course demonstration."""

import argparse
import hmac
import json
import os

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

from mlkem_adapter import PARAMETERS, make_mlkem
from ntt import SoftwareButterfly

AAD = b"ECE9433/target_pro/software-demo/v1"


def derive_key(shared_secret, salt):
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=salt,
                info=AAD).derive(shared_secret)


def run_demo(message=b"Hello from the NTT butterfly project!", parameter=768):
    if not isinstance(message, bytes):
        raise TypeError("message must be bytes")
    backend = SoftwareButterfly()
    kem = make_mlkem(parameter, backend=backend)

    # Receiver generates its keypair; sender encapsulates using the public key.
    ek, dk = kem.keygen()
    sender_secret, kem_ciphertext = kem.encaps(ek)
    receiver_secret = kem.decaps(dk, kem_ciphertext)
    if not hmac.compare_digest(sender_secret, receiver_secret):
        raise RuntimeError("ML-KEM shared secrets differ")

    # Salt and nonce are public; fresh randomness is used on every demo run.
    salt, nonce = os.urandom(32), os.urandom(12)
    sender_key = derive_key(sender_secret, salt)
    receiver_key = derive_key(receiver_secret, salt)
    ciphertext = AESGCM(sender_key).encrypt(nonce, message, AAD)
    recovered = AESGCM(receiver_key).decrypt(nonce, ciphertext, AAD)
    if recovered != message:
        raise RuntimeError("Recovered plaintext differs")

    # The last 16 bytes are the AES-GCM authentication tag.
    tampered = ciphertext[:-1] + bytes([ciphertext[-1] ^ 1])
    try:
        AESGCM(receiver_key).decrypt(nonce, tampered, AAD)
    except InvalidTag:
        pass
    else:
        raise RuntimeError("Tampered authentication tag was accepted")

    # Do not print or persist private keys, shared secrets, or AES keys.
    return {
        "mode": "software-only",
        "algorithm": f"ML-KEM-{parameter} + HKDF-SHA256 + AES-256-GCM",
        "shared_secret_match": True,
        "plaintext_match": True,
        "tampered_tag_rejected": True,
        "public_key_bytes": len(ek),
        "kem_ciphertext_bytes": len(kem_ciphertext),
        "message_bytes": len(message),
        "aes_ciphertext_and_tag_bytes": len(ciphertext),
        "forward_ntt_calls": backend.calls // 896,
        "butterfly_calls": backend.calls,
        "recovered_message": recovered.decode("utf-8", errors="replace"),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parameter", type=int, choices=PARAMETERS, default=768)
    parser.add_argument("--message", default="你好，NTT butterfly！")
    args = parser.parse_args()
    print(json.dumps(run_demo(args.message.encode("utf-8"), args.parameter),
                     indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
