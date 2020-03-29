//
//  MapView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit
import MapKit

final class MapView: UIViewRepresentable {

    @ObservedObject var segment: TimelineSegment
    @ObservedObject var mapState: MapState

    init(segment: TimelineSegment, mapState: MapState) {
        self.segment = segment
        self.mapState = mapState
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        var zoomOverlays: [MKOverlay] = []

        for timelineItem in segment.timelineItems {
            let disabled = isDisabled(timelineItem)

            if let path = timelineItem as? ArcPath {
                if let overlay = add(path, to: map, disabled: disabled), !disabled {
                    if mapState.itemSegments.isEmpty { zoomOverlays.append(overlay) }
                }

            } else if let visit = timelineItem as? ArcVisit {
                if let overlay = add(visit, to: map, disabled: disabled), !disabled {
                    if mapState.itemSegments.isEmpty { zoomOverlays.append(overlay) }
                }
            }
        }

        for segment in mapState.itemSegments {
            if let overlay = add(segment, to: map) {
                zoomOverlays.append(overlay)
            }
        }

        zoomToShow(overlays: zoomOverlays, in: map)
    }

    func isDisabled(_ timelineItem: TimelineItem) -> Bool {
        if !mapState.itemSegments.isEmpty { return true }
        if mapState.selectedItems.isEmpty { return false }
        return !mapState.selectedItems.contains(timelineItem)
    }

    // MARK: - Adding map elements

    func add(_ path: ArcPath, to map: MKMapView, disabled: Bool) -> MKOverlay? {
        if path.samples.isEmpty { return nil }

        var coords = path.samples.compactMap { $0.location?.coordinate }
        let line = PathPolyline(coordinates: &coords, count: coords.count, color: path.uiColor, disabled: disabled)
        map.addOverlay(line)

        return line
    }

    func add(_ visit: Visit, to map: MKMapView, disabled: Bool) -> MKOverlay? {
        guard let center = visit.center else { return nil }

        if !disabled {
            map.addAnnotation(VisitAnnotation(coordinate: center.coordinate))
        }

        let circle = VisitCircle(center: center.coordinate, radius: visit.radius2sd)
        circle.color = disabled ? .lightGray : .arcPurple
        map.addOverlay(circle, level: .aboveLabels)

        return circle
    }

    func add(_ segment: ItemSegment, to map: MKMapView) -> MKOverlay? {
        if segment.samples.isEmpty { return nil }

        // only one sample? add it alone, with annotation
        if segment.samples.count == 1, let sample = segment.samples.first {
            return add(sample, to: map)
        }

        var coords = segment.samples.compactMap { $0.location?.coordinate }

        let line = PathPolyline(coordinates: &coords, count: coords.count, color: segment.activityType?.color ?? .black)
        map.addOverlay(line)

        return line
    }

    func add(_ sample: LocomotionSample, to map: MKMapView) -> MKOverlay? {
        guard sample.hasUsableCoordinate else { return nil }
        guard let location = sample.location else { return nil }

        map.addAnnotation(VisitAnnotation(coordinate: location.coordinate))

        let circle = VisitCircle(center: location.coordinate, radius: location.horizontalAccuracy)
        circle.color = .arcPurple
        map.addOverlay(circle, level: .aboveLabels)

        return circle
    }

    // MARK: - Zoom

    func zoomToShow(overlays: [MKOverlay], in map: MKMapView) {
        guard !overlays.isEmpty else { return }

        var mapRect: MKMapRect?
        for overlay in overlays {
            if mapRect == nil {
                mapRect = overlay.boundingMapRect
            } else {
                mapRect = mapRect!.union(overlay.boundingMapRect)
            }
        }

        let padding = UIEdgeInsets(top: 20, left: 20, bottom: 420, right: 20)

        map.setVisibleMapRect(mapRect!, edgePadding: padding, animated: true)
    }

    // MARK: - MKMapViewDelegate

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let path = overlay as? PathPolyline { return path.renderer }
            if let circle = overlay as? VisitCircle { return circle.renderer }
            fatalError("you wot?")
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            return (annotation as? VisitAnnotation)?.view
        }
    }

}

//struct MapView_Previews: PreviewProvider {
//    static var previews: some View {
//        MapView()
//    }
//}
