include $(TOPDIR)/rules.mk

PKG_NAME:=oscam
PKG_REV:=r11577
PKG_VERSION:=1.20-$(PKG_REV)
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=f6248c4683fbae1ef736333482319d697f03ecd8
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/nx111/oscam.git
PKG_SOURCE:=$(PKG_SOURCE_SUBDIR).tar.bz2
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_MAINTAINER:=OSCam developers <unknown>
PKG_LICENSE:=GPL-3.0
PKG_LICENSE_FILES:=COPYING


PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

include $(INCLUDE_DIR)/package.mk

define Package/oscam
  SECTION:=net
  CATEGORY:=Network
  DEPENDS:=+libopenssl +libusb-1.0 +kmod-usb-serial +kmod-usb-serial-ch341 +kmod-usb-serial-ftdi +kmod-usb-serial-pl2303 +libpcsclite +pcscd +ccid
  TITLE:=OSCam is an Open Source Conditional Access Module software
  URL:=http://www.streamboard.tv/oscam/
endef

define Package/oscam/description
  OSCam is an Open Source Conditional Access Module software,
  based on the very good MpCS version 0.9d created by ​dukat.
endef

define Package/oscam/conffiles
/etc/oscam/
endef

CONFIGURE_CMD = ./config.sh
CONFIGURE_ARGS = \
	--enable all

MAKE_FLAGS += \
	CONF_DIR=/etc/oscam \
	OSCAM_BIN=Distribution/oscam \
        USE_SSL=1 \
	USE_LIBUSB=1 \
	USE_PCSC=1 \
	USE_LIBCRYPTO=1 \
	LEDSUPPORT=1


define Package/oscam/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/Distribution/oscam $(1)/usr/bin/oscam
endef

$(eval $(call BuildPackage,oscam))
