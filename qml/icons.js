.pragma library

// White Metro-style tile icons, drawn in a 48x48 box as SVG path data.
//   fill:  shapes that are filled in (where shapes overlap, the overlap becomes a hole)
//   line:  strokes drawn on top, with rounded ends
//   width: stroke width for "line" (default 4)
var shapes = {
    // Disc with a ring cut out and a dot in the middle
    disc: {
        fill: "M3,24 A21,21 0 1,0 45,24 A21,21 0 1,0 3,24 Z" +
              "M16,24 A8,8 0 1,0 32,24 A8,8 0 1,0 16,24 Z" +
              "M20.5,24 A3.5,3.5 0 1,0 27.5,24 A3.5,3.5 0 1,0 20.5,24 Z"
    },
    pin: {
        fill: "M18,4 H30 V8 H28 V19 L35,27 V30 H13 V27 L20,19 V8 H18 Z",
        line: "M24,30 V44"
    },
    clock: {
        line: "M42,24 A18,18 0 1,0 6,24 A18,18 0 1,0 42,24 M24,13 V24 L32,29"
    },
    play: {
        fill: "M19,14 L35,24 L19,34 Z",
        line: "M43,24 A19,19 0 1,0 5,24 A19,19 0 1,0 43,24",
        width: 3.5
    },
    apps: {
        fill: "M5,5 H22 V22 H5 Z M26,5 H43 V22 H26 Z M5,26 H22 V43 H5 Z M26,26 H43 V43 H26 Z"
    },
    search: {
        line: "M32,20 A12,12 0 1,0 8,20 A12,12 0 1,0 32,20 M29,29 L42,42",
        width: 5
    },
    gear: {
        fill: "M39.2,19.1 L44.5,19.5 L44.5,28.5 L39.2,28.9 L38.3,31.3 L41.7,35.3 L35.3,41.7 " +
              "L31.3,38.3 L28.9,39.2 L28.5,44.5 L19.5,44.5 L19.1,39.2 L16.7,38.3 L12.7,41.7 " +
              "L6.3,35.3 L9.7,31.3 L8.8,28.9 L3.5,28.5 L3.5,19.5 L8.8,19.1 L9.7,16.7 L6.3,12.7 " +
              "L12.7,6.3 L16.7,9.7 L19.1,8.8 L19.5,3.5 L28.5,3.5 L28.9,8.8 L31.3,9.7 L35.3,6.3 " +
              "L41.7,12.7 L38.3,16.7 Z" +
              "M17,24 A7,7 0 1,0 31,24 A7,7 0 1,0 17,24 Z"
    },
    // Controller with the guide button cut out
    controller: {
        fill: "M14,12 H34 C40,12 43,16 44,22 L46.5,33 C47.5,39 42.5,42 38.5,38 L33,32.5 H15 " +
              "L9.5,38 C5.5,42 0.5,39 1.5,33 L4,22 C5,16 8,12 14,12 Z" +
              "M21,19 A3,3 0 1,0 27,19 A3,3 0 1,0 21,19 Z"
    },
    person: {
        fill: "M16,13 A8,8 0 1,0 32,13 A8,8 0 1,0 16,13 Z" +
              "M9,44 C9,31 15,24 24,24 C33,24 39,31 39,44 Z"
    },
    // Person with an arrow: sign in / out
    signin: {
        fill: "M11,12 A7,7 0 1,0 25,12 A7,7 0 1,0 11,12 Z" +
              "M4,42 C4,30 9,23 18,23 C27,23 32,30 32,42 Z",
        line: "M30,35 H44 M38,29 L44,35 L38,41"
    },
    // Marketplace shopping bag
    bag: {
        fill: "M8,17 H40 L38,45 H10 Z",
        line: "M17,20 V12 C17,4 31,4 31,12 V20",
        width: 3.5
    },
    plus: {
        line: "M24,7 V41 M7,24 H41",
        width: 6
    },
    download: {
        line: "M24,5 V30 M14,20 L24,30 L34,20 M7,35 V42 H41 V35",
        width: 4.5
    },
    star: {
        fill: "M24.0,4.0 L29.3,17.7 L44.0,18.5 L32.6,27.8 L36.3,42.0 L24.0,34.0 L11.7,42.0 " +
              "L15.4,27.8 L4.0,18.5 L18.7,17.7 Z"
    },
    tv: {
        line: "M5,8 H43 V34 H5 Z M24,34 V41 M15,42 H33",
        width: 4
    },
    // Upright Xbox 360 console with its ring of light cut out
    console: {
        fill: "M18,3 H30 Q35,3 35,8 V40 Q35,45 30,45 H18 Q13,45 13,40 V8 Q13,3 18,3 Z" +
              "M20,27 A4,4 0 1,0 28,27 A4,4 0 1,0 20,27 Z"
    },
    wifi: {
        fill: "M21,40 A3,3 0 1,0 27,40 A3,3 0 1,0 21,40 Z",
        line: "M5,19 A27,27 0 0,1 43,19 M11,26 A18,18 0 0,1 37,26 M17,33 A9,9 0 0,1 31,33",
        width: 4.5
    },
    // Profile card with a person in it
    account: {
        fill: "M18.5,18 A5.5,5.5 0 1,0 29.5,18 A5.5,5.5 0 1,0 18.5,18 Z" +
              "M14,37 C14,30 18,26 24,26 C30,26 34,30 34,37 Z",
        line: "M9,5 H39 V43 H9 Z"
    },
    // Three bullet points, like the 360's Preferences tile
    list: {
        fill: "M5,10 H11 V16 H5 Z M5,21 H11 V27 H5 Z M5,32 H11 V38 H5 Z",
        line: "M17,13 H43 M17,24 H43 M17,35 H43",
        width: 3.5
    },
    // Hard drive: a flat box with a light and a slot
    storage: {
        fill: "M35,24 A2.5,2.5 0 1,0 40,24 A2.5,2.5 0 1,0 35,24 Z",
        line: "M5,14 H43 V34 H5 Z M10,24 H27"
    },
    sliders: {
        fill: "M26,13 A4.5,4.5 0 1,0 35,13 A4.5,4.5 0 1,0 26,13 Z" +
              "M11,24 A4.5,4.5 0 1,0 20,24 A4.5,4.5 0 1,0 11,24 Z" +
              "M22,35 A4.5,4.5 0 1,0 31,35 A4.5,4.5 0 1,0 22,35 Z",
        line: "M6,13 H42 M6,24 H42 M6,35 H42",
        width: 3
    },
    // Padlock with the keyhole cut out
    lock: {
        fill: "M10,21 H38 V44 H10 Z M21,31 A3,3 0 1,0 27,31 A3,3 0 1,0 21,31 Z",
        line: "M16,21 V15 C16,5 32,5 32,15 V21",
        width: 4.5
    },
    power: {
        line: "M24,4 V22 M14,10 A17,17 0 1,0 34,10",
        width: 4.5
    },
    home: {
        fill: "M24,5 L45,24 H39 V43 H29 V31 H19 V43 H9 V24 H3 Z"
    },
    folder: {
        fill: "M3,9 H18 L22,14 H45 V41 H3 Z"
    },
    // A picture in a frame: hills and a sun
    picture: {
        fill: "M3,8 H45 V40 H3 Z M7,12 H41 V35 L31,25 L26,30 L18,21 L7,34 Z" +
              "M29,18 A4,4 0 1,0 37,18 A4,4 0 1,0 29,18 Z"
    },
    // Two notes joined by a beam
    music: {
        fill: "M5,38 A7,5.5 0 1,0 19,38 A7,5.5 0 1,0 5,38 Z" +
              "M28,34 A7,5.5 0 1,0 42,34 A7,5.5 0 1,0 28,34 Z" +
              "M15.5,9 L42.5,4 V11 L15.5,16 Z",
        line: "M17.5,14 V37 M40.5,9 V33"
    },
    // Media buttons
    playSolid: {
        fill: "M13,7 L41,24 L13,41 Z"
    },
    previous: {
        fill: "M8,8 H14 V40 H8 Z M41,8 V40 L16,24 Z"
    },
    next: {
        fill: "M40,8 H34 V40 H40 Z M7,8 V40 L32,24 Z"
    },
    stop: {
        fill: "M10,10 H38 V38 H10 Z"
    },
    shuffle: {
        line: "M5,14 H13 C24,14 24,34 35,34 H43 M5,34 H13 C24,34 24,14 35,14 H43 " +
              "M37,8 L43,14 L37,20 M37,28 L43,34 L37,40",
        width: 4
    },
    volume: {
        fill: "M5,17 H14 L25,8 V40 L14,31 H5 Z",
        line: "M31,17 A10,10 0 0,1 31,31 M36,11 A18,18 0 0,1 36,37",
        width: 3.5
    },
    chevron: {
        line: "M10,17 L24,31 L38,17",
        width: 5
    },
    // Network cable plug: the clip with its pins cut out, the body, the cable
    ethernet: {
        fill: "M12,2 H36 V19 H12 Z M16.5,2 H20.5 V10 H16.5 Z M22,2 H26 V10 H22 Z M27.5,2 H31.5 V10 H27.5 Z" +
              "M9,21 H39 L35,34 H13 Z M18.5,36 H29.5 V46 H18.5 Z"
    },
    globe: {
        line: "M24,4 A20,20 0 1,0 24,44 A20,20 0 1,0 24,4 M4,24 H44 M24,4 C13,14 13,34 24,44 " +
              "M24,4 C35,14 35,34 24,44 M7,14 H41 M7,34 H41",
        width: 3
    },
    check: {
        line: "M9,25 L19,35 L39,13",
        width: 6
    },
    cross: {
        line: "M13,13 L35,35 M35,13 L13,35",
        width: 6
    },
    // USB stick: the plug with its two holes, then the body
    usb: {
        fill: "M17,3 H31 V14 H17 Z M20.5,6.5 H23 V9 H20.5 Z M25,6.5 H27.5 V9 H25 Z" +
              "M13,16 H35 V41 Q35,45 31,45 H17 Q13,45 13,41 Z"
    }
}