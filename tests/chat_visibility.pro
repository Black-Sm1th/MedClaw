QT = core
CONFIG += console c++17
CONFIG -= app_bundle
TARGET = chat_visibility
INCLUDEPATH += ..
SOURCES += chat_visibility.cpp ../ws_session.cpp ../session_reader.cpp
HEADERS += ../session_reader.h ../chat_message_visibility.h
win32: QMAKE_CXXFLAGS += /utf-8
