include $(TOPDIR)/rules.mk

PKG_NAME:=gfwlist
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Local Builder

include $(INCLUDE_DIR)/package.mk

define Package/gfwlist
  SECTION:=net
  CATEGORY:=Network
  TITLE:=GFW list based dnsmasq/ipset redirect helper
  DEPENDS:=+curl +jq +yq +bind-dig +dnsmasq-full +ipset
endef

define Package/gfwlist/description
 A small OpenWrt helper package that generates dnsmasq/ipset rules from
 local or remote rule files and installs iptables/ip6tables redirect rules.
endef

define Package/gfwlist/conffiles
/etc/config/gfwlist
/etc/gfwlist/gfwlist.yaml
/etc/gfwlist/bypass-ipset.conf
/etc/gfwlist/bypass-ipset-net.conf
/etc/gfwlist/bypass-ip6set.conf
/etc/gfwlist/bypass-ip6set-net.conf
/etc/gfwlist/proxy-ipset.conf
/etc/gfwlist/proxy-ipset-net.conf
/etc/gfwlist/proxy-ip6set.conf
/etc/gfwlist/proxy-ip6set-net.conf
endef

define Build/Compile
endef

define Package/gfwlist/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,gfwlist))
