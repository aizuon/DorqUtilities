-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text French Localization
-- Author: Mikord
-- French Translation by: Calthas, Devfool
-------------------------------------------------------------------------------

-- Don't do anything if the locale isn't French.
if (GetLocale() ~= "frFR") then return end

-- Local reference for faster access.
local L = DorqUtilities.translations

-------------------------------------------------------------------------------
-- French localization
-------------------------------------------------------------------------------

------------------------------
-- Fonts
------------------------------

L.FONT_FILES = {
	["MSBT Adventure"]		= "Interface\\Addons\\DorqUtilities\\Fonts\\adventure.ttf",
	["MSBT Bazooka"]		= "Interface\\Addons\\DorqUtilities\\Fonts\\bazooka.ttf",
	["MSBT Cooline"]		= "Interface\\Addons\\DorqUtilities\\Fonts\\cooline.ttf",
	["MSBT Diogenes"]		= "Interface\\Addons\\DorqUtilities\\Fonts\\diogenes.ttf",
	["MSBT Ginko"]			= "Interface\\Addons\\DorqUtilities\\Fonts\\ginko.ttf",
	["MSBT Heroic"]			= "Interface\\Addons\\DorqUtilities\\Fonts\\heroic.ttf",
	["MSBT Porky"]			= "Interface\\Addons\\DorqUtilities\\Fonts\\porky.ttf",
	["MSBT Talisman"]		= "Interface\\Addons\\DorqUtilities\\Fonts\\talisman.ttf",
	["MSBT Transformers"]	= "Interface\\Addons\\DorqUtilities\\Fonts\\transformers.ttf",
	["MSBT Yellowjacket"]	= "Interface\\Addons\\DorqUtilities\\Fonts\\yellowjacket.ttf",
}

L.DEFAULT_FONT_NAME = "MSBT Porky"


------------------------------
-- Commands
------------------------------

L.COMMAND_USAGE = {
	"Usage: " .. DorqUtilities.COMMAND .. " <command> [params]",
	" Commande:",
	"  " .. L.COMMAND_RESET .. " - Restaure les paramètres par défaut.",
	"  " .. L.COMMAND_DISABLE .. " - Désactive l'addon.",
	"  " .. L.COMMAND_ENABLE .. " - Active l'addon.",
	"  " .. L.COMMAND_SHOWVER .. " - Affiche la version actuelle.",
	"  " .. L.COMMAND_HELP .. " - Affiche l'aide des commandes.",
}


------------------------------
-- Output messages
------------------------------

L.MSG_DISABLE				= "Addon désactivé."
L.MSG_ENABLE				= "Addon activé."
L.MSG_PROFILE_RESET			= "Profil réinitialisé"
L.MSG_HITS					= "Coups"
L.MSG_CRIT					= "Crit"
L.MSG_CRITS					= "Crits"
L.MSG_MULTIPLE_TARGETS		= "Multiples"
L.MSG_READY_NOW				= "Disponible"


------------------------------
-- Scroll area messages
------------------------------

L.MSG_INCOMING			= "Entrant"
L.MSG_OUTGOING			= "Sortant"
L.MSG_NOTIFICATION		= "Alertes"
L.MSG_STATIC			= "Statique"


---------------------------------------
-- Master profile event output messages
---------------------------------------

L.MSG_COMBAT					= "Combat"
L.MSG_DISPEL					= "Dissiper"
--L.MSG_CHI_FULL					= "Full Chi"
L.MSG_CP						= "CP"
L.CP_FULL						= "Finissez-le"
L.MSG_HOLY_POWER_FULL			= "Full Holy Power"
--L.MSG_SHADOW_ORBS_FULL			= "Full Shadow Orbs"
L.MSG_KILLING_BLOW				= "Coup Fatal"
L.MSG_TRIGGER_LOW_HEALTH		= "Vie Faible"
L.MSG_TRIGGER_LOW_MANA			= "Mana Faible"
L.MSG_TRIGGER_LOW_PET_HEALTH	= "Vie du familier faible"

