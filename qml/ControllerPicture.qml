import QtQuick
import QtQuick.Shapes

// Test Controller picture: a plain line drawing of a controller, of any make,
// that shows what yours is doing. Buttons light up while held, the sticks
// move, the triggers fill as you squeeze them, and a quarter of the ring
// round the Guide button lights up for the player number, like the 360's
// Ring of Light. Drawn at 800 x 670; scale it to fit.
Item {
    id: pad
    width: 800; height: 670

    // Gamepad.state() of the controller to show (empty: nothing pressed)
    property var input: ({})
    property int player: 1

    readonly property var buttons: input.buttons || ({})
    readonly property real lt: input.lt || 0
    readonly property real rt: input.rt || 0

    readonly property color lit: "#6BD12B"
    readonly property color line: "#1A1A1A"             // every outline
    readonly property color face: "#55595D"
    readonly property color underside: "#2E3134"        // seen below the body
    readonly property color grip: "#4D5155"             // the lines where the grips start
    readonly property real stroke: 4

    readonly property string bodyPath: "M 408.7,178.0 C 397.3,178.0 385.9,178.0 374.5,178.0 "
                                     + "C 363.1,178.0 351.7,178.0 340.3,178.0 C 329.0,178.0 317.6,178.0 306.2,178.0 "
                                     + "C 294.8,178.0 283.3,177.5 272.0,178.0 C 260.6,178.4 249.1,178.2 238.1,180.6 "
                                     + "C 227.1,183.0 216.1,187.2 206.2,192.5 C 196.2,197.7 186.5,204.4 178.5,212.3 "
                                     + "C 170.6,220.1 164.0,229.8 158.4,239.6 C 152.7,249.3 149.0,260.3 144.7,270.9 "
                                     + "C 140.5,281.4 136.6,292.1 132.7,302.8 C 128.8,313.5 124.9,324.2 121.2,335.0 "
                                     + "C 117.5,345.8 114.0,356.6 110.6,367.5 C 107.1,378.3 103.7,389.2 100.5,400.1 "
                                     + "C 97.3,411.0 94.2,422.0 91.3,433.0 C 88.4,444.0 85.6,455.1 83.3,466.2 "
                                     + "C 80.9,477.4 78.7,488.6 77.4,499.9 C 76.1,511.2 75.3,522.6 75.6,533.9 "
                                     + "C 75.8,545.2 76.3,556.9 79.1,567.8 C 81.8,578.7 85.1,590.9 92.0,599.1 "
                                     + "C 98.9,607.3 110.1,613.7 120.5,616.9 C 130.8,620.1 143.8,621.0 154.1,618.2 "
                                     + "C 164.5,615.3 174.1,607.2 182.4,599.7 C 190.7,592.2 196.8,582.0 203.8,573.1 "
                                     + "C 210.8,564.1 217.2,554.6 224.4,545.8 C 231.5,536.9 238.6,527.8 246.7,520.0 "
                                     + "C 254.8,512.1 263.2,503.5 273.2,498.6 C 283.1,493.7 295.0,492.0 306.2,490.7 "
                                     + "C 317.4,489.3 329.0,490.6 340.3,490.6 C 351.7,490.6 363.1,490.6 374.5,490.6 "
                                     + "C 385.9,490.6 397.3,490.6 408.7,490.6 C 420.1,490.6 431.5,490.6 442.9,490.6 "
                                     + "C 454.3,490.6 465.7,490.6 477.0,490.6 C 488.4,490.6 500.0,489.3 511.2,490.7 "
                                     + "C 522.4,492.0 534.3,493.7 544.2,498.6 C 554.2,503.5 562.5,512.1 570.7,520.0 "
                                     + "C 578.8,527.8 585.9,536.9 593.0,545.8 C 600.2,554.6 606.6,564.1 613.6,573.1 "
                                     + "C 620.6,582.0 626.7,592.2 635.0,599.7 C 643.3,607.2 652.9,615.3 663.3,618.2 "
                                     + "C 673.6,621.0 686.5,620.1 696.9,616.9 C 707.3,613.7 718.5,607.3 725.4,599.1 "
                                     + "C 732.3,590.9 735.6,578.7 738.3,567.8 C 741.1,556.9 741.6,545.2 741.8,533.9 "
                                     + "C 742.1,522.6 741.3,511.2 740.0,499.9 C 738.7,488.6 736.4,477.4 734.1,466.2 "
                                     + "C 731.8,455.1 729.0,444.0 726.1,433.0 C 723.2,422.0 720.1,411.0 716.9,400.1 "
                                     + "C 713.7,389.2 710.2,378.3 706.8,367.5 C 703.3,356.6 699.9,345.8 696.2,335.0 "
                                     + "C 692.5,324.2 688.6,313.5 684.7,302.8 C 680.8,292.1 676.9,281.4 672.7,270.9 "
                                     + "C 668.4,260.3 664.6,249.3 659.0,239.6 C 653.4,229.8 646.8,220.1 638.9,212.3 "
                                     + "C 630.9,204.4 621.2,197.7 611.2,192.5 C 601.3,187.2 590.3,183.0 579.3,180.6 "
                                     + "C 568.3,178.2 556.7,178.4 545.4,178.0 C 534.1,177.5 522.6,178.0 511.2,178.0 "
                                     + "C 499.8,178.0 488.4,178.0 477.0,178.0 C 465.7,178.0 454.3,178.0 442.9,178.0 "
                                     + "C 431.5,178.0 420.1,178.0 408.7,178.0 Z"

    // ---- The body: its underside showing below it, then the top, with the
    // lines where the grips start ----
    Shape {
        y: 27
        width: pad.width; height: pad.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: pad.underside
            PathSvg { path: pad.bodyPath }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: pad.face
            PathSvg { path: pad.bodyPath }
        }
        ShapePath {
            strokeColor: pad.grip
            strokeWidth: 3.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 113.9,357.2 L 272.1,499.6 M 703.5,357.2 L 545.3,499.6" }
        }
        ShapePath {
            strokeColor: pad.line
            strokeWidth: pad.stroke
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: pad.bodyPath }
        }
    }

    // ---- Triggers and bumpers, above the body ----
    Trigger { x: 259.75; y: 39.65; amount: pad.lt }
    Trigger { x: 510.95; y: 39.65; amount: pad.rt }
    Bumper { x: 239.6; y: 129.85; pressed: !!pad.buttons.lb }
    Bumper { x: 511.1; y: 129.85; pressed: !!pad.buttons.rb }

    // ---- Left stick and the face buttons, the d-pad and the right stick.
    // SDL names the face buttons by where they are (a = bottom, b = right,
    // x = left, y = top), so these light up right on any make ----
    Stick { x: 242.7; y: 283.0; dx: pad.input.leftX || 0; dy: pad.input.leftY || 0; pressed: !!pad.buttons.leftStick }
    Petals {
        x: 574.7; y: 283.0
        topHeld: !!pad.buttons.y; rightHeld: !!pad.buttons.b; bottomHeld: !!pad.buttons.a; leftHeld: !!pad.buttons.x
    }
    Petals {
        x: 322.7; y: 402.4
        topHeld: !!pad.buttons.up; rightHeld: !!pad.buttons.right; bottomHeld: !!pad.buttons.down; leftHeld: !!pad.buttons.left
    }
    Stick { x: 494.7; y: 402.4; dx: pad.input.rightX || 0; dy: pad.input.rightY || 0; pressed: !!pad.buttons.rightStick }

    // ---- Back, Guide and Start ----
    Button { x: 351.7; y: 286.0; r: 15.1; pressed: !!pad.buttons.back }
    Button { x: 408.7; y: 286.0; r: 20.3; pressed: !!pad.buttons.guide }
    Button { x: 465.7; y: 286.0; r: 15.1; pressed: !!pad.buttons.start }

    // The player number: player 1's quarter is top left, 2 top right,
    // 3 bottom left and 4 bottom right
    Shape {
        x: 408.7 - 40; y: 286.0 - 40
        width: 80; height: 80
        visible: pad.player >= 1 && pad.player <= 4
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: pad.lit
            strokeWidth: 5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 40; centerY: 40
                radiusX: 30; radiusY: 30
                startAngle: [190, 280, 100, 10][Math.max(0, Math.min(pad.player, 4) - 1)]
                sweepAngle: 70
            }
        }
    }

    // ---- Pieces ----

    // A circle round (0, 0), r to the middle of its outline
    component Circle: Rectangle {
        property real r
        x: -r - pad.stroke / 2; y: x
        width: 2 * r + pad.stroke; height: width
        radius: width / 2
        color: pad.face
        border.color: pad.line
        border.width: pad.stroke
    }

    component Button: Item {
        id: button
        property real r
        property bool pressed
        Circle { r: button.r; color: button.pressed ? pad.lit : pad.face }
    }

    // A stick in its ring, moved the way it's pushed
    component Stick: Item {
        id: stick
        property real dx                        // -1 to 1, right and down are positive
        property real dy
        property bool pressed
        // pushed into a corner it goes no further than pushed straight
        readonly property real reach: Math.max(1, Math.hypot(dx, dy))
        Circle { r: 57.4 }
        Item {
            x: stick.dx / stick.reach * 9; y: stick.dy / stick.reach * 9
            Circle { r: 42.9; color: stick.pressed ? pad.lit : pad.face }
        }
    }

    // Four buttons in a ring: the face buttons, or the d-pad
    component Petals: Item {
        id: petals
        property bool topHeld
        property bool rightHeld
        property bool bottomHeld
        property bool leftHeld
        Circle { r: 57.4 }
        Petal { rotation: 0; pressed: petals.topHeld }
        Petal { rotation: 90; pressed: petals.rightHeld }
        Petal { rotation: 180; pressed: petals.bottomHeld }
        Petal { rotation: 270; pressed: petals.leftHeld }
    }

    // One of them, at the top of a 90 x 90 box round the ring's centre
    // (turned to its place by rotation)
    component Petal: Shape {
        id: petal
        property bool pressed
        x: -45; y: -45
        width: 90; height: 90
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: pad.line
            strokeWidth: pad.stroke
            fillColor: petal.pressed ? pad.lit : pad.face
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M 45.0,4.2 C 42.7,4.2 40.3,4.2 38.1,4.5 C 36.0,4.8 33.8,5.2 31.9,6.1 "
                      + "C 30.0,6.9 27.7,8.1 26.7,9.8 C 25.8,11.4 25.8,14.0 26.2,16.0 "
                      + "C 26.7,17.9 28.2,19.8 29.5,21.5 C 30.8,23.1 32.5,24.5 34.1,26.0 "
                      + "C 35.7,27.4 37.3,29.0 39.1,30.0 C 40.9,31.1 43.0,32.3 45.0,32.3 "
                      + "C 47.0,32.3 49.1,31.1 50.9,30.0 C 52.7,29.0 54.3,27.4 55.9,26.0 "
                      + "C 57.5,24.5 59.2,23.1 60.5,21.5 C 61.8,19.8 63.3,17.9 63.8,16.0 "
                      + "C 64.2,14.0 64.2,11.4 63.3,9.8 C 62.3,8.1 60.0,6.9 58.1,6.1 C 56.2,5.2 54.0,4.8 51.9,4.5 "
                      + "C 49.7,4.2 47.3,4.2 45.0,4.2 Z"
            }
        }
    }

    // A trigger, round at the top, filling up from the bottom as it's squeezed
    component Trigger: Item {
        id: trigger
        property real amount                    // 0 to 1
        width: 46.7; height: 68.3

        Rectangle {
            anchors.fill: parent
            topLeftRadius: width / 2; topRightRadius: width / 2
            bottomLeftRadius: 11.7; bottomRightRadius: 11.7
            color: pad.face
        }
        Item {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * Math.min(trigger.amount, 1)
            clip: true
            visible: trigger.amount > 0.02
            Rectangle {
                anchors.bottom: parent.bottom
                width: trigger.width; height: trigger.height
                topLeftRadius: width / 2; topRightRadius: width / 2
                bottomLeftRadius: 11.7; bottomRightRadius: 11.7
                color: pad.lit
            }
        }
        Rectangle {
            anchors.fill: parent
            topLeftRadius: width / 2; topRightRadius: width / 2
            bottomLeftRadius: 11.7; bottomRightRadius: 11.7
            color: "transparent"
            border.color: pad.line
            border.width: pad.stroke
        }
    }

    component Bumper: Rectangle {
        property bool pressed
        width: 66.6; height: 23.9
        radius: height / 2
        color: pressed ? pad.lit : pad.face
        border.color: pad.line
        border.width: pad.stroke
    }
}