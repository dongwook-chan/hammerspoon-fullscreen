-- ~/.hammerspoon/watchers/maximize_window.lua
local checkForWindow

local function isStandardAppWindow(win)
    return win
       and not win:isMinimized()
       and win:role()    == "AXWindow"
       and win:subrole() == "AXStandardWindow"
end

local function isWindowMaximizedOnMainScreen(win)
    local main = hs.screen.primaryScreen()
    return win and main
       and win:screen() == main
       and win:frame():equals(main:frame())
end

local function maximizeWindow(win, retries)
    if not win then return end
    local main = hs.screen.primaryScreen()
    win:moveToScreen(main)
    win:maximize()
    if retries > 0 then
        hs.timer.doAfter(0.1, function()
            if not isWindowMaximizedOnMainScreen(win) then
                maximizeWindow(win, retries - 1)
            end
        end)
    end
end

do
    local wf = hs.window.filter.new()
    wf:setAppFilter("Hammerspoon", nil)
    wf:subscribe(hs.window.filter.windowCreated, function(win)
        if isStandardAppWindow(win) then
            maximizeWindow(win, 10)
        end
    end)
    -- wrap for focus so retries is always 10, not the appName string
    wf:subscribe(hs.window.filter.windowFocused, function(win)
        maximizeWindow(win, 10)
    end)
end

local function applicationWatcher(appName, eventType)
    if eventType ~= hs.application.watcher.launched then return end
    if checkForWindow then checkForWindow:stop() end

    local attempts = 0
    checkForWindow = hs.timer.doEvery(0.1, function()
        local app = hs.appfinder.appFromName(appName)
        if app then
            local win = app:mainWindow()
            if win then
                maximizeWindow(win, 10)
                if isWindowMaximizedOnMainScreen(win) then
                    checkForWindow:stop()
                end
            elseif attempts >= 300 then
                checkForWindow:stop()
            end
        end
        attempts = attempts + 1
    end)
end

local appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()
