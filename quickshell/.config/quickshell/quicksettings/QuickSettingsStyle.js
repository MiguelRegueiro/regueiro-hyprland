.pragma library

// Local Quick Settings palette. This deliberately does not reuse the shared
// qs tokens, because notification surfaces consume those too.
var surfaceBg = Qt.rgba(0.115, 0.12, 0.135, 0.84);
var edge = Qt.rgba(1, 1, 1, 0.12);
var edgeSoft = Qt.rgba(0.56, 0.58, 0.62, 0.22);

// Layer-shell popup surfaces: audio outputs, power actions, and Wi-Fi credentials.
var popupSurfaceBg = surfaceBg;
var popupSurfaceOutline = edge;
var popupSurfaceRadius = 24;
var popupSurfaceRevealOffset = 18;
var popupSurfaceShadow = Qt.rgba(0, 0, 0, 0.46);
var popupSurfaceShadowBlur = 1.04;
var popupSurfaceShadowOffsetY = 1;
var popupSurfaceBlurMax = 48;

var cardBg = Qt.rgba(1, 1, 1, 0.065);
var cardBgHover = Qt.rgba(1, 1, 1, 0.10);
var cardActiveBg = Qt.rgba(1, 1, 1, 0.12);
var cardBorder = Qt.rgba(0.56, 0.58, 0.62, 0.22);
var cardBorderHover = Qt.rgba(0.62, 0.64, 0.68, 0.35);
var cardActiveBorder = Qt.rgba(0.62, 0.64, 0.68, 0.35);

var chipBg = Qt.rgba(1, 1, 1, 0.075);
var chipBgHover = Qt.rgba(1, 1, 1, 0.12);
var chipBorder = Qt.rgba(0.56, 0.58, 0.62, 0.20);
var chipBorderHover = Qt.rgba(0.62, 0.64, 0.68, 0.32);

var tileActiveBg = "#3266bd";
var tileActiveBgHover = "#3a73d0";
var tileActiveBorder = "transparent";
var tileActiveBorderHover = "transparent";

var mediaControlBg = Qt.rgba(1, 1, 1, 0.10);
var mediaControlBgHover = Qt.rgba(1, 1, 1, 0.16);
