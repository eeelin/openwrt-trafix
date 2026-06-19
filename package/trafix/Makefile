include $(TOPDIR)/rules.mk

PKG_NAME:=trafix
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Local Builder

include $(INCLUDE_DIR)/package.mk

define Package/trafix
  SECTION:=net
  CATEGORY:=Network
  TITLE:=GFW list based dnsmasq/ipset redirect helper
  DEPENDS:=+curl +jq +yq +bind-dig +dnsmasq-full +ipset
endef

define Package/trafix/description
 A small OpenWrt helper package that generates dnsmasq/ipset rules from
 local or remote rule files and installs iptables/ip6tables redirect rules.
endef

define Package/trafix/conffiles
/etc/config/trafix
/etc/trafix/trafix.yaml
/etc/trafix/bypass-ipset.conf
/etc/trafix/bypass-ipset-net.conf
/etc/trafix/bypass-ip6set.conf
/etc/trafix/bypass-ip6set-net.conf
/etc/trafix/proxy-ipset.conf
/etc/trafix/proxy-ipset-net.conf
/etc/trafix/proxy-ip6set.conf
/etc/trafix/proxy-ip6set-net.conf
endef

define Build/Compile
endef

define Package/trafix/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,trafix))
