import { App, Spin } from 'antd';
import { useCallback, useEffect, useRef, useState } from 'react';
import grapesjs, { type Editor } from 'grapesjs';
import parserPostCss from 'grapesjs-parser-postcss';
import presetWebpage from 'grapesjs-preset-webpage';
import zh from 'grapesjs/locale/zh';
import 'grapesjs/dist/css/grapes.min.css';
import { handler } from '../../util/vscode';
import { loadOfficeBuffer } from '../../util/loadOfficeContent';
import {
    composeHtmlDocument,
    decodeHtml,
    splitHtmlDocument,
    type HtmlDocumentParts,
} from './htmlDocument';
import './HtmlEditor.css';

type HostWindow = Window & { __officeViewerRequestSaveAs?: () => boolean };

function applyDocumentAttributes(document: Document, parts: HtmlDocumentParts) {
    const apply = (element: HTMLElement, attributes: Record<string, string>) => {
        Object.entries(attributes).forEach(([name, value]) => {
            // Workspace event handlers stay disabled inside the editor canvas.
            if (!/^on/i.test(name)) element.setAttribute(name, value);
        });
    };
    apply(document.documentElement, parts.htmlAttributeMap);
    apply(document.body, parts.bodyAttributeMap);
}

function HtmlEditorView() {
    const { message } = App.useApp();
    const containerRef = useRef<HTMLDivElement | null>(null);
    const editorRef = useRef<Editor | null>(null);
    const partsRef = useRef<HtmlDocumentParts | null>(null);
    const readOnlyRef = useRef(false);
    const savingRef = useRef(false);
    const editorReadyRef = useRef(false);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');

    const documentHtml = useCallback(() => {
        const editor = editorRef.current;
        const parts = partsRef.current;
        if (!editor || !parts) return '';
        return composeHtmlDocument(parts, editor.getHtml(), editor.getCss({ keepUnusedStyles: true }));
    }, []);

    const save = useCallback(async (saveAs = false) => {
        if (!editorRef.current || !partsRef.current || savingRef.current || readOnlyRef.current) return false;
        savingRef.current = true;
        setSaving(true);
        try {
            const bytes = Array.from(new TextEncoder().encode(documentHtml()));
            const response = saveAs
                ? await handler.emitAsync('saveAs', { content: bytes, ext: 'html' })
                : await handler.emitAsync('save', bytes);
            if (response.events?.some(event => event.type === 'saveCanceled')) return false;
            message.success(saveAs ? 'HTML 已另存为' : 'HTML 保存成功');
            return true;
        } catch (saveError) {
            message.error(`HTML 保存失败：${saveError instanceof Error ? saveError.message : String(saveError)}`);
            return false;
        } finally {
            savingRef.current = false;
            setSaving(false);
        }
    }, [documentHtml, message]);

    useEffect(() => {
        let disposed = false;
        handler.on('open', payload => {
            readOnlyRef.current = payload.readOnly === true;
            loadOfficeBuffer(payload).then(buffer => {
                if (disposed || !containerRef.current) return;
                const parts = splitHtmlDocument(decodeHtml(buffer));
                partsRef.current = parts;

                const session = new URLSearchParams(location.search).get('session');
                const documentBase = session
                    ? new URL(`/api/html/${encodeURIComponent(session)}/`, location.origin).href
                    : location.href;
                const editor = grapesjs.init({
                    container: containerRef.current,
                    height: '100%',
                    width: '100%',
                    storageManager: false,
                    noticeOnUnload: false,
                    telemetry: false,
                    keepUnusedStyles: true,
                    components: parts.body,
                    style: parts.css,
                    // GrapesJS' default browser CSSOM parser drops valid author styles
                    // such as CSS variables and prefixed gradient declarations. PostCSS
                    // keeps the editable canvas visually aligned with the real preview.
                    plugins: [parserPostCss, editorInstance => presetWebpage(editorInstance, {
                            modalImportTitle: '导入 HTML',
                            modalImportButton: '导入',
                            textCleanCanvas: '确定要清空当前页面吗？',
                            block: blockId => ({
                                category: '基础组件',
                                label: {
                                    'link-block': '链接',
                                    quote: '引用',
                                    'text-basic': '文本区域',
                                }[blockId] ?? blockId,
                            }),
                    })],
                    i18n: {
                        locale: 'zh',
                        localeFallback: 'zh',
                        detectLocale: false,
                        messages: { zh },
                    },
                    parser: {
                        optionsHtml: {
                            allowScripts: false,
                            allowUnsafeAttr: false,
                            allowUnsafeAttrValue: false,
                        },
                    },
                    canvas: {
                        frameContent: `<!doctype html><html><head><base href="${documentBase.replace(/"/g, '&quot;')}"></head><body></body></html>`,
                        styles: parts.stylesheetHrefs.map(href => new URL(href, documentBase).href),
                    },
                });
                editorRef.current = editor;

                // Source import/export bypasses preservation of the original document shell.
                editor.Panels.removeButton('options', 'export-template');
                editor.Panels.removeButton('options', 'gjs-open-import-webpage');
                editor.on('load', () => {
                    const canvasDocument = editor.Canvas.getDocument();
                    if (canvasDocument) applyDocumentAttributes(canvasDocument, parts);
                    editorReadyRef.current = true;
                    setLoading(false);
                });
                editor.on('update', () => {
                    if (editorReadyRef.current) handler.emit('change');
                });
                editor.on('canvas:frame:load', ({ window: frameWindow }: { window: Window }) => {
                    applyDocumentAttributes(frameWindow.document, parts);
                    frameWindow.addEventListener('keydown', event => {
                        if ((event.ctrlKey || event.metaKey) && event.code === 'KeyS') {
                            event.preventDefault();
                            void save(false);
                        }
                    });
                });
            }).catch(loadError => {
                if (disposed) return;
                setError(loadError instanceof Error ? loadError.message : String(loadError));
                setLoading(false);
            });
        }).emit('init');

        return () => {
            disposed = true;
            editorReadyRef.current = false;
            editorRef.current?.destroy();
            editorRef.current = null;
        };
    }, [save]);

    useEffect(() => {
        const hostWindow = window as HostWindow;
        const requestSaveAs = () => {
            void save(true);
            return true;
        };
        hostWindow.__officeViewerRequestSaveAs = requestSaveAs;
        return () => {
            if (hostWindow.__officeViewerRequestSaveAs === requestSaveAs) delete hostWindow.__officeViewerRequestSaveAs;
        };
    }, [save]);

    useEffect(() => {
        const onKeyDown = (event: KeyboardEvent) => {
            if ((event.ctrlKey || event.metaKey) && event.code === 'KeyS') {
                event.preventDefault();
                void save(false);
            }
        };
        window.addEventListener('keydown', onKeyDown);
        return () => window.removeEventListener('keydown', onKeyDown);
    }, [save]);

    return (
        <div className="html-editor-view">
            <Spin spinning={loading || saving} fullscreen />
            {error && <div className="html-editor-error">打开 HTML 失败：{error}</div>}
            <div ref={containerRef} className="html-grapes-editor" hidden={Boolean(error)} />
        </div>
    );
}

export default function HtmlEditor() {
    return <App><HtmlEditorView /></App>;
}
