const vscode = window['acquireVsCodeApi']?.();
export { vscode as vscodeApi };

type HostMessage = { type: string; content?: unknown };
export type HostResponse = { error?: string; events?: HostMessage[] };
const events = {}

function dispatch(message: HostMessage) {
    if (message?.type && events[message.type]) {
        events[message.type](message.content);
    }
}

async function postToStandaloneHost(message: HostMessage) {
    const session = new URLSearchParams(window.location.search).get('session');
    const endpoint = new URL('/api/events', window.location.origin);
    if (session) endpoint.searchParams.set('session', session);
    const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(message),
    });
    const payload = await response.json().catch(() => ({})) as HostResponse;
    if (!response.ok) {
        throw new Error(payload.error || `Desktop host returned ${response.status}`);
    }
    for (const event of payload.events ?? []) dispatch(event);
    return payload;
}

const postMessage = (message: HostMessage) => {
    if (vscode) vscode.postMessage(message);
    else void postToStandaloneHost(message).catch(error => dispatch({
        type: 'hostError',
        content: error instanceof Error ? error.message : String(error),
    }));
}

const postMessageAsync = async (message: HostMessage) => {
    if (vscode) {
        vscode.postMessage(message);
        return {} as HostResponse;
    }
    return await postToStandaloneHost(message);
}

const DARK_MODE_KEY = 'office-dark-mode';

export function loadDarkMode(): boolean {
    const state = vscode?.getState?.() as { darkMode?: boolean } | undefined;
    if (state?.darkMode !== undefined) {
        return state.darkMode;
    }
    try {
        return localStorage.getItem(DARK_MODE_KEY) === '1';
    } catch {
        return false;
    }
}

export function saveDarkMode(dark: boolean) {
    try {
        localStorage.setItem(DARK_MODE_KEY, dark ? '1' : '0');
    } catch { }
    if (vscode?.setState) {
        const prev = (vscode.getState?.() ?? {}) as Record<string, unknown>;
        vscode.setState({ ...prev, darkMode: dark });
    }
}

export function applyDarkMode(dark: boolean) {
    document.body.classList.toggle('office-dark', dark);
    saveDarkMode(dark);
}

function receive({ data }) {
    if (!data)
        return;
    dispatch(data);
}
window.addEventListener('message', receive)
const isMac = navigator.userAgent.includes('Mac OS');
window.addEventListener('keydown', e => {
    if (isMac && isCompose(e) && (e.altKey || e.code == 'KeyW')) {
        e.preventDefault()
    }
}, isMac ? true : undefined)

const getVscodeEvent = () => {
    return {
        on(event: string, data) {
            events[event] = data
            return this;
        },
        emit(event: string, data?: any) {
            postMessage({ type: event, content: data })
        },
        async emitAsync(event: string, data?: any) {
            return await postMessageAsync({ type: event, content: data })
        }
    }
}
export const handler = getVscodeEvent();

export function isCompose(e) {
    return e.metaKey || e.ctrlKey;
}

window.addEventListener('keydown', e => {
    if (e.code == 'F12') handler.emit('developerTool')
    else if ((isCompose(e) && e.code == 'KeyV')) e.preventDefault()  // vscode的bug, hebrew(希伯来语)键盘会粘贴两次
})
