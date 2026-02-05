-- ~/.hammerspoon/vpn_connect.lua
-- Cmd+Shift+1: 메뉴바 → prod → 마지막 아이템(Connect) + Proceed
-- Cmd+Shift+2: 메뉴바 → prod → 마지막 아이템(Resume)

local ax = require("hs.axuielement")

local APP_NAME = "Ivanti Secure Access Client"

--- UI 트리에서 조건에 맞는 요소를 재귀 탐색
local function findElement(element, matchFn, maxDepth, depth)
    depth = depth or 0
    if depth > (maxDepth or 15) then return nil end

    if matchFn(element) then return element end

    local children = element:attributeValue("AXChildren")
    if children then
        for _, child in ipairs(children) do
            local found = findElement(child, matchFn, maxDepth, depth + 1)
            if found then return found end
        end
    end
    return nil
end

--- Alert에서 Proceed 버튼 클릭
local function clickProceed(axApp)
    local btn = findElement(axApp, function(el)
        local role = el:attributeValue("AXRole") or ""
        local title = string.lower(el:attributeValue("AXTitle") or "")
        return role == "AXButton" and string.find(title, "proceed")
    end)
    if btn then
        btn:performAction("AXPress")
        return true
    end
    return false
end

--- 메뉴바 → prod 서브메뉴 열고 items를 콜백에 전달
local function withProdSubMenu(callback)
    local app = hs.application.find(APP_NAME)
    if not app then
        hs.alert.show(APP_NAME .. " not running")
        return
    end

    local axApp = ax.applicationElement(app)
    local extras = axApp:attributeValue("AXExtrasMenuBar")
    if not extras then
        hs.alert.show("VPN: Menu bar icon not found")
        return
    end

    extras:performAction("AXPress")

    hs.timer.doAfter(0.15, function()
        local prodItem = findElement(axApp, function(el)
            local role = el:attributeValue("AXRole") or ""
            local title = string.lower(el:attributeValue("AXTitle") or "")
            return role == "AXMenuItem" and string.find(title, "prod")
        end)

        if not prodItem then
            hs.alert.show("VPN: prod menu not found")
            return
        end

        prodItem:performAction("AXPress")

        hs.timer.doAfter(0.15, function()
            local children = prodItem:attributeValue("AXChildren")
            local menu = children and children[1]
            local items = menu and menu:attributeValue("AXChildren")
            if items and #items > 0 then
                callback(app, items)
            else
                hs.alert.show("VPN: No menu items found")
            end
        end)
    end)
end

--- 메뉴바 → prod → 마지막 아이템 실행 + Proceed (5초간 폴링)
local function connectVPN()
    withProdSubMenu(function(app, items)
        local lastItem = items[#items]
        lastItem:performAction("AXPress")
        local title = lastItem:attributeValue("AXTitle") or "unknown"
        hs.alert.show("VPN: " .. title .. "...")

        local attempts = 0
        local proceedTimer
        proceedTimer = hs.timer.doEvery(0.1, function()
            attempts = attempts + 1
            local axApp = ax.applicationElement(app)
            if clickProceed(axApp) or attempts > 50 then
                proceedTimer:stop()
            end
        end)
    end)
end

--- 메뉴바 → prod → 마지막 아이템 실행
local function resumeVPN()
    withProdSubMenu(function(app, items)
        local lastItem = items[#items]
        lastItem:performAction("AXPress")
        local title = lastItem:attributeValue("AXTitle") or "unknown"
        hs.alert.show("VPN: " .. title)
    end)
end

--- 디버그: UI 트리 출력 (Hammerspoon 콘솔에서 inspectVPN() 실행)
function inspectVPN()
    local app = hs.application.find(APP_NAME)
    if not app then
        print("App not found: " .. APP_NAME)
        return
    end

    local axApp = ax.applicationElement(app)
    local function dump(el, depth)
        if depth > 6 then return end
        local role = el:attributeValue("AXRole") or "?"
        local title = el:attributeValue("AXTitle") or ""
        local value = el:attributeValue("AXValue") or ""
        local desc = el:attributeValue("AXDescription") or ""
        local indent = string.rep("  ", depth)
        print(string.format("%s%s  title=%q  value=%q  desc=%q",
            indent, role, title, tostring(value), desc))

        local children = el:attributeValue("AXChildren")
        if children then
            for _, child in ipairs(children) do
                dump(child, depth + 1)
            end
        end
    end

    dump(axApp, 0)
end

hs.hotkey.bind({"cmd", "shift"}, "1", connectVPN)
hs.hotkey.bind({"cmd", "shift"}, "2", resumeVPN)
