import SwiftUI
import Metal
import MetalKit

final class MSDFPreviewCoordinator: NSObject, MTKViewDelegate
{
    let renderer: MSDFExampleTextRenderer

    init(device: MTLDevice)
    {
        renderer = MSDFExampleTextRenderer(device: device)
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView)
    {
        renderer.draw(in: view)
    }
}

struct MSDFTextPreviewView: NSViewRepresentable
{
    let atlasBundle: MSDFAtlasBundle
    let text: String
    let fontSize: CGFloat
    let opacity: Double
    let foregroundColor: Color
    let backgroundColor: Color

    init(
        atlasBundle: MSDFAtlasBundle,
        text: String,
        fontSize: CGFloat,
        opacity: Double,
        foregroundColor: Color,
        backgroundColor: Color
    )
    {
        self.atlasBundle = atlasBundle
        self.text = text
        self.fontSize = fontSize
        self.opacity = opacity
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    func makeCoordinator() -> MSDFPreviewCoordinator
    {
        guard let device = MTLCreateSystemDefaultDevice()
        else { fatalError("Metal is not available on this device") }
        return MSDFPreviewCoordinator(device: device)
    }

    func makeNSView(context: Context) -> MTKView
    {
        let coordinator = context.coordinator
        let view = MTKView(frame: .zero, device: coordinator.renderer.device)
        view.delegate = coordinator
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true

        coordinator.renderer.loadAtlasIfNeeded(atlasBundle: atlasBundle)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context)
    {
        let coordinator = context.coordinator

        coordinator.renderer.loadAtlasIfNeeded(atlasBundle: atlasBundle)
        coordinator.renderer.text = text
        coordinator.renderer.fontSize = fontSize
        coordinator.renderer.opacity = opacity
        coordinator.renderer.foregroundCGColor = NSColor(foregroundColor)
            .usingColorSpace(.deviceRGB)?.cgColor
            ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1)

        if let bg = NSColor(backgroundColor).usingColorSpace(.deviceRGB)
        {
            coordinator.renderer.backgroundClearColor = MTLClearColorMake(
                bg.redComponent,
                bg.greenComponent,
                bg.blueComponent,
                bg.alphaComponent
            )
        }

        view.needsDisplay = true
    }
}
