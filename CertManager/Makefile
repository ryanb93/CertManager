ARCHS = armv7 arm64
TARGET = iphone:8.1

include theos/makefiles/common.mk
SOURCE_DIR = .
APPLICATION_NAME = CertManager
CertManager_FILES = $(foreach ext, c cpp m mm x xm xi xmi, $(wildcard $(SOURCE_DIR)/*.$(ext)))
CertManager_FRAMEWORKS = UIKit CoreGraphics Foundation Security
CertManager_LDFLAGS = -lcrypto -lssl

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += CertHook
