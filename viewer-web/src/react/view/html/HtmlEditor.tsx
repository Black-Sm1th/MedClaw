import { App, Spin } from 'antd';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Editor, Toolbar } from '@wangeditor/editor-for-react';
import type { IDomEditor, IEditorConfig, IToolbarConfig } from '@wangeditor/editor';
import '@wangeditor/editor/dist/css/style.css';
import { handler } from '../../util/vscode';
import { loadOfficeBuffer } from '../../util/loadOfficeContent';
import './HtmlEditor.css';

type HtmlParts = {
    doctype: string;
    htmlAttributes: string;
    head: string;
    bodyAttributes: string;
    body: string;
};

type HostWindow = Window & { __officeViewerRequestSaveAs?: () => boolean };

function attributesOf(element: Element | null): string {
    if (!element) return '';
    return Array.from(element.attributes)
        .map(attribute => ` ${attribute.name}="${attribute.value.replace(/&/g, '&amp;').replace(/"/g, '&quot;')}"`)
        .join('');
}

function splitHtml(source: string): HtmlParts {
    const parser = new DOMParser();
    const document = parser.parseFromString(source, 'text/html');
    const doctypeMatch = source.match(/^\s*(<!doctype[^>]*>)/i);
    return {
        doctype: doctypeMatch?.[1] ?? '<!doctype html>',
        htmlAttributes: attributesOf(document.documentElement),
        head: document.head.innerHTML,
        bodyAttributes: attributesOf(document.body),
        body: document.body.innerHTML,
    };
}

function composeHtml(parts: HtmlParts, body: string): string {
    return `${parts.doctype}\n<html${parts.htmlAttributes}>\n<head>${parts.head}</head>\n<body${parts.bodyAttributes}>${body}</body>\n</html>\n`;
}

function decodeHtml(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    const charset = new TextDecoder('utf-8', { fatal: false }).decode(bytes.slice(0, Math.min(bytes.length, 2048)))
        .match(/<meta[^>]+charset\s*=\s*["']?\s*([^\s"'/>]+)/i)?.[1]?.toLowerCase();
    try {
        return new TextDecoder(charset || 'utf-8').decode(bytes);
    } catch {
        return new TextDecoder('utf-8').decode(bytes);
    }
}

function HtmlEditorView() {
    const { message } = App.useApp();
    const [editor, setEditor] = useState<IDomEditor | null>(null);
    const [html, setHtml] = useState('');
    const [source, setSource] = useState('');
    const [mode, setMode] = useState<'visual' | 'source'>('visual');
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');
    const [readOnly, setReadOnly] = useState(false);
    const partsRef = useRef<HtmlParts | null>(null);
    const changedRef = useRef(false);

    const toolbarConfig = useMemo<Partial<IToolbarConfig>>(() => ({}), []);
    const editorConfig = useMemo<Partial<IEditorConfig>>(() => ({
        placeholder: '请输入 HTML 内容…',
        MENU_CONF: {
            uploadImage: {
                base64LimitSize: 10 * 1024 * 1024,
            },
            uploadVideo: {
                maxFileSize: 100 * 1024 * 1024,
            },
        },
    }), []);

    const documentHtml = useCallback(() => {
        if (mode === 'source') return source;
        const parts = partsRef.current;
        return parts ? composeHtml(parts, editor?.getHtml() ?? html) : html;
    }, [editor, html, mode, source]);

    const save = useCallback(async (saveAs = false) => {
        if (!partsRef.current || saving || readOnly) return false;
        setSaving(true);
        try {
            const bytes = Array.from(new TextEncoder().encode(documentHtml()));
            const response = saveAs
                ? await handler.emitAsync('saveAs', { content: bytes, ext: 'html' })
                : await handler.emitAsync('save', bytes);
            if (response.events?.some(event => event.type === 'saveCanceled')) return false;
            changedRef.current = false;
            message.success('HTML 保存成功');
            return true;
        } catch (saveError) {
            message.error(`HTML 保存失败：${saveError instanceof Error ? saveError.message : String(saveError)}`);
            return false;
        } finally {
            setSaving(false);
        }
    }, [documentHtml, message, readOnly, saving]);

    useEffect(() => {
        handler.on('open', payload => {
            setReadOnly(payload.readOnly === true);
            loadOfficeBuffer(payload).then(buffer => {
                const parts = splitHtml(decodeHtml(buffer));
                const fullSource = composeHtml(parts, parts.body);
                partsRef.current = parts;
                setHtml(parts.body);
                setSource(fullSource);
                if (/<(?:script|style|iframe|canvas|svg|form)\b/i.test(parts.body)) setMode('source');
                setLoading(false);

                const session = new URLSearchParams(location.search).get('session');
                if (session) {
                    let base = document.querySelector<HTMLBaseElement>('base[data-html-editor-base]');
                    if (!base) {
                        base = document.createElement('base');
                        base.dataset.htmlEditorBase = 'true';
                        document.head.appendChild(base);
                    }
                    base.href = `/api/html/${session}/`;
                }
            }).catch(loadError => {
                setError(loadError instanceof Error ? loadError.message : String(loadError));
                setLoading(false);
            });
        }).emit('init');

        return () => document.querySelector('base[data-html-editor-base]')?.remove();
    }, []);

    useEffect(() => () => editor?.destroy(), [editor]);

    useEffect(() => {
        if (!editor) return;
        if (readOnly) editor.disable();
        else editor.enable();
    }, [editor, readOnly]);

    useEffect(() => {
        const hostWindow = window as HostWindow;
        const requestSaveAs = () => {
            void save(true);
            return true;
        };
        if (!readOnly) hostWindow.__officeViewerRequestSaveAs = requestSaveAs;
        return () => {
            if (hostWindow.__officeViewerRequestSaveAs === requestSaveAs) delete hostWindow.__officeViewerRequestSaveAs;
        };
    }, [readOnly, save]);

    useEffect(() => {
        const onKeyDown = (event: KeyboardEvent) => {
            if ((event.ctrlKey || event.metaKey) && event.code === 'KeyS') {
                event.preventDefault();
                if (!readOnly) void save(false);
            }
        };
        window.addEventListener('keydown', onKeyDown);
        return () => window.removeEventListener('keydown', onKeyDown);
    }, [readOnly, save]);

    return (
        <div className="html-editor-view">
            <Spin spinning={loading || saving} fullscreen />
            {readOnly && (
                <div className="html-readonly-banner">
                    只读模式：当前仅可浏览和查找。如需修改，请点击“编辑”进入编辑模式。
                </div>
            )}
            {error ? <div className="html-editor-error">打开 HTML 失败：{error}</div> : (
                <div className="html-editor-shell">
                    {mode === 'visual' ? (
                        <>
                            {!readOnly && <Toolbar editor={editor} defaultConfig={toolbarConfig} mode="default" className="html-editor-toolbar" />}
                            <Editor
                                defaultConfig={editorConfig}
                                value={html}
                                onCreated={setEditor}
                                onChange={currentEditor => {
                                    setHtml(currentEditor.getHtml());
                                    if (!loading) {
                                        changedRef.current = true;
                                        handler.emit('change');
                                    }
                                }}
                                mode="default"
                                className="html-editor-content"
                            />
                        </>
                    ) : (
                        <textarea
                            className="html-source-editor"
                            value={source}
                            readOnly={readOnly}
                            spellCheck={false}
                            onChange={event => {
                                setSource(event.target.value);
                                changedRef.current = true;
                                handler.emit('change');
                            }}
                        />
                    )}
                </div>
            )}
        </div>
    );
}

export default function HtmlEditor() {
    return <App><HtmlEditorView /></App>;
}
