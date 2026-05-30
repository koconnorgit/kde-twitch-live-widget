import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQControls

// One self-contained group of border/background controls. Used twice from
// configGeneral.qml (once for the whole widget, once for each streamer chip).
// The public properties below are bound to config entries via cfg_ aliases on
// the parent page, so each control reads from / writes to its own property.
Kirigami.FormLayout {
    id: fs

    // Section title shown above the controls.
    property string title: ""

    // Bound to config (see configGeneral.qml cfg_ aliases).
    property bool   frameEnabled: false
    property int    borderWidth: 1
    property int    cornerStyle: 1   // 0 = square, 1 = rounded
    property int    cornerRadius: 8
    property string borderColor: ""  // "" = theme highlight color
    property real   fillOpacity: 0.35
    property int    fillMode: 0      // 0 = single, 1 = gradient, 2 = random
    property string fillColors: ""   // comma/space separated hex list

    function parseColors(s) {
        return (s || "").split(/[\s,]+/)
            .map(function (x) { return x.trim(); })
            .filter(function (x) { return x.length > 0; });
    }

    Kirigami.Separator {
        Kirigami.FormData.label: fs.title
        Kirigami.FormData.isSection: true
    }

    QQC2.CheckBox {
        id: enableBox
        Kirigami.FormData.label: i18n("Frame:")
        text: i18n("Show border / background")
        checked: fs.frameEnabled
        onToggled: fs.frameEnabled = checked
    }

    QQC2.SpinBox {
        Kirigami.FormData.label: i18n("Border width:")
        enabled: fs.frameEnabled
        from: 0
        to: 12
        stepSize: 1
        value: fs.borderWidth
        onValueModified: fs.borderWidth = value
        textFromValue: function (v) { return v === 0 ? i18n("None") : i18n("%1 px", v); }
        valueFromText: function (t) { return parseInt(t) || 0; }
    }

    KQControls.ColorButton {
        id: borderColorBtn
        Kirigami.FormData.label: i18n("Border color:")
        enabled: fs.frameEnabled
        property bool ready: false
        Component.onCompleted: {
            color = fs.borderColor ? fs.borderColor : Kirigami.Theme.highlightColor;
            ready = true;
        }
        onColorChanged: if (ready) fs.borderColor = color.toString()
    }

    QQC2.Button {
        Kirigami.FormData.label: ""
        enabled: fs.frameEnabled
        visible: fs.borderColor.length > 0
        text: i18n("Use theme color")
        icon.name: "edit-clear"
        onClicked: {
            fs.borderColor = "";
            borderColorBtn.color = Kirigami.Theme.highlightColor;
        }
    }

    QQC2.ComboBox {
        id: cornerCombo
        Kirigami.FormData.label: i18n("Corners:")
        enabled: fs.frameEnabled
        model: [i18n("Square"), i18n("Rounded")]
        currentIndex: fs.cornerStyle
        onActivated: fs.cornerStyle = currentIndex
    }

    QQC2.SpinBox {
        Kirigami.FormData.label: i18n("Corner radius:")
        enabled: fs.frameEnabled && fs.cornerStyle === 1
        from: 0
        to: 64
        stepSize: 1
        value: fs.cornerRadius
        onValueModified: fs.cornerRadius = value
        textFromValue: function (v) { return i18n("%1 px", v); }
        valueFromText: function (t) { return parseInt(t) || 0; }
    }

    QQC2.ComboBox {
        id: fillModeCombo
        Kirigami.FormData.label: i18n("Fill mode:")
        enabled: fs.frameEnabled
        model: [i18n("Single color"), i18n("Gradient"), i18n("Random")]
        currentIndex: fs.fillMode
        onActivated: fs.fillMode = currentIndex
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Fill opacity:")
        enabled: fs.frameEnabled
        QQC2.Slider {
            id: opacitySlider
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            from: 0
            to: 1
            stepSize: 0.05
            value: fs.fillOpacity
            onMoved: fs.fillOpacity = value
        }
        QQC2.Label {
            text: Math.round(fs.fillOpacity * 100) + "%"
            opacity: 0.8
        }
    }

    // ---- fill color list editor (swatches persisted as a hex string) ----
    Flow {
        Kirigami.FormData.label: i18n("Fill colors:")
        enabled: fs.frameEnabled
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: fs.parseColors(fs.fillColors)
            delegate: KQControls.ColorButton {
                color: modelData
                onColorChanged: {
                    var arr = fs.parseColors(fs.fillColors);
                    if (index >= 0 && index < arr.length
                            && color.toString() !== arr[index]) {
                        arr[index] = color.toString();
                        fs.fillColors = arr.join(", ");
                    }
                }
            }
        }
    }

    RowLayout {
        Kirigami.FormData.label: ""
        enabled: fs.frameEnabled
        QQC2.Button {
            text: i18n("Add color")
            icon.name: "list-add"
            onClicked: {
                var arr = fs.parseColors(fs.fillColors);
                arr.push(Kirigami.Theme.highlightColor.toString());
                fs.fillColors = arr.join(", ");
            }
        }
        QQC2.Button {
            text: i18n("Remove last")
            icon.name: "list-remove"
            enabled: fs.parseColors(fs.fillColors).length > 0
            onClicked: {
                var arr = fs.parseColors(fs.fillColors);
                arr.pop();
                fs.fillColors = arr.join(", ");
            }
        }
        QQC2.Button {
            text: i18n("Clear")
            icon.name: "edit-clear"
            enabled: fs.parseColors(fs.fillColors).length > 0
            onClicked: fs.fillColors = ""
        }
    }

    QQC2.Label {
        Kirigami.FormData.label: ""
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: i18n("Single uses the first color; Gradient blends all of them; Random picks one per streamer (a random hue is used when no colors are set).")
    }
}
