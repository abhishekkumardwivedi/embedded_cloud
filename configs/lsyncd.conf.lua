-----
-- configuration file to sync specified directory in multiple nodes
-- node address comes from csync2.
-----
settings {
        logident        = "lsyncd",
        logfacility     = "user",
        logfile         = "/var/log/lsyncd/lsyncd.log",
        statusFile      = "/var/log/lsyncd/lsyncd.status",
        statusInterval  = 1
}

initSync = {
        delay = 1,
        maxProcesses = 1,
        action = function(inlet)
                local config = inlet.getConfig()
                local elist = inlet.getEvents(function(event)
                        return event.etype ~= "Init"
                end)
                local directory = string.sub(config.source, 1, -2)
                local paths = elist.getPaths(function(etype, path)
                        return "\t" .. config.syncid .. ":" .. directory .. path
                end)
                log("Normal", "Processing syncing list:\n", table.concat(paths, "\n"))
                spawn(elist, "/usr/sbin/csync2", "-C", config.syncid, "-x")
        end,
        collect = function(agent, exitcode)
                local config = agent.config
                if not agent.isList and agent.etype == "Init" then
                        if exitcode == 0 then
                                log("Normal", "Startup of '", config.syncid, "' instance finished.")
                        elseif config.exitcodes and config.exitcodes[exitcode] == "again" then
                                log("Normal", "Retrying startup of '", config.syncid, "' instance.")
                                return "again"
                        else
                                log("Error", "Failure on startup of '", config.syncid, "' instance.")
                                terminate(-1)
                        end
                        return
                end
                local rc = config.exitcodes and config.exitcodes[exitcode]
                if rc == "die" then
                        return rc
                end
                if agent.isList then
                        if rc == "again" then
                                log("Normal", "Retrying events list on exitcode = ", exitcode)
                        else
                                log("Normal", "Finished events list = ", exitcode)
                        end
                else
                        if rc == "again" then
                                log("Normal", "Retrying ", agent.etype, " on ", agent.sourcePath, " = ", exitcode)
                        else
                                log("Normal", "Finished ", agent.etype, " on ", agent.sourcePath, " = ", exitcode)
                        end
                end
                return rc
        end,
        init = function(event)
                local inlet = event.inlet;
                local config = inlet.getConfig()
                log("Normal", "Recursive startup sync: ", config.syncid, ":", config.source)
                log("Normal", "event: ", event)
                -- spawn(event, "/usr/sbin/csync2", "-xvv")
                spawn(elist, "/usr/sbin/csync2", "-C", config.syncid, "-x")
        end,
                -- spawn(event, "/usr/sbin/csync2", "-C", config.syncid, "-x")
        -- end,
        prepare = function(config)
                if not config.syncid then
                        error("Missing 'syncid' parameter.", 4)
                end
                local c = "csync2_" .. config.syncid .. ".cfg"
                local f, err = io.open("/etc/" .. c, "r")
                if not f then
                        error("Invalid 'syncid' parameter: " .. err, 4)
                end
                f:close()
        end
}

local sources = {
        ["/tmp/test/"] = "common",
}
for key, value in pairs(sources) do
        sync {initSync, source=key, syncid=value}
end
