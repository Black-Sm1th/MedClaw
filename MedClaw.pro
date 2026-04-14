QT += quick quickcontrols2 websockets

CONFIG += c++11

msvc: QMAKE_CXXFLAGS += /utf-8

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
    session_reader.h

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
    session_reader.cpp

RESOURCES += qml.qrc

RC_ICONS = images/icon.ico

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
