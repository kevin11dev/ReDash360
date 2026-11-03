import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Test Controller picture: a black Xbox One style controller that shows
// what yours is doing. Buttons light up while held, the sticks move, the
// triggers fill as you squeeze them and the squares show the player number.
// Drawn at 800 x 670; scale it to fit.
Item {
    id: pad
    width: 800; height: 670

    // Gamepad.state() of the controller to show (empty: nothing pressed)
    property var input: ({})
    property int player: 1
    property string family: "xbox"          // "xbox", "playstation" or "nintendo": face button labels

    readonly property var buttons: input.buttons || ({})
    readonly property color lit: "#6BD12B"

    readonly property color shell: "#050505"
    readonly property color bumperRim: "#0D0D0D"
    readonly property color bumperFace: "#1A1A1A"
    readonly property color triggerLight: "#1A1A1A"
    readonly property color triggerDark: "#141414"
    readonly property color ring: "#080808"            // flat ring round the sticks
    readonly property color ringEdge: "#1E1515"
    readonly property color hole: "#000000"            // the opening a stick sits in
    readonly property color knurl: "#383838"
    readonly property color knurlTick: "#5E5E5E"
    readonly property color capEdge: "#1A1A1A"
    readonly property color capTop: "#212121"
    readonly property color cross: "#141414"
    readonly property color crossEdge: "#2A2A2A"
    readonly property color buttonTop: "#141414"
    readonly property color buttonLip: "#0A0A0A"
    readonly property color buttonEdge: "#1E1E1E"
    readonly property color icon: "#6D6B6C"
    readonly property color square: "#9A9A9A"

    readonly property real lt: input.lt || 0
    readonly property real rt: input.rt || 0

    // ---- The controller itself, with a soft shadow under it ----
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#A0000000"
            shadowBlur: 0.9
            shadowVerticalOffset: 14
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // Triggers: the inner half a shade darker, like the real thing
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 177; y1: 0; x2: 265; y2: 0
                    GradientStop { position: 0.52; color: pad.triggerLight }
                    GradientStop { position: 0.53; color: pad.triggerDark }
                }
                PathSvg { path: "M 264.8,30 L 264.8,128 Q 264.8,131.5 261,132 L 181.5,141.6 Q 177.2,142 177.4,137.5 C 178,112 183,86 192,62 C 200,41 220,21 250,20 C 259,19.7 264.8,22 264.8,30 Z" }
            }
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 623; y1: 0; x2: 535; y2: 0
                    GradientStop { position: 0.52; color: pad.triggerLight }
                    GradientStop { position: 0.53; color: pad.triggerDark }
                }
                PathSvg { path: "M 535.2,30 L 535.2,128 Q 535.2,131.5 539,132 L 618.5,141.6 Q 622.8,142 622.6,137.5 C 622,112 617,86 608,62 C 600,41 580,21 550,20 C 541,19.7 535.2,22 535.2,30 Z" }
            }
        }
        TriggerFill { path: "M 264.8,30 L 264.8,128 Q 264.8,131.5 261,132 L 181.5,141.6 Q 177.2,142 177.4,137.5 C 178,112 183,86 192,62 C 200,41 220,21 250,20 C 259,19.7 264.8,22 264.8,30 Z"; amount: pad.lt }
        TriggerFill { path: "M 535.2,30 L 535.2,128 Q 535.2,131.5 539,132 L 618.5,141.6 Q 622.8,142 622.6,137.5 C 622,112 617,86 608,62 C 600,41 580,21 550,20 C 541,19.7 535.2,22 535.2,30 Z"; amount: pad.rt }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // The body, one solid colour
            ShapePath {
                strokeColor: "transparent"
                fillColor: pad.shell
                PathSvg { path: "M 400,167 L 304,167 C 298,166.5 293,163 285,158.5 C 278,154.5 271,150 262,149 C 250,148 232,150 216,154.2 C 196,159.6 166,173 151,181.2 C 145,184.6 142,188 140.5,193 L 137.8,204.5 C 136.8,207.6 133,210.5 128,213.6 C 121,218 114,223 111,231.2 C 101,256 72,333 55.2,385.2 C 40,433 25,490 25,535 C 25,580 37,614 62,633 C 75,645 92,651 103.5,649.8 C 112,649 122,639 132.5,629.5 C 160,602 190,570 210,552 C 228,535.5 248,524 268,520.8 L 400,520.8 L 532,520.8 C 552,524 572,535.5 590,552 C 610,570 640,602 667.5,629.5 C 678,639 688,649 696.5,649.8 C 708,651 725,645 738,633 C 763,614 775,580 775,535 C 775,490 760,433 744.8,385.2 C 728,333 699,256 689,231.2 C 686,223 679,218 672,213.6 C 667,210.5 663.2,207.6 662.2,204.5 L 659.5,193 C 658,188 655,184.6 649,181.2 C 634,173 604,159.6 584,154.2 C 568,150 550,148 538,149 C 529,150 522,154.5 515,158.5 C 507,163 502,166.5 496,167 L 400,167 Z" }
            }

            // Bumpers: a darker rim along the top edge, then the face
            ShapePath {
                strokeColor: "transparent"
                fillColor: pad.buttons.lb ? Qt.darker(pad.lit, 1.4) : pad.bumperRim
                PathSvg { path: "M 298.5,166.5 C 290,161 280,155 270,151 C 262,148.5 250,148.5 242,149.2 C 222,151 196,160 170,171.5 C 156,178 146,184 142.5,190 L 137.3,206.8 C 160,198 190,187 212,181.8 C 228,178 244,175.5 252,177 C 262,179 272,190 281.5,200 L 296.8,172 Q 298.5,168.5 298.5,166.5 Z" }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: pad.buttons.rb ? Qt.darker(pad.lit, 1.4) : pad.bumperRim
                PathSvg { path: "M 501.5,166.5 C 510,161 520,155 530,151 C 538,148.5 550,148.5 558,149.2 C 578,151 604,160 630,171.5 C 644,178 654,184 657.5,190 L 662.7,206.8 C 640,198 610,187 588,181.8 C 572,178 556,175.5 548,177 C 538,179 528,190 518.5,200 L 503.2,172 Q 501.5,168.5 501.5,166.5 Z" }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: pad.buttons.lb ? pad.lit : pad.bumperFace
                PathSvg { path: "M 296.5,172.8 C 290,168 283,163 276.8,159.5 C 270,156 258,153.6 250.5,154 C 240,154.5 215,162 189,171 C 170,178 154,184 148,187.5 C 144,189.5 142.5,191 142,193 L 137.3,206.8 C 160,198 190,187 212,181.8 C 228,178 244,175.5 252,177 C 262,179 272,190 281.5,200 L 296.5,172.8 Z" }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: pad.buttons.rb ? pad.lit : pad.bumperFace
                PathSvg { path: "M 503.5,172.8 C 510,168 517,163 523.2,159.5 C 530,156 542,153.6 549.5,154 C 560,154.5 585,162 611,171 C 630,178 646,184 652,187.5 C 656,189.5 657.5,191 658,193 L 662.7,206.8 C 640,198 610,187 588,181.8 C 572,178 556,175.5 548,177 C 538,179 528,190 518.5,200 L 503.5,172.8 Z" }
            }
        }
    }

    // ---- Guide: no logo, just a glow where it is while it's held ----
    Glow { x: 400; y: 216; r: 46; visible: !!pad.buttons.guide }

    // ---- Sticks and d-pad ----
    Stick { x: 211.3; y: 300.8; dx: pad.input.leftX || 0; dy: pad.input.leftY || 0; pressed: !!pad.buttons.leftStick }
    Stick { x: 498.8; y: 413.8; dx: pad.input.rightX || 0; dy: pad.input.rightY || 0; pressed: !!pad.buttons.rightStick }
    DPad { x: 303; y: 420.5 }

    // ---- View, the player squares, Menu ----
    SmallButton { x: 346.9; y: 299.6; kind: pad.family === "playstation" ? "create" : pad.family === "nintendo" ? "minus" : "view"; pressed: !!pad.buttons.back }
    SmallButton { x: 453.1; y: 299.6; kind: pad.family === "playstation" ? "options" : pad.family === "nintendo" ? "plus" : "menu"; pressed: !!pad.buttons.start }
    Item {
        x: 400; y: 301
        Repeater {
            model: 4                            // 1 top left, 2 top right, 3 bottom left, 4 bottom right
            Item {
                x: index % 2 ? 9.5 : -9.5
                y: index < 2 ? -9.5 : 9.5
                readonly property bool on: index + 1 === pad.player
                Glow { r: 16; tint: "white"; visible: parent.on }
                Rectangle {
                    x: -4.5; y: -4.5; width: 9; height: 9
                    color: parent.on ? "white" : "transparent"
                    border.color: parent.on ? "white" : pad.square
                    border.width: 1.5
                    antialiasing: true
                }
            }
        }
    }

    // ---- Face buttons. SDL names them by position (a = bottom, b = right,
    // x = left, y = top), so only the labels change with the family ----
    Face { x: 591.4; y: 245.8; which: "top"; pressed: !!pad.buttons.y }
    Face { x: 540.9; y: 296.3; which: "left"; pressed: !!pad.buttons.x }
    Face { x: 641.9; y: 296.3; which: "right"; pressed: !!pad.buttons.b }
    Face { x: 591.4; y: 346.8; which: "bottom"; pressed: !!pad.buttons.a }

    // ---- Pieces ----

    // A trigger's fill: rises from the bottom as it's squeezed. (A solid
    // shape cut off at the right height, not a gradient: Qt shares one
    // gradient between shapes whose gradients have the same colours, so
    // both triggers would show the same amount.)
    component TriggerFill: Item {
        id: fill
        property string path
        property real amount
        anchors.fill: parent
        visible: amount > 0.02
        Item {
            y: 142 - 122 * Math.min(fill.amount, 1)
            width: parent.width
            height: 143 - y
            clip: true
            Shape {
                y: -parent.y
                width: fill.width; height: fill.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: pad.lit
                    PathSvg { path: fill.path }
                }
            }
        }
    }

    // A soft round glow around (0, 0)
    component Glow: Shape {
        id: glow
        property real r: 40
        property color tint: pad.lit
        x: -r; y: -r; width: 2 * r; height: 2 * r
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.r; centerY: glow.r; centerRadius: glow.r
                focalX: glow.r; focalY: glow.r
                GradientStop { position: 0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.7) }
                GradientStop { position: 0.45; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.28) }
                GradientStop { position: 1; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0) }
            }
            PathAngleArc { centerX: glow.r; centerY: glow.r; radiusX: glow.r; radiusY: glow.r; startAngle: 0; sweepAngle: 360 }
        }
    }

    // A circle around (0, 0)
    component Circle: Rectangle {
        property real r
        x: -r; y: -r; width: 2 * r; height: 2 * r; radius: r
    }

    component Stick: Item {
        id: stick
        property real dx                        // -1 to 1, right and down are positive
        property real dy
        property bool pressed

        Circle { r: 69; color: pad.ring; border.color: pad.ringEdge; border.width: 1 }
        Circle { r: 55; color: pad.hole }
        Item {                                  // the cap, moved the way the stick is pushed
            x: stick.dx * 14; y: stick.dy * 14
            Glow { r: 64; visible: stick.pressed }
            Circle { r: 41; color: stick.pressed ? pad.lit : pad.knurl }
            Repeater {                          // the grip ridges round the edge
                model: 64
                Rectangle {
                    x: -0.6; y: -40
                    width: 1.2; height: 8
                    color: stick.pressed ? Qt.lighter(pad.lit, 1.35) : pad.knurlTick
                    transform: Rotation { origin.x: 0.6; origin.y: 40; angle: index * 360 / 64 }
                }
            }
            Circle { r: 31; color: stick.pressed ? Qt.darker(pad.lit, 1.5) : pad.capEdge }
            Circle { r: 26; color: stick.pressed ? Qt.darker(pad.lit, 1.2) : pad.capTop }
        }
    }

    component DPad: Item {
        Circle { r: 60; color: pad.hole; border.color: pad.ringEdge; border.width: 1 }
        Shape {
            x: -60; y: -60; width: 120; height: 120
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: pad.crossEdge
                strokeWidth: 2.5
                fillColor: pad.cross
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M 44,12 Q 44,6 50,6 L 70,6 Q 76,6 76,12 L 76,44 L 108,44 Q 114,44 114,50 L 114,70 Q 114,76 108,76 "
                        + "L 76,76 L 76,108 Q 76,114 70,114 L 50,114 Q 44,114 44,108 L 44,76 L 12,76 Q 6,76 6,70 L 6,50 Q 6,44 12,44 L 44,44 Z"
                }
            }
        }
        Arm { x: -14; y: -52; width: 28; height: 34; pressed: !!pad.buttons.up }
        Arm { x: -14; y: 18; width: 28; height: 34; pressed: !!pad.buttons.down }
        Arm { x: -52; y: -14; width: 34; height: 28; pressed: !!pad.buttons.left }
        Arm { x: 18; y: -14; width: 34; height: 28; pressed: !!pad.buttons.right }
    }

    component Arm: Rectangle {
        property bool pressed
        radius: 4
        visible: pressed
        color: pad.lit
    }

    component SmallButton: Item {
        id: small
        property string kind
        property bool pressed
        readonly property color mark: pressed ? "#10240A" : pad.icon

        Glow { r: 34; visible: small.pressed }
        Circle { r: 18; color: small.pressed ? pad.lit : pad.buttonLip; border.color: small.pressed ? Qt.darker(pad.lit, 1.3) : pad.buttonEdge; border.width: 1.5 }
        // view: two overlapping windows
        Rectangle { visible: small.kind === "view"; x: -8; y: -6; width: 10; height: 8; color: "transparent"; border.color: small.mark; border.width: 1.5; antialiasing: true }
        Rectangle { visible: small.kind === "view"; x: -3; y: -2; width: 10; height: 8; color: small.pressed ? pad.lit : pad.buttonLip; border.color: small.mark; border.width: 1.5; antialiasing: true }
        // menu / options: three lines
        Column {
            visible: small.kind === "menu" || small.kind === "options"
            x: -7; y: -5; spacing: 2.5
            Repeater { model: 3; Rectangle { width: 14; height: 1.6; color: small.mark } }
        }
        // create: three short upright lines
        Row {
            visible: small.kind === "create"
            x: -5.5; y: -6; spacing: 2.6
            Repeater { model: 3; Rectangle { width: 1.8; height: 12; color: small.mark } }
        }
        // minus / plus
        Rectangle { visible: small.kind === "minus" || small.kind === "plus"; x: -6; y: -1; width: 12; height: 2; color: small.mark }
        Rectangle { visible: small.kind === "plus"; x: -1; y: -6; width: 2; height: 12; color: small.mark }
    }

    component Face: Item {
        id: face
        property string which                   // where it sits: top, left, right, bottom
        property bool pressed

        // label and colour for each family, by position
        readonly property var looks: ({
            xbox: { top: ["Y", "#FCEE21"], left: ["X", "#0071BC"], right: ["B", "#C1272D"], bottom: ["A", "#39B54A"] },
            playstation: { top: ["triangle", "#3DC6B4"], left: ["square", "#E07ED2"], right: ["circle", "#FF5A5A"], bottom: ["cross", "#7FA8FF"] },
            nintendo: { top: ["X", ""], left: ["Y", ""], right: ["A", ""], bottom: ["B", ""] }
        })
        readonly property var look: (looks[pad.family] || looks.xbox)[which]
        readonly property color tint: look[1] !== "" ? look[1] : pad.lit
        readonly property color mark: pressed ? "#0A0A0A" : look[1] !== "" ? look[1] : "#D8D8D8"

        Glow { r: 50; tint: face.tint; visible: face.pressed }
        Circle { y: -r + 4; r: 27; color: pad.buttonLip; border.color: pad.buttonEdge; border.width: 1 }   // the side, seen below
        Circle { r: 26; color: face.pressed ? face.tint : pad.buttonTop; border.color: face.pressed ? Qt.darker(face.tint, 1.2) : pad.buttonEdge; border.width: 1 }
        Text {
            anchors.centerIn: parent
            visible: face.look[0].length === 1
            text: face.look[0]
            color: face.mark
            font.pixelSize: 36
            font.weight: Font.DemiBold
        }
        Shape {
            anchors.centerIn: parent
            width: 22; height: 22
            visible: face.look[0].length > 1
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: face.mark
                strokeWidth: 2.6
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: face.look[0] === "triangle" ? "M 11,1.5 L 21,19 L 1,19 Z"
                        : face.look[0] === "square" ? "M 2,2 L 20,2 L 20,20 L 2,20 Z"
                        : face.look[0] === "circle" ? "M 11,1.5 A 9.5,9.5 0 1 1 10.99,1.5 Z"
                        : "M 2,2 L 20,20 M 20,2 L 2,20"
                }
            }
        }
    }
}