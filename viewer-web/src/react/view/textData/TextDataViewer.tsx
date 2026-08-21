import { Alert, Spin } from 'antd';
import { useEffect, useState } from 'react';
import { handler } from '../../util/vscode';
import { loadOfficeBuffer } from '../../util/loadOfficeContent';
import './TextDataViewer.css';

type OpenPayload = { path?: string; buffer?: number[]; fileName?: string; ext?: string; error?: string };

function extensionOf(payload: OpenPayload): string {
    return (String(payload.ext || payload.fileName || payload.path || '').split('.').pop()?.toLowerCase() || '').replace(/^\./, '');
}

function decode(buffer: ArrayBuffer): string {
    return new TextDecoder('utf-8', { fatal: false }).decode(buffer).replace(/^\uFEFF/, '');
}

function prettyJson(text: string): string {
    try { return JSON.stringify(JSON.parse(text), null, 2); } catch { return text; }
}

function prettyXml(text: string): string {
    const compact = text.replace(/>\s*</g, '><').trim();
    let depth = 0;
    return compact.replace(/(<[^>]+>)/g, '\u0000$1\u0000').split('\u0000').filter(Boolean).map(part => {
        if (part.startsWith('</')) depth = Math.max(0, depth - 1);
        const line = `${'  '.repeat(depth)}${part}`;
        if (part.startsWith('<') && !part.startsWith('</') && !part.startsWith('<?')
            && !part.startsWith('<!') && !part.endsWith('/>') && !part.includes('</')) depth++;
        return line;
    }).join('\n');
}

export default function TextDataViewer() {
    const [text, setText] = useState('');
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    useEffect(() => {
        handler.on('open', async (payload: OpenPayload) => {
            try {
                setLoading(true); setError('');
                const nextExt = extensionOf(payload);
                const raw = decode(await loadOfficeBuffer(payload));
                setText(nextExt === 'json' ? prettyJson(raw) : nextExt === 'xml' ? prettyXml(raw) : raw);
            } catch (e) { setError(e instanceof Error ? e.message : String(e)); }
            finally { setLoading(false); }
        }).emit('init');
    }, []);

    const lines = text.split(/\r?\n/);

    return <main className="text-data-viewer">
        {loading && <Spin className="text-data-loading" />}
        {error && <Alert type="error" message={error} showIcon />}
        {!loading && !error && <pre className="text-data-content">{lines.map((line, index) => <div key={index}><span className="text-data-line-number">{index + 1}</span>{line || ' '}</div>)}</pre>}
    </main>;
}
