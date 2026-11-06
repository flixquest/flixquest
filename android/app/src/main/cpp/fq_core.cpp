// Mixes a compiled-in secret into the scraper key. Dart only ever sees the HMAC
// output, so the secret itself never leaves this library.
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#ifndef FQ_NATIVE_SECRET
#error "FQ_NATIVE_SECRET is not defined"
#endif

namespace {

#define FQ_STRINGIFY_INNER(value) #value
#define FQ_STRINGIFY(value) FQ_STRINGIFY_INNER(value)

constexpr size_t kSecretBytes = 32;
constexpr size_t kBlockBytes = 64;
constexpr size_t kDigestBytes = 32;

constexpr uint8_t HexValue(char c) {
  return static_cast<uint8_t>(c <= '9' ? c - '0' : c - 'a' + 10);
}

// Differs per build and per position, so the secret's bytes do not appear
// together in the binary.
constexpr uint8_t MaskAt(size_t index) {
  const char* time = __TIME__;
  uint32_t state = 0x9E3779B9u + static_cast<uint32_t>(index) * 0x85EBCA6Bu;
  for (size_t i = 0; i < 8; ++i) {
    state = (state ^ static_cast<uint8_t>(time[i])) * 0x01000193u;
    state ^= state >> 13;
  }
  return static_cast<uint8_t>(state >> 16);
}

struct MaskedSecret {
  uint8_t bytes[kSecretBytes];
};

constexpr MaskedSecret MaskSecret(const char* hex) {
  MaskedSecret masked{};
  for (size_t i = 0; i < kSecretBytes; ++i) {
    const uint8_t value = static_cast<uint8_t>(HexValue(hex[1 + i * 2]) << 4 |
                                               HexValue(hex[2 + i * 2]));
    masked.bytes[i] = value ^ MaskAt(i);
  }
  return masked;
}

// constexpr forces this at compile time. Only the masked bytes reach .rodata.
constexpr MaskedSecret kMaskedSecret = MaskSecret(FQ_STRINGIFY(FQ_NATIVE_SECRET));

void Wipe(void* data, size_t length) {
  volatile uint8_t* bytes = static_cast<volatile uint8_t*>(data);
  while (length-- > 0) *bytes++ = 0;
}

constexpr uint32_t kRoundConstants[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

inline uint32_t RotateRight(uint32_t value, int bits) {
  return (value >> bits) | (value << (32 - bits));
}

class Sha256 {
 public:
  void Update(const uint8_t* data, size_t length) {
    total_bytes_ += length;
    while (length > 0) {
      const size_t room = kBlockBytes - buffered_;
      const size_t take = length < room ? length : room;
      memcpy(buffer_ + buffered_, data, take);
      buffered_ += take;
      data += take;
      length -= take;
      if (buffered_ == kBlockBytes) {
        Compress();
        buffered_ = 0;
      }
    }
  }

  void Finish(uint8_t* digest) {
    const uint64_t total_bits = total_bytes_ * 8;
    const uint8_t marker = 0x80;
    const uint8_t zero = 0;
    Update(&marker, 1);
    while (buffered_ != kBlockBytes - 8) Update(&zero, 1);
    uint8_t length_bytes[8];
    for (int i = 0; i < 8; ++i) {
      length_bytes[i] = static_cast<uint8_t>(total_bits >> (56 - i * 8));
    }
    Update(length_bytes, 8);
    for (int i = 0; i < 8; ++i) {
      for (int j = 0; j < 4; ++j) {
        digest[i * 4 + j] = static_cast<uint8_t>(state_[i] >> (24 - j * 8));
      }
    }
    Wipe(buffer_, sizeof(buffer_));
    Wipe(state_, sizeof(state_));
  }

 private:
  void Compress() {
    uint32_t w[64];
    for (int i = 0; i < 16; ++i) {
      w[i] = static_cast<uint32_t>(buffer_[i * 4]) << 24 |
             static_cast<uint32_t>(buffer_[i * 4 + 1]) << 16 |
             static_cast<uint32_t>(buffer_[i * 4 + 2]) << 8 |
             static_cast<uint32_t>(buffer_[i * 4 + 3]);
    }
    for (int i = 16; i < 64; ++i) {
      const uint32_t s0 = RotateRight(w[i - 15], 7) ^
                          RotateRight(w[i - 15], 18) ^ (w[i - 15] >> 3);
      const uint32_t s1 = RotateRight(w[i - 2], 17) ^
                          RotateRight(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    uint32_t a = state_[0], b = state_[1], c = state_[2], d = state_[3];
    uint32_t e = state_[4], f = state_[5], g = state_[6], h = state_[7];
    for (int i = 0; i < 64; ++i) {
      const uint32_t s1 =
          RotateRight(e, 6) ^ RotateRight(e, 11) ^ RotateRight(e, 25);
      const uint32_t choose = (e & f) ^ (~e & g);
      const uint32_t temp1 = h + s1 + choose + kRoundConstants[i] + w[i];
      const uint32_t s0 =
          RotateRight(a, 2) ^ RotateRight(a, 13) ^ RotateRight(a, 22);
      const uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
      const uint32_t temp2 = s0 + majority;
      h = g;
      g = f;
      f = e;
      e = d + temp1;
      d = c;
      c = b;
      b = a;
      a = temp1 + temp2;
    }
    state_[0] += a;
    state_[1] += b;
    state_[2] += c;
    state_[3] += d;
    state_[4] += e;
    state_[5] += f;
    state_[6] += g;
    state_[7] += h;
    Wipe(w, sizeof(w));
  }

  uint32_t state_[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
  uint8_t buffer_[kBlockBytes] = {};
  size_t buffered_ = 0;
  uint64_t total_bytes_ = 0;
};

}  // namespace

// HMAC-SHA256(secret, input). Returns 0 on success.
extern "C" __attribute__((visibility("default"))) int32_t fqc_h(
    const uint8_t* input, intptr_t input_length, uint8_t* output) {
  if (input == nullptr || output == nullptr || input_length < 0) return 1;

  uint8_t inner_pad[kBlockBytes];
  uint8_t outer_pad[kBlockBytes];
  memset(inner_pad, 0x36, kBlockBytes);
  memset(outer_pad, 0x5c, kBlockBytes);
  // Without this the compiler sees both constants, folds them together, and
  // stores the plain secret in the binary.
  const uint8_t* masked = kMaskedSecret.bytes;
  __asm__ volatile("" : "+r"(masked));
  for (size_t i = 0; i < kSecretBytes; ++i) {
    const uint8_t byte = masked[i] ^ MaskAt(i);
    inner_pad[i] ^= byte;
    outer_pad[i] ^= byte;
  }

  uint8_t inner_digest[kDigestBytes];
  Sha256 inner;
  inner.Update(inner_pad, kBlockBytes);
  inner.Update(input, static_cast<size_t>(input_length));
  inner.Finish(inner_digest);

  Sha256 outer;
  outer.Update(outer_pad, kBlockBytes);
  outer.Update(inner_digest, kDigestBytes);
  outer.Finish(output);

  Wipe(inner_pad, kBlockBytes);
  Wipe(outer_pad, kBlockBytes);
  Wipe(inner_digest, kDigestBytes);
  return 0;
}
