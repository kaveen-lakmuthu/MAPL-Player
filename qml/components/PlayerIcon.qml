import QtQuick

// A single monochrome icon vocabulary, independent of the desktop icon theme.
Canvas {
    id: root
    property string name: ""
    property color ink: "#edf3fa"
    implicitWidth: 18
    implicitHeight: 18
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onPaint: {
        var c = getContext("2d");
        c.reset();
        c.scale(width / 24, height / 24);
        c.strokeStyle = ink;
        c.fillStyle = ink;
        c.lineWidth = 1.7;
        c.lineCap = "round";
        c.lineJoin = "round";
        function line(points) {
            c.beginPath();
            c.moveTo(points[0], points[1]);
            for (var i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i + 1]);
            c.stroke();
        }
        function triangle(a, b, d, e, f, g) {
            c.beginPath(); c.moveTo(a, b); c.lineTo(d, e); c.lineTo(f, g); c.closePath(); c.fill();
        }
        switch (name) {
        case "play": triangle(8, 5, 19, 12, 8, 19); break;
        case "pause": c.fillRect(7, 5, 3, 14); c.fillRect(14, 5, 3, 14); break;
        case "previous": line([5, 5, 5, 19]); triangle(18, 5, 7, 12, 18, 19); break;
        case "next": line([19, 5, 19, 19]); triangle(6, 5, 17, 12, 6, 19); break;
        case "back": case "forward":
            c.save();
            if (name === "forward") { c.translate(24, 0); c.scale(-1, 1); }
            line([8, 3, 4, 7, 9, 8]);
            c.beginPath(); c.arc(12, 12, 8, -2.45, 2.6); c.stroke();
            c.restore();
            c.font = "bold 10px sans-serif"; c.textAlign = "center"; c.fillText("5", 12, 16);
            break;
        case "loop": line([5, 8, 7, 5, 19, 5, 19, 10]); line([16, 8, 19, 11, 22, 8]);
            line([19, 16, 17, 19, 5, 19, 5, 14]); line([2, 16, 5, 13, 8, 16]); break;
        case "volume": case "muted":
            line([4, 9, 8, 9, 13, 5, 13, 19, 8, 15, 4, 15, 4, 9]);
            if (name === "muted") { line([17, 9, 22, 15]); line([22, 9, 17, 15]); }
            else { c.beginPath(); c.arc(12, 12, 6, -0.75, 0.75); c.stroke(); c.beginPath(); c.arc(12, 12, 10, -0.75, 0.75); c.stroke(); }
            break;
        case "fullscreen": line([9, 4, 4, 4, 4, 9]); line([15, 4, 20, 4, 20, 9]);
            line([4, 15, 4, 20, 9, 20]); line([15, 20, 20, 20, 20, 15]); break;
        case "restore": line([4, 9, 9, 9, 9, 4]); line([15, 4, 15, 9, 20, 9]);
            line([4, 15, 9, 15, 9, 20]); line([15, 20, 15, 15, 20, 15]); break;
        case "expand": line([5, 19, 19, 5]); line([11, 5, 19, 5, 19, 13]); break;
        case "close": line([6, 6, 18, 18]); line([18, 6, 6, 18]); break;
        case "chevron": line([8, 10, 12, 14, 16, 10]); break;
        case "chapters": case "playlist":
            for (var y = 6; y <= 18; y += 6) { line([9, y, 20, y]); c.fillRect(3, y - 1, 2, 2); } break;
        case "captions":
            c.strokeRect(3, 5, 18, 14); c.font = "bold 9px sans-serif"; c.textAlign = "center"; c.fillText("CC", 12, 15); break;
        case "image": c.strokeRect(3, 4, 18, 16); line([4, 18, 9, 12, 13, 16, 16, 11, 20, 16]);
            c.beginPath(); c.arc(8, 9, 1.5, 0, Math.PI * 2); c.fill(); break;
        case "audio": line([9, 17, 9, 5, 19, 3, 19, 15]);
            c.beginPath(); c.ellipse(6, 18, 3, 2, 0, 0, Math.PI * 2); c.fill();
            c.beginPath(); c.ellipse(16, 16, 3, 2, 0, 0, Math.PI * 2); c.fill(); break;
        case "video": c.strokeRect(3, 5, 18, 14); triangle(10, 8, 16, 12, 10, 16); break;
        case "file": line([14, 3, 5, 3, 5, 21, 19, 21, 19, 8, 14, 3, 14, 8, 19, 8]); break;
        case "settings":
            line([4, 6, 20, 6]); line([4, 12, 20, 12]); line([4, 18, 20, 18]);
            c.fillRect(8, 3, 3, 6); c.fillRect(15, 9, 3, 6); c.fillRect(6, 15, 3, 6); break;
        case "tasks":
            c.beginPath(); c.arc(12, 12, 8, 0, Math.PI * 2); c.stroke();
            line([12, 7, 12, 12, 16, 14]); break;
        case "trash": line([5, 6, 19, 6]); line([9, 6, 9, 3, 15, 3, 15, 6]);
            line([7, 9, 8, 21, 16, 21, 17, 9]); break;
        }
    }
}
