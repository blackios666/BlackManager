TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk


TOOL_NAME = BlackHelper

BlackHelper_FILES = $(wildcard *.m)
BlackHelper_CFLAGS = -fobjc-arc
BlackHelper_CODESIGN_FLAGS = -Sentitlements.plist
BlackHelper_INSTALL_PATH = /usr/local/bin
BlackHelper_PRIVATE_FRAMEWORKS = SpringBoardServices BackBoardServices MobileCoreServices

include $(THEOS_MAKE_PATH)/tool.mk
