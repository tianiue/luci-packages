module("luci.controller.admin.sattv", package.seeall)

function index()

	if nixio.fs.access("/etc/config/oscam") then
	entry({"admin", "sattv"}, cbi("sattv/epg"), _("OSCAM"), 66).index = true
	entry({"admin", "sattv", "oscam"}, cbi("sattv/oscam"), _("OSCAM"), 1).i18n = "sattv"
	end

	if nixio.fs.access("/etc/config/epg") then
	entry({"admin", "sattv", "epg"}, cbi("sattv/epg"), _("EPG"), 5).i18n = "sattv"
	end

end
