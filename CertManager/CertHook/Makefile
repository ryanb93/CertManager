ARCHS = armv7 arm64
TARGET = iphone:8.1

include ../theos/makefiles/common.mk

TWEAK_NAME = CertHook
CertHook_FILES = CertHook.xm
CertHook_FRAMEWORKS = Foundation, UIKit, Security

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
