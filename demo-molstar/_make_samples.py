# One-off sample builder for Mol* format smoke tests.
from __future__ import annotations
import gzip
import math
import shutil
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def write_gzip(src: Path, dest: Path) -> None:
    dest.write_bytes(gzip.compress(src.read_bytes(), compresslevel=9))


def mp_uint(n: int) -> bytes:
    if n < 128:
        return bytes([n])
    if n < 256:
        return b"\xcc" + bytes([n])
    if n < 65536:
        return b"\xcd" + struct.pack(">H", n)
    return b"\xce" + struct.pack(">I", n)


def mp_int(n: int) -> bytes:
    if 0 <= n < 128:
        return bytes([n])
    if -32 <= n < 0:
        return struct.pack("b", n)
    if -128 <= n < 256:
        return b"\xd0" + struct.pack("b", n)
    if -32768 <= n < 32768:
        return b"\xd1" + struct.pack(">h", n)
    return b"\xd2" + struct.pack(">i", n)


def mp_str(s: str) -> bytes:
    b = s.encode("utf-8")
    n = len(b)
    if n < 32:
        return bytes([0xA0 | n]) + b
    if n < 256:
        return b"\xd9" + bytes([n]) + b
    return b"\xda" + struct.pack(">H", n) + b


def mp_bin(b: bytes) -> bytes:
    n = len(b)
    if n < 256:
        return b"\xc4" + bytes([n]) + b
    if n < 65536:
        return b"\xc5" + struct.pack(">H", n) + b
    return b"\xc6" + struct.pack(">I", n) + b


def mp_array(items: list[bytes]) -> bytes:
    n = len(items)
    if n < 16:
        head = bytes([0x90 | n])
    elif n < 65536:
        head = b"\xdc" + struct.pack(">H", n)
    else:
        head = b"\xdd" + struct.pack(">I", n)
    return head + b"".join(items)


def mp_map(pairs: list[tuple[str, bytes]]) -> bytes:
    n = len(pairs)
    if n < 16:
        head = bytes([0x80 | n])
    elif n < 65536:
        head = b"\xde" + struct.pack(">H", n)
    else:
        head = b"\xdf" + struct.pack(">I", n)
    return head + b"".join(mp_str(k) + v for k, v in pairs)


def encode_int32s(values: list[int]) -> bytes:
    payload = b"".join(struct.pack(">i", v) for v in values)
    return struct.pack(">iii", 2, len(values), 0) + payload


def encode_int8s(values: list[int]) -> bytes:
    payload = b"".join(struct.pack("b", v) for v in values)
    return struct.pack(">iii", 5, len(values), 0) + payload


def encode_coords(values: list[float], divisor: int = 1000) -> bytes:
    ints = [int(round(v * divisor)) for v in values]
    deltas = []
    prev = 0
    for x in ints:
        deltas.append(x - prev)
        prev = x
    payload = b"".join(struct.pack(">h", d) for d in deltas)
    return struct.pack(">iii", 10, len(values), divisor) + payload


def encode_fourcc(labels: list[str]) -> bytes:
    raw = b"".join(s.encode("ascii")[:4].ljust(4, b" ") for s in labels)
    return struct.pack(">iii", 5, len(raw), 0) + raw


def build_mmtf() -> bytes:
    """Single GLY CA atom. Enough for Mol* to accept the MMTF magic/fields."""
    group = mp_map([
        ("groupName", mp_str("GLY")),
        ("chemCompType", mp_str("L-PEPTIDE LINKING")),
        ("singleLetterCode", mp_str("G")),
        ("formalChargeList", mp_array([mp_int(0)])),
        ("atomNameList", mp_array([mp_str("CA")])),
        ("elementList", mp_array([mp_str("C")])),
        ("bondAtomList", mp_array([])),
        ("bondOrderList", mp_array([])),
    ])
    return mp_map([
        ("mmtfVersion", mp_str("1.0.0")),
        ("mmtfProducer", mp_str("MedClaw demo-molstar")),
        ("numBonds", mp_uint(0)),
        ("numAtoms", mp_uint(1)),
        ("numGroups", mp_uint(1)),
        ("numChains", mp_uint(1)),
        ("numModels", mp_uint(1)),
        ("groupList", mp_array([group])),
        ("groupTypeList", mp_bin(encode_int32s([0]))),
        ("groupIdList", mp_bin(encode_int32s([1]))),
        ("groupsPerChain", mp_array([mp_uint(1)])),
        ("chainsPerModel", mp_array([mp_uint(1)])),
        ("chainIdList", mp_bin(encode_fourcc(["A"]))),
        ("chainNameList", mp_bin(encode_fourcc(["A"]))),
        ("xCoordList", mp_bin(encode_coords([0.0]))),
        ("yCoordList", mp_bin(encode_coords([0.0]))),
        ("zCoordList", mp_bin(encode_coords([0.0]))),
        ("bFactorList", mp_bin(encode_coords([20.0]))),
        ("occupancyList", mp_bin(encode_coords([1.0]))),
        ("atomIdList", mp_bin(encode_int32s([1]))),
        ("secStructList", mp_bin(encode_int8s([7]))),
    ])


def write_mrc(path: Path, n: int = 24) -> None:
    """Tiny CCP4/MRC mode-2 map: a Gaussian blob in a 24^3 box."""
    nx = ny = nz = n
    data = []
    cx = cy = cz = (n - 1) / 2.0
    sigma = n / 6.0
    for z in range(nz):
        for y in range(ny):
            for x in range(nx):
                r2 = (x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2
                data.append(math.exp(-r2 / (2 * sigma * sigma)))
    vmin, vmax = min(data), max(data)
    vmean = sum(data) / len(data)
    rms = math.sqrt(sum((v - vmean) ** 2 for v in data) / len(data))
    cell = float(n)  # 1 A per voxel
    header = bytearray(1024)
    def put_i(off, val):
        struct.pack_into("<i", header, off, val)
    def put_f(off, val):
        struct.pack_into("<f", header, off, val)
    put_i(0, nx); put_i(4, ny); put_i(8, nz)
    put_i(12, 2)  # mode 2 = float32
    put_i(16, 0); put_i(20, 0); put_i(24, 0)
    put_i(28, nx); put_i(32, ny); put_i(36, nz)
    put_f(40, cell); put_f(44, cell); put_f(48, cell)
    put_f(52, 90.0); put_f(56, 90.0); put_f(60, 90.0)
    put_i(64, 1); put_i(68, 2); put_i(72, 3)
    put_f(76, vmin); put_f(80, vmax); put_f(84, vmean)
    put_i(88, 1)  # space group P1
    put_i(92, 0)  # extra bytes
    header[208:212] = b"MAP "
    header[212:216] = b"\x44\x41\x00\x00"  # little-endian MACHST
    put_f(216, rms)
    put_i(220, 1)
    label = b"MedClaw demo Gaussian blob"
    header[224:224 + len(label)] = label
    body = b"".join(struct.pack("<f", v) for v in data)
    path.write_bytes(header + body)


def sdf_to_xyz(sdf: str) -> str:
    lines = sdf.splitlines()
    counts = lines[3]
    natoms = int(counts[:3])
    atoms = []
    for i in range(natoms):
        line = lines[4 + i]
        x, y, z = float(line[0:10]), float(line[10:20]), float(line[20:30])
        el = line[31:34].strip()
        atoms.append((el, x, y, z))
    out = [str(len(atoms)), "caffeine from CFF_ideal.sdf"]
    for el, x, y, z in atoms:
        out.append(f"{el:2s} {x:12.6f} {y:12.6f} {z:12.6f}")
    return "\n".join(out) + "\n"


def sdf_to_mol2(sdf: str) -> str:
    lines = sdf.splitlines()
    counts = lines[3]
    natoms = int(counts[:3])
    nbonds = int(counts[3:6])
    atoms = []
    for i in range(natoms):
        line = lines[4 + i]
        x, y, z = float(line[0:10]), float(line[10:20]), float(line[20:30])
        el = line[31:34].strip()
        atoms.append((el, x, y, z))
    bonds = []
    for i in range(nbonds):
        line = lines[4 + natoms + i]
        a = int(line[0:3]); b = int(line[3:6]); t = int(line[6:9])
        order = {1: "1", 2: "2", 3: "3"}.get(t, "1")
        bonds.append((a, b, order))
    out = [
        "@<TRIPOS>MOLECULE",
        "caffeine",
        f"{natoms} {nbonds} 0 0 0",
        "SMALL",
        "NO_CHARGES",
        "",
        "@<TRIPOS>ATOM",
    ]
    for i, (el, x, y, z) in enumerate(atoms, 1):
        out.append(f"{i:7d} {el:<4s} {x:10.4f} {y:10.4f} {z:10.4f} {el:<5s} 1 UNL  0.0000")
    out.append("@<TRIPOS>BOND")
    for i, (a, b, order) in enumerate(bonds, 1):
        out.append(f"{i:6d} {a:5d} {b:5d} {order}")
    return "\n".join(out) + "\n"


def write_gro(path: Path) -> None:
    rows = [
        "    1WATER  OW    1   0.000   0.000   0.000",
        "    1WATER  HW1   2   0.096   0.000   0.000",
        "    1WATER  HW2   3  -0.024   0.093   0.000",
        "    2WATER  OW    4   0.280   0.000   0.000",
        "    2WATER  HW1   5   0.376   0.000   0.000",
        "    2WATER  HW2   6   0.256   0.093   0.000",
    ]
    text = "two water molecules (nm)\n" + f"{len(rows):5d}\n" + "\n".join(rows) + "\n   0.60000   0.40000   0.40000\n"
    path.write_text(text, encoding="ascii")


def mol_from_sdf(sdf: str) -> str:
    body = sdf.split("$$$$")[0].rstrip() + "\n"
    return body


def main() -> None:
    pdb = ROOT / "1crn.pdb"
    cif = ROOT / "1crn.cif"
    sdf = ROOT / "caffeine.sdf"
    assert pdb.exists() and cif.exists() and sdf.exists()

    shutil.copyfile(pdb, ROOT / "1crn.ent")
    write_gzip(ROOT / "1crn.ent", ROOT / "1crn.ent.gz")
    shutil.copyfile(cif, ROOT / "1crn.mmcif")
    shutil.copyfile(cif, ROOT / "1crn.mcif")
    write_gzip(ROOT / "1crn.mmcif", ROOT / "1crn.mmcif.gz")

    sdf_text = sdf.read_text(encoding="utf-8")
    (ROOT / "caffeine.mol").write_text(mol_from_sdf(sdf_text), encoding="ascii")
    (ROOT / "caffeine.sd").write_text(sdf_text, encoding="ascii")
    write_gzip(sdf, ROOT / "caffeine.sdf.gz")
    (ROOT / "caffeine.xyz").write_text(sdf_to_xyz(sdf_text), encoding="ascii")
    (ROOT / "caffeine.mol2").write_text(sdf_to_mol2(sdf_text), encoding="ascii")

    write_gro(ROOT / "water.gro")
    (ROOT / "1crn.mmtf").write_bytes(build_mmtf())

    write_mrc(ROOT / "blob.mrc")
    shutil.copyfile(ROOT / "blob.mrc", ROOT / "blob.map")
    shutil.copyfile(ROOT / "blob.mrc", ROOT / "blob.ccp4")

    skip = ROOT / "_skip.md"
    if skip.exists():
        skip.unlink()
    script = Path(__file__)
    print("wrote samples in", ROOT)
    for p in sorted(ROOT.iterdir()):
        if p.name.startswith("_"):
            continue
        print(f"  {p.name:18s} {p.stat().st_size:8d}")


if __name__ == "__main__":
    main()
