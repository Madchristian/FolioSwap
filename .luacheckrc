std = "lua51"
max_line_length = 120
exclude_files = { ".lua/**", ".luarocks/**", ".release/**" }

globals = {
  "FolioSwapDB", "SLASH_FOLIOSWAP1", "SLASH_FOLIOSWAP2", "SlashCmdList", "StaticPopupDialogs",
}
read_globals = {
  "C_Traits", "C_Spell", "CreateFrame", "GetLocale", "GetSpecialization", "GetSpecializationInfo",
  "InCombatLockdown", "hooksecurefunc", "StaticPopup_Show", "RunesOfPowerMixin", "ExpansionLandingPage",
  "ACCEPT", "CANCEL",
}

files["spec/**"] = {
  std = "+busted",
  globals = { "C_Traits", "C_Spell", "GetLocale", "InCombatLockdown", "GetSpecialization", "GetSpecializationInfo" },
}
