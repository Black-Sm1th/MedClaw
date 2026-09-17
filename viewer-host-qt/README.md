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

MedClaw uses desktop OpenGL for both Qt Quick and Qt WebEngine. This avoids
ANGLE/D3D11 device loss (`0x887A0020`) while keeping hardware WebGL2 enabled
for MPR and volume rendering. GPU rasterization and unbounded GPU crash
retries are no longer forced. Restart the application after rebuilding.

For drivers that also fail on desktop OpenGL, launch with
`MEDCLAW_SOFTWARE_OPENGL=1`. This selects Qt's Mesa `opengl32sw.dll`; include
that DLL from the matching Qt kit when deploying. Software WebGL2 supports
3D textures but large volumes may render slowly. Qt 6.8.3 builds disable
SwiftShader, so adding `--enable-unsafe-swiftshader` is not a fallback.

Validation on the installed Qt 6.8.3 kit: Intel UHD Graphics desktop OpenGL
and Mesa llvmpipe both passed WebGL2 creation, 3D texture allocation and
framebuffer readback (maximum 3D texture dimension: 2048). Actual DICOM
MPR/volume rendering and simultaneous Edge OHIF use still require a data-set
regression check.
