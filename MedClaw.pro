QT += quick quickcontrols2 websockets sql webengine network

include(online-office-integration/client-qt/online-office-client.pri)
include(viewer-host-qt/viewer-host-qt.pri)

TARGET = AetherStudy

CONFIG += c++11

msvc: QMAKE_CXXFLAGS += /utf-8

# Qt 5.15.2 WebEngineCore from the official gcc_64 package can trigger
# GNU ld.bfd ".dynsym local symbol" diagnostics on newer Linux toolchains.
# gold links the same library cleanly.
linux:QMAKE_LFLAGS += -fuse-ld=gold

# Uncomment to make code fail on deprecated API usage
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000

HEADERS += \
    mainviewcontroller.h \
    CommonFunc.h \
    gateway_client.h \
    chatmodel.h \
    ed25519_local.h \
    ws_config.h \
    ws_session.h \
    ws_skill.h \
    ws_tools.h \
    ws_scheduled_task.h \
    session_reader.h \
    auth_controller.h

SOURCES += \
    main.cpp \
    mainviewcontroller.cpp \
    gateway_client.cpp \
    chatmodel.cpp \
    ed25519_local.cpp \
    ws_config.cpp \
    ws_session.cpp \
    ws_skill.cpp \
    ws_tools.cpp \
    ws_scheduled_task.cpp \
    session_reader.cpp \
    auth_controller.cpp

RESOURCES += qml.qrc

OTHER_FILES += \
    components/ExpertPage.qml \
    components/TemplateLibraryPage.qml \
    data/TemplatePrompts.js \
    config/office.json

office_config.files = config/office.json
office_config.path = $$OUT_PWD/config
COPIES += office_config

# Keep the local viewer assets beside the executable. A post-link directory
# copy avoids expanding every frontend asset into qmake's source archive rule.
viewer_web_source = $$shell_path($$PWD/viewer-web/dist)
win32 {
    CONFIG(debug, debug|release): viewer_web_target = $$shell_path($$OUT_PWD/debug/viewer-web)
    else: viewer_web_target = $$shell_path($$OUT_PWD/release/viewer-web)
} else {
    viewer_web_target = $$shell_path($$OUT_PWD/viewer-web)
}
QMAKE_POST_LINK += $$QMAKE_COPY_DIR $$shell_quote($$viewer_web_source) $$shell_quote($$viewer_web_target)

RC_ICONS = images/icon.ico

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
