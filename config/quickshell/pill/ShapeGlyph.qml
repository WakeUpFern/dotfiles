import QtQuick
import QtQuick.Shapes

// Un "caracter" de la contrasena dibujado como figura:
// 0 circulo, 1 cuadrado redondeado, 2 triangulo, 3 estrella, 4 rombo.
Item {
    id: g

    property int kind: 0
    property color color: "white"
    property real size: 28

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    function star(cx, cy, ro, ri) {
        const pts = [];
        for (let i = 0; i <= 10; i++) {                  // i = 10 cierra el poligono
            const r = i % 2 === 0 ? ro : ri;
            const a = -Math.PI / 2 + i * Math.PI / 5;
            pts.push(Qt.point((cx + r * Math.cos(a)) * size, (cy + r * Math.sin(a)) * size));
        }
        return pts;
    }

    readonly property var poly: {
        switch (kind) {
        case 2: return [Qt.point(0.50 * size, 0.16 * size), Qt.point(0.86 * size, 0.80 * size),
                        Qt.point(0.14 * size, 0.80 * size), Qt.point(0.50 * size, 0.16 * size)];
        case 3: return star(0.5, 0.54, 0.38, 0.18);
        case 4: return [Qt.point(0.50 * size, 0.10 * size), Qt.point(0.90 * size, 0.50 * size),
                        Qt.point(0.50 * size, 0.90 * size), Qt.point(0.10 * size, 0.50 * size),
                        Qt.point(0.50 * size, 0.10 * size)];
        default: return [];
        }
    }

    Rectangle {
        visible: g.kind === 0
        anchors.fill: parent
        anchors.margins: g.size * 0.08
        radius: width / 2
        color: g.color
    }

    Rectangle {
        visible: g.kind === 1
        anchors.fill: parent
        anchors.margins: g.size * 0.10
        radius: width * 0.28
        color: g.color
    }

    Shape {
        visible: g.kind >= 2
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: g.color
            strokeColor: g.color
            strokeWidth: g.size * 0.14        // el trazo redondeado suaviza las esquinas
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: g.poly }
        }
    }
}
