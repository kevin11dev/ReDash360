import QtQuick
import QtQuick.Shapes

// Someone's avatar from ReDash360 (the animated picture on their Social
// tab), or for anyone without one a plain standing figure, like the white
// "ghost" avatars on the 360's Sign In screen. lit: the profile you're on,
// standing out and moving, with a shadow at its feet; the others are faded
// and still.
Item {
    id: avatar
    property bool lit: false
    property string source                      // their avatar, if they have one

    width: 220
    height: 410
    opacity: lit ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // Shadow on the floor
    Shape {
        x: 20; y: 372
        width: 180; height: 36
        opacity: avatar.lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 90; centerY: 18; centerRadius: 90
                focalX: 90; focalY: 18
                GradientStop { position: 0.0; color: "#55000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
            PathSvg { path: "M0,18 A90,18 0 1,0 180,18 A90,18 0 1,0 0,18 Z" }
        }
    }

    AnimatedImage {
        id: own
        x: -5
        width: 230; height: 400                 // standing on the shadow
        source: avatar.source
        visible: status === AnimatedImage.Ready
        playing: avatar.lit
        fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom
        smooth: true
        asynchronous: true
    }

    Item {
        id: figure
        width: parent.width
        height: parent.height
        visible: !own.visible

        // Breathing: the figure rises and settles while it's the one you're on
        property real bob: 0
        transform: Translate { y: -figure.bob }
        SequentialAnimation on bob {
            running: avatar.lit
            loops: Animation.Infinite
            NumberAnimation { to: 5; duration: 1300; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0; duration: 1300; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) figure.bob = 0
        }

        // The light parts share one shading from head to toe
        LinearGradient {
            id: light
            x1: 0; y1: 10; x2: 0; y2: 400
            GradientStop { position: 0.0; color: "#FFFFFF" }
            GradientStop { position: 0.6; color: "#E4E6E7" }
            GradientStop { position: 1.0; color: "#D2D5D7" }
        }

        // Each part is its own shape, so where they overlap they just overlap
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            Part {                                                  // trousers
                fillGradient: LinearGradient {
                    x1: 0; y1: 250; x2: 0; y2: 390
                    GradientStop { position: 0.0; color: "#A9ADB0" }
                    GradientStop { position: 1.0; color: "#7F8487" }
                }
                PathSvg { path: "M66,250 H154 L151,312 L143,384 H117 L110,318 L103,384 H77 L69,312 Z" }
            }
            Part { PathSvg { path: "M98,116 H122 V140 H98 Z" } }                                  // neck
            Part { PathSvg { path: "M60,150 Q110,128 160,150 L156,262 Q110,272 64,262 Z" } }      // top
            Part { PathSvg { path: "M62,152 Q46,158 42,192 L34,262 Q36,278 49,275 L58,206 Q61,182 70,168 Z" } }        // left arm
            Part { PathSvg { path: "M158,152 Q174,158 178,192 L186,262 Q184,278 171,275 L162,206 Q159,182 150,168 Z" } } // right arm
            Part { PathSvg { path: "M64,70 A46,52 0 1,0 156,70 A46,52 0 1,0 64,70 Z" } }         // head
            Part { PathSvg { path: "M72,390 A20,10 0 1,0 112,390 A20,10 0 1,0 72,390 Z" } }       // left shoe
            Part { PathSvg { path: "M108,390 A20,10 0 1,0 148,390 A20,10 0 1,0 108,390 Z" } }     // right shoe
        }
    }

    component Part: ShapePath {
        strokeColor: "transparent"
        fillGradient: light
    }
}
