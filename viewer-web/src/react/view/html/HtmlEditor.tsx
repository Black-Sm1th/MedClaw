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
    restoreCanvasEventHandlers,
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

async function activateCanvasRuntime(frameWindow: Window, parts: HtmlDocumentParts) {
    const document = frameWindow.document;
    restoreCanvasEventHandlers(document, parts);

    for (const source of parts.scripts) {
        const parsed = new DOMParser().parseFromString(`<body>${source}</body>`, 'text/html');
        const original = parsed.body.querySelector('script');
        if (!original) continue;

        const script = document.createElement('script');
        Array.from(original.attributes).forEach(attribute => {
            script.setAttribute(attribute.name, attribute.value);
        });
        script.textContent = original.textContent;

        if (script.src) {
            await new Promise<void>(resolve => {
                script.addEventListener('load', () => resolve(), { once: true });
                script.addEventListener('error', () => resolve(), { once: true });
                document.body.appendChild(script);
            });
        } else {
            document.body.appendChild(script);
        }
    }

    // Body scripts are activated after GrapesJS' iframe has loaded, so pages
    // that initialize through DOMContentLoaded need the lifecycle event again.
    document.dispatchEvent(new frameWindow.Event('DOMContentLoaded', { bubbles: true }));
    frameWindow.dispatchEvent(new frameWindow.Event('load'));
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
        const canvasRetryTimers: number[] = [];
        handler.on('open', payload => {
            readOnlyRef.current = payload.readOnly === true;
            loadOfficeBuffer(payload).then(buffer => {
                if (disposed || !containerRef.current) return;
                const parts = splitHtmlDocument(decodeHtml(buffer));
                partsRef.current = parts;

                const session = new URLSearchParams(location.search).get('session');
                const workspaceBaseUrl = typeof payload.workspaceBaseUrl === 'string'
                    ? payload.workspaceBaseUrl
                    : (session ? `/api/html/${encodeURIComponent(session)}/` : location.href);
                const documentBase = new URL(workspaceBaseUrl, location.origin).href;
                const stylesheetUrls = parts.stylesheetHrefs.flatMap(href => {
                    try {
                        return [new URL(href, documentBase).href];
                    } catch {
                        return [];
                    }
                });
                const editor = grapesjs.init({
                    container: containerRef.current,
                    height: '100%',
                    width: '100%',
                    storageManager: false,
                    noticeOnUnload: false,
                    telemetry: false,
                    keepUnusedStyles: true,
                    // Populate the document only after the canvas iframe is
                    // ready. Older Qt WebEngine builds can otherwise lose the
                    // initial render while frameContent is being installed.
                    components: '',
                    style: '',
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
                        styles: stylesheetUrls,
                    },
                });
                editorRef.current = editor;

                // Source import/export bypasses preservation of the original document shell.
                editor.Panels.removeButton('options', 'export-template');
                editor.Panels.removeButton('options', 'gjs-open-import-webpage');
                let canvasReady = false;
                let canvasInitializing = false;
                let initGeneration = 0;
                const initializeCanvas = async () => {
                    if (disposed || canvasInitializing) return false;
                    const generation = initGeneration;
                    const canvasDocument = editor.Canvas.getDocument();
                    const frameWindow = editor.Canvas.getWindow();
                    if (!canvasDocument?.body || !frameWindow) return false;
                    canvasInitializing = true;
                    try {
                        editor.setComponents(parts.body);
                        editor.setStyle(parts.css);
                        const refresh = (editor as Editor & { refresh?: () => void }).refresh;
                        if (typeof refresh === 'function') refresh.call(editor);
                        applyDocumentAttributes(canvasDocument, parts);
                        await activateCanvasRuntime(frameWindow, parts);
                        if (disposed || generation !== initGeneration) return false;
                        const hasAuthorContent = Boolean(parts.body.trim());
                        const rendered = Boolean(
                            canvasDocument.body.childElementCount
                            || canvasDocument.body.textContent?.trim(),
                        );
                        if (hasAuthorContent && !rendered) return false;
                        canvasReady = true;
                        editorReadyRef.current = true;
                        setLoading(false);
                        return true;
                    } catch (canvasError) {
                        if (disposed || generation !== initGeneration) return false;
                        setError(canvasError instanceof Error ? canvasError.message : String(canvasError));
                        setLoading(false);
                        return false;
                    } finally {
                        canvasInitializing = false;
                    }
                };
                editor.on('load', () => { void initializeCanvas(); });
                editor.on('update', () => {
                    if (editorReadyRef.current) handler.emit('change');
                });
                editor.on('canvas:frame:load', ({ window: frameWindow }: { window: Window }) => {
                    // Qt WebEngine often installs frameContent after the first
                    // initializeCanvas pass, wiping the iframe. Invalidate any
                    // in-flight populate and paint into the new document.
                    initGeneration += 1;
                    canvasReady = false;
                    canvasInitializing = false;
                    applyDocumentAttributes(frameWindow.document, parts);
                    void initializeCanvas();
                    frameWindow.addEventListener('keydown', event => {
                        if ((event.ctrlKey || event.metaKey) && event.code === 'KeyS') {
                            event.preventDefault();
                            void save(false);
                        }
                    });
                });
                const frameEl = (editor.Canvas as { getFrameEl?: () => HTMLIFrameElement | undefined }).getFrameEl?.();
                frameEl?.addEventListener('load', () => { void initializeCanvas(); });
                let attempts = 0;
                const retryTimer = window.setInterval(() => {
                    if (disposed || canvasReady) {
                        window.clearInterval(retryTimer);
                        return;
                    }
                    attempts += 1;
                    if (!canvasInitializing)
                        void initializeCanvas();
                    if (attempts >= 40) {
                        window.clearInterval(retryTimer);
                        if (!canvasReady && !disposed) setLoading(false);
                    }
                }, 100);
                canvasRetryTimers.push(retryTimer);
            }).catch(loadError => {
                if (disposed) return;
                setError(loadError instanceof Error ? loadError.message : String(loadError));
                setLoading(false);
            });
        }).emit('init');

        return () => {
            disposed = true;
            canvasRetryTimers.forEach(timer => window.clearInterval(timer));
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
