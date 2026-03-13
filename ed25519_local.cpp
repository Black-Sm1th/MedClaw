// Pure C++ Ed25519 digital signatures.
// Core arithmetic derived from TweetNaCl (public domain, D.J. Bernstein et al.).
// SHA-512 provided by Qt's QCryptographicHash.

#include "ed25519_local.h"
#include <QCryptographicHash>
#include <QByteArray>
#include <QRandomGenerator>
#include <cstring>

namespace {

typedef int64_t i64;
typedef i64 gf[16];

static const gf
    gf0 = {0},
    gf1 = {1},
    D2  = {0xf159,0x26b2,0x9b94,0xebd6,0xb156,0x8283,0x149a,0x00e0,
            0xd130,0xeef3,0x80f2,0x198e,0xfce7,0x56df,0xd9dc,0x2406},
    X   = {0xd51a,0x8f25,0x2d60,0xc956,0xa7b2,0x9525,0xc760,0x692c,
            0xdc5c,0xfdd6,0xe231,0xc0a4,0x53fe,0xcd6e,0x36d3,0x2169},
    Y   = {0x6658,0x6666,0x6666,0x6666,0x6666,0x6666,0x6666,0x6666,
            0x6666,0x6666,0x6666,0x6666,0x6666,0x6666,0x6666,0x6666};

static const uint8_t L_[32] = {
    0xed,0xd3,0xf5,0x5c,0x1a,0x63,0x12,0x58,
    0xd6,0x9c,0xf7,0xa2,0xde,0xf9,0xde,0x14,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0x10
};

// ── SHA-512 via Qt ──────────────────────────────────────────────────────

static void sha512(uint8_t out[64], const uint8_t *m, int n)
{
    QByteArray h = QCryptographicHash::hash(
        QByteArray::fromRawData(reinterpret_cast<const char *>(m), n),
        QCryptographicHash::Sha512);
    memcpy(out, h.constData(), 64);
}

// ── Field arithmetic in GF(2^255-19), radix 2^16 ───────────────────────

static void set25519(gf r, const gf a)
{
    for (int i = 0; i < 16; i++) r[i] = a[i];
}

static void car25519(gf o)
{
    i64 c;
    for (int i = 0; i < 16; i++) {
        o[i] += (1LL << 16);
        c = o[i] >> 16;
        o[(i + 1) * (i < 15)] += c - 1 + 37 * (c - 1) * (i == 15);
        o[i] -= c << 16;
    }
}

static void sel25519(gf p, gf q, int b)
{
    i64 t, c = ~(i64)(b - 1);
    for (int i = 0; i < 16; i++) {
        t = c & (p[i] ^ q[i]);
        p[i] ^= t;
        q[i] ^= t;
    }
}

static void pack25519(uint8_t o[32], const gf n)
{
    int i, j;
    gf m, t;
    set25519(t, n);
    car25519(t);
    car25519(t);
    car25519(t);
    for (j = 0; j < 2; j++) {
        m[0] = t[0] - 0xffed;
        for (i = 1; i < 15; i++) {
            m[i] = t[i] - 0xffff - ((m[i - 1] >> 16) & 1);
            m[i - 1] &= 0xffff;
        }
        m[15] = t[15] - 0x7fff - ((m[14] >> 16) & 1);
        i64 b = (m[15] >> 16) & 1;
        m[14] &= 0xffff;
        sel25519(t, m, 1 - static_cast<int>(b));
    }
    for (i = 0; i < 16; i++) {
        o[2 * i]     = static_cast<uint8_t>(t[i] & 0xff);
        o[2 * i + 1] = static_cast<uint8_t>(t[i] >> 8);
    }
}

static void A(gf o, const gf a, const gf b)
{
    for (int i = 0; i < 16; i++) o[i] = a[i] + b[i];
}

static void Z(gf o, const gf a, const gf b)
{
    for (int i = 0; i < 16; i++) o[i] = a[i] - b[i];
}

static void M(gf o, const gf a, const gf b)
{
    i64 t[31];
    for (int i = 0; i < 31; i++) t[i] = 0;
    for (int i = 0; i < 16; i++)
        for (int j = 0; j < 16; j++)
            t[i + j] += a[i] * b[j];
    for (int i = 0; i < 15; i++)
        t[i] += 38 * t[i + 16];
    for (int i = 0; i < 16; i++) o[i] = t[i];
    car25519(o);
    car25519(o);
}

static void S(gf o, const gf a) { M(o, a, a); }

static void inv25519(gf o, const gf a)
{
    gf c;
    set25519(c, a);
    for (int i = 253; i >= 0; i--) {
        S(c, c);
        if (i != 2 && i != 4) M(c, c, a);
    }
    set25519(o, c);
}

static uint8_t par25519(const gf a)
{
    uint8_t d[32];
    pack25519(d, a);
    return d[0] & 1;
}

// ── Group operations (extended coordinates: X, Y, Z, T) ────────────────

static void pack_point(uint8_t r[32], gf p[4])
{
    gf tx, ty, zi;
    inv25519(zi, p[2]);
    M(tx, p[0], zi);
    M(ty, p[1], zi);
    pack25519(r, ty);
    r[31] ^= par25519(tx) << 7;
}

static void add_points(gf p[4], gf q[4])
{
    gf a, b, c, d, t, e, f, g, h;
    Z(a, p[1], p[0]);
    Z(t, q[1], q[0]);
    M(a, a, t);
    A(b, p[0], p[1]);
    A(t, q[0], q[1]);
    M(b, b, t);
    M(c, p[3], q[3]);
    M(c, c, D2);
    M(d, p[2], q[2]);
    A(d, d, d);
    Z(e, b, a);
    Z(f, d, c);
    A(g, d, c);
    A(h, b, a);
    M(p[0], e, f);
    M(p[1], h, g);
    M(p[2], g, f);
    M(p[3], e, h);
}

static void cswap_points(gf p[4], gf q[4], uint8_t b)
{
    for (int i = 0; i < 4; i++)
        sel25519(p[i], q[i], b);
}

static void scalarmult(gf p[4], gf q[4], const uint8_t *s)
{
    set25519(p[0], gf0);
    set25519(p[1], gf1);
    set25519(p[2], gf1);
    set25519(p[3], gf0);
    for (int i = 255; i >= 0; --i) {
        uint8_t b = (s[i / 8] >> (i & 7)) & 1;
        cswap_points(p, q, b);
        add_points(q, p);
        add_points(p, p);
        cswap_points(p, q, b);
    }
}

static void scalarbase(gf p[4], const uint8_t *s)
{
    gf q[4];
    set25519(q[0], X);
    set25519(q[1], Y);
    set25519(q[2], gf1);
    M(q[3], X, Y);
    scalarmult(p, q, s);
}

// ── Scalar reduction modulo L (group order) ─────────────────────────────

static void modL(uint8_t *r, i64 x[64])
{
    i64 carry;
    int i, j;
    for (i = 63; i >= 32; --i) {
        carry = 0;
        for (j = i - 32; j < i - 12; ++j) {
            x[j] += carry - 16 * x[i] * static_cast<i64>(L_[j - (i - 32)]);
            carry = (x[j] + 128) >> 8;
            x[j] -= carry << 8;
        }
        x[j] += carry;
        x[i] = 0;
    }
    carry = 0;
    for (j = 0; j < 32; j++) {
        x[j] += carry - (x[31] >> 4) * static_cast<i64>(L_[j]);
        carry = x[j] >> 8;
        x[j] &= 255;
    }
    for (j = 0; j < 32; j++) x[j] -= carry * static_cast<i64>(L_[j]);
    for (i = 0; i < 32; i++) r[i] = static_cast<uint8_t>(x[i]);
}

static void reduce(uint8_t r[64])
{
    i64 x[64];
    for (int i = 0; i < 64; i++) x[i] = static_cast<i64>(r[i]);
    memset(r, 0, 64);
    modL(r, x);
}

} // anonymous namespace

// ═══════════════════════════════════════════════════════════════════════
//  Public API
// ═══════════════════════════════════════════════════════════════════════

void ed25519_create_keypair(uint8_t pk[32], uint8_t sk[64])
{
    for (int i = 0; i < 8; i++) {
        quint32 r = QRandomGenerator::global()->generate();
        memcpy(sk + i * 4, &r, 4);
    }

    uint8_t d[64];
    sha512(d, sk, 32);
    d[0]  &= 248;
    d[31] &= 127;
    d[31] |= 64;

    gf p[4];
    scalarbase(p, d);
    pack_point(pk, p);

    memcpy(sk + 32, pk, 32);
}

void ed25519_sign(uint8_t sig[64],
                  const uint8_t *msg, size_t mlen,
                  const uint8_t sk[64])
{
    uint8_t d[64], nonce[64], hram[64];
    i64 x[64];

    sha512(d, sk, 32);
    d[0]  &= 248;
    d[31] &= 127;
    d[31] |= 64;

    // r = H(d[32..63] || msg) mod L
    {
        QCryptographicHash h(QCryptographicHash::Sha512);
        h.addData(reinterpret_cast<const char *>(d + 32), 32);
        h.addData(reinterpret_cast<const char *>(msg), static_cast<int>(mlen));
        QByteArray res = h.result();
        memcpy(nonce, res.constData(), 64);
    }
    reduce(nonce);

    // R = r * B
    gf p[4];
    scalarbase(p, nonce);
    pack_point(sig, p);  // sig[0..31] = encode(R)

    // hram = H(R || pk || msg) mod L
    {
        QCryptographicHash h(QCryptographicHash::Sha512);
        h.addData(reinterpret_cast<const char *>(sig), 32);
        h.addData(reinterpret_cast<const char *>(sk + 32), 32);
        h.addData(reinterpret_cast<const char *>(msg), static_cast<int>(mlen));
        QByteArray res = h.result();
        memcpy(hram, res.constData(), 64);
    }
    reduce(hram);

    // S = (r + hram * a) mod L
    for (int i = 0; i < 64; i++) x[i] = 0;
    for (int i = 0; i < 32; i++) x[i] = static_cast<i64>(nonce[i]);
    for (int i = 0; i < 32; i++)
        for (int j = 0; j < 32; j++)
            x[i + j] += static_cast<i64>(hram[i]) * static_cast<i64>(d[j]);
    modL(sig + 32, x);  // sig[32..63] = S
}
