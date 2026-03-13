QT += quick quickcontrols2 websockets

CONFIG += c++11

msvc: QMAKE_CXXFLAGS += /utf-8

# Uncomment to make code fail on deprecated API usage
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000

HEADERS += \
    openclawclient.h \
    chatmodel.h \
    ed25519_local.h

SOURCES += \
    main.cpp \
    openclawclient.cpp \
    chatmodel.cpp \
    ed25519_local.cpp

RESOURCES += qml.qrc

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
