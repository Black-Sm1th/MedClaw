#ifndef ED25519_LOCAL_H
#define ED25519_LOCAL_H

#include <cstdint>
#include <cstddef>

void ed25519_create_keypair(uint8_t public_key[32], uint8_t private_key[64]);

void ed25519_sign(uint8_t signature[64],
                  const uint8_t *message, size_t message_len,
                  const uint8_t private_key[64]);

#endif // ED25519_LOCAL_H
