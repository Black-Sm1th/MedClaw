# Standalone Office Viewer Web Module

This directory is a reusable web module derived from `cweijan/vscode-office`
commit `76334ae0d623ce192b40270158914211febdd98d`.

It does not require a Qt API. Any desktop or browser host can integrate it by
implementing the HTTP contract below.

## Open a viewer

Serve `dist/` and navigate to a URL containing a host-issued session:

```text
/index.html?route=word&language=zh-CN&session=host-session-id
```

Known routes include `word`, `excel`, `ppt`, `image`, `svg`, `zip`, `font`,
`epub`, `icns`, `psd`, `xmind`, and `parquet`. PDF uses the bundled PDF.js
viewer and can be exposed directly by a host.

## Host contract

The viewer sends JSON messages to `POST /api/events?session=host-session-id`:

```json
{ "type": "init" }
```

The host responds with zero or more events:

```json
{
  "events": [{
    "type": "open",
    "content": {
      "path": "/api/document",
      "fileName": "example.docx",
      "ext": ".docx",
      "readOnly": false,
      "documentCacheId": "session-id",
      "nonce": 1
    }
  }]
}
```

`GET /api/document?session=host-session-id` returns the raw document bytes. Viewer events such as
`change`, `save`, `saveAs`, `openExternal`, and `developerTool` use the same
endpoint. This protocol deliberately contains no Qt or VS Code types.

Run `npm install` and `npm run build` to produce `dist/`.

The standalone package deliberately omits VS Code extension build, lint, and
Markdown-editor build dependencies. Those belong to the upstream extension,
not to the embeddable viewer runtime.

The upstream MIT license is preserved in `LICENSE`. Distributors must also
review licenses of bundled third-party dependencies.
