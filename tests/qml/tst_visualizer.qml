import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "AudioVisualizer"
    when: windowShown
    visible: true
    width: 400
    height: 160
    property var app
    property var visualizer
    Component {
        id: appComponent
        QtObject {
            property bool reduceMotion: false
            property bool isMuted: false
            property QtObject audioLevels: QtObject {
                property bool available: true
                property var spectrum: Array(24).fill(0)
            }
            property QtObject volumeSlider: QtObject { property real value: 50 }
            property QtObject mediaPlayer: QtObject {
                property bool hasAudio: true
                property int activeAudioTrack: 0
            }
        }
    }
    Component { id: visualizerComponent; Components.AudioVisualizer { width: 280; height: 62 } }
    function init() {
        failOnWarning(/(ReferenceError|TypeError|is not defined|Cannot assign|Binding loop)/);
        app = createTemporaryObject(appComponent, testCase);
        visualizer = createTemporaryObject(visualizerComponent, testCase, {app: app});
        verify(visualizer !== null);
    }
    function test_barsFollowIndividualFrequencyBands() {
        var values = Array(24).fill(0);
        values[2] = .5;
        values[20] = .05;
        app.audioLevels.spectrum = values;
        var bass = findChild(visualizer, "audioSpectrumBar2");
        var treble = findChild(visualizer, "audioSpectrumBar20");
        tryVerify(function () { return bass.height > treble.height && treble.height > 0; });
        verify(bass.x < treble.x);
        verify(bass.height <= findChild(visualizer, "audioSpectrumBars").height);
        compare(findChild(visualizer, "audioSpectrumBar10").height, 0);
        app.audioLevels.spectrum = Array(24).fill(0);
        tryCompare(bass, "height", 0);
        tryCompare(treble, "height", 0);
    }
    function test_smallWidthAndReducedMotion() {
        visualizer.width = 140;
        app.audioLevels.spectrum = Array(24).fill(.1);
        var bars = findChild(visualizer, "audioSpectrumBars");
        waitForRendering(bars);
        var last = findChild(visualizer, "audioSpectrumBar23");
        verify(last.x + last.width <= visualizer.width + .1);
        app.reduceMotion = true;
        verify(!bars.visible);
        var status = findChild(visualizer, "audioPlaybackIndicator");
        verify(status.visible);
        app.isMuted = true;
        compare(status.text, "Muted");
        app.reduceMotion = false;
        app.audioLevels.available = false;
        verify(!bars.visible);
        verify(status.visible);
    }
}
