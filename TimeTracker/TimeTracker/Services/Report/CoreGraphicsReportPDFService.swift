import Foundation
import AppKit

final class CoreGraphicsReportPDFService: ReportPDFService {

    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let marginX: CGFloat = 50
    private let marginTop: CGFloat = 50
    private let marginBottom: CGFloat = 50

    func generatePDF(config: ReportPDFConfig) -> Data {
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let contentWidth = pageWidth - 2 * marginX
        var yPosition = pageHeight - marginTop

        context.beginPage(mediaBox: &mediaBox)

        yPosition = drawHeader(context: context, config: config, y: yPosition, contentWidth: contentWidth)
        yPosition -= 20
        yPosition = drawSeparator(context: context, y: yPosition, contentWidth: contentWidth)
        yPosition -= 20
        yPosition = drawTable(context: context, config: config, y: yPosition, contentWidth: contentWidth, mediaBox: &mediaBox)

        context.endPage()
        context.closePDF()

        return pdfData as Data
    }

    // MARK: - Header

    private func drawHeader(context: CGContext, config: ReportPDFConfig, y: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var yPos = y

        if !config.businessName.isEmpty {
            let businessAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
            let businessStr = NSAttributedString(string: config.businessName, attributes: businessAttrs)
            yPos = drawAttributedString(businessStr, context: context, x: marginX, y: yPos, maxWidth: contentWidth)
            yPos -= 16
        }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let titleStr = NSAttributedString(string: "TIME REPORT", attributes: titleAttrs)
        yPos = drawAttributedString(titleStr, context: context, x: marginX, y: yPos, maxWidth: contentWidth)
        yPos -= 12

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let periodAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.darkGray
        ]
        let periodStr = NSAttributedString(
            string: "Period: \(dateFormatter.string(from: config.startDate)) – \(dateFormatter.string(from: config.endDate))",
            attributes: periodAttrs
        )
        yPos = drawAttributedString(periodStr, context: context, x: marginX, y: yPos, maxWidth: contentWidth)
        yPos -= 6

        let generatedStr = NSAttributedString(
            string: "Generated: \(dateFormatter.string(from: config.generatedDate))",
            attributes: periodAttrs
        )
        yPos = drawAttributedString(generatedStr, context: context, x: marginX, y: yPos, maxWidth: contentWidth)

        return yPos
    }

    // MARK: - Separator

    private func drawSeparator(context: CGContext, y: CGFloat, contentWidth: CGFloat) -> CGFloat {
        context.setStrokeColor(NSColor.gray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: marginX, y: y))
        context.addLine(to: CGPoint(x: marginX + contentWidth, y: y))
        context.strokePath()
        return y
    }

    // MARK: - Table

    private func drawTable(context: CGContext, config: ReportPDFConfig, y: CGFloat, contentWidth: CGFloat, mediaBox: inout CGRect) -> CGFloat {
        let showRate = config.showRateColumns
        let columns = buildColumnLayout(contentWidth: contentWidth, showRate: showRate)
        let rowHeight: CGFloat = 28
        let headerHeight: CGFloat = 32

        var yPos = y

        yPos = drawTableHeaderRow(context: context, columns: columns, y: yPos, height: headerHeight, contentWidth: contentWidth, showRate: showRate)

        for task in config.tasks {
            if yPos - rowHeight < marginBottom {
                context.endPage()
                context.beginPage(mediaBox: &mediaBox)
                yPos = pageHeight - marginTop
                yPos = drawTableHeaderRow(context: context, columns: columns, y: yPos, height: headerHeight, contentWidth: contentWidth, showRate: showRate)
            }
            yPos = drawTaskRow(context: context, task: task, columns: columns, y: yPos, height: rowHeight, contentWidth: contentWidth, showRate: showRate, config: config)
        }

        drawTableRowBorder(context: context, y: yPos, contentWidth: contentWidth)

        yPos = drawTotalRow(context: context, config: config, columns: columns, y: yPos, height: rowHeight + 4, contentWidth: contentWidth, showRate: showRate)

        return yPos
    }

    private struct ColumnLayout {
        let taskX: CGFloat
        let taskWidth: CGFloat
        let timeX: CGFloat
        let timeWidth: CGFloat
        let rateX: CGFloat
        let rateWidth: CGFloat
        let amountX: CGFloat
        let amountWidth: CGFloat
    }

    private func buildColumnLayout(contentWidth: CGFloat, showRate: Bool) -> ColumnLayout {
        let startX = marginX
        if showRate {
            let taskWidth = contentWidth * 0.45
            let timeWidth = contentWidth * 0.18
            let rateWidth = contentWidth * 0.17
            let amountWidth = contentWidth * 0.20
            return ColumnLayout(
                taskX: startX, taskWidth: taskWidth,
                timeX: startX + taskWidth, timeWidth: timeWidth,
                rateX: startX + taskWidth + timeWidth, rateWidth: rateWidth,
                amountX: startX + taskWidth + timeWidth + rateWidth, amountWidth: amountWidth
            )
        } else {
            let taskWidth = contentWidth * 0.70
            let timeWidth = contentWidth * 0.30
            return ColumnLayout(
                taskX: startX, taskWidth: taskWidth,
                timeX: startX + taskWidth, timeWidth: timeWidth,
                rateX: 0, rateWidth: 0,
                amountX: 0, amountWidth: 0
            )
        }
    }

    private func drawTableHeaderRow(context: CGContext, columns: ColumnLayout, y: CGFloat, height: CGFloat, contentWidth: CGFloat, showRate: Bool) -> CGFloat {
        let bgRect = CGRect(x: marginX, y: y - height, width: contentWidth, height: height)
        context.setFillColor(NSColor(white: 0.92, alpha: 1.0).cgColor)
        context.fill(bgRect)

        drawTableRowBorder(context: context, y: y, contentWidth: contentWidth)
        drawTableRowBorder(context: context, y: y - height, contentWidth: contentWidth)

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.black
        ]

        let textY = y - height + 9
        drawText("Task", attrs: headerAttrs, context: context, x: columns.taskX + 8, y: textY, maxWidth: columns.taskWidth - 16)
        drawTextRightAligned("Time", attrs: headerAttrs, context: context, x: columns.timeX, y: textY, width: columns.timeWidth - 8)
        if showRate {
            drawTextRightAligned("Rate", attrs: headerAttrs, context: context, x: columns.rateX, y: textY, width: columns.rateWidth - 8)
            drawTextRightAligned("Amount", attrs: headerAttrs, context: context, x: columns.amountX, y: textY, width: columns.amountWidth - 8)
        }

        return y - height
    }

    private func drawTaskRow(context: CGContext, task: ReportPDFTaskRow, columns: ColumnLayout, y: CGFloat, height: CGFloat, contentWidth: CGFloat, showRate: Bool, config: ReportPDFConfig) -> CGFloat {
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.black
        ]
        let dashAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.gray
        ]

        let textY = y - height + 9
        drawText(task.title, attrs: cellAttrs, context: context, x: columns.taskX + 8, y: textY, maxWidth: columns.taskWidth - 16)
        drawTextRightAligned(task.formattedTime, attrs: cellAttrs, context: context, x: columns.timeX, y: textY, width: columns.timeWidth - 8)

        if showRate {
            let rateStr = task.formattedRate ?? "—"
            let rateAttrs = task.formattedRate != nil ? cellAttrs : dashAttrs
            drawTextRightAligned(rateStr, attrs: rateAttrs, context: context, x: columns.rateX, y: textY, width: columns.rateWidth - 8)

            let amountStr = task.formattedAmount ?? "—"
            let amountAttrs = task.formattedAmount != nil ? cellAttrs : dashAttrs
            drawTextRightAligned(amountStr, attrs: amountAttrs, context: context, x: columns.amountX, y: textY, width: columns.amountWidth - 8)
        }

        drawTableRowBorder(context: context, y: y - height, contentWidth: contentWidth)
        return y - height
    }

    private func drawTotalRow(context: CGContext, config: ReportPDFConfig, columns: ColumnLayout, y: CGFloat, height: CGFloat, contentWidth: CGFloat, showRate: Bool) -> CGFloat {
        let bgRect = CGRect(x: marginX, y: y - height, width: contentWidth, height: height)
        context.setFillColor(NSColor(white: 0.95, alpha: 1.0).cgColor)
        context.fill(bgRect)

        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.black
        ]

        let textY = y - height + 10
        drawText("TOTAL", attrs: boldAttrs, context: context, x: columns.taskX + 8, y: textY, maxWidth: columns.taskWidth - 16)
        drawTextRightAligned(config.totalTime, attrs: boldAttrs, context: context, x: columns.timeX, y: textY, width: columns.timeWidth - 8)

        if showRate, let totalAmount = config.totalAmount {
            drawTextRightAligned(totalAmount, attrs: boldAttrs, context: context, x: columns.amountX, y: textY, width: columns.amountWidth - 8)
        }

        drawTableRowBorder(context: context, y: y - height, contentWidth: contentWidth)
        return y - height
    }

    private func drawTableRowBorder(context: CGContext, y: CGFloat, contentWidth: CGFloat) {
        context.setStrokeColor(NSColor(white: 0.78, alpha: 1.0).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: marginX, y: y))
        context.addLine(to: CGPoint(x: marginX + contentWidth, y: y))
        context.strokePath()
    }

    // MARK: - Text Drawing

    private func drawAttributedString(_ attrStr: NSAttributedString, context: CGContext, x: CGFloat, y: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attrStr.length),
            nil,
            CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            nil
        )
        let framePath = CGPath(rect: CGRect(x: x, y: y - suggestedSize.height, width: maxWidth, height: suggestedSize.height), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrStr.length), framePath, nil)
        context.saveGState()
        CTFrameDraw(frame, context)
        context.restoreGState()
        return y - suggestedSize.height
    }

    private func drawText(_ text: String, attrs: [NSAttributedString.Key: Any], context: CGContext, x: CGFloat, y: CGFloat, maxWidth: CGFloat) {
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attrStr.length),
            nil,
            CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            nil
        )
        let framePath = CGPath(rect: CGRect(x: x, y: y, width: maxWidth, height: suggestedSize.height), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrStr.length), framePath, nil)
        CTFrameDraw(frame, context)
    }

    private func drawTextRightAligned(_ text: String, attrs: [NSAttributedString.Key: Any], context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat) {
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attrStr.length),
            nil,
            CGSize(width: width, height: .greatestFiniteMagnitude),
            nil
        )
        let rightX = x + width - suggestedSize.width
        let framePath = CGPath(rect: CGRect(x: rightX, y: y, width: suggestedSize.width, height: suggestedSize.height), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrStr.length), framePath, nil)
        CTFrameDraw(frame, context)
    }
}
