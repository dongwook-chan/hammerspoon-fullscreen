local checkForWindow = nil  -- Declare it at the top

-- Function to set a window to full-screen mode
local function setWindowToFullScreen(win)
    if win then
        win:setFullScreen(true)
    end
end

-- Set up the application watcher for apps being launched
local function applicationWatcher(appName, eventType, appObject)
    if (eventType == hs.application.watcher.launched) then
        local attempts = 0

        -- If there's an existing timer, stop it
        if checkForWindow then
            checkForWindow:stop()
        end

        -- Assign the timer to checkForWindow
        checkForWindow = hs.timer.doEvery(0.5, function()
            local app = hs.appfinder.appFromName(appName)
            if app then
                local win = app:mainWindow()
                if win then
                    setWindowToFullScreen(win)
                    checkForWindow:stop()
                else
                    attempts = attempts + 1
                    if attempts >= 10 then
                        -- Stop checking after 10 failed attempts (5 seconds in total)
                        checkForWindow:stop()
                    end
                end
            end
        end)
    end
end

-- Set up a window filter to watch for new windows being created
local windowFilter = hs.window.filter.new()
windowFilter:subscribe(hs.window.filter.windowCreated, function(win)
    setWindowToFullScreen(win)
end)

-- Start the application watcher
local appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

