.pragma library

// Bar
var barBg = Qt.rgba(0.015, 0.02, 0.035, 0.68);
var screenFrameBg = "#000000";
var menuBg = screenFrameBg;
var popupBg = "#131313";
var barBorder = Qt.rgba(0.88, 0.92, 1, 0.11);
var barHeight = 28;
var barItemHeight = 26;
var barCornerRadius = 16; // matches hyprland rounding = 16
var borderSize = 14; // screen frame thickness -- matches hyprland gaps_out
var frameTopOverlap = 1; // hide fractional-scale seam below the top bar

// Text
var textPrimary = "#f6f5f4";
var textDim = Qt.rgba(0.965, 0.961, 0.957, 0.75);
var textDisabled = Qt.rgba(0.965, 0.961, 0.957, 0.35);

// Interactive
var hoverBg = Qt.rgba(0.72, 0.80, 0.96, 0.12);
var hoverBgStrong = Qt.rgba(0.72, 0.80, 0.96, 0.18);
var activeBg = Qt.rgba(0.72, 0.80, 0.96, 0.22);
var workspaceActiveBg = "#343438";
var workspaceActiveHoverBg = "#414146";
var workspaceActiveBorder = Qt.rgba(1, 1, 1, 0.24);
var hoverAnimDuration = 105;

// State colors
var accent = "#3f6fd5";
var green = "#8ff0a4";
var yellow = "#f8e45c";
var red = "#ff7b63";
var blue = "#78aeed";
var urgentAccent = Qt.rgba(0.47, 0.68, 0.93, 0.72);
var urgentBg = Qt.rgba(0.47, 0.68, 0.93, 0.06);
var urgentBorder = Qt.rgba(0.47, 0.68, 0.93, 0.16);
var urgentBorderHover = Qt.rgba(0.47, 0.68, 0.93, 0.22);

// Radius
var radiusSmall = 7;

// Fonts
var fontUi = "Adwaita Sans";
var fontFallback = "Cantarell";
var fontIcons = "Symbols Nerd Font Mono";
var fontSizeDelta = 0;

// Quick Settings
var qsBg = Qt.rgba(0.09, 0.11, 0.15, 0.96);
var qsSurfaceBg = Qt.rgba(0.063, 0.075, 0.106, 0.68);
var qsBorder = Qt.rgba(0.82, 0.88, 1, 0.14);
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
var qsApplicationVolumeMaxHeight = 216;
var qsEdge = Qt.rgba(0.82, 0.88, 1, 0.13);
var qsEdgeSoft = Qt.rgba(0.82, 0.88, 1, 0.08);
var qsGlow = Qt.rgba(0.28, 0.49, 0.88, 0.12);
var qsRowBg = Qt.rgba(0.58, 0.68, 0.86, 0.10);
var qsRowBgHover = Qt.rgba(0.58, 0.68, 0.86, 0.16);
var qsCardBg = Qt.rgba(0.106, 0.114, 0.129, 0.54);
var qsCardBgHover = Qt.rgba(0.106, 0.114, 0.129, 0.66);
var qsCardActiveBg = Qt.rgba(0.15, 0.16, 0.18, 0.66);
var qsCardBorder = Qt.rgba(0.82, 0.88, 1, 0.12);
var qsCardBorderHover = Qt.rgba(0.82, 0.88, 1, 0.19);
var qsCardActiveBorder = Qt.rgba(0.62, 0.74, 0.96, 0.25);
var qsCardChipBg = Qt.rgba(0.72, 0.80, 0.96, 0.08);
var qsCardChipBgHover = Qt.rgba(0.72, 0.80, 0.96, 0.14);
var qsCardChipBorder = Qt.rgba(0.82, 0.88, 1, 0.10);
var qsCardChipBorderHover = Qt.rgba(0.82, 0.88, 1, 0.16);

// Notification center
var ncWidth = 760;
var toastWidth = 500;
var notificationImageSize = 88;
var notificationImageCompactSize = 72;
var notificationImageMinimalSize = 64;
var ncAttachTop = qsBarFuseOverlap + 10;
var ncSurfaceTopLeftRadius = barCornerRadius + 2;
var ncSurfaceTopRightRadius = barCornerRadius + 2;
var ncSurfaceBottomLeftRadius = barCornerRadius + 6;
var ncSurfaceBottomRightRadius = barCornerRadius + 6;

// Bottom-center panels
var bottomPanelWidth = 760;
var bottomPanelHeight = 630;
var bottomPanelBg = Qt.rgba(0.063, 0.075, 0.106, 0.68);
var notificationPanelBg = Qt.rgba(0.063, 0.075, 0.106, 0.54);
var notificationCardBg = Qt.rgba(0.106, 0.114, 0.129, 0.54);
var notificationCardBgHover = Qt.rgba(0.106, 0.114, 0.129, 0.66);
var notificationCardBorder = Qt.rgba(0.851, 0.867, 0.902, 0.20);
var notificationCardBorderHover = Qt.rgba(0.851, 0.867, 0.902, 0.32);
var bottomPanelSearchBg = Qt.rgba(0.106, 0.114, 0.129, 0.30);
var bottomPanelCardBg = Qt.rgba(0.106, 0.114, 0.129, 0.20);
var bottomPanelCardBgHover = Qt.rgba(0.106, 0.114, 0.129, 0.30);
var bottomPanelCardActiveBg = Qt.rgba(0.18, 0.20, 0.24, 0.42);
var bottomPanelOutline = Qt.rgba(0.851, 0.867, 0.902, 0.44);
var bottomPanelTextPrimary = "#ffffff";
var bottomPanelTextSecondary = Qt.rgba(1, 1, 1, 0.78);
var bottomPanelTextMuted = Qt.rgba(1, 1, 1, 0.56);
var bottomPanelCardBorder = Qt.rgba(0.75, 0.77, 0.81, 0.12);
var bottomPanelCardBorderHover = Qt.rgba(0.75, 0.77, 0.81, 0.20);
var bottomPanelCardActiveBorder = Qt.rgba(0.75, 0.80, 0.88, 0.28);

// Clipboard
var clipboardWidth = bottomPanelWidth;
var clipboardHeight = bottomPanelHeight;
var clipboardAttachBottom = borderSize;
var clipboardBorderFuseInset = 2;
var clipboardSurfaceTopLeftRadius = barCornerRadius + 6;
var clipboardSurfaceTopRightRadius = barCornerRadius + 6;

// Launcher
var launcherWidth = bottomPanelWidth;
var launcherHeight = bottomPanelHeight;
var launcherAttachBottom = borderSize;
var launcherSurfaceTopLeftRadius = barCornerRadius + 6;
var launcherSurfaceTopRightRadius = barCornerRadius + 6;

// Tile active state -- accent blue (#3584e4) at two opacities
var tileActiveBg = "#264fa8";
var tileActiveBgHover = "#2f64c9";
var tileActiveBorder = Qt.rgba(0.60, 0.75, 1.0, 0.24);
var tileActiveBorderHover = Qt.rgba(0.66, 0.80, 1.0, 0.32);

// Screen identity
var primaryScreen = "eDP-1";

// Timings (ms)
var hoverCloseDelay = 140;
var osdTimeout = 1500;
var slowPollInterval = 10000;
var inputPollInterval = 250;
var networkPollInterval = 3000;
var sshSessionsPollInterval = 3000;
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
// Widget hover color durations (ms)
var sliderColorDuration = 100;
var popupButtonColorDuration = 90;
var outputItemColorDuration = 85;

// Panel animation durations (ms)
var panelOpenDuration = 140;
var panelCloseDuration = 140;
var panelOpenSpatialDuration = 210;
var panelSnappyOpenDuration = 180;
var topBarMenuOpenDuration = 105;
var topBarMenuCloseDuration = 55;
var qsPageSlideDuration = 210;
var qsPageFadeDuration = 145;
var qsHeightDuration = 180;
var batteryFillDuration = 200;

// Material 3 motion curves (caelestia-derived)
// Each entry is a flat array of cubic Bezier control points: [c1x, c1y, c2x, c2y, endX, endY, ...].
// Spatial curves have c1.y > 1 -> overshoot, used for organic spring-like motion on opens.
var curveStandard          = [0.2, 0, 0, 1, 1, 1];
var curveStandardAccel     = [0.3, 0, 1, 1, 1, 1];
var curveStandardDecel     = [0, 0, 0, 1, 1, 1];
var curveEmphasized        = [0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1];
var curveEmphasizedAccel   = [0.3, 0, 0.8, 0.15, 1, 1];
var curveEmphasizedDecel   = [0.05, 0.7, 0.1, 1, 1, 1];
var curveDefaultSpatial    = [0.38, 1.21, 0.22, 1, 1, 1];
var curveFastSpatial       = [0.42, 1.67, 0.21, 0.9, 1, 1];
var curveSlowSpatial       = [0.39, 1.29, 0.35, 0.98, 1, 1];
var curveDefaultEffects    = [0.34, 0.8, 0.34, 1, 1, 1];
var curveFastEffects       = [0.31, 0.94, 0.34, 1, 1, 1];
var curveSlowEffects       = [0.34, 0.88, 0.34, 1, 1, 1];

// M3 motion durations (ms)
var animDurSmall            = 200;
var animDurNormal           = 400;
var animDurLarge            = 600;
var animDurExtraLarge       = 1000;
var animDurFastSpatial      = 350;
var animDurDefaultSpatial   = 500;
var animDurSlowSpatial      = 650;
var animDurFastEffects      = 150;
var animDurDefaultEffects   = 200;
var animDurSlowEffects      = 300;

// OSD animation durations (ms)
var osdSelectorDuration = 100;
var osdTextColorDuration = 150;

// Toast animation durations (ms)
var toastOpenDuration = 220;
var toastCloseDuration = 150;
var toastSlideDuration = 180;

// Thresholds
var batteryLowThreshold = 25;
var batteryCriticalThreshold = 15;
var cpuWarnThreshold = 70;
var cpuCritThreshold = 90;
