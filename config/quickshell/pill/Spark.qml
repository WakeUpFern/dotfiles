import QtQuick

// Grafica de linea con relleno para un historial de valores. `max` > 0 fija el techo; con 0 se ajusta
// al mayor valor visible (para la red). Se repinta solo cuando cambian los datos.
Canvas {
    id: root

    property var values: []
    property real max: 1
    property color color: Theme.accent

    implicitHeight: 38
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values;
        if (!v || v.length < 2 || width < 4) return;
        const top = max > 0 ? max : Math.max(1, ...v);
        const step = width / (60 - 1);
        const x0 = width - (v.length - 1) * step;
        const y = d => height - 2 - Math.min(1, d / top) * (height - 4);

        ctx.beginPath();
        ctx.moveTo(x0, height);
        for (let i = 0; i < v.length; i++) ctx.lineTo(x0 + i * step, y(v[i]));
        ctx.lineTo(x0 + (v.length - 1) * step, height);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.18);
        ctx.fill();

        ctx.beginPath();
        for (let i = 0; i < v.length; i++) {
            if (i === 0) ctx.moveTo(x0, y(v[0])); else ctx.lineTo(x0 + i * step, y(v[i]));
        }
        ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.9);
        ctx.lineWidth = 1.5;
        ctx.lineJoin = "round";
        ctx.stroke();
    }
}
