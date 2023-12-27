local checkForWindow = nil  -- Declare it at the top

-- Function to maximize a window
local function maximizeWindow(win)
    if win then
        win:moveToScreen(mainScreen)
        win:maximize()
    end
end

-- Set up the application watcher for apps being launched
local function applicationWatcher(appName, eventType, appObject)
    if eventType == hs.application.watcher.launched then
        local attempts = 0

        -- If there's an existing timer, stop it
        if checkForWindow then
            checkForWindow:stop()
        end

        -- Assign the timer to checkForWindow
        checkForWindow = hs.timer.doEvery(0.1, function()
            local app = hs.appfinder.appFromName(appName)
            if app then
                local win = app:mainWindow()
                if win then
                    maximizeWindow(win)
                    checkForWindow:stop()
                else
                    attempts = attempts + 1
                    if attempts >= 300 then
                        -- Stop checking after 300 failed attempts (30 seconds in total)
                        checkForWindow:stop()
                    end
                end
            end
        end)
    end
end

-- Set up a window filter to watch for new windows being created
local windowFilter = hs.window.filter.new()
windowFilter:setAppFilter('Hammerspoon', nil)  -- This excludes Hammerspoon from being monitored
windowFilter:subscribe(hs.window.filter.windowCreated, function(win)
    maximizeWindow(win)
end)

-- Start the application watcher
local appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()
