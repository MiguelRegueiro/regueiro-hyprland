import QtQuick
import Quickshell
import "../theme/Theme.js" as Theme

Item {
    id: root

    property int monthOffset: 0
    property int selectedYear: -1
    property int selectedMonth: -1
    property int selectedDay: -1
    property bool followToday: true
    property int lastTodayYear: -1
    property int lastTodayMonth: -1
    property int lastTodayDay: -1
    readonly property var today: clock.date
    readonly property var visibleMonth: new Date(root.today.getFullYear(), root.today.getMonth() + root.monthOffset, 1)
    readonly property int visibleYear: root.visibleMonth.getFullYear()
    readonly property int visibleMonthIndex: root.visibleMonth.getMonth()
    readonly property int firstWeekday: (new Date(root.visibleYear, root.visibleMonthIndex, 1).getDay() + 6) % 7
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["月", "火", "水", "木", "金", "土", "日"]
    readonly property var weekdayNamesLong: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property string monthTitle: `${root.monthNames[root.visibleMonthIndex]} ${root.visibleYear}`
    readonly property string todayTitle: `${root.weekdayNamesLong[root.today.getDay()]}, ${root.monthNames[root.today.getMonth()]} ${root.today.getDate()}`
    readonly property bool todayButtonEnabled: root.monthOffset !== 0 || !root.isSelectedDay(root.today)
    readonly property int calendarColumns: 7
    readonly property real calendarSpacing: 4
    readonly property real calendarCellWidth: Math.max(1, Math.floor((root.width - root.calendarSpacing * (root.calendarColumns - 1)) / root.calendarColumns))
    readonly property real calendarGridWidth: root.calendarCellWidth * root.calendarColumns + root.calendarSpacing * (root.calendarColumns - 1)

    function cellDate(index) {
        return new Date(root.visibleYear, root.visibleMonthIndex, index - root.firstWeekday + 1);
    }

    function isSameDay(left, right) {
        return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
    }

    function isSelectedDay(value) {
        return root.selectedYear === value.getFullYear() && root.selectedMonth === value.getMonth() && root.selectedDay === value.getDate();
    }

    function selectDate(value) {
        root.selectedYear = value.getFullYear();
        root.selectedMonth = value.getMonth();
        root.selectedDay = value.getDate();
    }

    function activateDate(value) {
        root.selectDate(value);
        root.followToday = root.isSameDay(value, root.today);
        root.monthOffset = (value.getFullYear() - root.today.getFullYear()) * 12 + value.getMonth() - root.today.getMonth();
    }

    function captureToday() {
        root.lastTodayYear = root.today.getFullYear();
        root.lastTodayMonth = root.today.getMonth();
        root.lastTodayDay = root.today.getDate();
    }

    function selectedLastToday() {
        return root.selectedYear === root.lastTodayYear && root.selectedMonth === root.lastTodayMonth && root.selectedDay === root.lastTodayDay;
    }

    function handleTodayChanged() {
        const previousTodayKnown = root.lastTodayYear >= 0;
        const dateChanged = !previousTodayKnown || root.today.getFullYear() !== root.lastTodayYear || root.today.getMonth() !== root.lastTodayMonth || root.today.getDate() !== root.lastTodayDay;
        if (!dateChanged)
            return ;

        const shouldFollowToday = root.followToday || root.selectedLastToday();
        root.captureToday();
        if (shouldFollowToday) {
            root.selectDate(root.today);
            root.monthOffset = 0;
            root.followToday = true;
        }
    }

    implicitHeight: content.implicitHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    readonly property color secondaryTextColor: Qt.rgba(1, 1, 1, 0.88)
    readonly property color mutedTextColor: Qt.rgba(1, 1, 1, 0.68)

    Component.onCompleted: {
        root.selectDate(root.today);
        root.captureToday();
    }

    onTodayChanged: root.handleTodayChanged()

    Column {
        id: content

        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 48

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                text: root.monthTitle + "  ·  " + root.weekdayNamesLong[root.today.getDay()] + " " + root.today.getDate()
                color: Theme.textPrimary
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 6

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 8
                    color: "transparent"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: "󰅁"
                        color: previousHover.hovered ? Theme.textPrimary : root.secondaryTextColor
                        font.family: Theme.fontIcons
                        font.pixelSize: 16
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
                    width: 30
                    height: 30
                    radius: 8
                    color: "transparent"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: "󰅂"
                        color: nextHover.hovered ? Theme.textPrimary : root.secondaryTextColor
                        font.family: Theme.fontIcons
                        font.pixelSize: 16
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

        Item {
            width: parent.width
            height: weekdayRow.implicitHeight

            Row {
                id: weekdayRow

                anchors.horizontalCenter: parent.horizontalCenter
                width: root.calendarGridWidth
                spacing: root.calendarSpacing

                Repeater {
                    model: root.weekdayNames

                    delegate: Text {
                        required property string modelData

                        width: root.calendarCellWidth
                        text: modelData
                        color: root.mutedTextColor
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                    }

                }
            }

        }

        Item {
            width: parent.width
            height: dayGrid.implicitHeight

            Grid {
                id: dayGrid

                anchors.horizontalCenter: parent.horizontalCenter
                width: root.calendarGridWidth
                columns: root.calendarColumns
                columnSpacing: root.calendarSpacing
                rowSpacing: root.calendarSpacing
                readonly property real dayWidth: root.calendarCellWidth

                WheelHandler {
                    onWheel: (event) => {
                        if (event.angleDelta.y > 0)
                            root.monthOffset -= 1;
                        else if (event.angleDelta.y < 0)
                            root.monthOffset += 1;

                    }
                }

                Repeater {
                    model: 42

                    delegate: Rectangle {
                        required property int index
                        readonly property var dateValue: root.cellDate(index)
                        readonly property bool inVisibleMonth: dateValue.getMonth() === root.visibleMonthIndex
                        readonly property bool isToday: root.isSameDay(dateValue, root.today)
                        readonly property bool selected: root.isSelectedDay(dateValue)
                        readonly property bool isWeekend: dateValue.getDay() === 0 || dateValue.getDay() === 6

                        width: dayGrid.dayWidth
                        height: 34
                        color: "transparent"
                        border.width: 0

                        Rectangle {
                            visible: parent.selected || (dayHover.hovered && parent.inVisibleMonth) || (parent.isToday && !parent.selected)
                            width: Math.min(parent.width, parent.height)
                            height: width
                            radius: width / 2
                            color: parent.selected ? Theme.tileActiveBg : (dayHover.hovered && parent.inVisibleMonth ? Theme.qsRowBg : "transparent")
                            border.width: parent.isToday && !parent.selected ? 1 : 0
                            border.color: Theme.tileActiveBorderHover
                            anchors.centerIn: parent
                        }

                        Text {
                            anchors.centerIn: parent
                            text: String(parent.dateValue.getDate())
                            color: parent.selected ? Theme.textPrimary : parent.inVisibleMonth ? root.secondaryTextColor : root.mutedTextColor
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            font.weight: parent.selected || parent.isToday ? Font.DemiBold : Font.Medium
                        }

                        HoverHandler {
                            id: dayHover

                            blocking: false
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: root.activateDate(dateValue)
                        }

                    }

                }

            }

        }

        Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: todayHover.hovered && root.todayButtonEnabled ? Theme.qsRowBgHover : Theme.qsRowBg
            border.width: 1
            border.color: todayHover.hovered && root.todayButtonEnabled ? Theme.qsCardBorderHover : Theme.qsCardBorder
            opacity: root.todayButtonEnabled ? 1 : 0.45

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

                enabled: root.todayButtonEnabled
                blocking: false
                cursorShape: root.todayButtonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: root.todayButtonEnabled
                onTapped: root.activateDate(root.today)
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
