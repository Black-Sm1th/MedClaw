# ViewerHostQt

`ViewerHostQt` is a reusable Qt 5.15 local HTTP host for `viewer-web`. Its
public API accepts filesystem paths and returns browser URLs; it has no
dependency on this demo application's document model.

## CMake integration

```cmake
add_subdirectory(path/to/viewer-host-qt)
target_link_libraries(your_app PRIVATE ViewerHostQt::ViewerHostQt)
```

Create one host for the lifetime of the application:

```cpp
ViewerHost viewerHost;
viewerHost.setViewerRootPath("path/to/viewer-web/dist"); // optional in development
const QString url = viewerHost.openDocument(filePath, false, "zh-CN");
```

Load `url` in Qt WebEngine, WebView2, CEF, Electron, or a browser view. Qt
Quick applications may also add `qml/ViewerWebView.qml` to their resources.

At deployment time, place the contents of `viewer-web/dist` beside the
executable in a directory named `viewer-web`.

Run the module's protocol smoke test with `ctest --test-dir build -C Release`.

## Host protocol

The module binds only to `127.0.0.1`, chooses the first available port from
8200 through 8210, and issues a new random session for each opened document.
Both document reads and viewer events require that session. Saves use
`QSaveFile` for atomic replacement.

The built-in event handlers cover normal document initialization, change,
save, save-as, and external links. Other viewer events are emitted through
`viewerEvent`, allowing an embedding application to add its own policy.
