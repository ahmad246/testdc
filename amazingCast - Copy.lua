-- ##############################################################
-- Discord Fish Notifier (Server + Client in one file)
-- Cara pakai:
--   1. Pisahkan manual: bagian SERVER ke ServerScriptService,
--      bagian CLIENT ke StarterPlayerScripts.
--   2. Atau upload file ini ke GitHub hanya sebagai backup/reference.
-- ##############################################################

-----------------------------------------------------------------
-- == SERVER PART (taruh di ServerScriptService) ==
-----------------------------------------------------------------
if game:GetService("RunService"):IsServer() then
    local HttpService = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- === KONFIGURASI ===
    local WEBHOOK_URL = "https://discord.com/api/webhooks/1405580760697536574/BJ58t21CAS78XE8fDJe_N8KDt65deW1kNPmqRm-XctVHOiLkzSlPS14L1kAWC0cNcD9S" -- GANTI
    local USERNAME    = "Fish It Notifier"
    local COLOR       = 5793266
    local MIN_INTERVAL_SEC = 2
    -- ====================

    local RE = ReplicatedStorage:FindFirstChild("FishChatCaptured")
    if not RE then
        RE = Instance.new("RemoteEvent")
        RE.Name = "FishChatCaptured"
        RE.Parent = ReplicatedStorage
    end

    local lastSentAt = 0
    local recentHash = {}
    local function dedup(key)
        local now = os.clock()
        for k, t in pairs(recentHash) do
            if now - t > 30 then
                recentHash[k] = nil
            end
        end
        if recentHash[key] then return true end
        recentHash[key] = now
        return false
    end

    local function sendDiscord(data)
        local now = os.clock()
        if now - lastSentAt < MIN_INTERVAL_SEC then return end
        lastSentAt = now

        local fishName  = data.fishName or "?"
        local player    = data.playerName or "Player"
        local weightStr = data.weightKg and (tostring(data.weightKg).." kg") or "?"
        local rarityStr = data.chanceIn and ("1 in "..tostring(data.chanceIn)) or "?"

        local embed = {
            title = "Fish Caught!",
            description = string.format("**%s** obtained a **%s**", player, fishName),
            color = COLOR,
            fields = {
                { name = "FISH DATA", value = ("Weight: **%s**"):format(weightStr), inline = true },
                { name = "RARITY",    value = ("**%s**"):format(rarityStr),          inline = true },
                { name = "SOURCE",    value = ("Channel: `%s`"):format(data.channel or "Server"), inline = false },
            },
            timestamp = DateTime.now():ToIsoDate(),
        }
        if data.imageUrl then
            embed.thumbnail = { url = data.imageUrl }
        end

        local payload = { username = USERNAME, embeds = { embed } }
        local ok, err = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
        end)
        if not ok then
            warn("[DiscordFishNotifier] Webhook error:", err)
        end
    end

    RE.OnServerEvent:Connect(function(plr, data)
        if typeof(data) ~= "table" then return end
        if not (data.raw and data.playerName and data.fishName) then return end
        if dedup(data.raw) then return end
        sendDiscord(data)
    end)

    print("[DiscordFishNotifier] SERVER ready")
end

-----------------------------------------------------------------
-- == CLIENT PART (taruh di StarterPlayerScripts) ==
-----------------------------------------------------------------
if game:GetService("RunService"):IsClient() then
    local TextChatService = game:GetService("TextChatService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local RE = ReplicatedStorage:WaitForChild("FishChatCaptured")

    local function normalizeChance(chanceStr)
        if not chanceStr then return nil end
        local s = string.upper((chanceStr:gsub("%s", "")))
        local k = s:match("^([%d%.]+)K$")
        if k then
            local n = tonumber(k)
            return n and math.floor(n * 1000) or nil
        end
        return tonumber(s)
    end

    local function normalizeWeight(weightStr)
        if not weightStr then return nil end
        local s = string.upper((weightStr:gsub("%s", "")))
        local k = s:match("^([%d%.]+)K$")
        if k then
            local n = tonumber(k)
            return n and (n * 1000) or nil
        end
        return tonumber(s)
    end

    local PATTERNS = {
        "^%[Server%]%:%s*(.-)%s+obtained a%s+(.+)%s*%(([%d%.Kk]+)%s*kg%)%s+with a 1 in%s+([%d%.Kk]+)",
        "^%[Server%]%:%s*(.-)%s+caught a%s+(.+)%s*%(([%d%.Kk]+)%s*kg%)%s+with a 1 in%s+([%d%.Kk]+)",
        "^%[Server%]%:%s*(.-)%s+obtained a%s+(.+)%s*%(([%d%.Kk]+)%)%s+with a 1 in%s+([%d%.Kk]+)",
    }

    local function tryParse(text)
        for _, pat in ipairs(PATTERNS) do
            local name, fish, weightStr, chanceStr = text:match(pat)
            if name and fish and weightStr and chanceStr then
                return {
                    playerName = name,
                    fishName   = fish,
                    weightKg   = normalizeWeight(weightStr),
                    chanceIn   = normalizeChance(chanceStr),
                    raw        = text,
                }
            end
        end
        return nil
    end

    if TextChatService and TextChatService.OnIncomingMessage ~= nil then
        TextChatService.OnIncomingMessage = function(msg)
            local text = msg.Text or ""
            local channel = msg.TextChannel and msg.TextChannel.Name or "Server"
            local data = tryParse(text)
            if data then
                data.channel = channel
                RE:FireServer(data)
            end
        end
    else
        warn("[ListenFishChat] TextChatService.OnIncomingMessage tidak tersedia.")
    end

    print("[ListenFishChat] CLIENT listening...")
end
