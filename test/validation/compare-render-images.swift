/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

import CoreGraphics
import Foundation
import ImageIO

enum RenderCompareError: Error {
	case imageLoadFailed(String)
	case contextCreateFailed(String)
	case sizeMismatch((Int, Int), (Int, Int))
}

struct RenderCompareThresholds {
	let maxDiffPixels: Int?
	let maxChannelDelta: Int?
}

func loadThreshold(_ name: String) -> Int? {
	guard let rawValue = ProcessInfo.processInfo.environment[name], !rawValue.isEmpty else {
		return nil
	}

	return Int(rawValue)
}

func loadRGBA(_ path: String) throws -> (size: (Int, Int), pixels: [UInt8]) {
	let url = URL(fileURLWithPath: path)

	guard
		let source = CGImageSourceCreateWithURL(url as CFURL, nil),
		let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
	else {
		throw RenderCompareError.imageLoadFailed(path)
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
		throw RenderCompareError.contextCreateFailed(path)
	}

	context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
	return ((width, height), pixels)
}

guard CommandLine.arguments.count == 3 else {
	fputs("Usage: compare-render-images.swift /path/to/reference.png /path/to/captured.png\n", stderr)
	exit(1)
}

let referencePath = CommandLine.arguments[1]
let capturedPath = CommandLine.arguments[2]
let thresholds = RenderCompareThresholds(
	maxDiffPixels: loadThreshold("RECOIL_RENDER_COMPARE_MAX_DIFF_PIXELS"),
	maxChannelDelta: loadThreshold("RECOIL_RENDER_COMPARE_MAX_CHANNEL_DELTA")
)

do {
	let reference = try loadRGBA(referencePath)
	let captured = try loadRGBA(capturedPath)

	if reference.size != captured.size {
		throw RenderCompareError.sizeMismatch(reference.size, captured.size)
	}

	if reference.pixels == captured.pixels {
		print("Render images match.")
		exit(0)
	}

	var diffPixels = 0
	var maxChannelDelta = 0

	for pixelOffset in stride(from: 0, to: reference.pixels.count, by: 4) {
		var pixelDiffers = false

		for channelOffset in 0..<4 {
			let lhs = reference.pixels[pixelOffset + channelOffset]
			let rhs = captured.pixels[pixelOffset + channelOffset]
			let channelDelta = Int(abs(Int(lhs) - Int(rhs)))

			if channelDelta != 0 {
				pixelDiffers = true
				if channelDelta > maxChannelDelta {
					maxChannelDelta = channelDelta
				}
			}
		}

		if pixelDiffers {
			diffPixels += 1
		}
	}

	let allowedDiffPixels = thresholds.maxDiffPixels ?? 0
	let allowedChannelDelta = thresholds.maxChannelDelta ?? 0

	if thresholds.maxDiffPixels != nil || thresholds.maxChannelDelta != nil {
		if diffPixels <= allowedDiffPixels && maxChannelDelta <= allowedChannelDelta {
			print("Render images match within tolerance.")
			print("Diff pixels: \(diffPixels)")
			print("Max channel delta: \(maxChannelDelta)")
			exit(0)
		}
	}

	print("Render images differ.")
	print("Reference image: \(referencePath)")
	print("Captured image:  \(capturedPath)")
	print("Diff pixels: \(diffPixels)")
	print("Max channel delta: \(maxChannelDelta)")
	exit(1)
} catch RenderCompareError.imageLoadFailed(let path) {
	fputs("Failed to load image for render comparison: \(path)\n", stderr)
	exit(1)
} catch RenderCompareError.contextCreateFailed(let path) {
	fputs("Failed to create RGBA bitmap context for render comparison: \(path)\n", stderr)
	exit(1)
} catch RenderCompareError.sizeMismatch(let refSize, let capSize) {
	fputs("Render image sizes differ: reference=\(refSize.0)x\(refSize.1) captured=\(capSize.0)x\(capSize.1)\n", stderr)
	exit(1)
} catch {
	fputs("Unexpected render comparison failure: \(error)\n", stderr)
	exit(1)
}
