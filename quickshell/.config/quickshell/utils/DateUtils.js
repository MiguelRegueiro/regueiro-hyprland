.pragma library

var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function formatBarTime(date) {
    if (!date) return ""
    var hours   = String(date.getHours()).padStart(2, "0")
    var minutes = String(date.getMinutes()).padStart(2, "0")
    return months[date.getMonth()] + " " + date.getDate() + "  " + hours + ":" + minutes
}

function timeAgo(ms) {
    var seconds = Math.floor((Date.now() - ms) / 1000)
    if (seconds < 60)  return "moments ago"
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60)  return minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    if (hours < 24)    return hours + "h ago"
    return Math.floor(hours / 24) + "d ago"
}
