.pragma library
.import "MediaUtils.js" as MediaUtils

function parseSRT(srtText) {
    var chunks = [];
    var text = srtText.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    var blocks = text.split("\n\n");

    for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i].trim();
        if (block === "") continue;

        var lines = block.split("\n");
        if (lines.length < 2) continue;

        var timeLine = lines[1];
        var times = timeLine.split("-->");
        if (times.length !== 2) {
            timeLine = lines[0];
            times = timeLine.split("-->");
            if (times.length !== 2) continue;
            lines.unshift("");
        }

        var startStr = times[0].trim();
        var endStr = times[1].trim();

        var startSec = parseSRTTime(startStr);
        var endSec = parseSRTTime(endStr);

        var textLines = [];
        for (var j = 2; j < lines.length; j++) {
            textLines.push(lines[j]);
        }
        var textStr = textLines.join("\n").trim();
        textStr = textStr.replace(/\{[^\}]*\}/g, "");
        textStr = textStr.replace(/\\N/g, "\n").replace(/\\n/g, "\n").replace(/\\h/g, " ");
        textStr = textStr.replace(/<[^>]*>/g, "");

        chunks.push({
            start: startSec,
            end: endSec,
            text: textStr
        });
    }

    // Mark overlapping metadata/banner chunks (e.g. long credit/title lines that overlap dialogues)
    for (var i = 0; i < chunks.length; i++) {
        var chunkA = chunks[i];
        var durA = chunkA.end - chunkA.start;
        chunkA.isMetadata = false;

        if (durA > 15.0) {
            for (var j = 0; j < chunks.length; j++) {
                if (i === j) continue;
                var chunkB = chunks[j];
                var durB = chunkB.end - chunkB.start;

                if (durB < durA) {
                    var overlap = (chunkA.start < chunkB.end && chunkB.start < chunkA.end);
                    if (overlap) {
                        chunkA.isMetadata = true;
                        break;
                    }
                }
            }
        }
    }

    return chunks;
}

function parseSRTTime(timeStr) {
    // Ignore WebVTT cue settings after the timestamp (e.g. align:start).
    var parts = timeStr.trim().split(/\s+/)[0].replace(",", ".").split(":");
    if (parts.length === 2) parts.unshift("0");
    if (parts.length !== 3) return 0;

    var hours = parseFloat(parts[0]);
    var minutes = parseFloat(parts[1]);
    var seconds = parseFloat(parts[2]);

    return hours * 3600 + minutes * 60 + seconds;
}

function parseVTT(vttText) {
    var blocks = vttText.replace(/^\uFEFF/, "")
        .replace(/\r\n/g, "\n").replace(/\r/g, "\n")
        .split(/\n[ \t]*\n/)
    var cues = []
    for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i].trim()
        var firstLine = block.split("\n")[0].trim()
        // Remove metadata blocks without rewriting timestamps or cue text.
        if (block === "" || /^WEBVTT(?:[ \t]|$)/.test(firstLine) ||
            /^NOTE(?:[ \t]|$)/.test(firstLine) ||
            firstLine === "STYLE" || firstLine === "REGION") continue
        cues.push(block)
    }
    return parseSRT(cues.join("\n\n"))
}

function formatSRTTime(seconds) {
    var hrs = Math.floor(seconds / 3600);
    var mins = Math.floor((seconds % 3600) / 60);
    var secs = Math.floor(seconds % 60);
    var ms = Math.floor((seconds % 1) * 1000);
    return pad(hrs, 2) + ":" + pad(mins, 2) + ":" + pad(secs, 2) + "," + pad(ms, 3);
}

function formatVTTTime(seconds) {
    var hrs = Math.floor(seconds / 3600);
    var mins = Math.floor((seconds % 3600) / 60);
    var secs = Math.floor(seconds % 60);
    var ms = Math.floor((seconds % 1) * 1000);
    return pad(hrs, 2) + ":" + pad(mins, 2) + ":" + pad(secs, 2) + "." + pad(ms, 3);
}

function pad(num, size) {
    var s = num + "";
    while (s.length < size) s = "0" + s;
    return s;
}

function formatSRT(chunks) {
    var srt = "";
    for (var i = 0; i < chunks.length; i++) {
        var chunk = chunks[i];
        srt += (i + 1) + "\n";
        srt += formatSRTTime(chunk.start) + " --> " + formatSRTTime(chunk.end) + "\n";
        srt += chunk.text + "\n\n";
    }
    return srt;
}

function formatVTT(chunks) {
    var vtt = "WEBVTT\n\n";
    for (var i = 0; i < chunks.length; i++) {
        var chunk = chunks[i];
        vtt += (i + 1) + "\n";
        vtt += formatVTTTime(chunk.start) + " --> " + formatVTTTime(chunk.end) + "\n";
        vtt += chunk.text + "\n\n";
    }
    return vtt;
}

function formatTXT(chunks, lyrics) {
    if (chunks.length === 0) {
        return lyrics;
    }
    var txt = "";
    for (var i = 0; i < chunks.length; i++) {
        var chunk = chunks[i];
        txt += "[" + MediaUtils.formatTime(chunk.start) + "] " + chunk.text + "\n";
    }
    return txt;
}
