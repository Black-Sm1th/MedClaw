QT += concurrent quick quickcontrols2 websockets sql network webenginequick widgets core5compat pdf pdfquick

include(viewer-host-qt/viewer-host-qt.pri)

TARGET = AetherStudy

CONFIG += c++17

# Product model: C (consumer: phone/SMS login, public network, no tenant) or
# B (product_b + one tenant + one network). The content edition is orthogonal:
# edition_imaging ships either as B (tenant_imaging) or as C
# (product_c edition_imaging). Legacy edition_* flags remain aliases for B.
contains(CONFIG, product_b):contains(CONFIG, product_c) {
    error("product_b and product_c are mutually exclusive")
}

# Bare edition_* flags still mean their historical B target. They must not
# rewrite the product type once product_b/product_c is set explicitly.
!contains(CONFIG, product_b):!contains(CONFIG, product_c) {
    contains(CONFIG, edition_government) {
        CONFIG += product_b tenant_government network_public
    }
    contains(CONFIG, edition_imaging) {
        CONFIG += product_b tenant_imaging network_public
    }
    contains(CONFIG, edition_hospital_chang2) {
        CONFIG += product_b tenant_hospital_chang2 network_internal
    }
}

contains(CONFIG, product_b) {
    # edition_imaging alone also picks the imaging tenant for B builds.
    !contains(CONFIG, tenant_government):!contains(CONFIG, tenant_imaging):!contains(CONFIG, tenant_hospital_chang2):contains(CONFIG, edition_imaging) {
        CONFIG += tenant_imaging
    }
    !contains(CONFIG, tenant_government):!contains(CONFIG, tenant_imaging):!contains(CONFIG, tenant_hospital_chang2): error("B product requires one tenant_government, tenant_imaging, or tenant_hospital_chang2")
    contains(CONFIG, tenant_government) {
        contains(CONFIG, tenant_imaging): error("B product can only have one tenant")
        contains(CONFIG, tenant_hospital_chang2): error("B product can only have one tenant")
    }
    contains(CONFIG, tenant_imaging):contains(CONFIG, tenant_hospital_chang2): error("B product can only have one tenant")
    !contains(CONFIG, network_public):!contains(CONFIG, network_internal): error("B product requires network_public or network_internal")
    contains(CONFIG, network_public):contains(CONFIG, network_internal): error("B product can only have one network mode")
    DEFINES += MEDCLAW_PRODUCT_B
    contains(CONFIG, network_public): DEFINES += MEDCLAW_NETWORK_PUBLIC
    contains(CONFIG, network_internal): DEFINES += MEDCLAW_NETWORK_INTERNAL
    contains(CONFIG, tenant_government) {
        DEFINES += MEDCLAW_TENANT_GOVERNMENT MEDCLAW_EDITION_GOVERNMENT
        message("MedClaw product: B, tenant: government, network: configured")
    }
    contains(CONFIG, tenant_imaging) {
        DEFINES += MEDCLAW_TENANT_IMAGING MEDCLAW_EDITION_IMAGING
        message("MedClaw product: B, tenant: imaging, network: configured")
    }
    contains(CONFIG, tenant_hospital_chang2) {
        DEFINES += MEDCLAW_TENANT_HOSPITAL_CHANG2 MEDCLAW_EDITION_HOSPITAL_CHANG2
        message("MedClaw product: B, tenant: hospital-chang2, network: configured")
    }
} else {
    # Under product_c a tenant name carries no tenant code; tenant_imaging is
    # accepted as a shorthand for the imaging content edition so builds written
    # as "product_c tenant_imaging network_public" keep working.
    contains(CONFIG, tenant_imaging): CONFIG += edition_imaging
    contains(CONFIG, tenant_government): error("A tenant can only be set for product_b; the C imaging build uses product_c edition_imaging")
    contains(CONFIG, tenant_hospital_chang2): error("A tenant can only be set for product_b")
    contains(CONFIG, network_internal): error("Network mode can only be set for product_b; C product is public")
    contains(CONFIG, edition_government): error("edition_government is a B target; use product_b tenant_government")
    contains(CONFIG, edition_hospital_chang2): error("edition_hospital_chang2 is a B target; use product_b tenant_hospital_chang2")
    DEFINES += MEDCLAW_PRODUCT_C MEDCLAW_NETWORK_PUBLIC
    contains(CONFIG, edition_imaging) {
        DEFINES += MEDCLAW_EDITION_IMAGING
        message("MedClaw product: C, public network, imaging edition")
    } else {
        DEFINES += MEDCLAW_EDITION_MAIN
        message("MedClaw product: C, public network")
    }
}

msvc: QMAKE_CXXFLAGS += /utf-8

# Qt 5.15.2 WebEngineCore from the official gcc_64 package can trigger
# GNU ld.bfd ".dynsym local symbol" diagnostics on newer Linux toolchains.
# gold links the same library cleanly.
linux:QMAKE_LFLAGS += -fuse-ld=gold
unix: LIBS += -lz

# Uncomment to make code fail on deprecated API usage
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000

HEADERS += \
    product_config.h \
    chat_message_visibility.h \
    tool_result_status.h \
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
    auth_controller.h \
    updatecontroller.h \
    filetreeprovider.h \
    thumbnailer.h

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
    auth_controller.cpp \
    updatecontroller.cpp \
    filetreeprovider.cpp \
    thumbnailer.cpp

RESOURCES += qml.qrc

OTHER_FILES += \
    components/ExpertPage.qml \
    components/ProjectSidebar.qml \
    components/TemplateLibraryPage.qml \
    data/TemplatePrompts.js \
    data/ToolCategories.js

# Keep the local viewer assets beside the executable. A post-link directory
# copy avoids expanding every frontend asset into qmake's source archive rule.
# Windows xcopy of viewer-web/dist can OOM if jbrowse2/node_modules leaked into
# dist (hundreds of thousands of files). Use robocopy and skip node_modules.
viewer_web_source = $$shell_path($$PWD/viewer-web/dist)
win32 {
    CONFIG(debug, debug|release): viewer_web_target = $$shell_path($$OUT_PWD/debug/viewer-web)
    else: viewer_web_target = $$shell_path($$OUT_PWD/release/viewer-web)
    QMAKE_POST_LINK += cmd /c \"robocopy $$shell_quote($$viewer_web_source) $$shell_quote($$viewer_web_target) /E /XO /XD node_modules .git /NFL /NDL /NJH /NJS /NC /NS /NP & if errorlevel 8 exit /b 1\"
} else {
    viewer_web_target = $$shell_path($$OUT_PWD/viewer-web)
    QMAKE_POST_LINK += $$QMAKE_COPY_DIR $$shell_quote($$viewer_web_source) $$shell_quote($$viewer_web_target)
}

contains(DEFINES, MEDCLAW_EDITION_IMAGING) {
    RC_ICONS = images/icon-dark.ico
} else {
    RC_ICONS = images/icon.ico
}

win32:LIBS += -lShell32

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
