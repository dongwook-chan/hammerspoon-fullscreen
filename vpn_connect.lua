-- ~/.hammerspoon/vpn_connect.lua
-- Hotkey: Cmd+Alt+V → Ivanti Secure Access Client에서 prod VPN 자동 연결

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

--- 하위 요소 중 특정 텍스트를 포함하는지 확인
local function subtreeContainsText(element, text, maxDepth, depth)
    depth = depth or 0
    if depth > (maxDepth or 8) then return false end

    for _, attr in ipairs({"AXValue", "AXTitle", "AXDescription"}) do
        local v = element:attributeValue(attr)
        if v and type(v) == "string" and string.find(string.lower(v), string.lower(text)) then
            return true
        end
    end

    local children = element:attributeValue("AXChildren")
    if children then
        for _, child in ipairs(children) do
            if subtreeContainsText(child, text, maxDepth, depth + 1) then
                return true
            end
        end
    end
    return false
end

--- "prod" 행에서 Connect 버튼 찾아 클릭
local function clickConnectForProd(axApp)
    -- 전략 1: "prod" 텍스트를 포함하는 행/그룹 안에서 Connect 버튼 찾기
    local prodRow = findElement(axApp, function(el)
        local role = el:attributeValue("AXRole") or ""
        if role == "AXRow" or role == "AXGroup" or role == "AXCell"
           or role == "AXTableRow" or role == "AXOutlineRow" then
            return subtreeContainsText(el, "prod", 5)
        end
        return false
    end)

    if prodRow then
        local btn = findElement(prodRow, function(el)
            local role = el:attributeValue("AXRole") or ""
            local title = string.lower(el:attributeValue("AXTitle") or "")
            return role == "AXButton" and string.find(title, "connect")
        end, 8)
        if btn then
            btn:performAction("AXPress")
            return true
        end
    end

    -- 전략 2: 앱 전체에서 Connect 버튼 직접 찾기 (fallback)
    local btn = findElement(axApp, function(el)
        local role = el:attributeValue("AXRole") or ""
        local title = string.lower(el:attributeValue("AXTitle") or "")
        return role == "AXButton" and string.find(title, "connect")
    end)
    if btn then
        btn:performAction("AXPress")
        return true
    end

    return false
end

--- Alert에서 Proceed 버튼 클릭
local function clickProceed(axApp)
    return findElement(axApp, function(el)
        local role = el:attributeValue("AXRole") or ""
        local title = string.lower(el:attributeValue("AXTitle") or "")
        return role == "AXButton" and string.find(title, "proceed")
    end) ~= nil and (function()
        local btn = findElement(axApp, function(el)
            local role = el:attributeValue("AXRole") or ""
            local title = string.lower(el:attributeValue("AXTitle") or "")
            return role == "AXButton" and string.find(title, "proceed")
        end)
        btn:performAction("AXPress")
        return true
    end)()
end

--- 메인 VPN 연결 함수
local function connectVPN()
    local app = hs.application.find(APP_NAME)
    if not app then
        hs.alert.show("Opening " .. APP_NAME .. "...")
        hs.application.open(APP_NAME)
        hs.timer.doAfter(3, connectVPN)
        return
    end

    app:activate()

    hs.timer.doAfter(0.5, function()
        local axApp = ax.applicationElement(app)

        if clickConnectForProd(axApp) then
            hs.alert.show("VPN: Connecting...")

            -- Proceed 버튼이 나타날 때까지 반복 확인
            local attempts = 0
            local proceedTimer
            proceedTimer = hs.timer.doEvery(0.5, function()
                attempts = attempts + 1
                local axApp2 = ax.applicationElement(app)
                if clickProceed(axApp2) then
                    hs.alert.show("VPN: Done!")
                    proceedTimer:stop()
                elseif attempts > 20 then
                    hs.alert.show("VPN: Proceed button not found")
                    proceedTimer:stop()
                end
            end)
        else
            hs.alert.show("VPN: Connect button not found. Run inspectVPN() in console.")
        end
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
