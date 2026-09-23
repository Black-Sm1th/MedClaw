import JSZip from "jszip";

export interface OfficeOpenPayload {
    path?: string;
    buffer?: number[];
    error?: string;
    readOnly?: boolean;
}

export function arrayBufferFromPayload(payload: OfficeOpenPayload): ArrayBuffer {
    if (payload.error) {
        throw new Error(payload.error);
    }
    if (!payload.buffer?.length) {
        throw new Error('Empty file content');
    }
    const bytes = new Uint8Array(payload.buffer.length);
    for (let i = 0; i < payload.buffer.length; i++) {
        bytes[i] = payload.buffer[i];
    }
    return bytes.buffer;
}

function isZipBuffer(buffer: ArrayBuffer): boolean {
    const bytes = new Uint8Array(buffer);
    return bytes.length >= 4
        && bytes[0] === 0x50
        && bytes[1] === 0x4b
        && (bytes[2] === 0x03 || bytes[2] === 0x05 || bytes[2] === 0x07);
}

/**
 * Some Windows writers store OOXML/ZIP entry names with backslashes
 * (`word\\document.xml`). JSZip and Office parsers only look up forward
 * slashes, so those files open as empty or "No document.xml found".
 */
export async function normalizeZipEntryPaths(buffer: ArrayBuffer): Promise<ArrayBuffer> {
    if (!isZipBuffer(buffer)) {
        return buffer;
    }
    try {
        const zip = await JSZip.loadAsync(buffer);
        const names = Object.keys(zip.files);
        if (!names.some((name) => name.includes("\\"))) {
            return buffer;
        }
        const rewritten = new JSZip();
        for (const [name, entry] of Object.entries(zip.files)) {
            const normalized = name.replace(/\\/g, "/");
            if (entry.dir) {
                rewritten.folder(normalized.replace(/\/$/, ""));
                continue;
            }
            rewritten.file(normalized, await entry.async("uint8array"), {
                date: entry.date,
                unixPermissions: entry.unixPermissions,
                dosPermissions: entry.dosPermissions,
            });
        }
        return await rewritten.generateAsync({
            type: "arraybuffer",
            compression: "DEFLATE",
            compressionOptions: { level: 6 },
        });
    } catch {
        return buffer;
    }
}

export async function loadOfficeBuffer(payload: OfficeOpenPayload): Promise<ArrayBuffer> {
    let buffer: ArrayBuffer;
    if (payload.buffer) {
        buffer = arrayBufferFromPayload(payload);
    } else if (!payload.path) {
        throw new Error(payload.error ?? 'No file path');
    } else {
        const response = await fetch(payload.path);
        if (!response.ok) {
            throw new Error(`Failed to fetch (${response.status})`);
        }
        buffer = await response.arrayBuffer();
    }
    return normalizeZipEntryPaths(buffer);
}
