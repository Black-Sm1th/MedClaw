import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  createViewState,
  JBrowseLinearGenomeView,
} from "@jbrowse/react-linear-genome-view";

function fileKind(name) {
  const n = String(name || "").toLowerCase();
  if (/\.(fa|fasta|fna|faa)(\.gz)?$/.test(n)) return "fasta";
  if (/\.2bit$/.test(n)) return "twobit";
  if (/\.fai$/.test(n) || /\.gzi$/.test(n)) return "index";
  if (/\.gff3?$/.test(n) || /\.gtf$/.test(n)) return "gff";
  if (/\.bed$/.test(n) || /\.bedgraph$/.test(n)) return "bed";
  if (/\.(bb|bigbed)$/.test(n)) return "bigbed";
  if (/\.(bw|bigwig)$/.test(n)) return "bigwig";
  if (/\.vcf\.gz$/.test(n)) return "vcfGz";
  if (/\.vcf$/.test(n)) return "vcf";
  if (/\.bam$/.test(n)) return "bam";
  if (/\.cram$/.test(n)) return "cram";
  if (/\.sam$/.test(n)) return "sam";
  if (/\.hic$/.test(n)) return "hic";
  if (/\.paf$/.test(n)) return "paf";
  if (/\.(bai|crai|tbi|csi)$/.test(n) || /\.bam\.bai$/.test(n) || /\.cram\.crai$/.test(n))
    return "index";
  return "other";
}

function findBySuffix(files, stem, suffixes) {
  const lower = stem.toLowerCase();
  return files.find((f) => {
    const n = String(f.name || "").toLowerCase();
    return suffixes.some((s) => n === lower + s || n === lower.replace(/\.[^.]+$/, "") + s);
  });
}

function parseFasta(text) {
  const seqs = [];
  let name = null;
  const chunks = [];
  String(text || "").split(/\r?\n/).forEach((line) => {
    if (!line) return;
    if (line.charAt(0) === ">") {
      if (name) {
        const seq = chunks.join("");
        seqs.push({ refName: name, uniqueId: name, start: 0, end: seq.length, seq });
      }
      name = line.slice(1).trim().split(/\s+/)[0] || `seq${seqs.length + 1}`;
      chunks.length = 0;
    } else if (name) chunks.push(line.trim());
  });
  if (name) {
    const seq = chunks.join("");
    seqs.push({ refName: name, uniqueId: name, start: 0, end: seq.length, seq });
  }
  return seqs;
}

function bumpRef(refs, name, end) {
  name = String(name || "").trim();
  if (!name || name.charAt(0) === "#") return;
  end = Number(end);
  if (!isFinite(end) || end < 1) end = 1;
  refs.set(name, Math.max(refs.get(name) || 0, Math.ceil(end)));
}

function harvestAnnotationRefs(kind, text, refs) {
  String(text || "").split(/\r?\n/).forEach((line) => {
    if (!line) return;
    if (kind === "vcf" && line.indexOf("##contig=") === 0) {
      const id = /ID=([^,>]+)/.exec(line);
      const len = /length=(\d+)/i.exec(line);
      if (id) bumpRef(refs, id[1], len ? len[1] : 1);
      return;
    }
    if (line.charAt(0) === "#") return;
    const cols = line.split("\t");
    if (kind === "bed" && cols.length >= 3) bumpRef(refs, cols[0], cols[2]);
    else if (kind === "gff" && cols.length >= 5) bumpRef(refs, cols[0], cols[4]);
    else if (kind === "vcf" && cols.length >= 2) {
      bumpRef(refs, cols[0], Number(cols[1]) + String(cols[3] || "N").length);
    }
  });
}

function refsToFeatures(refs) {
  const features = [];
  refs.forEach((end, name) => {
    features.push({
      refName: name,
      uniqueId: name,
      start: 0,
      end: Math.max(end + 200, 1000),
      seq: "",
    });
  });
  features.sort((a, b) => a.refName.localeCompare(b.refName));
  return features;
}

async function inferAssemblyFromTracks(files) {
  const refs = new Map();
  for (const file of files) {
    const kind = fileKind(file.name);
    if (kind !== "gff" && kind !== "bed" && kind !== "vcf") continue;
    if (file.size && file.size > 20 * 1024 * 1024) continue;
    try {
      const res = await fetch(file.url, { cache: "no-store" });
      if (!res.ok) continue;
      harvestAnnotationRefs(kind, await res.text(), refs);
    } catch (e) {}
  }
  return refsToFeatures(refs);
}

async function buildConfig(files) {
  const notes = [];
  const fasta = files.find((f) => fileKind(f.name) === "fasta");
  const twobit = files.find((f) => fileKind(f.name) === "twobit");
  let assembly;
  let defaultLoc = "";

  if (twobit) {
    assembly = {
      name: twobit.name.replace(/\.2bit$/i, "") || "ref",
      sequence: {
        type: "ReferenceSequenceTrack",
        trackId: "refseq",
        adapter: {
          type: "TwoBitAdapter",
          twoBitLocation: { uri: twobit.url, locationType: "UriLocation" },
        },
      },
    };
  } else if (fasta) {
    const fai = files.find((f) => {
      const n = String(f.name || "").toLowerCase();
      const stem = String(fasta.name || "").toLowerCase();
      return n === `${stem}.fai` || n === stem.replace(/\.(fa|fasta|fna|faa)(\.gz)?$/, "") + ".fai";
    });
    if (fai) {
      assembly = {
        name: fasta.name.replace(/\.(fa|fasta|fna|faa)(\.gz)?$/i, "") || "ref",
        sequence: {
          type: "ReferenceSequenceTrack",
          trackId: "refseq",
          adapter: {
            type: "IndexedFastaAdapter",
            fastaLocation: { uri: fasta.url, locationType: "UriLocation" },
            faiLocation: { uri: fai.url, locationType: "UriLocation" },
          },
        },
      };
    } else {
      const text = await fetch(fasta.url, { cache: "no-store" }).then((r) => {
        if (!r.ok) throw new Error("读取 FASTA 失败");
        return r.text();
      });
      const features = parseFasta(text);
      if (!features.length) throw new Error("FASTA 为空");
      defaultLoc = `${features[0].refName}:1-${Math.min(features[0].end, 2000)}`;
      assembly = {
        name: fasta.name.replace(/\.(fa|fasta|fna|faa)(\.gz)?$/i, "") || "ref",
        sequence: {
          type: "ReferenceSequenceTrack",
          trackId: "refseq",
          adapter: {
            type: "FromConfigSequenceAdapter",
            features,
          },
        },
      };
    }
  } else {
    const inferred = await inferAssemblyFromTracks(files);
    const features = inferred.length
      ? inferred
      : [{ refName: "chr1", uniqueId: "chr1", start: 0, end: 1000000, seq: "" }];
    if (inferred.length) {
      notes.push("未提供 FASTA/2bit，已根据注释推断染色体（不显示碱基）。要看序列请同时打开 .fa 或 .2bit。");
    } else {
      notes.push("未提供 FASTA/2bit，也未能从 BED/GFF/VCF 推断染色体。BAM/BigWig 仍可尝试显示，但尺子可能对不齐。");
    }
    defaultLoc = `${features[0].refName}:1-${Math.min(features[0].end, 2000)}`;
    assembly = {
      name: (files[0] && String(files[0].name).replace(/\.[^.]+$/, "")) || "inferred",
      sequence: {
        type: "ReferenceSequenceTrack",
        trackId: "refseq",
        adapter: { type: "FromConfigSequenceAdapter", features },
      },
    };
  }

  const tracks = [];
  files.forEach((file) => {
    const kind = fileKind(file.name);
    const id = file.name.replace(/[^A-Za-z0-9._-]/g, "_");
    if (kind === "gff") {
      tracks.push({
        type: "FeatureTrack",
        trackId: `gff-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: { type: "Gff3Adapter", gffLocation: { uri: file.url, locationType: "UriLocation" } },
      });
    } else if (kind === "bed") {
      tracks.push({
        type: "FeatureTrack",
        trackId: `bed-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: { type: "BedAdapter", bedLocation: { uri: file.url, locationType: "UriLocation" } },
      });
    } else if (kind === "bigbed") {
      tracks.push({
        type: "FeatureTrack",
        trackId: `bb-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: { type: "BigBedAdapter", bigBedLocation: { uri: file.url, locationType: "UriLocation" } },
      });
    } else if (kind === "bigwig") {
      tracks.push({
        type: "QuantitativeTrack",
        trackId: `bw-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: { type: "BigWigAdapter", bigWigLocation: { uri: file.url, locationType: "UriLocation" } },
      });
    } else if (kind === "vcf") {
      tracks.push({
        type: "VariantTrack",
        trackId: `vcf-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: { type: "VcfAdapter", vcfLocation: { uri: file.url, locationType: "UriLocation" } },
      });
    } else if (kind === "vcfGz") {
      const tbi = files.find((f) => String(f.name).toLowerCase() === String(file.name).toLowerCase() + ".tbi")
        || files.find((f) => String(f.name).toLowerCase() === String(file.name).toLowerCase() + ".csi");
      if (!tbi) {
        notes.push(`${file.name} 缺少 .tbi/.csi 索引`);
        return;
      }
      tracks.push({
        type: "VariantTrack",
        trackId: `vcfgz-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: {
          type: "VcfTabixAdapter",
          vcfGzLocation: { uri: file.url, locationType: "UriLocation" },
          index: { location: { uri: tbi.url, locationType: "UriLocation" } },
        },
      });
    } else if (kind === "bam") {
      const bai = files.find((f) => {
        const n = String(f.name).toLowerCase();
        const stem = String(file.name).toLowerCase();
        return n === stem + ".bai" || n === stem.replace(/\.bam$/, "") + ".bai";
      });
      if (!bai) {
        notes.push(`${file.name} 缺少 .bai 索引`);
        return;
      }
      tracks.push({
        type: "AlignmentsTrack",
        trackId: `bam-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: {
          type: "BamAdapter",
          bamLocation: { uri: file.url, locationType: "UriLocation" },
          index: { location: { uri: bai.url, locationType: "UriLocation" } },
        },
      });
    } else if (kind === "cram") {
      const crai = files.find((f) => {
        const n = String(f.name).toLowerCase();
        const stem = String(file.name).toLowerCase();
        return n === stem + ".crai" || n === stem.replace(/\.cram$/, "") + ".crai";
      });
      if (!crai) {
        notes.push(`${file.name} 缺少 .crai 索引`);
        return;
      }
      tracks.push({
        type: "AlignmentsTrack",
        trackId: `cram-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: {
          type: "CramAdapter",
          cramLocation: { uri: file.url, locationType: "UriLocation" },
          craiLocation: { uri: crai.url, locationType: "UriLocation" },
          sequenceAdapter: assembly.sequence.adapter,
        },
      });
    } else if (kind === "hic") {
      tracks.push({
        type: "HicTrack",
        trackId: `hic-${id}`,
        name: file.name,
        assemblyNames: [assembly.name],
        adapter: {
          type: "HicAdapter",
          hicLocation: { uri: file.url, locationType: "UriLocation" },
        },
      });
    } else if (kind === "sam") {
      notes.push(`${file.name} 请先转 BAM+BAI 再打开`);
    } else if (kind === "paf") {
      notes.push(`${file.name} 线性视图暂不显示 PAF，请用 FASTA/GFF 主视图`);
    }
  });

  return { assembly, tracks, defaultLoc, notes, files };
}

function App() {
  const [state, setState] = useState(null);
  const [error, setError] = useState("");
  const [notes, setNotes] = useState([]);

  useEffect(() => {
    const session = new URLSearchParams(location.search).get("session") || "";
    (async () => {
      const res = await fetch("/api/medical/manifest?session=" + encodeURIComponent(session), { cache: "no-store" });
      if (!res.ok) throw new Error("清单读取失败 " + res.status);
      const manifest = await res.json();
      const files = Array.isArray(manifest.files) ? manifest.files : [];
      if (!files.length) throw new Error("没有基因组文件");
      const cfg = await buildConfig(files);
      const viewState = createViewState({
        assembly: cfg.assembly,
        tracks: cfg.tracks,
        location: cfg.defaultLoc || undefined,
      });
      cfg.tracks.forEach((track) => {
        try {
          viewState.session.view.showTrack(track.trackId);
        } catch (err) {
          cfg.notes.push(track.name + " 轨道未能自动打开");
        }
      });
      setNotes(cfg.notes || []);
      setState(viewState);
      document.getElementById("status").textContent =
        "JBrowse 2 · " + files.map((f) => f.name).join(", ") + (cfg.notes.length ? " · " + cfg.notes.join("；") : "");
    })().catch((e) => {
      setError(e.message || String(e));
      document.getElementById("status").textContent = e.message || String(e);
      document.getElementById("status").style.color = "#fca5a5";
    });
  }, []);

  if (error) return <div style={{ padding: 16, color: "#fca5a5" }}>{error}</div>;
  if (!state) return <div style={{ padding: 16 }}>正在创建 JBrowse 2 视图…</div>;
  return <JBrowseLinearGenomeView viewState={state} />;
}

createRoot(document.getElementById("root")).render(<App />);
