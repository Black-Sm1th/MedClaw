QT += network webengine

msvc: QMAKE_CXXFLAGS += /utf-8

INCLUDEPATH += $$PWD

HEADERS += $$PWD/OnlineOfficeClient.h
SOURCES += $$PWD/OnlineOfficeClient.cpp
RESOURCES += $$PWD/online-office-client.qrc
