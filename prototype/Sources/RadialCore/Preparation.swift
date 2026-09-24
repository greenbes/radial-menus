extension Change {
    mutating func prepared(_ scope: InputScope, _ operation: OperationID,
                           _ measurements: MenuMeasurements, _ screen: ScreenContext) {
        guard case .preparing(let session, operation) = phase, session.scope == scope else { return }
        do {
            guard measurements.style == session.style else { throw LayoutFailure.invalidMeasurements }
            let layout = try MenuLayout.make(menu: session.menu, measurements: measurements,
                context: session.presentation.context, availableSize: Size(width: screen.bounds.width, height: screen.bounds.height))
            let placement = try layout.placement(in: screen)
            guard let presentation = allocateOperation() else { return }
            phase = .presenting(session.prepared(layout), presentation)
            effects.append(.present(scope, layout, placement, presentation))
        } catch {
            let message = (error as? LayoutFailure)?.message ?? "Menu layout preparation failed"
            dismiss(session, .failed(SessionFailure(message: message)))
        }
    }
}
