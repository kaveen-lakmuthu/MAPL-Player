.pragma library

function formatTime(seconds) {
    if (isNaN(seconds) || seconds < 0) return "0:00"
    var mins = Math.floor(seconds / 60)
    var secs = Math.floor(seconds % 60)
    return mins + ":" + (secs < 10 ? "0" : "") + secs
}

function isVideo(url) {
    var lower = url.toString().toLowerCase()
    var extensions = ["mp4", "mkv", "webm", "avi", "mov", "flv", "m4v", "ogv", "ts", "wmv", "3gp", "mpg", "mpeg"]
    return extensions.some(function(extension) { return lower.endsWith("." + extension) })
}
