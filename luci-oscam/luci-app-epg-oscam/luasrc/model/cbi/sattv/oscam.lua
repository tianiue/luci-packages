local fs = require "nixio.fs"
local uci = require "luci.model.uci".cursor()
local util = require "nixio.util"
require("luci.sys")
require("luci.util")
require("luci.tools.webadmin")

local lanipaddr = uci:get("network", "lan", "ipaddr") or "192.168.1.1"
--- Retrieves the output of the "get_oscam_port" command.
-- @return	String containing the current get_oscam_port
function get_oscam_port()

	local oscam_conf= fs.readfile("/etc/oscam/oscam.conf")
	local oscam_conf_port = tonumber(oscam_conf:match("[Hh]ttppor[Tt].-= ([^\n]+)")) or "8899"
	return oscam_conf_port
end

local oscamport = get_oscam_port()

local state_msg = ""
local running=(luci.sys.call("pidof oscam > /dev/null") == 0)

if running then
	state_msg = "<b><font color=\"green\">" .. translate("Running") .. "</font></b>"
else
	state_msg = "<b><font color=\"red\">" .. translate("Not running") .. "</font></b>"
end

m = Map("oscam", translate("OSCAM"),translate("OSCAM： ") .. state_msg)

s = m:section(TypedSection, "oscam")
s.anonymous = true

s:tab("basic",  translate("基本设置"))

en = s:taboption("basic", Flag, "enable", translate("开机启动"))
en.rmempty = false
en.enabled = "1"
en.disabled = "0"
function en.cfgvalue(self,section)
	return luci.sys.init.enabled("oscam") and self.enabled or self.disabled
end

if running then
	op = s:taboption("basic",Button, "stop", translate("停止运行"),translate("启动不了的话要点多一次才可以！"))
	op.inputstyle = "remove"
else
	op = s:taboption("basic",Button, "start", translate("启动"),translate("启动不了的话要点多一次才可以！"))
	op.inputstyle = "apply"
end
op.write = function(self, section)
	opstatus = (luci.sys.call("/etc/init.d/oscam %s >/dev/null" %{ self.option }) == 0)
	if self.option == "start" and opstatus then
		self.inputstyle = "remove"
		self.title = "停止运行"
		self.option = "stop"
	elseif opstatus then
		self.inputstyle = "apply"
		self.title = "启动"
		self.option = "start"
	end
		luci.http.redirect(luci.dispatcher.build_url("admin", "sattv", "oscam"))
end

interval = s:taboption("basic", Value, "interval", translate("间隔"),translate("分钟"))
interval.optional = false
interval.rmempty = false
interval.default = 30

s:taboption("basic", DummyValue,"oscamweb" ,translate("<a target=\"_blank\" href='http://"..lanipaddr..":"..oscamport.."'>OSCAM Web Intelface</a> "),translate("Open the OSCAM Web"))

s:tab("editconf_etm", translate("OSCAM 配置"))
editconf_etm = s:taboption("editconf_etm", Value, "_editconf_etm", 
	translate("OSCAM 配置："), 
	translate("注释用“ # ”"))
editconf_etm.template = "cbi/tvalue"
editconf_etm.rows = 20
editconf_etm.wrap = "off"

function editconf_etm.cfgvalue(self, section)
	return fs.readfile("/etc/oscam/oscam.conf") or ""
end
function editconf_etm.write(self, section, value1)
	if value1 then
		value1 = value1:gsub("\r\n?", "\n")
		fs.writefile("/tmp/oscam.cfg", value1)
		if (luci.sys.call("cmp -s /tmp/oscam.cfg /etc/oscam/oscam.conf") == 1) then
			fs.writefile("/etc/oscam/oscam.conf", value1)
		end
		fs.remove("/tmp/oscam.cfg")
	end
end

s:tab("editconf_server", translate("Server 配置"))
editconf_server = s:taboption("editconf_server", Value, "_editconf_server", 
	translate("Server 配置"), 
	translate("注释用“ #”"))
editconf_server.template = "cbi/tvalue"
editconf_server.rows = 20
editconf_server.wrap = "off"

function editconf_server.cfgvalue(self, section)
	return fs.readfile("/etc/oscam/oscam.server") or ""
end
function editconf_server.write(self, section, value2)
	if value2 then
		value2 = value2:gsub("\r\n?", "\n")
		fs.writefile("/tmp/oscam.server", value2)
		if (luci.sys.call("cmp -s /tmp/oscam.server /etc/oscam/oscam.server") == 1) then
			fs.writefile("/etc/oscam/oscam.server", value2)
		end
		fs.remove("/tmp/oscam.server")
	end
end

s:tab("editconf_user", translate("User 配置"))
editconf_user = s:taboption("editconf_user", Value, "_editconf_user", 
	translate("User 配置"), 
	translate("注释用“# ”"))
editconf_user.template = "cbi/tvalue"
editconf_user.rows = 20
editconf_user.wrap = "off"

function editconf_user.cfgvalue(self, section)
	return fs.readfile("/etc/oscam/oscam.user") or ""
end
function editconf_user.write(self, section, value3)
	if value3 then
		value3 = value3:gsub("\r\n?", "\n")
		fs.writefile("/tmp/oscam.user", value3)
		if (luci.sys.call("cmp -s /tmp/oscam.user /etc/oscam/oscam.user") == 1) then
			fs.writefile("/etc/oscam/oscam.user", value3)
		end
		fs.remove("/tmp/oscam.user")
	end
end

return m
