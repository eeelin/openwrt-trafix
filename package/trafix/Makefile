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
  TITLE:=Rule-based dnsmasq/ipset redirect helper
  DEPENDS:=+curl +jq +yq +bind-dig +dnsmasq-full +ipset
endef

define Package/trafix/description
 A small OpenWrt helper package that compiles rule_sets and route_rules into
 dnsmasq/ipset data and installs iptables/ip6tables redirect rules.
endef

define Package/trafix/conffiles
/etc/config/trafix
/etc/trafix/config.yaml
endef

define Build/Compile
endef

define Package/trafix/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,trafix))
