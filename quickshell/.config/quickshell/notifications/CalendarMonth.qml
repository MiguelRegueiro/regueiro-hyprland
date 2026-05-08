import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme/Theme.js" as Theme

Item {
    id: root

    property int monthOffset: 0
    readonly property var today: clock.date
    readonly property var visibleMonth: new Date(root.today.getFullYear(), root.today.getMonth() + root.monthOffset, 1)
    readonly property int visibleYear: root.visibleMonth.getFullYear()
    readonly property int visibleMonthIndex: root.visibleMonth.getMonth()
    readonly property int firstWeekday: (new Date(root.visibleYear, root.visibleMonthIndex, 1).getDay() + 6) % 7
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var weekdayNamesLong: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property string monthTitle: `${root.monthNames[root.visibleMonthIndex]} ${root.visibleYear}`
    readonly property string todayTitle: `${root.weekdayNamesLong[root.today.getDay()]}, ${root.monthNames[root.today.getMonth()]} ${root.today.getDate()}`

    function cellDate(index) {
        return new Date(root.visibleYear, root.visibleMonthIndex, index - root.firstWeekday + 1);
    }

    function isSameDay(left, right) {
        return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
    }

    implicitHeight: content.implicitHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        id: content

        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 48

            Column {
                spacing: 3

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.monthTitle
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.todayTitle
                    color: Theme.textDim
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }

            }

            Row {
                spacing: 6

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: previousHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg
                    border.width: 1
                    border.color: previousHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Theme.textPrimary
                        font.family: Theme.fontUi
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: previousHover

                        blocking: false
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.monthOffset -= 1
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

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: nextHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg
                    border.width: 1
                    border.color: nextHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Theme.textPrimary
                        font.family: Theme.fontUi
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: nextHover

                        blocking: false
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.monthOffset += 1
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

            }

        }

        RowLayout {
            width: parent.width
            spacing: 4

            Repeater {
                model: root.weekdayNames

                delegate: Text {
                    required property string modelData

                    Layout.fillWidth: true
                    text: modelData
                    color: Theme.textDisabled
                    font.family: Theme.fontUi
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

        Grid {
            id: dayGrid

            width: parent.width
            columns: 7
            columnSpacing: 4
            rowSpacing: 4
            readonly property real dayWidth: Math.max(1, Math.floor((width - columnSpacing * 6) / 7))

            Repeater {
                model: 42

                delegate: Rectangle {
                    required property int index
                    readonly property var dateValue: root.cellDate(index)
                    readonly property bool inVisibleMonth: dateValue.getMonth() === root.visibleMonthIndex
                    readonly property bool isToday: root.isSameDay(dateValue, root.today)
                    readonly property bool isWeekend: dateValue.getDay() === 0 || dateValue.getDay() === 6
                    readonly property color restingColor: isToday ? Theme.tileActiveBg : "transparent"
                    readonly property color hoverColor: isToday ? Theme.tileActiveBgHover : Theme.qsRowBg

                    width: dayGrid.dayWidth
                    height: 32
                    radius: 8
                    color: dayHover.hovered && inVisibleMonth ? hoverColor : restingColor
                    border.width: isToday ? 1 : 0
                    border.color: Theme.tileActiveBorderHover

                    Text {
                        anchors.centerIn: parent
                        text: String(parent.dateValue.getDate())
                        color: parent.isToday ? Theme.textPrimary : parent.inVisibleMonth ? (parent.isWeekend ? Theme.textDim : Theme.textPrimary) : Theme.textDisabled
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: parent.isToday ? Font.DemiBold : Font.Medium
                    }

                    HoverHandler {
                        id: dayHover

                        blocking: false
                        cursorShape: Qt.ArrowCursor
                    }

                }

            }

        }

        Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: todayHover.hovered && root.monthOffset !== 0 ? Theme.qsRowBgHover : Theme.qsRowBg
            border.width: 1
            border.color: todayHover.hovered && root.monthOffset !== 0 ? Theme.qsCardBorderHover : Theme.qsCardBorder
            opacity: root.monthOffset === 0 ? 0.45 : 1

            Text {
                anchors.centerIn: parent
                text: "Today"
                color: Theme.textPrimary
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: todayHover

                enabled: root.monthOffset !== 0
                blocking: false
                cursorShape: root.monthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: root.monthOffset !== 0
                onTapped: root.monthOffset = 0
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

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.hoverAnimDuration
                }

            }

        }

    }

}
