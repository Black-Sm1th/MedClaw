(function () {
  var JB = window.JBrowseReactLinearGenomeView;
  if (!JB || !window.React || !window.ReactDOM) {
    document.getElementById("status").textContent = "未找到 JBrowse 2 运行时（jbrowse-lgv.js）";
    document.getElementById("status").style.color = "#fca5a5";
    return;
  }

  function fileKind(name) {
    var n = String(name || "").toLowerCase();
    if (/\.(fa|fasta|fna|faa)(\.gz)?$/.test(n)) return "fasta";
    if (/\.2bit$/.test(n)) return "twobit";
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
    return "other";
  }

  function parseFasta(text) {
    var seqs = [];
    var name = null;
    var chunks = [];
    String(text || "").split(/\r?\n/).forEach(function (line) {
      if (!line) return;
      if (line.charAt(0) === ">") {
        if (name) {
          var seq = chunks.join("");
          seqs.push({ refName: name, uniqueId: name, start: 0, end: seq.length, seq: seq });
        }
        name = line.slice(1).trim().split(/\s+/)[0] || ("seq" + (seqs.length + 1));
        chunks = [];
      } else if (name) chunks.push(line.trim());
    });
    if (name) {
      var seq = chunks.join("");
      seqs.push({ refName: name, uniqueId: name, start: 0, end: seq.length, seq: seq });
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
    String(text || "").split(/\r?\n/).forEach(function (line) {
      if (!line) return;
      if (kind === "vcf" && line.indexOf("##contig=") === 0) {
        var id = /ID=([^,>]+)/.exec(line);
        var len = /length=(\d+)/i.exec(line);
        if (id) bumpRef(refs, id[1], len ? len[1] : 1);
        return;
      }
      if (line.charAt(0) === "#") return;
      var cols = line.split("\t");
      if (kind === "bed" && cols.length >= 3) {
        bumpRef(refs, cols[0], cols[2]);
      } else if (kind === "gff" && cols.length >= 5) {
        bumpRef(refs, cols[0], cols[4]);
      } else if (kind === "vcf" && cols.length >= 2) {
        bumpRef(refs, cols[0], Number(cols[1]) + String(cols[3] || "N").length);
      }
    });
  }

  function refsToFeatures(refs) {
    var features = [];
    refs.forEach(function (end, name) {
      features.push({
        refName: name,
        uniqueId: name,
        start: 0,
        end: Math.max(end + 200, 1000),
        seq: ""
      });
    });
    features.sort(function (a, b) { return a.refName.localeCompare(b.refName); });
    return features;
  }

  async function inferAssemblyFromTracks(files) {
    var refs = new Map();
    var scanned = [];
    for (var i = 0; i < files.length; i += 1) {
      var file = files[i];
      var kind = fileKind(file.name);
      if (kind !== "gff" && kind !== "bed" && kind !== "vcf") continue;
      if (file.size && file.size > 20 * 1024 * 1024) continue;
      try {
        var res = await fetch(file.url, { cache: "no-store" });
        if (!res.ok) continue;
        harvestAnnotationRefs(kind, await res.text(), refs);
        scanned.push(file.name);
      } catch (e) {}
    }
    return { features: refsToFeatures(refs), scanned: scanned };
  }

  function findIndex(files, fileName, suffixes) {
    var stem = String(fileName || "").toLowerCase();
    return files.find(function (f) {
      var n = String(f.name || "").toLowerCase();
      return suffixes.some(function (s) {
        return n === stem + s || n === stem.replace(/\.[^.]+$/, "") + s;
      });
    });
  }

  async function buildConfig(files) {
    var notes = [];
    var fasta = files.find(function (f) { return fileKind(f.name) === "fasta"; });
    var twobit = files.find(function (f) { return fileKind(f.name) === "twobit"; });
    var assembly;
    var defaultLoc = "";

    if (twobit) {
      assembly = {
        name: twobit.name.replace(/\.2bit$/i, "") || "ref",
        sequence: {
          type: "ReferenceSequenceTrack",
          trackId: "refseq",
          adapter: { type: "TwoBitAdapter", twoBitLocation: { uri: twobit.url, locationType: "UriLocation" } }
        }
      };
    } else if (fasta) {
      var fai = findIndex(files, fasta.name, [".fai"]);
      if (fai) {
        assembly = {
          name: fasta.name.replace(/\.(fa|fasta|fna|faa)(\.gz)?$/i, "") || "ref",
          sequence: {
            type: "ReferenceSequenceTrack",
            trackId: "refseq",
            adapter: {
              type: "IndexedFastaAdapter",
              fastaLocation: { uri: fasta.url, locationType: "UriLocation" },
              faiLocation: { uri: fai.url, locationType: "UriLocation" }
            }
          }
        };
      } else {
        var text = await fetch(fasta.url, { cache: "no-store" }).then(function (r) {
          if (!r.ok) throw new Error("读取 FASTA 失败");
          return r.text();
        });
        var features = parseFasta(text);
        if (!features.length) throw new Error("FASTA 为空");
        defaultLoc = features[0].refName + ":1-" + Math.min(features[0].end, 2000);
        assembly = {
          name: fasta.name.replace(/\.(fa|fasta|fna|faa)(\.gz)?$/i, "") || "ref",
          sequence: {
            type: "ReferenceSequenceTrack",
            trackId: "refseq",
            adapter: { type: "FromConfigSequenceAdapter", features: features }
          }
        };
      }
    } else {
      var inferred = await inferAssemblyFromTracks(files);
      var features = inferred.features.length
        ? inferred.features
        : [{ refName: "chr1", uniqueId: "chr1", start: 0, end: 1000000, seq: "" }];
      if (inferred.features.length) {
        notes.push("未提供 FASTA/2bit，已根据注释推断染色体（不显示碱基）。要看序列请同时打开 .fa 或 .2bit。");
      } else {
        notes.push("未提供 FASTA/2bit，也未能从 BED/GFF/VCF 推断染色体。BAM/BigWig 仍可尝试显示，但尺子可能对不齐。");
      }
      defaultLoc = features[0].refName + ":1-" + Math.min(features[0].end, 2000);
      assembly = {
        name: files[0] && files[0].name
          ? String(files[0].name).replace(/\.[^.]+$/, "") || "inferred"
          : "inferred",
        sequence: {
          type: "ReferenceSequenceTrack",
          trackId: "refseq",
          adapter: { type: "FromConfigSequenceAdapter", features: features }
        }
      };
    }

    var tracks = [];
    files.forEach(function (file) {
      var kind = fileKind(file.name);
      var id = String(file.name).replace(/[^A-Za-z0-9._-]/g, "_");
      var loc = { uri: file.url, locationType: "UriLocation" };
      if (kind === "gff") {
        tracks.push({ type: "FeatureTrack", trackId: "gff-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "Gff3Adapter", gffLocation: loc } });
      } else if (kind === "bed") {
        tracks.push({ type: "FeatureTrack", trackId: "bed-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "BedAdapter", bedLocation: loc } });
      } else if (kind === "bigbed") {
        tracks.push({ type: "FeatureTrack", trackId: "bb-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "BigBedAdapter", bigBedLocation: loc } });
      } else if (kind === "bigwig") {
        tracks.push({ type: "QuantitativeTrack", trackId: "bw-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "BigWigAdapter", bigWigLocation: loc } });
      } else if (kind === "vcf") {
        tracks.push({ type: "VariantTrack", trackId: "vcf-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "VcfAdapter", vcfLocation: loc } });
      } else if (kind === "vcfGz") {
        var tbi = findIndex(files, file.name, [".tbi", ".csi"]);
        if (!tbi) { notes.push(file.name + " 缺少 .tbi/.csi"); return; }
        tracks.push({ type: "VariantTrack", trackId: "vcfgz-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "VcfTabixAdapter", vcfGzLocation: loc, index: { location: { uri: tbi.url, locationType: "UriLocation" } } } });
      } else if (kind === "bam") {
        var bai = findIndex(files, file.name, [".bai"]);
        if (!bai) { notes.push(file.name + " 缺少 .bai"); return; }
        tracks.push({ type: "AlignmentsTrack", trackId: "bam-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "BamAdapter", bamLocation: loc, index: { location: { uri: bai.url, locationType: "UriLocation" } } } });
      } else if (kind === "cram") {
        var crai = findIndex(files, file.name, [".crai"]);
        if (!crai) { notes.push(file.name + " 缺少 .crai"); return; }
        tracks.push({ type: "AlignmentsTrack", trackId: "cram-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "CramAdapter", cramLocation: loc, craiLocation: { uri: crai.url, locationType: "UriLocation" }, sequenceAdapter: assembly.sequence.adapter } });
      } else if (kind === "hic") {
        tracks.push({ type: "HicTrack", trackId: "hic-" + id, name: file.name, assemblyNames: [assembly.name], adapter: { type: "HicAdapter", hicLocation: loc } });
      } else if (kind === "sam") {
        notes.push(file.name + " 请转成 BAM + BAI");
      } else if (kind === "paf") {
        notes.push(file.name + " 线性视图不显示 PAF");
      }
    });
    return { assembly: assembly, tracks: tracks, defaultLoc: defaultLoc, notes: notes, files: files };
  }

  var session = new URLSearchParams(location.search).get("session") || "";
  var statusEl = document.getElementById("status");
  fetch("/api/medical/manifest?session=" + encodeURIComponent(session), { cache: "no-store" })
    .then(function (r) {
      if (!r.ok) throw new Error("清单读取失败 " + r.status);
      return r.json();
    })
    .then(function (manifest) {
      var files = Array.isArray(manifest.files) ? manifest.files : [];
      if (!files.length) throw new Error("没有基因组文件");
      return buildConfig(files);
    })
    .then(function (cfg) {
      var viewState = JB.createViewState({
        assembly: cfg.assembly,
        tracks: cfg.tracks,
        location: cfg.defaultLoc || undefined
      });
      (cfg.tracks || []).forEach(function (track) {
        try { viewState.session.view.showTrack(track.trackId); } catch (e) {}
      });
      statusEl.textContent = "JBrowse 2 · " + cfg.files.map(function (f) { return f.name; }).join(", ")
        + (cfg.notes.length ? " · " + cfg.notes.join("；") : "");
      var root = ReactDOM.createRoot(document.getElementById("root"));
      root.render(React.createElement(JB.JBrowseLinearGenomeView, { viewState: viewState }));
    })
    .catch(function (err) {
      statusEl.textContent = err && err.message ? err.message : String(err);
      statusEl.style.color = "#fca5a5";
    });
}());
