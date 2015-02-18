ARCHS := armv7 arm64
TARGET := iphone:8.1

include ../theos/makefiles/common.mk

TWEAK_NAME = CertHook
CertHook_FILES = CertHook.xm
CertHook_FRAMEWORKS = Security
CertHook_LIBRARIES = substrate


include ../theos/makefiles/tweak.mk
