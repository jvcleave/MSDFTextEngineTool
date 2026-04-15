import SwiftUI
import Metal
import MetalKit
import ImageIO

final class MSDFExampleTextRenderer
{
    private struct GlyphInstance
    {
        var screenRect: SIMD4<Float>
        var atlasUVRect: SIMD4<Float>
        var color: SIMD4<Float>
    }

    private struct MSDFUniforms
    {
        var viewportSize: SIMD2<Float>
        var distanceRange: Float
        var padding: Float
    }

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    var atlasBundle: MSDFAtlasBundle?
    var atlasTexture: MTLTexture?
    private var loadedAtlasImageURL: URL?

    var text: String = "HELLO"
    var fontSize: CGFloat = 64
    var opacity: Double = 1.0
    var foregroundCGColor: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    var backgroundClearColor: MTLClearColor = MTLClearColorMake(0.08, 0.08, 0.1, 1)

    private var pipelineState: MTLRenderPipelineState?
    private var samplerState: MTLSamplerState?

    init(device: MTLDevice)
    {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        buildPipeline()
    }

    func loadAtlasIfNeeded(atlasBundle: MSDFAtlasBundle)
    {
        let newAtlasImageURL = atlasBundle.atlasImageURL
        if loadedAtlasImageURL != newAtlasImageURL
        {
            atlasTexture = loadAtlasTexture(
                atlasBundle: atlasBundle,
                device: device
            )
            self.atlasBundle = atlasBundle
            loadedAtlasImageURL = newAtlasImageURL
        }
    }

    func draw(in view: MTKView)
    {
        guard let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        passDescriptor.colorAttachments[0].clearColor = backgroundClearColor
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store

        guard let pipelineState,
              let samplerState,
              let atlasBundle,
              let atlasTexture
        else
        {
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
            {
                encoder.endEncoding()
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else { return }

        let viewportSize = view.drawableSize
        let layoutRect = CGRect(origin: .zero, size: viewportSize)
        let instances = buildGlyphInstances(
            atlasBundle: atlasBundle,
            layoutRect: layoutRect,
            fontSize: fontSize
        )

        guard !instances.isEmpty
        else
        {
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }

        let instancesLength = MemoryLayout<GlyphInstance>.stride * instances.count
        guard let instancesBuffer = instances.withUnsafeBytes({ bytes -> MTLBuffer? in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device.makeBuffer(
                bytes: baseAddress,
                length: instancesLength,
                options: .storageModeShared
            )
        })
        else
        {
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }

        var uniforms = MSDFUniforms(
            viewportSize: SIMD2<Float>(
                Float(viewportSize.width),
                Float(viewportSize.height)
            ),
            distanceRange: Float(atlasBundle.metadata.atlas.distanceRange),
            padding: Float(atlasBundle.metadata.atlas.padding)
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(instancesBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<MSDFUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MSDFUniforms>.stride, index: 0)
        encoder.setFragmentTexture(atlasTexture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: instances.count
        )
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func buildPipeline()
    {
        guard let library = device.makeDefaultLibrary()
        else
        {
            print("[MSDFPreview] Failed to load default Metal library")
            return
        }

        guard let vertexFunction = library.makeFunction(name: "msdf_vertex"),
              let fragmentFunction = library.makeFunction(name: "msdf_fragment")
        else
        {
            print("[MSDFPreview] Missing shader functions in compiled library")
            return
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do
        {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        }
        catch
        {
            print("[MSDFPreview] Pipeline state creation failed: \(error)")
            return
        }

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    private func buildGlyphInstances(
        atlasBundle: MSDFAtlasBundle,
        layoutRect: CGRect,
        fontSize: CGFloat
    ) -> [GlyphInstance]
    {
        let characters = Array(text)
        if characters.isEmpty
        {
            return []
        }

        let metadata = atlasBundle.metadata
        let scale = fontSize / CGFloat(metadata.atlas.emSize)
        let simdColor = simd4Color(foregroundCGColor, opacity: Float(opacity))

        var penX: CGFloat = 0
        var lineMinX = CGFloat.greatestFiniteMagnitude
        var lineMaxX = -CGFloat.greatestFiniteMagnitude
        var lineMinY = CGFloat.greatestFiniteMagnitude
        var lineMaxY = -CGFloat.greatestFiniteMagnitude
        var positionedGlyphs: [(screen: CGRect, uv: CGRect)] = []

        for character in characters
        {
            if let glyph = atlasBundle.glyph(for: character)
            {
                if let planeBounds = glyph.planeBoundsPx, let atlasUV = glyph.atlasBoundsUV
                {
                    let screenRect = CGRect(
                        x: penX + CGFloat(planeBounds.left) * scale,
                        y: CGFloat(planeBounds.top) * scale,
                        width: CGFloat(planeBounds.right - planeBounds.left) * scale,
                        height: CGFloat(planeBounds.bottom - planeBounds.top) * scale
                    )
                    let uvRect = CGRect(
                        x: atlasUV.left,
                        y: atlasUV.top,
                        width: atlasUV.right - atlasUV.left,
                        height: atlasUV.bottom - atlasUV.top
                    )
                    positionedGlyphs.append((screenRect, uvRect))
                    lineMinX = min(lineMinX, screenRect.minX)
                    lineMaxX = max(lineMaxX, screenRect.maxX)
                    lineMinY = min(lineMinY, screenRect.minY)
                    lineMaxY = max(lineMaxY, screenRect.maxY)
                }

                penX += CGFloat(glyph.advancePx) * scale
            }
            else if character == " "
            {
                penX += fontSize * 0.33
            }
        }

        if positionedGlyphs.isEmpty
        {
            return []
        }

        let centerX = layoutRect.midX - (lineMinX + lineMaxX) * 0.5
        let centerY = layoutRect.midY - (lineMinY + lineMaxY) * 0.5

        return positionedGlyphs.map
        { positionedGlyph in
            let centeredScreenRect = positionedGlyph.screen.offsetBy(dx: centerX, dy: centerY)
            return GlyphInstance(
                screenRect: SIMD4<Float>(
                    Float(centeredScreenRect.minX),
                    Float(centeredScreenRect.minY),
                    Float(centeredScreenRect.maxX),
                    Float(centeredScreenRect.maxY)
                ),
                atlasUVRect: SIMD4<Float>(
                    Float(positionedGlyph.uv.minX),
                    Float(positionedGlyph.uv.minY),
                    Float(positionedGlyph.uv.maxX),
                    Float(positionedGlyph.uv.maxY)
                ),
                color: simdColor
            )
        }
    }

    private func loadAtlasTexture(
        atlasBundle: MSDFAtlasBundle,
        device: MTLDevice
    ) -> MTLTexture?
    {
        let atlasBundleLoader = MSDFAtlasBundleLoader.shared
        if !atlasBundleLoader.hasRequiredFiles(bundle: atlasBundle)
        {
            print(
                "[MSDFPreview] Missing required atlas files: \(atlasBundleLoader.missingRequiredFilePaths(bundle: atlasBundle))"
            )
            return nil
        }

        let imageURL = atlasBundle.atlasImageURL
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else
        {
            print("[MSDFPreview] CGImageSource failed for: \(imageURL.path)")
            return nil
        }

        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .generateMipmaps: false,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
        ]

        let texture: MTLTexture
        do
        {
            texture = try loader.newTexture(cgImage: cgImage, options: options)
        }
        catch
        {
            print("[MSDFPreview] MTKTextureLoader failed: \(error)")
            return nil
        }

        texture.label = "MSDFAtlas"
        return texture
    }

    private func simd4Color(_ color: CGColor, opacity: Float) -> SIMD4<Float>
    {
        let rgbColor = color.converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ) ?? color
        let components = rgbColor.components ?? [1, 1, 1, 1]
        switch components.count
        {
        case 4...:
            return SIMD4<Float>(
                Float(components[0]),
                Float(components[1]),
                Float(components[2]),
                Float(components[3]) * opacity
            )
        case 2:
            return SIMD4<Float>(
                Float(components[0]),
                Float(components[0]),
                Float(components[0]),
                Float(components[1]) * opacity
            )
        default:
            return SIMD4<Float>(1, 1, 1, opacity)
        }
    }
}
