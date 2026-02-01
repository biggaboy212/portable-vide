--!nocheck
--!nolint LocalUnused

local io = require("@lune/stdio")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local net = require("@lune/net")
local dateTime = require("@lune/datetime")

local config = serde.decode("json", fs.readFile(process.args[1]))
local buildConfigs = config.buildConfigs

-- State
local currentBuildSource
local currentBuildConfig
local currentVersion

local composerMarkers = {
    ["__COMPOSER.Insert(__COMPOSER.build)"] = function() return currentBuildSource or "" end,
    ["__COMPOSER.Insert(__COMPOSER.genDate)"] = function() return string.format("%q", dateTime.now():toIsoDate()) end,
    ["__COMPOSER.Insert(__COMPOSER.cfg)"] = function() return string.format("%q", currentBuildConfig or "") end,
    ["__COMPOSER.Insert(__COMPOSER.vers)"] = function() return string.format("%q", currentVersion or "") end,
}

local RELEASE_BODY = `{process.env.TEMP or process.env.TMP}/RELEASE_BODY.md`

local function getBaseName(path)
    return path:match("^.+[\\/](.+)$") or path
end

local function getGhKey()
    if not fs.isFile(".env") then return nil end
    for line in fs.readFile(".env"):gmatch("[^\r\n]+") do
        local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key == "GITHUB_API_KEY" and val then
            return val:gsub('^["\']', ""):gsub('["\']$', "")
        end
    end
    return nil
end

local function mergeOptions(base, override)
    local new = table.clone(base)
    if override then
        for k, v in pairs(override) do new[k] = v end
    end
    return new
end

-- Config
local configNames = {}
for _, v in pairs(buildConfigs) do
    table.insert(configNames, v.name)
end

local selectedIdx = io.prompt("select", "Build configuration", configNames)
local baseOptions = buildConfigs[selectedIdx]

currentBuildConfig = baseOptions.name
currentVersion = baseOptions.promptVersion and io.prompt("text", "Build version (vMAJOR.MINOR.PATCH)") or "0.0.0"

-- Tasks
local tasks = { baseOptions }
if baseOptions.variants then
    for _, variant in pairs(baseOptions.variants) do
        table.insert(tasks, mergeOptions(baseOptions, variant))
    end
end

local artifacts = {}

-- Loop
for _, task in ipairs(tasks) do
    print(`Building {task.name or currentBuildConfig} [{task.output}]...`)

    local result = process.exec("darklua", {
        "process", task.input, task.output,
        "-c", task.darkluaConfig,
    })

    if not result.ok then
        print(`Error building {task.output}\n{result.stderr}`)
        return
    end

    currentBuildSource = fs.readFile(task.output)
    local frame = fs.readFile(task.frame)

    for marker, handler in pairs(composerMarkers) do
        -- Escape
        local cleanMarker = marker:gsub("([%%%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
        frame = frame:gsub(cleanMarker, handler)
    end

    fs.writeFile(task.output, frame)
    print(`Build complete: {task.output}`)
    table.insert(artifacts, task.output)
end

-- Output
if config.openComposedOutput and process.os == "windows" and #artifacts > 0 then
    process.exec("powershell", {
        "-ExecutionPolicy", "Bypass", "-NoProfile", "-Command",
        `code '{artifacts[1]}'`,
    })
end

-- Deploy
if baseOptions.promptDeploy and config.deployment.enabled then
    local ghCfg = config.deployment.github
    local apiKey = getGhKey() or ghCfg.apiKey

    print("\nFiles prepared for upload:")
    for _, path in ipairs(artifacts) do
        print(` - {getBaseName(path)}`)
    end

    if not io.prompt("confirm", "Do you want to distribute this build publicly?") then
        return
    end

    if not (ghCfg and ghCfg.enabled) then return end

    fs.writeFile(RELEASE_BODY, `# {ghCfg.repo} {currentVersion}`)

    if process.os == "windows" then
        process.exec("powershell", {
            "-ExecutionPolicy", "Bypass", "-NoProfile", "-Command",
            `code '{RELEASE_BODY}'`,
        })
    end

    if not io.prompt("confirm", "Add release notes, and confirm when done") then
        return
    end

    local response = net.request({
        url = `https://api.github.com/repos/{ghCfg.owner}/{ghCfg.repo}/releases`,
        method = "POST",
        headers = {
            ["Authorization"] = `Bearer {apiKey}`,
            ["Content-Type"] = "application/json",
        },
        body = serde.encode("json", {
            tag_name = currentVersion,
            name = `{currentBuildConfig} {currentVersion}`,
            body = fs.isFile(RELEASE_BODY) and fs.readFile(RELEASE_BODY) or "",
            draft = false,
            prerelease = baseOptions.prerelease,
        }),
    })

    if fs.isFile(RELEASE_BODY) then
        fs.removeFile(RELEASE_BODY)
    end

    if not response.ok then
        print(`Deployment failed: {response.statusMessage}\n{response.body}`)
        return
    end

    print(`Release created: {response.statusMessage}`)
    
    local releaseId = serde.decode("json", response.body).id
    if not releaseId then
        print("Error: Could not retrieve release ID.")
        return
    end

    -- Artifacts
    for _, filePath in ipairs(artifacts) do
        local assetName = getBaseName(filePath)
        print(`Uploading {assetName}...`)
        
        local uploadResp = net.request({
            url = `https://uploads.github.com/repos/{ghCfg.owner}/{ghCfg.repo}/releases/{releaseId}/assets?name={assetName}`,
            method = "POST",
            headers = {
                ["Authorization"] = `Bearer {apiKey}`,
                ["Content-Type"] = "application/octet-stream",
            },
            body = fs.readFile(filePath),
        })

        if uploadResp.ok then
            print(`✅ Uploaded: {assetName}`)
        else
            print(`❌ Failed: {assetName} - {uploadResp.statusMessage}`)
        end
    end
end