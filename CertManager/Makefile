ARCHS = armv7 arm64
TARGET = iphone:8.1

SOURCE_DIR = .

APPLICATION_NAME = CertManager

CertManager_FILES = $(foreach ext, c cpp m mm x xm xi xmi, $(wildcard $(SOURCE_DIR)/*.$(ext)))
CertManager_FRAMEWORKS = UIKit CoreGraphics Foundation Security
CertManager_LDFLAGS = -lcrypto -lssl

include theos/makefiles/common.mk
include theos/makefiles/application.mk

SUBPROJECTS += CertHook
include theos/makefiles/aggregate.mk

after-install::
	install.exec "killall -9 backboardd"