.pragma library

// Bar
var barBg       = Qt.rgba(0, 0, 0, 1.0)
var screenFrameBg = Qt.rgba(0, 0, 0, 1.0)
var menuBg     = Qt.rgba(0, 0, 0, 1.0)
var popupBg    = Qt.rgba(0.075, 0.075, 0.075, 1.0)
var barBorder   = Qt.rgba(1, 1, 1, 0.08)
var barHeight   = 34
var barCornerRadius = 16  // matches hyprland rounding = 16
var borderSize      = 14  // screen frame thickness — matches hyprland gaps_out

// Text
var textPrimary  = "#f6f5f4"
var textDim      = Qt.rgba(0.965, 0.961, 0.957, 0.75)
var textDisabled = Qt.rgba(0.965, 0.961, 0.957, 0.35)

// Interactive
var hoverBg      = Qt.rgba(1, 1, 1, 0.11)
var hoverBgStrong = Qt.rgba(1, 1, 1, 0.17)
var activeBg     = Qt.rgba(1, 1, 1, 0.18)
var hoverAnimDuration = 75

// State colors
var accent  = "#3584e4"
var green   = "#8ff0a4"
var yellow  = "#f8e45c"
var red     = "#ff7b63"
var blue    = "#78aeed"

// Radius
var radiusSmall = 7

// Fonts
var fontUi      = "Adwaita Sans"
var fontFallback = "Cantarell"
var fontIcons   = "Symbols Nerd Font Mono"

// Quick Settings
var qsBg        = Qt.rgba(0.16, 0.18, 0.24, 0.18)
var qsBorder    = Qt.rgba(1, 1, 1, 0.10)
var qsWidth     = 400
var qsRadius    = 12
var qsBarFuseOverlap = 2
var qsAttachTop = borderSize + qsBarFuseOverlap
var qsAttachRight = 6
var qsSurfaceTopLeftRadius     = barCornerRadius + 2
var qsSurfaceTopRightRadius    = barCornerRadius
var qsSurfaceBottomLeftRadius  = barCornerRadius + 6
var qsSurfaceBottomRightRadius = barCornerRadius + 2
var qsContentPadding = 14
var qsEdge      = Qt.rgba(1, 1, 1, 0.08)
var qsEdgeSoft  = Qt.rgba(1, 1, 1, 0.06)
var qsGlow      = Qt.rgba(0.28, 0.49, 0.88, 0.08)
var qsRowBg     = Qt.rgba(1, 1, 1, 0.08)
var qsRowBgHover = Qt.rgba(1, 1, 1, 0.12)

// Notification center
var ncWidth     = 460
var toastWidth  = 500
var ncAttachTop = qsBarFuseOverlap + 10
var ncSurfaceTopLeftRadius     = barCornerRadius + 2
var ncSurfaceTopRightRadius    = barCornerRadius + 2
var ncSurfaceBottomLeftRadius  = barCornerRadius + 6
var ncSurfaceBottomRightRadius = barCornerRadius + 6

// Tile active state — accent blue (#3584e4) at two opacities
var tileActiveBg      = Qt.rgba(0.208, 0.518, 0.894, 0.85)
var tileActiveBgHover = Qt.rgba(0.208, 0.518, 0.894, 1.0)
