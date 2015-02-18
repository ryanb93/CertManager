ARCHS = armv7 arm64
TARGET = iphone:8.1

include ../theos/makefiles/common.mk

SOURCE_DIR = .

TWEAK_NAME = CertHook
CertHook_FILES = $(foreach ext, c cpp m mm x xm xi xmi, $(wildcard $(SOURCE_DIR)/*.$(ext)))
CertHook_FRAMEWORKS = UIKit, Foundation, Security
CertHook_LDFLAGS = -lcrypto -lssl

include $(THEOS_MAKE_PATH)/tweak.mk