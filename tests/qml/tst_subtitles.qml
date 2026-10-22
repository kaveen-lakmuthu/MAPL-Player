import QtQuick
import QtTest
import "../../qml/logic/SubtitleUtils.js" as Subtitles
import "SubtitleCases.js" as Cases

TestCase {
    name: "SubtitleFormats"
    function test_parse_data() { return Cases.rows() }
    function test_parse(data) {
        var chunks = data.format === "vtt" ? Subtitles.parseVTT(data.input) : Subtitles.parseSRT(data.input);
        compare(chunks.length, data.expected.length);
        for (var i = 0; i < chunks.length; ++i) {
            compare(chunks[i].start, data.expected[i].start);
            compare(chunks[i].end, data.expected[i].end);
            compare(chunks[i].text, data.expected[i].text);
        }
    }
    function test_overlapMetadata() {
        var chunks = Subtitles.parseSRT("1\n00:00:00,000 --> 00:00:30,000\nTitle.\n\n2\n00:00:05,000 --> 00:00:06,000\nDialogue.");
        verify(chunks[0].isMetadata);
        verify(!chunks[1].isMetadata);
    }
    function test_roundTrip_data() {
        return [
            {
                tag: "srt",
                format: "srt"
            },
            {
                tag: "vtt",
                format: "vtt"
            }
        ];
    }
    function test_roundTrip(data) {
        var chunks = [
            {
                start: 1.25,
                end: 5.5,
                text: "Hello. World."
            }
        ];
        var serialized = data.format === "srt" ? Subtitles.formatSRT(chunks) : Subtitles.formatVTT(chunks);
        var parsed = data.format === "srt" ? Subtitles.parseSRT(serialized) : Subtitles.parseVTT(serialized);
        compare(parsed[0].start, 1.25);
        compare(parsed[0].end, 5.5);
        compare(parsed[0].text, "Hello. World.");
    }
    function test_plainTextExport() {
        compare(Subtitles.formatTXT([], "Plain lyrics."), "Plain lyrics.");
        compare(Subtitles.formatTXT([
            {
                start: 65,
                end: 66,
                text: "Line."
            }
        ], ""), "[1:05] Line.\n");
    }
}
