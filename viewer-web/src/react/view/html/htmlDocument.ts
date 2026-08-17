export type PreservedEventHandlers = Record<string, Record<string, string>>;

export type HtmlDocumentParts = {
    doctype: string;
    htmlAttributes: string;
    htmlAttributeMap: Record<string, string>;
    headTemplate: string;
    bodyAttributes: string;
    bodyAttributeMap: Record<string, string>;
    body: string;
    css: string;
    stylesheetHrefs: string[];
    eventHandlers: PreservedEventHandlers;
    scripts: string[];
};

const STYLE_MARKER = '<!--medclaw-editor-overrides-->';
const SCRIPT_SLOT = 'data-medclaw-script-slot';
const EVENT_SLOT = 'data-medclaw-event-slot';

function escapeAttribute(value: string): string {
    return value.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function attributesOf(element: Element | null): string {
    if (!element) return '';
    return Array.from(element.attributes)
        .map(attribute => ` ${attribute.name}="${escapeAttribute(attribute.value)}"`)
        .join('');
}

function attributeMapOf(element: Element | null): Record<string, string> {
    if (!element) return {};
    return Object.fromEntries(Array.from(element.attributes).map(attribute => [attribute.name, attribute.value]));
}

function doctypeOf(source: string): string {
    return source.match(/^\s*(<!doctype[^>]*>)/i)?.[1] ?? '<!doctype html>';
}

export function decodeHtml(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    const prefix = new TextDecoder('utf-8', { fatal: false })
        .decode(bytes.slice(0, Math.min(bytes.length, 4096)));
    const charset = prefix.match(/<meta[^>]+charset\s*=\s*["']?\s*([^\s"'/>]+)/i)?.[1]?.toLowerCase();
    try {
        return new TextDecoder(charset || 'utf-8').decode(bytes);
    } catch {
        return new TextDecoder('utf-8').decode(bytes);
    }
}

export function splitHtmlDocument(source: string): HtmlDocumentParts {
    const document = new DOMParser().parseFromString(source, 'text/html');
    // Keep only author CSS. The editor override layer is generated on save and
    // must never become part of the next editing session's source CSS.
    const css = Array.from(document.head.querySelectorAll('style:not([data-medclaw-editor-overrides])'))
        .map(style => style.textContent ?? '')
        .join('\n');

    const previousOverrides = Array.from(
        document.head.querySelectorAll<HTMLStyleElement>('style[data-medclaw-editor-overrides]'),
    );
    if (previousOverrides.length > 0) {
        previousOverrides.forEach((style, index) => {
            if (index === 0) style.replaceWith(document.createComment('medclaw-editor-overrides'));
            else style.remove();
        });
    } else {
        document.head.appendChild(document.createComment('medclaw-editor-overrides'));
    }

    const scripts: string[] = [];
    document.body.querySelectorAll('script').forEach(script => {
        const slot = document.createElement('span');
        slot.setAttribute(SCRIPT_SLOT, String(scripts.length));
        slot.setAttribute('hidden', '');
        scripts.push(script.outerHTML);
        script.replaceWith(slot);
    });

    const eventHandlers: PreservedEventHandlers = {};
    let eventSlot = 0;
    document.body.querySelectorAll('*').forEach(element => {
        const handlers: Record<string, string> = {};
        Array.from(element.attributes).forEach(attribute => {
            if (/^on/i.test(attribute.name)) {
                handlers[attribute.name] = attribute.value;
                element.removeAttribute(attribute.name);
            }
        });
        if (Object.keys(handlers).length > 0) {
            const slot = String(eventSlot++);
            element.setAttribute(EVENT_SLOT, slot);
            eventHandlers[slot] = handlers;
        }
    });

    return {
        doctype: doctypeOf(source),
        htmlAttributes: attributesOf(document.documentElement),
        htmlAttributeMap: attributeMapOf(document.documentElement),
        headTemplate: document.head.innerHTML.replace('<!--medclaw-editor-overrides-->', STYLE_MARKER),
        bodyAttributes: attributesOf(document.body),
        bodyAttributeMap: attributeMapOf(document.body),
        body: document.body.innerHTML,
        css,
        stylesheetHrefs: Array.from(document.head.querySelectorAll<HTMLLinkElement>('link[rel~="stylesheet"][href]'))
            .map(link => link.getAttribute('href') ?? '')
            .filter(Boolean),
        eventHandlers,
        scripts,
    };
}

function restorePreservedBody(parts: HtmlDocumentParts, editedBody: string): string {
    const document = new DOMParser().parseFromString(`<body>${editedBody}</body>`, 'text/html');

    document.body.querySelectorAll(`[${EVENT_SLOT}]`).forEach(element => {
        const slot = element.getAttribute(EVENT_SLOT) ?? '';
        const handlers = parts.eventHandlers[slot];
        if (handlers) {
            Object.entries(handlers).forEach(([name, value]) => element.setAttribute(name, value));
        }
        element.removeAttribute(EVENT_SLOT);
    });

    document.body.querySelectorAll(`[${SCRIPT_SLOT}]`).forEach(element => {
        const index = Number(element.getAttribute(SCRIPT_SLOT));
        const original = parts.scripts[index];
        if (!original) {
            element.remove();
            return;
        }
        const range = document.createRange();
        range.selectNode(element);
        element.replaceWith(range.createContextualFragment(original));
    });

    return document.body.innerHTML;
}

export function composeHtmlDocument(parts: HtmlDocumentParts, editedBody: string, css: string): string {
    const style = `<style data-medclaw-editor-overrides>${css.replace(/<\/style/gi, '<\\/style')}</style>`;
    const head = parts.headTemplate.includes(STYLE_MARKER)
        ? parts.headTemplate.replace(STYLE_MARKER, style)
        : `${parts.headTemplate}${style}`;
    const body = restorePreservedBody(parts, editedBody);
    return `${parts.doctype}\n<html${parts.htmlAttributes}>\n<head>${head}</head>\n<body${parts.bodyAttributes}>${body}</body>\n</html>\n`;
}
