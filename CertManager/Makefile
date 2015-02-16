ARCHS = armv7 arm64
TARGET = iphone:8.1

include theos/makefiles/common.mk

APPLICATION_NAME = CertManager
CertManager_FILES = main.m AppDelegate.m X509Wrapper.m SecTrustServer.c OTATrustUtilities.c TableViewController.m
CertManager_FRAMEWORKS = UIKit CoreGraphics Foundation Security
CertManager_PRIVATE_FRAMEWORKS = CertUI
CertManager_LDFLAGS = -lcrypto -lssl

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += CertHook
