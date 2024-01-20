local checkForWindow = nil

-- Function to check if a window is a standard application window
local function isStandardAppWindow(win)
    print(win:role())
    print(win:subrole())
    return win and not win:isMinimized() and win:role() == "AXWindow" and win:subrole() == "AXStandardWindow"
end

-- Function to check if a window is on the main screen and maximized
local function isWindowMaximizedOnMainScreen(win)
    local mainScreen = hs.screen.primaryScreen()
    if win and mainScreen then
        local winFrame = win:frame()
        local screenFrame = mainScreen:frame()
        return win:screen() == mainScreen and winFrame:equals(screenFrame)
    end
    return false
end

-- Function to maximize a window on the main screen
local function maximizeWindow(win, retryAttempts)
    print("maximizeWindow")
    if win then
        local mainScreen = hs.screen.primaryScreen()
        if mainScreen then
            win:moveToScreen(mainScreen)
            win:maximize()
            hs.timer.doAfter(0.1, function()
                if not isWindowMaximizedOnMainScreen(win) and retryAttempts > 0 then
                    print("window not maximized or on main screen")
                    maximizeWindow(win, retryAttempts - 1)
                end
            end)
        end
    end
end

-- Set up a window filter to watch for new windows and focus changes
local windowFilter = hs.window.filter.new()
windowFilter:setAppFilter('Hammerspoon', nil)
windowFilter:subscribe(hs.window.filter.windowCreated, function(win)
    if isStandardAppWindow(win) then
        print("New standard window created, maximizing...")
        maximizeWindow(win, 10)
    else
        print("Non-standard window detected, ignoring...")
    end
end)
windowFilter:subscribe(hs.window.filter.windowFocused, maximizeWindow)

-- Set up the application watcher for apps being launched
local function applicationWatcher(appName, eventType, appObject)
    if eventType == hs.application.watcher.launched then
        print("target spotted")
        local attempts = 0

        if checkForWindow then
            checkForWindow:stop()
        end

        checkForWindow = hs.timer.doEvery(0.1, function()
            local app = hs.appfinder.appFromName(appName)
            if app then
                local win = app:mainWindow()
                if win then
                    maximizeWindow(win, 10)
                    if isWindowMaximizedOnMainScreen(win) then
                        checkForWindow:stop()
                        print("success")
                    end
                else
                    attempts = attempts + 1
                    if attempts >= 300 then
                        checkForWindow:stop()
                        print("failed to maximize " .. appName .. " after 300 attempts")
                    end
                end
            end
        end)
    end
end

-- Start the application watcher
local appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()
