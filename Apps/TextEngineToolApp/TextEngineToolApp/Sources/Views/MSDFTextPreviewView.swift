import SwiftUI
import Metal
import MetalKit

// MARK: - MTKView coordinator / renderer

final class MSDFPreviewCoordinator: NSObject, MTKViewDelegate
{
    let renderer: MSDFExampleTextRenderer

    init(device: MTLDevice)
    {
        renderer = MSDFExampleTextRenderer(device: device)
        super.init()
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView)
    {
        renderer.draw(in: view)
    }
}

// MARK: - SwiftUI NSViewRepresentable

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
        let coord = context.coordinator
        let view = MTKView(frame: .zero, device: coord.renderer.device)
        view.delegate = coord
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true

        coord.renderer.loadAtlasIfNeeded(atlasBundle: atlasBundle)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context)
    {
        let coord = context.coordinator

        coord.renderer.loadAtlasIfNeeded(atlasBundle: atlasBundle)
        coord.renderer.text = text
        coord.renderer.fontSize = fontSize
        coord.renderer.opacity = opacity
        coord.renderer.foregroundCGColor = NSColor(foregroundColor)
            .usingColorSpace(.deviceRGB)?.cgColor
            ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1)

        if let bg = NSColor(backgroundColor).usingColorSpace(.deviceRGB)
        {
            coord.renderer.backgroundClearColor = MTLClearColorMake(
                bg.redComponent, bg.greenComponent,
                bg.blueComponent, bg.alphaComponent
            )
        }

        view.needsDisplay = true
    }
}
