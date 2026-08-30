local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Smaller Error Frame"],
  description = T["Resizes the error frame to 1 line instead of 3."],
  expansions = { ["vanilla"] = true },
  category = T["Interface"],
  enabled = nil,
})

module.enable = function(self)
  -- Remember the original frame height so repeated enable() calls do not
  -- keep dividing an already-resized frame (1/3, 1/9, 1/27, ...).
  if not self.originalHeight then
    self.originalHeight = UIErrorsFrame:GetHeight()
  end

  local targetHeight = self.originalHeight / 3
  if UIErrorsFrame:GetHeight() ~= targetHeight then
    UIErrorsFrame:SetHeight(targetHeight)
  end
end
