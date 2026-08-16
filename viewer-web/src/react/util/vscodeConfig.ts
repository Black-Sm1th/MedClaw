let configs = null;

export function getConfigs() {
    if (configs) return configs;
    const elem = document.getElementById('office-configs')
    const value = elem?.getAttribute('data-config');
    if (value && value !== '{{configs}}') {
        configs = JSON.parse(value);
        return configs;
    }

    // Standalone desktop host: configuration is intentionally URL based so
    // this web module has no dependency on Qt, QML, Electron, or VS Code.
    const query = new URLSearchParams(window.location.search);
    configs = {
        route: query.get('route') || 'word',
        language: query.get('language') || navigator.language || 'en',
        config: {},
        standalone: true,
    };
    return configs;
}

// export function getConfig(key, defaultValue) {
//     const config = configs?.config;
//     if (!config) return false;
//     return config[key] ?? defaultValue ?? false
// }
