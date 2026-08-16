const vscode = typeof (acquireVsCodeApi) != "undefined" ? acquireVsCodeApi() : null;
let events = {}

function dispatch(message) {
    if (message && events[message.type]) {
        events[message.type](message.content);
    }
}

async function postToStandaloneHost(message) {
    try {
        const session = new URLSearchParams(window.location.search).get('session');
        const endpoint = new URL('/api/events', window.location.origin);
        if (session) endpoint.searchParams.set('session', session);
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(message),
        });
        if (!response.ok) throw new Error(`Desktop host returned ${response.status}`);
        const payload = await response.json();
        for (const event of payload.events || []) dispatch(event);
    } catch (error) {
        dispatch({ type: 'hostError', content: String(error) });
    }
}

const postMessage = (message) => {
    if (vscode) vscode.postMessage(message);
    else void postToStandaloneHost(message);
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
        on(event, data) {
            events[event] = data
            return this;
        },
        emit(event, data) {
            postMessage({ type: event, content: data })
        }
    }
}

window.vscodeEvent = getVscodeEvent();
window.handler = getVscodeEvent();

function addCss(css) {
    const style = document.createElement('style');
    style.innerText = css;
    document.documentElement.appendChild(style)
}



window.addThemeCss = function () {
    addCss(`
    *{
        background-color: var(--vscode-editor-background) !important;
        color: var(--vscode-editor-foreground) !important;
    }
    *{
        border-color: var(--vscode-quickInputTitle-background) !important;
    }
    `);
}

function isCompose(e) {
    return e.metaKey || e.ctrlKey;
}

function isInsideCodeMirrorTarget(target) {
    const node = target?.nodeType === 1 ? target : target?.parentElement;
    return !!node?.closest?.(".vditor-code-block--cm .cm-editor");
}

window.addEventListener('keydown', e => {
    if (e.code == 'F12') window.vscodeEvent.emit('developerTool')
    else if ((isCompose(e) && e.code == 'KeyV')
        && !isInsideCodeMirrorTarget(e.target)
        && !isInsideCodeMirrorTarget(document.activeElement)) {
        e.preventDefault()  // vscode的bug, hebrew(希伯来语)键盘会粘贴两次
    }
})
