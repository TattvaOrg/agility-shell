/*
 * Adapted from pctrade/end4-pC (modules/common/widgets/MaterialShape.qml and
 * modules/common/functions/ShapeUtils.qml), originally derived from
 * end-4/dots-hyprland (illogical-impulse), licensed under GNU GPL v3.0.
 * Uses the Apache-2.0 Material 3 rounded-polygon shape engine in ./shapes/.
 *
 * Modified for Agility Shell (2026): standalone integration with Agility's
 * DesktopWidgets/End module; combined under AGPL-3.0 Section 13 / GPL-3.0 Section 13.
 */
import QtQuick
import "shapes"
import "shapes/material-shapes.js" as MaterialShapes

ShapeCanvas {
    id: root

    enum Shape {
        Circle,
        Square,
        Slanted,
        Arch,
        Fan,
        Arrow,
        SemiCircle,
        Oval,
        Pill,
        Triangle,
        Diamond,
        ClamShell,
        Pentagon,
        Gem,
        Sunny,
        VerySunny,
        Cookie4Sided,
        Cookie6Sided,
        Cookie7Sided,
        Cookie9Sided,
        Cookie12Sided,
        Ghostish,
        Clover4Leaf,
        Clover8Leaf,
        Burst,
        SoftBurst,
        Boom,
        SoftBoom,
        Flower,
        Puffy,
        PuffyDiamond,
        PixelCircle,
        PixelTriangle,
        Bun,
        Heart
    }

    property int shape: MaterialShape.Shape.Arch
    property string shapeName: ""
    property double implicitSize: 100

    function shapeFromName(name) {
        switch (name) {
            case "Circle":        return MaterialShape.Shape.Circle
            case "Square":        return MaterialShape.Shape.Square
            case "Slanted":       return MaterialShape.Shape.Slanted
            case "Arch":          return MaterialShape.Shape.Arch
            case "Fan":           return MaterialShape.Shape.Fan
            case "Arrow":         return MaterialShape.Shape.Arrow
            case "SemiCircle":    return MaterialShape.Shape.SemiCircle
            case "Oval":          return MaterialShape.Shape.Oval
            case "Pill":          return MaterialShape.Shape.Pill
            case "Triangle":      return MaterialShape.Shape.Triangle
            case "Diamond":       return MaterialShape.Shape.Diamond
            case "ClamShell":     return MaterialShape.Shape.ClamShell
            case "Pentagon":      return MaterialShape.Shape.Pentagon
            case "Gem":           return MaterialShape.Shape.Gem
            case "Sunny":         return MaterialShape.Shape.Sunny
            case "VerySunny":     return MaterialShape.Shape.VerySunny
            case "Cookie4Sided":  return MaterialShape.Shape.Cookie4Sided
            case "Cookie6Sided":  return MaterialShape.Shape.Cookie6Sided
            case "Cookie7Sided":  return MaterialShape.Shape.Cookie7Sided
            case "Cookie9Sided":  return MaterialShape.Shape.Cookie9Sided
            case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided
            case "Ghostish":      return MaterialShape.Shape.Ghostish
            case "Clover4Leaf":   return MaterialShape.Shape.Clover4Leaf
            case "Clover8Leaf":   return MaterialShape.Shape.Clover8Leaf
            case "Burst":         return MaterialShape.Shape.Burst
            case "SoftBurst":     return MaterialShape.Shape.SoftBurst
            case "Boom":          return MaterialShape.Shape.Boom
            case "SoftBoom":      return MaterialShape.Shape.SoftBoom
            case "Flower":        return MaterialShape.Shape.Flower
            case "Puffy":         return MaterialShape.Shape.Puffy
            case "PuffyDiamond":  return MaterialShape.Shape.PuffyDiamond
            case "PixelCircle":   return MaterialShape.Shape.PixelCircle
            case "PixelTriangle": return MaterialShape.Shape.PixelTriangle
            case "Bun":           return MaterialShape.Shape.Bun
            case "Heart":         return MaterialShape.Shape.Heart
            default:              return MaterialShape.Shape.Arch
        }
    }

    readonly property int resolvedShape: shapeName !== "" ? shapeFromName(shapeName) : shape

    implicitHeight: implicitSize
    implicitWidth: implicitSize
    polygonIsNormalized: true
    roundedPolygon: {
        switch (root.resolvedShape) {
            case MaterialShape.Shape.Circle: return MaterialShapes.getCircle();
            case MaterialShape.Shape.Square: return MaterialShapes.getSquare();
            case MaterialShape.Shape.Slanted: return MaterialShapes.getSlanted();
            case MaterialShape.Shape.Arch: return MaterialShapes.getArch();
            case MaterialShape.Shape.Fan: return MaterialShapes.getFan();
            case MaterialShape.Shape.Arrow: return MaterialShapes.getArrow();
            case MaterialShape.Shape.SemiCircle: return MaterialShapes.getSemiCircle();
            case MaterialShape.Shape.Oval: return MaterialShapes.getOval();
            case MaterialShape.Shape.Pill: return MaterialShapes.getPill();
            case MaterialShape.Shape.Triangle: return MaterialShapes.getTriangle();
            case MaterialShape.Shape.Diamond: return MaterialShapes.getDiamond();
            case MaterialShape.Shape.ClamShell: return MaterialShapes.getClamShell();
            case MaterialShape.Shape.Pentagon: return MaterialShapes.getPentagon();
            case MaterialShape.Shape.Gem: return MaterialShapes.getGem();
            case MaterialShape.Shape.Sunny: return MaterialShapes.getSunny();
            case MaterialShape.Shape.VerySunny: return MaterialShapes.getVerySunny();
            case MaterialShape.Shape.Cookie4Sided: return MaterialShapes.getCookie4Sided();
            case MaterialShape.Shape.Cookie6Sided: return MaterialShapes.getCookie6Sided();
            case MaterialShape.Shape.Cookie7Sided: return MaterialShapes.getCookie7Sided();
            case MaterialShape.Shape.Cookie9Sided: return MaterialShapes.getCookie9Sided();
            case MaterialShape.Shape.Cookie12Sided: return MaterialShapes.getCookie12Sided();
            case MaterialShape.Shape.Ghostish: return MaterialShapes.getGhostish();
            case MaterialShape.Shape.Clover4Leaf: return MaterialShapes.getClover4Leaf();
            case MaterialShape.Shape.Clover8Leaf: return MaterialShapes.getClover8Leaf();
            case MaterialShape.Shape.Burst: return MaterialShapes.getBurst();
            case MaterialShape.Shape.SoftBurst: return MaterialShapes.getSoftBurst();
            case MaterialShape.Shape.Boom: return MaterialShapes.getBoom();
            case MaterialShape.Shape.SoftBoom: return MaterialShapes.getSoftBoom();
            case MaterialShape.Shape.Flower: return MaterialShapes.getFlower();
            case MaterialShape.Shape.Puffy: return MaterialShapes.getPuffy();
            case MaterialShape.Shape.PuffyDiamond: return MaterialShapes.getPuffyDiamond();
            case MaterialShape.Shape.PixelCircle: return MaterialShapes.getPixelCircle();
            case MaterialShape.Shape.PixelTriangle: return MaterialShapes.getPixelTriangle();
            case MaterialShape.Shape.Bun: return MaterialShapes.getBun();
            case MaterialShape.Shape.Heart: return MaterialShapes.getHeart();
            default: return MaterialShapes.getArch();
        }
    }
}
