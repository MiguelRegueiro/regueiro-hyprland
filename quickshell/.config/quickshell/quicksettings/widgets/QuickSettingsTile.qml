import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme

// GNOME 43+ style horizontal tile
Rectangle {
    id: tile

    property string label: ""
    property string sublabel: ""
    property string iconOn: ""
    property string iconOff: ""
    property bool toggled: false
    property bool interactive: true
    property bool hasMenu: false
    property bool pillShape: false
    property bool showMenuIndicator: hasMenu
    property bool showIconChip: hasMenu
    property real iconCenterOffsetX: 0
    readonly property bool hovered: tileHover.hovered

    signal clicked()
    signal menuClicked()

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredWidth: 0
    height: 64
    radius: pillShape ? height / 2 : Theme.qsRadius
    color: {
        if (tile.toggled)
            return tile.hovered ? Theme.tileActiveBgHover : Theme.tileActiveBg;

        return tile.hovered ? Theme.qsCardBgHover : Theme.qsCardBg;
    }
    border.width: 1
    border.color: {
        if (tile.toggled)
            return tile.hovered ? Theme.tileActiveBorderHover : Theme.tileActiveBorder;

        return tile.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder;
    }

    HoverHandler {
        id: tileHover

        blocking: false
        enabled: tile.interactive
        cursorShape: Qt.ArrowCursor
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: hasMenu && showMenuIndicator ? 4 : 12
        spacing: 12

        // Icon chip
        Rectangle {
            id: iconCircle

            width: 36
            height: 36
            radius: 18
            color: {
                if (!tile.showIconChip)
                    return "transparent";

                if (tile.toggled)
                    return Qt.rgba(1, 1, 1, tile.hovered ? 0.13 : 0.1);

                return tile.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg;
            }
            border.width: tile.showIconChip ? 1 : 0
            border.color: {
                if (!tile.showIconChip)
                    return "transparent";

                if (tile.toggled)
                    return Qt.rgba(1, 1, 1, tile.hovered ? 0.13 : 0.1);

                return tile.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder;
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: tile.iconCenterOffsetX
                text: tile.toggled ? tile.iconOn : tile.iconOff
                font.family: Theme.fontIcons
                font.pixelSize: 18
                color: tile.toggled ? "white" : Theme.textPrimary
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverAnimDuration
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.hoverAnimDuration
                }

            }

        }

        // Labels (Clicking here opens menu if hasMenu, otherwise toggles)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: tile.label
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.Medium
                color: tile.interactive ? (tile.toggled ? "white" : Theme.textPrimary) : Theme.textDim
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: text.length > 0
                text: tile.sublabel
                font.family: Theme.fontUi
                font.pixelSize: 11
                color: tile.interactive ? (tile.toggled ? Qt.rgba(1, 1, 1, 0.76) : Theme.textDim) : Theme.textDisabled
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

        }

        // Arrow Icon
        Item {
            visible: tile.hasMenu && tile.showMenuIndicator
            Layout.preferredWidth: 28
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                font.family: Theme.fontIcons
                font.pixelSize: 16
                color: tile.toggled ? "white" : Theme.textDim
            }

        }

    }

    MouseArea {
        id: tileActionArea

        anchors.fill: parent
        enabled: tile.interactive
        cursorShape: Qt.ArrowCursor
        onClicked: {
            if (tile.hasMenu)
                tile.menuClicked();
            else
                tile.clicked();
        }
    }

    // Give the left-side icon action a much larger target than the icon itself.
    MouseArea {
        width: 72
        enabled: tile.interactive && tile.hasMenu
        cursorShape: Qt.ArrowCursor
        onClicked: tile.clicked()

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }

    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }

    }

}
