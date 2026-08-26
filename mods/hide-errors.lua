local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Hide Errors"],
  description = T["Hides and ignores all Lua errors produced by broken addons."],
  expansions = { ["vanilla"] = true },
  enabled = nil,
})

module.enable = function(self)
  -- Silence the client's error output without replacing Lua's global error()
  -- function. Addons may rely on error() to abort invalid execution paths.
  if not self.errorHandler then
    self.errorHandler = function() end
  end

  seterrorhandler(self.errorHandler)
end
