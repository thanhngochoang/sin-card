// Công cụ tách người & xóa nền bằng Vision framework (macOS 14+)
// Cách dùng:  swift xoa-nen.swift <folder-ảnh-gốc> <folder-xuất>
// Ví dụ:     swift xoa-nen.swift assert/goc assert
import Foundation
import Vision
import CoreImage

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Cách dùng: swift xoa-nen.swift <folder-ảnh-gốc> <folder-xuất>")
    exit(1)
}
let inDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let exts = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp"]
let files: [URL]
do {
    files = try FileManager.default
        .contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil)
        .filter { exts.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
} catch {
    print("❌ Không đọc được folder \(inDir.path): \(error.localizedDescription)")
    exit(1)
}

if files.isEmpty {
    print("⚠️  Folder \(inDir.path) chưa có ảnh nào (hỗ trợ: \(exts.joined(separator: ", ")))")
    exit(0)
}

let ciContext = CIContext()
var ok = 0

for file in files {
    guard let ciImage = CIImage(contentsOf: file, options: [.applyOrientationProperty: true]) else {
        print("❌ Không mở được ảnh: \(file.lastPathComponent)")
        continue
    }
    let handler = VNImageRequestHandler(ciImage: ciImage)
    let request = VNGenerateForegroundInstanceMaskRequest()
    do {
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            print("⚠️  Không tìm thấy chủ thể trong: \(file.lastPathComponent)")
            continue
        }
        // Cắt theo khung chủ thể và xóa nền (nền trong suốt)
        let buffer = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )
        let cutout = CIImage(cvPixelBuffer: buffer)
        let dest = outDir.appendingPathComponent(
            file.deletingPathExtension().lastPathComponent + ".png"
        )
        try ciContext.writePNGRepresentation(
            of: cutout, to: dest,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            options: [:]
        )
        print("✅ \(file.lastPathComponent) → \(dest.lastPathComponent)")
        ok += 1
    } catch {
        print("❌ \(file.lastPathComponent): \(error.localizedDescription)")
    }
}
print("Hoàn tất: \(ok)/\(files.count) ảnh đã xóa nền, lưu vào \(outDir.path)")
