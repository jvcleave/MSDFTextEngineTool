import CoreText
import Foundation

struct ResolvedFontAsset: Equatable
{
    let fontURL: URL
    let temporaryFontURL: URL?
}

enum FontAssetResolver
{
    static func resolveFont(
        fontPath: String,
        fontPostScriptName: String?,
        relativeTo baseDirectoryURL: URL
    ) throws -> ResolvedFontAsset
    {
        let trimmedFontPath = fontPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuredFontURL: URL?
        if trimmedFontPath.isEmpty
        {
            configuredFontURL = nil
        }
        else
        {
            configuredFontURL = AtlasConfig.resolvePath(
                trimmedFontPath,
                relativeTo: baseDirectoryURL
            )
        }

        guard let fontPostScriptName
        else
        {
            if let configuredFontURL
            {
                return ResolvedFontAsset(
                    fontURL: configuredFontURL,
                    temporaryFontURL: nil
                )
            }

            throw ToolError(
                "No font input was provided. Set a font file path or a font PostScript name."
            )
        }

        let trimmedFontPostScriptName = fontPostScriptName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedFontPostScriptName.isEmpty
        {
            if let configuredFontURL
            {
                return ResolvedFontAsset(
                    fontURL: configuredFontURL,
                    temporaryFontURL: nil
                )
            }

            throw ToolError(
                "No font input was provided. Set a font file path or a font PostScript name."
            )
        }

        var candidateFontURLs: [URL] = []

        if let configuredFontURL = existingFileURL(configuredFontURL)
        {
            candidateFontURLs.append(configuredFontURL)
        }

        let installedFontURL = try installedFontURL(
            fontPostScriptName: trimmedFontPostScriptName
        )

        if !candidateFontURLs.contains(installedFontURL)
        {
            candidateFontURLs.append(installedFontURL)
        }

        for candidateFontURL in candidateFontURLs
        {
            if !fileContainsFont(
                fontURL: candidateFontURL,
                fontPostScriptName: trimmedFontPostScriptName
            )
            {
                continue
            }

            switch candidateFontURL.pathExtension.lowercased()
            {
            case "ttf", "otf":
                return ResolvedFontAsset(
                    fontURL: candidateFontURL,
                    temporaryFontURL: nil
                )

            case "ttc", "otc":
                let extractedFontURL = try FontCollectionExtractor
                    .extractStandaloneFont(
                        collectionURL: candidateFontURL,
                        fontPostScriptName: trimmedFontPostScriptName
                    )
                return ResolvedFontAsset(
                    fontURL: extractedFontURL,
                    temporaryFontURL: extractedFontURL
                )

            default:
                throw ToolError(
                    """
                    Font '\(trimmedFontPostScriptName)' was found at \(candidateFontURL.path), \
                    but TextEngineTool does not yet support that container format.
                    """
                )
            }
        }

        throw ToolError(
            """
            Could not resolve font '\(trimmedFontPostScriptName)'. \
            Set fontPath to a matching font file or install the font locally.
            """
        )
    }

    private static func existingFileURL(_ url: URL?) -> URL?
    {
        guard let url
        else
        {
            return nil
        }

        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        )

        if !exists || isDirectory.boolValue
        {
            return nil
        }

        return url
    }

    private static func installedFontURL(
        fontPostScriptName: String
    ) throws -> URL
    {
        let queryAttributes = [
            kCTFontNameAttribute as String: fontPostScriptName,
        ] as CFDictionary
        let queryDescriptor = CTFontDescriptorCreateWithAttributes(
            queryAttributes
        )
        let matchingDescriptors = CTFontDescriptorCreateMatchingFontDescriptors(
            queryDescriptor,
            nil
        ) as? [CTFontDescriptor] ?? []

        for matchingDescriptor in matchingDescriptors
        {
            let font = CTFontCreateWithFontDescriptor(
                matchingDescriptor,
                64,
                nil
            )
            let matchedPostScriptName = CTFontCopyPostScriptName(font) as String

            if matchedPostScriptName != fontPostScriptName
            {
                continue
            }

            if let fontURL = CTFontCopyAttribute(
                font,
                kCTFontURLAttribute
            ) as? URL
            {
                return fontURL
            }
        }

        throw ToolError(
            "Could not find installed font '\(fontPostScriptName)'"
        )
    }

    private static func fileContainsFont(
        fontURL: URL,
        fontPostScriptName: String
    ) -> Bool
    {
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(
            fontURL as CFURL
        ) as? [CTFontDescriptor] ?? []

        for descriptor in descriptors
        {
            if let resolvedPostScriptName = CTFontDescriptorCopyAttribute(
                descriptor,
                kCTFontNameAttribute
            ) as? String,
                resolvedPostScriptName == fontPostScriptName
            {
                return true
            }
        }

        return false
    }
}

enum FontCollectionExtractor
{
    private struct TableRecord
    {
        let tag: String
        let length: Int
        var tableData: Data
        var destinationOffset: Int
    }

    static func extractStandaloneFont(
        collectionURL: URL,
        fontPostScriptName: String
    ) throws -> URL
    {
        let collectionData = try Data(contentsOf: collectionURL)
        let faceOffset = try faceOffset(
            collectionData: collectionData,
            fontPostScriptName: fontPostScriptName
        )
        let standaloneFontData = try standaloneFontData(
            collectionData: collectionData,
            faceOffset: faceOffset
        )
        let fontFileExtension = fontFileExtension(
            collectionData: collectionData,
            faceOffset: faceOffset
        )
        let outputURL = temporaryFontURL(
            fontPostScriptName: fontPostScriptName,
            fileExtension: fontFileExtension
        )

        try standaloneFontData.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func faceOffset(
        collectionData: Data,
        fontPostScriptName: String
    ) throws -> Int
    {
        let collectionTag = try tagString(
            collectionData,
            offset: 0
        )

        if collectionTag != "ttcf"
        {
            throw ToolError(
                "Expected a TrueType collection but found '\(collectionTag)'"
            )
        }

        let fontCount = Int(
            try readUInt32(
                collectionData,
                offset: 8
            )
        )

        for fontIndex in 0 ..< fontCount
        {
            let currentFaceOffset = Int(
                try readUInt32(
                    collectionData,
                    offset: 12 + fontIndex * 4
                )
            )
            let currentPostScriptName = try postScriptName(
                collectionData: collectionData,
                faceOffset: currentFaceOffset
            )

            if currentPostScriptName == fontPostScriptName
            {
                return currentFaceOffset
            }
        }

        throw ToolError(
            "Could not find '\(fontPostScriptName)' in the font collection"
        )
    }

    private static func standaloneFontData(
        collectionData: Data,
        faceOffset: Int
    ) throws -> Data
    {
        let sfntVersion = try readUInt32(
            collectionData,
            offset: faceOffset
        )
        let tableCount = Int(
            try readUInt16(
                collectionData,
                offset: faceOffset + 4
            )
        )
        var tableRecords: [TableRecord] = []

        for tableIndex in 0 ..< tableCount
        {
            let recordOffset = faceOffset + 12 + tableIndex * 16
            let tag = try tagString(
                collectionData,
                offset: recordOffset
            )
            let tableOffset = Int(
                try readUInt32(
                    collectionData,
                    offset: recordOffset + 8
                )
            )
            let tableLength = Int(
                try readUInt32(
                    collectionData,
                    offset: recordOffset + 12
                )
            )
            var tableData = try slice(
                collectionData,
                offset: tableOffset,
                length: tableLength
            )

            if tag == "head"
            {
                try replaceUInt32(
                    value: 0,
                    in: &tableData,
                    offset: 8
                )
            }

            tableRecords.append(
                TableRecord(
                    tag: tag,
                    length: tableLength,
                    tableData: tableData,
                    destinationOffset: 0
                )
            )
        }

        let searchPower = highestPowerOfTwoLessThanOrEqualTo(tableCount)
        var entrySelector: UInt16 = 0
        var entryValue = searchPower

        while entryValue > 1
        {
            entrySelector += 1
            entryValue /= 2
        }

        let searchRange = UInt16(searchPower * 16)
        let rangeShift = UInt16(tableCount * 16) - searchRange
        let offsetTableLength = 12 + tableRecords.count * 16
        var currentOffset = offsetTableLength

        for tableRecordIndex in 0 ..< tableRecords.count
        {
            tableRecords[tableRecordIndex].destinationOffset = currentOffset
            currentOffset += tableRecords[tableRecordIndex].tableData.count

            let remainder = currentOffset % 4
            if remainder != 0
            {
                currentOffset += 4 - remainder
            }
        }

        var fontData = Data(count: currentOffset)

        try replaceUInt32(
            value: sfntVersion,
            in: &fontData,
            offset: 0
        )
        try replaceUInt16(
            value: UInt16(tableCount),
            in: &fontData,
            offset: 4
        )
        try replaceUInt16(
            value: searchRange,
            in: &fontData,
            offset: 6
        )
        try replaceUInt16(
            value: entrySelector,
            in: &fontData,
            offset: 8
        )
        try replaceUInt16(
            value: rangeShift,
            in: &fontData,
            offset: 10
        )

        for tableRecordIndex in 0 ..< tableRecords.count
        {
            let tableRecord = tableRecords[tableRecordIndex]
            let recordOffset = 12 + tableRecordIndex * 16
            try replaceTag(
                value: tableRecord.tag,
                in: &fontData,
                offset: recordOffset
            )
            try replaceUInt32(
                value: tableChecksum(tableRecord.tableData),
                in: &fontData,
                offset: recordOffset + 4
            )
            try replaceUInt32(
                value: UInt32(tableRecord.destinationOffset),
                in: &fontData,
                offset: recordOffset + 8
            )
            try replaceUInt32(
                value: UInt32(tableRecord.length),
                in: &fontData,
                offset: recordOffset + 12
            )
            fontData.replaceSubrange(
                tableRecord.destinationOffset ..< tableRecord.destinationOffset + tableRecord.tableData.count,
                with: tableRecord.tableData
            )
        }

        guard let headRecordIndex = tableRecords.firstIndex(where: { $0.tag == "head" })
        else
        {
            throw ToolError("Extracted font is missing a head table")
        }

        let headRecord = tableRecords[headRecordIndex]
        let checksumAdjustment = 0xB1B0AFBA as UInt32 &- fontChecksum(fontData)
        try replaceUInt32(
            value: checksumAdjustment,
            in: &fontData,
            offset: headRecord.destinationOffset + 8
        )

        let headTableData = fontData.subdata(
            in: headRecord.destinationOffset ..< headRecord.destinationOffset + headRecord.length
        )
        try replaceUInt32(
            value: tableChecksum(headTableData),
            in: &fontData,
            offset: 12 + headRecordIndex * 16 + 4
        )

        return fontData
    }

    private static func fontFileExtension(
        collectionData: Data,
        faceOffset: Int
    ) -> String
    {
        guard let sfntTag = try? tagString(
            collectionData,
            offset: faceOffset
        )
        else
        {
            return "ttf"
        }

        switch sfntTag
        {
        case "OTTO":
            return "otf"

        default:
            return "ttf"
        }
    }

    private static func temporaryFontURL(
        fontPostScriptName: String,
        fileExtension: String
    ) -> URL
    {
        let sanitizedName = fontPostScriptName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "TextEngineTool-\(sanitizedName)-\(UUID().uuidString).\(fileExtension)"

        return FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
    }

    private static func postScriptName(
        collectionData: Data,
        faceOffset: Int
    ) throws -> String?
    {
        let tableCount = Int(
            try readUInt16(
                collectionData,
                offset: faceOffset + 4
            )
        )
        var nameTableOffset: Int?
        var nameTableLength: Int?

        for tableIndex in 0 ..< tableCount
        {
            let recordOffset = faceOffset + 12 + tableIndex * 16
            let tag = try tagString(
                collectionData,
                offset: recordOffset
            )

            if tag == "name"
            {
                nameTableOffset = Int(
                    try readUInt32(
                        collectionData,
                        offset: recordOffset + 8
                    )
                )
                nameTableLength = Int(
                    try readUInt32(
                        collectionData,
                        offset: recordOffset + 12
                    )
                )
                break
            }
        }

        guard let nameTableOffset, let nameTableLength
        else
        {
            return nil
        }

        let nameTableData = try slice(
            collectionData,
            offset: nameTableOffset,
            length: nameTableLength
        )
        let recordCount = Int(
            try readUInt16(
                nameTableData,
                offset: 2
            )
        )
        let stringOffset = Int(
            try readUInt16(
                nameTableData,
                offset: 4
            )
        )

        for recordIndex in 0 ..< recordCount
        {
            let recordOffset = 6 + recordIndex * 12
            let platformID = try readUInt16(
                nameTableData,
                offset: recordOffset
            )
            let nameID = try readUInt16(
                nameTableData,
                offset: recordOffset + 6
            )

            if nameID != 6
            {
                continue
            }

            let stringLength = Int(
                try readUInt16(
                    nameTableData,
                    offset: recordOffset + 8
                )
            )
            let stringRecordOffset = Int(
                try readUInt16(
                    nameTableData,
                    offset: recordOffset + 10
                )
            )
            let rawStringData = try slice(
                nameTableData,
                offset: stringOffset + stringRecordOffset,
                length: stringLength
            )

            if let decodedString = decodeNameRecord(
                platformID: platformID,
                data: rawStringData
            )
            {
                return decodedString
            }
        }

        return nil
    }

    private static func decodeNameRecord(
        platformID: UInt16,
        data: Data
    ) -> String?
    {
        switch platformID
        {
        case 0, 3:
            return String(data: data, encoding: .utf16BigEndian)

        case 1:
            return String(data: data, encoding: .macOSRoman)

        default:
            return nil
        }
    }

    private static func highestPowerOfTwoLessThanOrEqualTo(
        _ value: Int
    ) -> Int
    {
        var currentValue = 1

        while currentValue * 2 <= value
        {
            currentValue *= 2
        }

        return currentValue
    }

    private static func tagString(
        _ data: Data,
        offset: Int
    ) throws -> String
    {
        let tagData = try slice(
            data,
            offset: offset,
            length: 4
        )

        guard let tag = String(data: tagData, encoding: .macOSRoman)
        else
        {
            throw ToolError("Could not decode font table tag")
        }

        return tag
    }

    private static func readUInt16(
        _ data: Data,
        offset: Int
    ) throws -> UInt16
    {
        let valueData = try slice(
            data,
            offset: offset,
            length: 2
        )

        return (UInt16(valueData[0]) << 8) | UInt16(valueData[1])
    }

    private static func readUInt32(
        _ data: Data,
        offset: Int
    ) throws -> UInt32
    {
        let valueData = try slice(
            data,
            offset: offset,
            length: 4
        )

        return (UInt32(valueData[0]) << 24)
            | (UInt32(valueData[1]) << 16)
            | (UInt32(valueData[2]) << 8)
            | UInt32(valueData[3])
    }

    private static func replaceUInt16(
        value: UInt16,
        in data: inout Data,
        offset: Int
    ) throws
    {
        let replacementData = Data([
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ])
        try replaceData(
            replacementData,
            in: &data,
            offset: offset
        )
    }

    private static func replaceUInt32(
        value: UInt32,
        in data: inout Data,
        offset: Int
    ) throws
    {
        let replacementData = Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ])
        try replaceData(
            replacementData,
            in: &data,
            offset: offset
        )
    }

    private static func replaceTag(
        value: String,
        in data: inout Data,
        offset: Int
    ) throws
    {
        guard let replacementData = value.data(using: .macOSRoman),
              replacementData.count == 4
        else
        {
            throw ToolError("Invalid font table tag '\(value)'")
        }

        try replaceData(
            replacementData,
            in: &data,
            offset: offset
        )
    }

    private static func replaceData(
        _ replacementData: Data,
        in data: inout Data,
        offset: Int
    ) throws
    {
        let range = offset ..< offset + replacementData.count

        if range.upperBound > data.count
        {
            throw ToolError("Font data write went out of bounds")
        }

        data.replaceSubrange(range, with: replacementData)
    }

    private static func slice(
        _ data: Data,
        offset: Int,
        length: Int
    ) throws -> Data
    {
        let range = offset ..< offset + length

        if range.lowerBound < 0 || range.upperBound > data.count
        {
            throw ToolError("Font data read went out of bounds")
        }

        return data.subdata(in: range)
    }

    private static func tableChecksum(
        _ tableData: Data
    ) -> UInt32
    {
        let paddedLength = ((tableData.count + 3) / 4) * 4
        var checksum: UInt64 = 0

        for wordOffset in stride(from: 0, to: paddedLength, by: 4)
        {
            var wordValue: UInt32 = 0
            let wordLength = min(4, max(0, tableData.count - wordOffset))

            if wordLength > 0
            {
                let wordData = tableData.subdata(
                    in: wordOffset ..< wordOffset + wordLength
                )

                for byte in wordData
                {
                    wordValue = (wordValue << 8) | UInt32(byte)
                }

                let missingBytes = 4 - wordLength
                if missingBytes > 0
                {
                    wordValue <<= UInt32(missingBytes * 8)
                }
            }

            checksum += UInt64(wordValue)
        }

        return UInt32(truncatingIfNeeded: checksum)
    }

    private static func fontChecksum(
        _ fontData: Data
    ) -> UInt32
    {
        tableChecksum(fontData)
    }
}
