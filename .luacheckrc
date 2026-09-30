std = "lua51"
max_line_length = 120
exclude_files = { ".lua/**", ".luarocks/**", ".release/**" }

globals = {
  "FolioSwapDB", "SLASH_FOLIOSWAP1", "SLASH_FOLIOSWAP2", "SlashCmdList", "StaticPopupDialogs",
}
read_globals = {
  "C_Traits", "C_Spell", "C_Timer", "CreateFrame", "CreateColor", "GetLocale", "GetSpecialization", "GetSpecializationInfo",
  "InCombatLockdown", "hooksecurefunc", "StaticPopup_Show", "StaticPopup_StandardEditBoxOnEscapePressed",
  "RunesOfPowerMixin", "ExpansionLandingPage", "ACCEPT", "CANCEL", "UIParent", "UISpecialFrames", "Settings",
}

files["spec/**"] = {
  std = "+busted",
  globals = {
    "C_Traits", "C_Spell", "C_Timer", "GetLocale", "InCombatLockdown", "GetSpecialization", "GetSpecializationInfo",
  },
}
