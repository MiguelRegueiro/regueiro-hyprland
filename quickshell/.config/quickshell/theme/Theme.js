.pragma library

// Bar
var barBg = Qt.rgba(0, 0, 0, 1.0);
var screenFrameBg = Qt.rgba(0, 0, 0, 1.0);
var menuBg = Qt.rgba(0, 0, 0, 1.0);
var popupBg = Qt.rgba(0.075, 0.075, 0.075, 1.0);
var barBorder = Qt.rgba(1, 1, 1, 0.08);
var barHeight = 34;
var barCornerRadius = 16; // matches hyprland rounding = 16
var borderSize = 14; // screen frame thickness -- matches hyprland gaps_out

// Text
var textPrimary = "#f6f5f4";
var textDim = Qt.rgba(0.965, 0.961, 0.957, 0.75);
var textDisabled = Qt.rgba(0.965, 0.961, 0.957, 0.35);

// Interactive
var hoverBg = Qt.rgba(1, 1, 1, 0.11);
var hoverBgStrong = Qt.rgba(1, 1, 1, 0.17);
var activeBg = Qt.rgba(1, 1, 1, 0.18);
var hoverAnimDuration = 75;

// State colors
var accent = "#3584e4";
var green = "#8ff0a4";
var yellow = "#f8e45c";
var red = "#ff7b63";
var blue = "#78aeed";

// Radius
var radiusSmall = 7;

// Fonts
var fontUi = "Adwaita Sans";
var fontFallback = "Cantarell";
var fontIcons = "Symbols Nerd Font Mono";

// Quick Settings
var qsBg = Qt.rgba(0.16, 0.18, 0.24, 0.18);
var qsBorder = Qt.rgba(1, 1, 1, 0.10);
var qsWidth = 400;
var qsRadius = 12;
var qsBarFuseOverlap = 2;
var qsAttachTop = borderSize + qsBarFuseOverlap;
var qsAttachRight = 6;
var qsSurfaceTopLeftRadius = barCornerRadius + 2;
var qsSurfaceTopRightRadius = barCornerRadius;
var qsSurfaceBottomLeftRadius = barCornerRadius + 6;
var qsSurfaceBottomRightRadius = barCornerRadius + 2;
var qsContentPadding = 14;
var qsEdge = Qt.rgba(1, 1, 1, 0.08);
var qsEdgeSoft = Qt.rgba(1, 1, 1, 0.06);
var qsGlow = Qt.rgba(0.28, 0.49, 0.88, 0.08);
var qsRowBg = Qt.rgba(1, 1, 1, 0.08);
var qsRowBgHover = Qt.rgba(1, 1, 1, 0.12);
var qsCardBg = Qt.rgba(0.094, 0.094, 0.094, 0.96);
var qsCardBgHover = Qt.rgba(0.112, 0.112, 0.112, 0.98);
var qsCardBorder = Qt.rgba(1, 1, 1, 0.10);
var qsCardBorderHover = Qt.rgba(1, 1, 1, 0.13);
var qsCardChipBg = Qt.rgba(1, 1, 1, 0.05);
var qsCardChipBgHover = Qt.rgba(1, 1, 1, 0.09);
var qsCardChipBorder = Qt.rgba(1, 1, 1, 0.08);
var qsCardChipBorderHover = Qt.rgba(1, 1, 1, 0.11);

// Notification center
var ncWidth = 460;
var toastWidth = 500;
var ncAttachTop = qsBarFuseOverlap + 10;
var ncSurfaceTopLeftRadius = barCornerRadius + 2;
var ncSurfaceTopRightRadius = barCornerRadius + 2;
var ncSurfaceBottomLeftRadius = barCornerRadius + 6;
var ncSurfaceBottomRightRadius = barCornerRadius + 6;

// Clipboard
var clipboardWidth = 560;
var clipboardHeight = 620;
var clipboardAttachBottom = borderSize;
var clipboardBorderFuseInset = 2;
var clipboardSurfaceTopLeftRadius = barCornerRadius + 6;
var clipboardSurfaceTopRightRadius = barCornerRadius + 6;

// Launcher
var launcherWidth = 720;
var launcherHeight = 540;
var launcherAttachBottom = borderSize;
var launcherSurfaceTopLeftRadius = barCornerRadius + 6;
var launcherSurfaceTopRightRadius = barCornerRadius + 6;

// Tile active state -- accent blue (#3584e4) at two opacities
var tileActiveBg = Qt.rgba(0.208, 0.518, 0.894, 0.82);
var tileActiveBgHover = Qt.rgba(0.208, 0.518, 0.894, 0.92);
var tileActiveBorder = Qt.rgba(0.82, 0.90, 1.0, 0.18);
var tileActiveBorderHover = Qt.rgba(0.84, 0.92, 1.0, 0.22);

// Screen identity
var primaryScreen = "eDP-1";

// Timings (ms)
var hoverCloseDelay = 140;
var osdTimeout = 1500;
var slowPollInterval = 10000;
var inputPollInterval = 250;
var networkPollInterval = 3000;
var statsFastInterval = 2000;
var statsSlowInterval = 5000;
var brightnessPollInterval = 2000;
var audioPollFastInterval = 500;
var audioPollSlowInterval = 1500;
var audioRefreshDelay = 150;
var audioOptimisticReset = 700;
var mediaActionRefreshDelay = 180;
var notificationHoldDelay = 500;
var brightnessRefreshDelay = 160;
var appVolumePollInterval = 1200;
var panelTickInterval = 40;

// Widget hover color durations (ms)
var sliderColorDuration = 100;
var popupButtonColorDuration = 90;
var outputItemColorDuration = 85;

// Panel animation durations (ms)
var panelOpenDuration = 250;
var panelCloseDuration = 145;
var qsPageSlideDuration = 130;
var qsPageFadeDuration = 110;
var qsHeightDuration = 120;
var batteryFillDuration = 200;

// OSD animation durations (ms)
var osdSelectorDuration = 100;
var osdTextColorDuration = 150;

// Toast animation durations (ms)
var toastOpenDuration = 220;
var toastCloseDuration = 150;
var toastSlideDuration = 180;

// Thresholds
var batteryLowThreshold = 15;
var cpuWarnThreshold = 70;
var cpuCritThreshold = 90;
