QT += core network webengine
CONFIG += console c++11
CONFIG -= app_bundle
msvc: QMAKE_CXXFLAGS += /utf-8
TEMPLATE = app
TARGET = online-office-client-smoke

SOURCES += OnlineOfficeClient.cpp smoke-main.cpp
HEADERS += OnlineOfficeClient.h
RESOURCES += online-office-client.qrc
