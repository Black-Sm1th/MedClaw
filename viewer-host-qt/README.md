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

## Windows WebGL rendering

Qt Quick and Qt WebEngine must share one GPU backend. On Windows the default
is D3D11 on both sides: Qt Quick uses the RHI D3D11 backend and Qt WebEngine
uses ANGLE/D3D11, the same stack Chrome uses there. This is required for
Cornerstone's WebGL: with native desktop OpenGL the volume loads and reports
correct dimensions, but the viewports paint black. It also avoids the
`Compositor returned null texture` failure that turns every WebEngine page
blank (DOM still clickable) when one side is on ANGLE and the other on desktop
OpenGL. Keep hardware WebGL2 enabled for MPR and volume rendering. GPU
rasterization and unbounded GPU crash retries are not forced. Restart the
application after rebuilding.

`MEDCLAW_WEBENGINE_GL=desktop` moves **both** Qt Quick and Qt WebEngine back to
desktop OpenGL (troubleshooting only; Cornerstone viewports will be black on
affected drivers, and the old WGL shared-context loss can reappear).

For drivers that also fail with hardware WebGL, launch with
`MEDCLAW_SOFTWARE_OPENGL=1`. This selects Qt's Mesa `opengl32sw.dll`; include
that DLL from the matching Qt kit when deploying. Software WebGL2 supports
3D textures but large volumes may render slowly. Qt 6.8.3 builds disable
SwiftShader, so adding `--enable-unsafe-swiftshader` is not a fallback.

Validation on the installed Qt 6.8.3 kit: Intel UHD Graphics desktop OpenGL
and Mesa llvmpipe both passed WebGL2 creation, 3D texture allocation and
framebuffer readback (maximum 3D texture dimension: 2048). Actual DICOM
MPR/volume rendering and simultaneous Edge OHIF use still require a data-set
regression check.
