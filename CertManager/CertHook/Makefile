ARCHS := armv7 arm64
TARGET := iphone:8.1

include ../theos/makefiles/common.mk

TWEAK_NAME = CertHook
CertHook_FILES = CertHook.xm ../NSData+SHA1.m ../LogInformation.m ../FSHandler.m ../DDFileReader.m
CertHook_FRAMEWORKS = Security, UIKit
CertHook_PRIVATE_FRAMEWORKS = BulletinBoard
CertHook_LIBRARIES = substrate rocketbootstrap
SHARED_CFLAGS = -fobjc-arc

include ../theos/makefiles/tweak.mk
