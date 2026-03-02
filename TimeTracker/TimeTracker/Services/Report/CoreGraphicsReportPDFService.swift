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
        let showAmount = config.showAmountColumn
        let columns = buildColumnLayout(contentWidth: contentWidth, showAmount: showAmount)
        let headerHeight: CGFloat = 32
        let summaryRowHeight: CGFloat = 32

        var yPos = y

        yPos = drawTableHeaderRow(context: context, columns: columns, y: yPos, height: headerHeight, contentWidth: contentWidth, showAmount: showAmount)

        for task in config.tasks {
            let rowHeight = rowHeight(for: task, columns: columns)
            if yPos - rowHeight < marginBottom {
                context.endPage()
                context.beginPage(mediaBox: &mediaBox)
                yPos = pageHeight - marginTop
                yPos = drawTableHeaderRow(context: context, columns: columns, y: yPos, height: headerHeight, contentWidth: contentWidth, showAmount: showAmount)
            }
            yPos = drawTaskRow(context: context, task: task, columns: columns, y: yPos, height: rowHeight, contentWidth: contentWidth, showAmount: showAmount)
        }

        drawTableRowBorder(context: context, y: yPos, contentWidth: contentWidth)

        if let totalRate = config.totalRate {
            yPos = drawRateRow(context: context, totalRate: totalRate, columns: columns, y: yPos, height: summaryRowHeight, contentWidth: contentWidth, showAmount: showAmount)
        }

        yPos = drawTotalRow(context: context, config: config, columns: columns, y: yPos, height: summaryRowHeight, contentWidth: contentWidth, showAmount: showAmount)

        return yPos
    }

    private struct ColumnLayout {
        let dateX: CGFloat
        let dateWidth: CGFloat
        let taskX: CGFloat
        let taskWidth: CGFloat
        let timeX: CGFloat
        let timeWidth: CGFloat
        let amountX: CGFloat
        let amountWidth: CGFloat
    }

    private func buildColumnLayout(contentWidth: CGFloat, showAmount: Bool) -> ColumnLayout {
        let startX = marginX
        if showAmount {
            let dateWidth = contentWidth * 0.17
            let taskWidth = contentWidth * 0.48
            let timeWidth = contentWidth * 0.10
            let amountWidth = contentWidth * 0.25
            return ColumnLayout(
                dateX: startX, dateWidth: dateWidth,
                taskX: startX + dateWidth, taskWidth: taskWidth,
                timeX: startX + dateWidth + taskWidth, timeWidth: timeWidth,
                amountX: startX + dateWidth + taskWidth + timeWidth, amountWidth: amountWidth
            )
        } else {
            let dateWidth = contentWidth * 0.17
            let taskWidth = contentWidth * 0.68
            let timeWidth = contentWidth * 0.15
            return ColumnLayout(
                dateX: startX, dateWidth: dateWidth,
                taskX: startX + dateWidth, taskWidth: taskWidth,
                timeX: startX + dateWidth + taskWidth, timeWidth: timeWidth,
                amountX: 0, amountWidth: 0
            )
        }
    }

    // MARK: - Row height

    private func rowHeight(for task: ReportPDFTaskRow, columns: ColumnLayout) -> CGFloat {
        let cellAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .regular)]
        let titleHeight = measureTextHeight(task.title, attrs: cellAttrs, maxWidth: columns.taskWidth - 16)
        let minHeight: CGFloat = 28
        let padding: CGFloat = 16
        return max(minHeight, titleHeight + padding)
    }

    // MARK: - Header Row

    private func drawTableHeaderRow(context: CGContext, columns: ColumnLayout, y: CGFloat, height: CGFloat, contentWidth: CGFloat, showAmount: Bool) -> CGFloat {
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
        drawText("Date", attrs: headerAttrs, context: context, x: columns.dateX + 8, y: textY, maxWidth: columns.dateWidth - 16)
        drawText("Task", attrs: headerAttrs, context: context, x: columns.taskX + 8, y: textY, maxWidth: columns.taskWidth - 16)
        drawTextRightAligned("Time", attrs: headerAttrs, context: context, x: columns.timeX, y: textY, width: columns.timeWidth - 8)
        if showAmount {
            drawTextRightAligned("Amount", attrs: headerAttrs, context: context, x: columns.amountX, y: textY, width: columns.amountWidth - 8)
        }

        return y - height
    }

    // MARK: - Task Row

    private func drawTaskRow(context: CGContext, task: ReportPDFTaskRow, columns: ColumnLayout, y: CGFloat, height: CGFloat, contentWidth: CGFloat, showAmount: Bool) -> CGFloat {
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.black
        ]
        let dashAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.gray
        ]

        let rowBottom = y - height

        if let date = task.formattedDate {
            let h = measureTextHeight(date, attrs: cellAttrs, maxWidth: columns.dateWidth - 16)
            let textY = rowBottom + (height - h) / 2
            drawText(date, attrs: cellAttrs, context: context, x: columns.dateX + 8, y: textY, maxWidth: columns.dateWidth - 16)
        }

        let titleH = measureTextHeight(task.title, attrs: cellAttrs, maxWidth: columns.taskWidth - 16)
        let titleY = rowBottom + (height - titleH) / 2
        drawText(task.title, attrs: cellAttrs, context: context, x: columns.taskX + 8, y: titleY, maxWidth: columns.taskWidth - 16)

        let timeH = measureTextHeight(task.formattedTime, attrs: cellAttrs, maxWidth: columns.timeWidth - 8)
        let timeY = rowBottom + (height - timeH) / 2
        drawTextRightAligned(task.formattedTime, attrs: cellAttrs, context: context, x: columns.timeX, y: timeY, width: columns.timeWidth - 8)

        if showAmount {
            let amountStr = task.formattedAmount ?? "—"
            let amountAttrs = task.formattedAmount != nil ? cellAttrs : dashAttrs
            let amountH = measureTextHeight(amountStr, attrs: amountAttrs, maxWidth: columns.amountWidth - 8)
            let amountY = rowBottom + (height - amountH) / 2
            drawTextRightAligned(amountStr, attrs: amountAttrs, context: context, x: columns.amountX, y: amountY, width: columns.amountWidth - 8)
        }

        drawTableRowBorder(context: context, y: rowBottom, contentWidth: contentWidth)
        return rowBottom
    }

    // MARK: - Summary Rows

    private func drawRateRow(context: CGContext, totalRate: String, columns: ColumnLayout, y: CGFloat, height: CGFloat, contentWidth: CGFloat, showAmount: Bool) -> CGFloat {
        let bgRect = CGRect(x: marginX, y: y - height, width: contentWidth, height: height)
        context.setFillColor(NSColor(white: 0.95, alpha: 1.0).cgColor)
        context.fill(bgRect)

        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.black
        ]

        let textY = y - height + 10
        drawText("RATE", attrs: boldAttrs, context: context, x: columns.taskX + 8, y: textY, maxWidth: columns.taskWidth - 16)
        let rateTargetX = showAmount ? columns.amountX : columns.timeX
        let rateTargetWidth = showAmount ? columns.amountWidth - 8 : columns.timeWidth - 8
        drawTextRightAligned(totalRate, attrs: boldAttrs, context: context, x: rateTargetX, y: textY, width: rateTargetWidth)

        drawTableRowBorder(context: context, y: y - height, contentWidth: contentWidth)
        return y - height
    }

    private func drawTotalRow(context: CGContext, config: ReportPDFConfig, columns: ColumnLayout, y: CGFloat, height: CGFloat, contentWidth: CGFloat, showAmount: Bool) -> CGFloat {
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

        if showAmount, let totalAmount = config.totalAmount {
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

    private func measureTextHeight(_ text: String, attrs: [NSAttributedString.Key: Any], maxWidth: CGFloat) -> CGFloat {
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attrStr.length),
            nil,
            CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            nil
        )
        return size.height
    }

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
