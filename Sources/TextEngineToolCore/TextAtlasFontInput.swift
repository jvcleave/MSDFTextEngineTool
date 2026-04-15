import Foundation

public enum TextAtlasFontInput: Equatable
{
    case fontFile(URL)
    case installedFont(postScriptName: String)
    case fontFileFace(
        fontURL: URL,
        postScriptName: String
    )

    public func apply(to config: inout AtlasConfig)
    {
        switch self
        {
        case let .fontFile(fontURL):
            config.fontPath = fontURL.path
            config.fontPostScriptName = nil

        case let .installedFont(postScriptName):
            config.fontPath = ""
            config.fontPostScriptName = postScriptName

        case let .fontFileFace(fontURL, postScriptName):
            config.fontPath = fontURL.path
            config.fontPostScriptName = postScriptName
        }
    }
}
