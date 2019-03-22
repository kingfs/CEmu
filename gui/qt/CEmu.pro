lessThan(QT_MAJOR_VERSION, 5) : error("You need at least Qt 5.5 to build CEmu!")
lessThan(QT_MINOR_VERSION, 5) : error("You need at least Qt 5.5 to build CEmu!")

# Error if git submodules are not downloaded
!exists("lua/lua/lua.h"): error("You have to run 'git submodule init' and 'git submodule update' first.")
!exists("../../core/debug/zdis/zdis.c"): error("You have to run 'git submodule init' and 'git submodule update' first.")

# CEmu version and info
CEMU_RELEASE = true
CEMU_GIT_SHA = $$system(git describe --abbrev=7 --always)
isEmpty(CEMU_VERSION) {
    CEMU_VERSION = v1.2dev
    CEMU_RELEASE = false
}
DEFINES += CEMU_VERSION=\\\"$$CEMU_VERSION\\\"
DEFINES += CEMU_GIT_SHA=\\\"$$CEMU_GIT_SHA\\\"
DEFINES += CEMU_RELEASE=$$CEMU_RELEASE
DEFINES += MULTITHREAD

# Continuous Integration (variable checked later)
CI = $$(CI)

# Code beautifying
DISTFILES += ../../.astylerc

# Linux desktop files
if (linux) {
    isEmpty(PREFIX) {
        PREFIX = /usr
    }
    target.path = $$PREFIX/bin
    desktop.target = desktop
    desktop.path = $$PREFIX/share/applications
    desktop.commands += command -v xdg-desktop-menu && \(xdg-desktop-menu install --novendor --mode system resources/linux/cemu.desktop &&
    desktop.commands += xdg-mime install --novendor --mode system resources/linux/cemu.xml &&
    desktop.commands += xdg-mime default cemu.desktop application/x-tice-rom &&
    desktop.commands += xdg-mime default cemu.desktop application/x-cemu-image &&
    desktop.commands += for length in 512 256 192 160 128 96 72 64 48 42 40 36 32 24 22 20 16; do xdg-icon-resource install --novendor --context apps --mode system --size \$\$length resources/icons/linux/cemu-\$\$\{length\}x\$\$length.png cemu; done\) || true
    desktop.uninstall += command -v xdg-desktop-menu && \(xdg-desktop-menu uninstall --novendor --mode system resources/linux/cemu.desktop &&
    desktop.uninstall += xdg-mime uninstall --novendor --mode system resources/linux/cemu.xml &&
    desktop.uninstall += for length in 512 256 192 160 128 96 72 64 48 42 40 36 32 24 22 20 16; do xdg-icon-resource uninstall --novendor --context apps --mode system --size \$\$length resources/icons/linux/cemu-\$\$\{length\}x\$\$length.png cemu; done\) || true
    INSTALLS += target desktop
}

QT += core gui widgets network

isEmpty(TARGET_NAME) {
    TARGET_NAME = CEmu
}
TARGET = $$TARGET_NAME
TEMPLATE = app

# Localization
TRANSLATIONS += i18n/fr_FR.ts i18n/es_ES.ts i18n/nl_NL.ts

# Sol2 needs at least C++14.
CONFIG += c++14 console

# Core options
DEFINES += DEBUG_SUPPORT

# These options can be disabled / enabled depending on
# compiler / library support for your toolchain
DEFINES += LIB_ARCHIVE_SUPPORT PNG_SUPPORT GLOB_SUPPORT

CONFIG(release, debug|release) {
    #This is a release build
    DEFINES += QT_NO_DEBUG_OUTPUT
} else {
    #This is a debug build
    GLOBAL_FLAGS += -g3
}

# TODO Lua: adjust options by platforms, see Makefile
GLOBAL_FLAGS += -DLUA_USE_LONGJMP
INCLUDEPATH += $$PWD/lua/

# GCC/clang flags
if (!win32-msvc*) {
    GLOBAL_FLAGS    += -W -Wall -Wextra -Wunused-function -Werror=write-strings -Werror=redundant-decls -Werror=format -Werror=format-security -Werror=declaration-after-statement -Werror=implicit-function-declaration -Werror=missing-prototypes -Werror=return-type -Werror=pointer-arith -Winit-self
    GLOBAL_FLAGS    += -ffunction-sections -fdata-sections -fno-strict-overflow
    QMAKE_CFLAGS    += -std=gnu11
    QMAKE_CXXFLAGS  += -ftemplate-depth=2048
    isEmpty(CI) {
        # Only enable opts for non-CI release builds
        # -flto might cause an internal compiler error on GCC in some circumstances (with -g3?)... Comment it if needed.
        CONFIG(release, debug|release): GLOBAL_FLAGS += -O3 -flto
    }

    if (contains(DEFINES, LIB_ARCHIVE_SUPPORT)) {
        CONFIG += link_pkgconfig
        PKGCONFIG += zlib libarchive
    }
    # You should run ./capture/get_libpng-apng.sh first!
    isEmpty(USE_LIBPNG) {
        exists("$$PWD/capture/libpng-apng/.libs/libpng16.a") {
            message("Built libpng-apng detected, using it")
            USE_LIBPNG = internal
        } else {
            packagesExist(libpng) {
                USE_LIBPNG = system
            } else {
                error("You have to run $$PWD/capture/get_libpng-apng.sh first, or at least get libpng-dev(el)!")
            }
        }
    }
    equals(USE_LIBPNG, "system") {
        message("Warning: unless your system libpng has APNG support, you will not be able to record screen captures!")
        PKGCONFIG += libpng
    } else {
        !exists("$$PWD/capture/libpng-apng/.libs/libpng16.a"): error("You have to run $$PWD/capture/get_libpng-apng.sh first!")
        INCLUDEPATH += $$PWD/capture/libpng-apng
        LIBS += $$PWD/capture/libpng-apng/.libs/libpng16.a
    }
} else {
    # TODO: add equivalent flags
    # Example for -Werror=shadow: /weC4456 /weC4457 /weC4458 /weC4459
    #     Source: https://connect.microsoft.com/VisualStudio/feedback/details/1355600/
    # /wd5045: disable C5045
    #          (new warning that causes errors: "Compiler will insert Spectre mitigation
    #          for memory load if /Qspectre switch specified")
    QMAKE_CXXFLAGS  += /Wall /wd5045

    # Add -MP to enable speedier builds
    QMAKE_CXXFLAGS += /MP

    # Do we have a flag specifying use of libpng-apng from vcpkg?
	equals(LIBPNG_APNG_FROM_VCPKG, 1) {
		warning("Enabled using libpng-apng from vcpkg. Note that if you do not have vcpkg integrated into MSVC, and/or do not have libpng-apng installed within vcpkg, the build will likely fail.")
		# This is a bad hack, but MOC kinda needs it to work correctly...
		QMAKE_MOC_OPTIONS += -DPNG_WRITE_APNG_SUPPORTED
	}

	# Otherwise...
    !equals(LIBPNG_APNG_FROM_VCPKG, 1) {
        # If we're not using vcpkg, we rely on manual variables to find needed
        # libpng-apng components.
        #
        # Note that libpng/zlib LIBS/INCLUDES should be specified in the envrionment.
        # We will use LIBPNG_APNG_LIB, ZLIB_LIB, and LIBPNG_APNG_INCLUDE.
        # The logic below accounts for both specifying in the real shell environment,
        # as well as directly on the command line (e.g. qmake VAR=1).
        isEmpty(LIBPNG_APNG_LIB) {
            LIBPNG_APNG_LIB = $$(LIBPNG_APNG_LIB)
            isEmpty(LIBPNG_APNG_LIB) {
                error("For MSVC builds, we require LIBPNG_APNG_LIB to point to the libpng-apng lib file to compile against. Please set this in your environment and try again. Alternatively, set LIBPNG_APNG_FROM_VCPKG=1 if you use vcpkg and installed libpng-apng in it.")
            }
        }
        isEmpty(ZLIB_LIB) {
            ZLIB_LIB = $$(ZLIB_LIB)
            isEmpty(ZLIB_LIB) {
                error("For MSVC builds, we require ZLIB_LIB to point to the zlib lib file to compile against. Please set this in your environment and try again. Alternatively, set LIBPNG_APNG_FROM_VCPKG=1 if you use vcpkg and installed libpng-apng in it.")
            }
        }
        isEmpty(LIBPNG_APNG_INCLUDE) {
            LIBPNG_APNG_INCLUDE = $$(LIBPNG_APNG_INCLUDE)
            isEmpty(LIBPNG_APNG_INCLUDE) {
                error("For MSVC builds, we require LIBPNG_APNG_INCLUDE to point to the libpng-apng include director to use for compiling. Please set this in your environment and try again. Alternatively, set LIBPNG_APNG_FROM_VCPKG=1 if you use vcpkg and installed libpng-apng in it.")
            }
        }

        LIBS += $$LIBPNG_APNG_LIB $$ZLIB_LIB
        INCLUDEPATH += $$LIBPNG_APNG_INCLUDE
    }
}

if (macx|linux) {
    # Be more secure by default...
    GLOBAL_FLAGS    += -fPIE -Wstack-protector -fstack-protector-strong --param=ssp-buffer-size=1
    # Lua can do better things in this case
    GLOBAL_FLAGS    += -DLUA_USE_POSIX
    # Use ASAN on debug builds. Watch out about ODR crashes when built with -flto. detect_odr_violation=0 as an env var may help.
    CONFIG(debug, debug|release): GLOBAL_FLAGS += -fsanitize=address,bounds -fsanitize-undefined-trap-on-error -O0
}

macx:  QMAKE_LFLAGS += -Wl,-dead_strip
linux: QMAKE_LFLAGS += -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack -Wl,--gc-sections -pie

QMAKE_CFLAGS    += $$GLOBAL_FLAGS
QMAKE_CXXFLAGS  += $$GLOBAL_FLAGS
QMAKE_LFLAGS    += $$GLOBAL_FLAGS

# If we want to keep supporting macOS down to 10.9, change this and build/deploy with Qt 5.8
macx: QMAKE_MACOSX_DEPLOYMENT_TARGET = 10.11

macx: ICON = resources/icons/icon.icns

SOURCES += \
    ../../tests/autotester/autotester.cpp \
    lua/lua/lapi.c \
    lua/lua/lauxlib.c \
    lua/lua/lbaselib.c \
    lua/lua/lbitlib.c \
    lua/lua/lcode.c \
    lua/lua/lcorolib.c \
    lua/lua/lctype.c \
    lua/lua/ldblib.c \
    lua/lua/ldebug.c \
    lua/lua/ldo.c \
    lua/lua/ldump.c \
    lua/lua/lfunc.c \
    lua/lua/lgc.c \
    lua/lua/linit.c \
    lua/lua/liolib.c \
    lua/lua/llex.c \
    lua/lua/lmathlib.c \
    lua/lua/lmem.c \
    lua/lua/loadlib.c \
    lua/lua/lobject.c \
    lua/lua/lopcodes.c \
    lua/lua/loslib.c \
    lua/lua/lparser.c \
    lua/lua/lstate.c \
    lua/lua/lstring.c \
    lua/lua/lstrlib.c \
    lua/lua/ltable.c \
    lua/lua/ltablib.c \
    lua/lua/ltm.c \
    lua/lua/lundump.c \
    lua/lua/lutf8lib.c \
    lua/lua/lvm.c \
    lua/lua/lzio.c \
    ../../core/asic.c \
    ../../core/cpu.c \
    ../../core/keypad.c \
    ../../core/lcd.c \
    ../../core/registers.c \
    ../../core/port.c \
    ../../core/interrupt.c \
    ../../core/flash.c \
    ../../core/misc.c \
    ../../core/schedule.c \
    ../../core/timers.c \
    ../../core/usb.c \
    ../../core/sha256.c \
    ../../core/realclock.c \
    ../../core/backlight.c \
    ../../core/cert.c \
    ../../core/control.c \
    ../../core/mem.c \
    ../../core/link.c \
    ../../core/vat.c \
    ../../core/emu.c \
    ../../core/extras.c \
    ../../core/spi.c \
    ../../core/debug/debug.c \
    ../../core/debug/zdis/zdis.c \
    ipc.cpp \
    main.cpp \
    utils.cpp \
    mainwindow.cpp \
    romselection.cpp \
    lcdwidget.cpp \
    emuthread.cpp \
    datawidget.cpp \
    dockwidget.cpp \
    searchwidget.cpp \
    basiccodeviewerwindow.cpp \
    sendinghandler.cpp \
    debugger.cpp \
    settings.cpp \
    luascripting.cpp \
    luaeditor.cpp \
    capture/animated-png.c \
    keypad/qtkeypadbridge.cpp \
    keypad/keymap.cpp \
    keypad/keypadwidget.cpp \
    keypad/rectkey.cpp \
    keypad/arrowkey.cpp \
    debugger/hexwidget.cpp \
    debugger/disasm.cpp \
    tivarslib/tivarslib_utils.cpp \
    tivarslib/BinaryFile.cpp \
    tivarslib/TIVarFile.cpp \
    tivarslib/TIModel.cpp \
    tivarslib/TIModels.cpp \
    tivarslib/TIVarType.cpp \
    tivarslib/TIVarTypes.cpp \
    tivarslib/TypeHandlers/DummyHandler.cpp \
    tivarslib/TypeHandlers/TH_GenericList.cpp \
    tivarslib/TypeHandlers/TH_Tokenized.cpp \
    tivarslib/TypeHandlers/TH_GenericComplex.cpp \
    tivarslib/TypeHandlers/TH_Matrix.cpp \
    tivarslib/TypeHandlers/TH_GenericReal.cpp \
    tivarslib/TypeHandlers/TH_AppVar.cpp \
    tivarslib/TypeHandlers/TH_TempEqu.cpp \
    tivarslib/TypeHandlers/STH_ExactFractionPi.cpp \
    tivarslib/TypeHandlers/STH_ExactFraction.cpp \
    tivarslib/TypeHandlers/STH_ExactRadical.cpp \
    tivarslib/TypeHandlers/STH_ExactPi.cpp \
    tivarslib/TypeHandlers/STH_FP.cpp \
    visualizerwidget.cpp \
    debugger/visualizerdisplaywidget.cpp \
    memorywidget.cpp \
    archive/extractor.c \
    runerbot/ops.c \
    runerbot/parse.c \
    ../../core/bus.c \
    keyhistorywidget.cpp

linux|macx: SOURCES += ../../core/os/os-linux.c
win32: SOURCES += ../../core/os/os-win32.c win32-console.cpp
win32: LIBS += -lpsapi

# This doesn't exist, but Qt Creator ignores that
just_show_up_in_qt_creator {
SOURCES +=  ../../tests/autotester/autotester_cli.cpp \
    ../../core/os/os-emscripten.c \
    ../../core/os/os-linux.c \
    ../../core/os/os-win32.c
}

HEADERS  += \
    ../../tests/autotester/autotester.h \
    lua/lua.hpp \
    lua/lua/lapi.h \
    lua/lua/lauxlib.h \
    lua/lua/lcode.h \
    lua/lua/lctype.h \
    lua/lua/ldebug.h \
    lua/lua/ldo.h \
    lua/lua/lfunc.h \
    lua/lua/lgc.h \
    lua/lua/llex.h \
    lua/lua/llimits.h \
    lua/lua/lmem.h \
    lua/lua/lobject.h \
    lua/lua/lopcodes.h \
    lua/lua/lparser.h \
    lua/lua/lprefix.h \
    lua/lua/lstate.h \
    lua/lua/lstring.h \
    lua/lua/ltable.h \
    lua/lua/ltm.h \
    lua/lua/lua.h \
    lua/lua/luaconf.h \
    lua/lua/lualib.h \
    lua/lua/lundump.h \
    lua/lua/lvm.h \
    lua/lua/lzio.h \
    lua/sol.hpp \
    ../../core/asic.h \
    ../../core/cpu.h \
    ../../core/atomics.h \
    ../../core/defines.h \
    ../../core/keypad.h \
    ../../core/lcd.h \
    ../../core/registers.h \
    ../../core/port.h \
    ../../core/interrupt.h \
    ../../core/emu.h \
    ../../core/flash.h \
    ../../core/misc.h \
    ../../core/schedule.h \
    ../../core/timers.h \
    ../../core/usb.h \
    ../../core/sha256.h \
    ../../core/realclock.h \
    ../../core/backlight.h \
    ../../core/cert.h \
    ../../core/control.h \
    ../../core/mem.h \
    ../../core/link.h \
    ../../core/vat.h \
    ../../core/extras.h \
    ../../core/os/os.h \
    ../../core/spi.h \
    ../../core/debug/debug.h \
    ../../core/debug/zdis/zdis.h \
    ipc.h \
    utils.h \
    cemuopts.h \
    mainwindow.h \
    romselection.h \
    lcdwidget.h \
    emuthread.h \
    datawidget.h \
    dockwidget.h \
    searchwidget.h \
    basiccodeviewerwindow.h \
    luaeditor.h \
    sendinghandler.h \
    keypad/qtkeypadbridge.h \
    keypad/keymap.h \
    keypad/keypadwidget.h \
    keypad/key.h \
    keypad/keycode.h \
    keypad/keyconfig.h \
    keypad/rectkey.h \
    keypad/graphkey.h \
    keypad/secondkey.h \
    keypad/alphakey.h \
    keypad/otherkey.h \
    keypad/numkey.h \
    keypad/operkey.h \
    keypad/arrowkey.h \
    capture/animated-png.h \
    debugger/hexwidget.h \
    debugger/disasm.h \
    tivarslib/tivarslib_utils.h \
    tivarslib/CommonTypes.h \
    tivarslib/BinaryFile.h \
    tivarslib/TIModel.h \
    tivarslib/TIModels.h \
    tivarslib/TIVarFile.h \
    tivarslib/TIVarType.h \
    tivarslib/TIVarTypes.h \
    tivarslib/TypeHandlers/TypeHandlers.h \
    visualizerwidget.h \
    debugger/visualizerdisplaywidget.h \
    archive/extractor.h \
    runerbot/runerbot.h \
    ../../core/bus.h \
    keyhistorywidget.h

FORMS    += \
    mainwindow.ui \
    romselection.ui \
    searchwidget.ui \
    basiccodeviewerwindow.ui

RESOURCES += \
    resources.qrc

RC_ICONS += resources\icons\icon.ico
