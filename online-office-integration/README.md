# MedClaw Online Office Integration

This directory is self-contained. No existing MedClaw source or project file is
modified by the integration package.

## Structure

- `server/`: FastAPI bridge, Nginx gateway, and Docker Compose deployment.
- `client-qt/`: reusable Qt 5.15 C++ client and QML editor view.
- `examples/`: copyable MedClaw registration and page examples.

## Runtime flow

1. The Qt client uploads a local document to the bridge.
2. The bridge returns a short-lived editor URL.
3. `OnlineOfficeView` loads the URL in `WebEngineView`.
4. ONLYOFFICE downloads the source and posts its save callback inside Docker.
5. The Qt client polls for the result and atomically replaces the local file.
6. The temporary server session is deleted. Expired abandoned sessions are
   automatically removed after `SESSION_TTL_SECONDS`.

Supported types include DOC/DOCX/ODT/RTF, XLS/XLSX/ODS/CSV,
PPT/PPTX/ODP, TXT/MD, PDF, HTML and HTM. Images should continue to use a native
image viewer rather than ONLYOFFICE.

## Server

The currently deployed service at `111.6.178.34:24641` can be shared by MedClaw;
another deployment is not required. The `server/` directory is included for
versioning, disaster recovery, and deployment to another environment.

For a new server deployment:

```bash
cd server
cp .env.example .env
# Replace every placeholder and set public URLs, bind address and port.
docker network create office-network || true
docker compose up -d --build
curl http://127.0.0.1:8090/healthcheck
curl http://127.0.0.1:8090/bridge/health
```

`ONLYOFFICE_JWT_SECRET` must match Document Server. `BRIDGE_API_KEY` must be a
separate secret. Never place the JWT secret in a desktop application.

## MedClaw integration (not applied)

When changes to MedClaw are authorized, perform these steps:

1. Add this line to `MedClaw.pro`:

```qmake
include(online-office-integration/client-qt/online-office-client.pri)
```

2. Register one `OnlineOfficeClient` before `engine.load(...)`. See
   `examples/main-registration.cpp`.

3. Supply credentials through the process environment, not source control:

```powershell
$env:MEDCLAW_OFFICE_BRIDGE_URL = "http://111.6.178.34:24641/bridge"
$env:MEDCLAW_OFFICE_API_KEY = "replace-with-the-bridge-api-key"
```

4. Load `qrc:/onlineoffice/OnlineOfficeView.qml` in the desired MedClaw page.
   See `examples/OfficePage.qml`.

5. Call `open(absoluteFilePath, "view")` for preview or
   `open(absoluteFilePath, "edit")` for editing. Before removing the view or
   switching documents, call `closeEditor()` and wait for `sessionClosed`.

The component emits `documentSaved(filePath)` after the edited result has been
downloaded and atomically written to the original local path.

## Security

A shared API key in a desktop process can be extracted. It is acceptable for a
controlled internal test, but production should exchange the user's MedClaw
login token for a short-lived, user-scoped office token at the application
backend. Public endpoints should use HTTPS before external distribution.
