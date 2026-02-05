-- ~/.hammerspoon/init.lua
package.path = hs.configdir .. "/watchers/?.lua;" .. package.path

require "backup_call_recordings"
require "maximize_window"
require "vpn_connect"

