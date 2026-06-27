-------------------------------------------------------------------------------
-- Title: DorqUtilities API Bridge
-------------------------------------------------------------------------------

local Media = DorqUtilities.Media
local Animations = DorqUtilities.Animations

DorqUtilities.RegisterFont = Media.RegisterFont
DorqUtilities.RegisterSound = Media.RegisterSound
DorqUtilities.IterateFonts = Media.IterateFonts
DorqUtilities.IterateSounds = Media.IterateSounds

DorqUtilities.RegisterAnimationStyle = Animations.RegisterAnimationStyle
DorqUtilities.RegisterStickyAnimationStyle = Animations.RegisterStickyAnimationStyle
DorqUtilities.IterateScrollAreas = Animations.IterateScrollAreas
DorqUtilities.DisplayMessage = Animations.DisplayMessage
DorqUtilities.DisplayEvent = Animations.DisplayEvent
