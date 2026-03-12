/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

import CoreGraphics
import Foundation
import ImageIO

enum FrameSelectError: Error {
	case imageLoadFailed(String)
	case contextCreateFailed(String)
	case invalidEnvironmentValue(String, String)
}

struct FrameSummary {
	let path: String
	let width: Int
	let height: Int
	let nonBlackPixels: Int
	let maxChannelValue: Int

	var totalPixels: Int {
		width * height
	}
}

func loadRGBA(_ path: String) throws -> (pixels: [UInt8], width: Int, height: Int) {
	let url = URL(fileURLWithPath: path)

	guard
		let source = CGImageSourceCreateWithURL(url as CFURL, nil),
		let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
	else {
		throw FrameSelectError.imageLoadFailed(path)
	}

	let width = image.width
	let height = image.height
	let bytesPerPixel = 4
	let bytesPerRow = width * bytesPerPixel
	var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

	let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
	guard let context = CGContext(
		data: &pixels,
		width: width,
		height: height,
		bitsPerComponent: 8,
		bytesPerRow: bytesPerRow,
		space: CGColorSpaceCreateDeviceRGB(),
		bitmapInfo: bitmapInfo
	) else {
		throw FrameSelectError.contextCreateFailed(path)
	}

	context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
	return (pixels, width, height)
}

func summarizeFrame(_ path: String) throws -> FrameSummary {
	let imageData = try loadRGBA(path)
	let pixels = imageData.pixels
	var nonBlackPixels = 0
	var maxChannelValue = 0

	for pixelOffset in stride(from: 0, to: pixels.count, by: 4) {
		let red = Int(pixels[pixelOffset])
		let green = Int(pixels[pixelOffset + 1])
		let blue = Int(pixels[pixelOffset + 2])
		let channelMax = max(red, max(green, blue))

		if channelMax > maxChannelValue {
			maxChannelValue = channelMax
		}

		if channelMax != 0 {
			nonBlackPixels += 1
		}
	}

	return FrameSummary(
		path: path,
		width: imageData.width,
		height: imageData.height,
		nonBlackPixels: nonBlackPixels,
		maxChannelValue: maxChannelValue
	)
}

func stderrPrint(_ line: String) {
	fputs("\(line)\n", stderr)
}

func envInt(_ name: String, defaultValue: Int) throws -> Int {
	guard let rawValue = ProcessInfo.processInfo.environment[name], !rawValue.isEmpty else {
		return defaultValue
	}

	guard let parsed = Int(rawValue), parsed >= 0 else {
		throw FrameSelectError.invalidEnvironmentValue(name, rawValue)
	}

	return parsed
}

guard CommandLine.arguments.count >= 2 else {
	fputs("Usage: select-first-nonblack-render-frame.swift /path/to/frame1.png [/path/to/frame2.png ...]\n", stderr)
	exit(1)
}

do {
	let minNonBlackPixels = try envInt(
		"RECOIL_RENDER_FRAME_SELECTION_MIN_NONBLACK_PIXELS",
		defaultValue: 1
	)
	let verboseDiagnostics = try envInt(
		"RECOIL_RENDER_FRAME_SELECTION_VERBOSE",
		defaultValue: 0
	) != 0

	for candidatePath in CommandLine.arguments.dropFirst() {
		let frameSummary = try summarizeFrame(candidatePath)
		let isUsable = frameSummary.nonBlackPixels >= minNonBlackPixels

		if verboseDiagnostics {
			stderrPrint(
				"frame-select: path=\(frameSummary.path) " +
				"nonBlackPixels=\(frameSummary.nonBlackPixels)/\(frameSummary.totalPixels) " +
				"maxChannel=\(frameSummary.maxChannelValue) usable=\(isUsable ? "yes" : "no")"
			)
		}

		if isUsable {
			stderrPrint(
				"frame-select: selected \(frameSummary.path) " +
				"nonBlackPixels=\(frameSummary.nonBlackPixels)/\(frameSummary.totalPixels) " +
				"maxChannel=\(frameSummary.maxChannelValue)"
			)
			print(frameSummary.path)
			exit(0)
		}
	}

	stderrPrint(
		"No usable render frame found. " +
		"minNonBlackPixels=\(minNonBlackPixels)"
	)
	exit(1)
} catch FrameSelectError.imageLoadFailed(let path) {
	fputs("Failed to load render frame: \(path)\n", stderr)
	exit(1)
} catch FrameSelectError.contextCreateFailed(let path) {
	fputs("Failed to create RGBA bitmap context for render frame: \(path)\n", stderr)
	exit(1)
} catch FrameSelectError.invalidEnvironmentValue(let name, let rawValue) {
	fputs("Invalid integer environment value for \(name): \(rawValue)\n", stderr)
	exit(1)
} catch {
	fputs("Unexpected render-frame selection failure: \(error)\n", stderr)
	exit(1)
}
