import Foundation
import SwiftUI
import AppKit

// MARK: - AppearanceConfig (全部字段用 @AppStorage 持久化)

final class AppearanceConfig: ObservableObject {
    static let shared = AppearanceConfig()

    // MARK: - 悬浮窗尺寸
    @AppStorage("float.width") var floatWidth: Double = 280
    @AppStorage("float.height") var floatHeight: Double = 72
    @AppStorage("float.fontSize") var floatFontSize: Double = 12
    @AppStorage("float.subFontSize") var floatSubFontSize: Double = 9
    @AppStorage("float.cornerRadius") var floatCornerRadius: Double = 12
    @AppStorage("float.bgOpacity") var floatBgOpacity: Double = 0.85

    // MARK: - 悬浮窗对齐
    @AppStorage("float.alignH") var floatAlignH: String = "center"     // left/center/right
    @AppStorage("float.alignV") var floatAlignV: String = "center"     // top/center/bottom
    @AppStorage("float.alignPaddingH") var floatAlignPaddingH: Double = 0  // 对齐前水平间距 px
    @AppStorage("float.alignPaddingV") var floatAlignPaddingV: Double = 0  // 对齐前垂直间距 px
    @AppStorage("float.pauseOnHover") var floatPauseOnHover: Bool = false   // 悬停暂停轮播

    // MARK: - 悬浮窗行为
    @AppStorage("float.resizable") var floatResizable: Bool = true
    @AppStorage("float.scrollInterval") var floatScrollInterval: Double = 4.0
    @AppStorage("float.scrollMode") var floatScrollMode: String = "page"     // page / continuousScroll
    @AppStorage("float.animMode") var floatAnimMode: String = "fade"
    // 可选: fade, horizontalSlide, verticalSlide, flip, rotate3D
    @AppStorage("float.animDuration") var floatAnimDuration: Double = 0.4
    @AppStorage("float.animSpeed") var floatAnimSpeed: Double = 30           // 连续滚动 px/s
    @AppStorage("float.itemsPerPage") var floatItemsPerPage: Int = 1
    @AppStorage("float.showInput") var floatShowInput: Bool = false
    @AppStorage("float.allowComplete") var floatAllowComplete: Bool = false

    // MARK: - 悬浮窗插件
    @AppStorage("float.widget.enabled") var floatWidgetEnabled: Bool = true
    @AppStorage("float.widget.position") var floatWidgetPosition: String = "topRight"
    @AppStorage("float.widget.content") var floatWidgetContent: String = "remaining"
    @AppStorage("float.widget.fontSize") var floatWidgetFontSize: Double = 9
    @AppStorage("float.widget.colorHex") var floatWidgetColorHex: String = "#FFFFFF"
    @AppStorage("float.widget.opacity") var floatWidgetOpacity: Double = 0.6

    // MARK: - 悬浮窗布局
    @AppStorage("float.layout.titleFields") var floatLayoutTitleFields: String = "flag,title"
    @AppStorage("float.layout.subtitleFields") var floatLayoutSubtitleFields: String = "listName,dueDate,location"
    @AppStorage("float.layout.badgeField") var floatLayoutBadgeField: String = "none"

    // MARK: - 悬浮窗筛选
    @AppStorage("float.filterMode") var floatFilterMode: String = "all"
    @AppStorage("float.filterListsRaw") var floatFilterListsRaw: String = ""

    var floatFilterLists: [String] {
        get { floatFilterListsRaw.isEmpty ? [] : floatFilterListsRaw.components(separatedBy: ",") }
        set { floatFilterListsRaw = newValue.joined(separator: ",") }
    }

    // MARK: - 悬浮窗颜色
    @AppStorage("float.bgColorHex") var floatBgColorHex: String = "#1E1E1E"
    @AppStorage("float.textColorHex") var floatTextColorHex: String = "#FFFFFF"
    @AppStorage("float.accentColorHex") var floatAccentColorHex: String = "#007AFF"
    @AppStorage("float.flagColorHex") var floatFlagColorHex: String = "#FF9500"  // 旗标专用色
    @AppStorage("float.dueDateColorHex") var floatDueDateColorHex: String = "#FF9500"

    // MARK: - 状态栏（仅图标）
    @AppStorage("statusbar.iconName") var statusBarIconName: String = "checklist"

    // MARK: - 通用列表
    @AppStorage("general.listFontSize") var listFontSize: Double = 12
    @AppStorage("general.showNotes") var showNotes: Bool = true
    @AppStorage("general.showLocation") var showLocation: Bool = true
    @AppStorage("general.showDueDate") var showDueDate: Bool = true
    @AppStorage("general.showListName") var showListName: Bool = true

    // MARK: - AI
    @AppStorage("ai.multiMode") var aiMultiMode: Bool = false

    // MARK: - 工作模式
    @AppStorage("work.width") var workWidth: Double = 300
    @AppStorage("work.height") var workHeight: Double = 480
    @AppStorage("work.fontSize") var workFontSize: Double = 13
    @AppStorage("work.subFontSize") var workSubFontSize: Double = 10
    @AppStorage("work.cornerRadius") var workCornerRadius: Double = 14
    @AppStorage("work.bgOpacity") var workBgOpacity: Double = 0.92
    @AppStorage("work.bgColorHex") var workBgColorHex: String = "#1A1A2E"
    @AppStorage("work.textColorHex") var workTextColorHex: String = "#EAEAEA"
    @AppStorage("work.accentColorHex") var workAccentColorHex: String = "#00D2FF"
    @AppStorage("work.currentBgColorHex") var workCurrentBgColorHex: String = "#0F3460"   // 当前任务高亮背景
    @AppStorage("work.currentTextColorHex") var workCurrentTextColorHex: String = "#00D2FF" // 当前任务文字
    @AppStorage("work.doneBgColorHex") var workDoneBgColorHex: String = "#16213E"          // 已完成背景
    @AppStorage("work.doneTextColorHex") var workDoneTextColorHex: String = "#4A4A6A"      // 已完成文字
    @AppStorage("work.pendingBgColorHex") var workPendingBgColorHex: String = "#1A1A2E"    // 待完成背景
    @AppStorage("work.rowHeight") var workRowHeight: Double = 44
    @AppStorage("work.rowSpacing") var workRowSpacing: Double = 4
    @AppStorage("work.showIndex") var workShowIndex: Bool = true       // 显示序号
    @AppStorage("work.showSubtitle") var workShowSubtitle: Bool = true  // 副标题行
    @AppStorage("work.resizable") var workResizable: Bool = true
    @AppStorage("work.headerText") var workHeaderText: String = "🎯 工作模式"  // 顶栏标题
    @AppStorage("work.headerFontSize") var workHeaderFontSize: Double = 14

    // Computed colors for work mode
    var workBgColor: Color { color(from: workBgColorHex) }
    var workTextColor: Color { color(from: workTextColorHex) }
    var workAccentColor: Color { color(from: workAccentColorHex) }
    var workCurrentBgColor: Color { color(from: workCurrentBgColorHex) }
    var workCurrentTextColor: Color { color(from: workCurrentTextColorHex) }
    var workDoneBgColor: Color { color(from: workDoneBgColorHex) }
    var workDoneTextColor: Color { color(from: workDoneTextColorHex) }
    var workPendingBgColor: Color { color(from: workPendingBgColorHex) }

    private init() {}

    // MARK: - Computed Colors

    var floatBgColor: Color { color(from: floatBgColorHex) }
    var floatTextColor: Color { color(from: floatTextColorHex) }
    var floatAccentColor: Color { color(from: floatAccentColorHex) }
    var floatWidgetColor: Color { color(from: floatWidgetColorHex) }
    var floatFlagColor: Color { color(from: floatFlagColorHex) }
    var floatDueDateColor: Color { color(from: floatDueDateColorHex) }

    // MARK: - Alignment

    var contentHAlignment: HorizontalAlignment {
        switch floatAlignH {
        case "left": return .leading
        case "right": return .trailing
        default: return .center
        }
    }

    var contentVAlignment: VerticalAlignment {
        switch floatAlignV {
        case "top": return .top
        case "bottom": return .bottom
        default: return .center
        }
    }

    // MARK: - Color Helpers

    func color(from hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6 else { return .white }
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    func nsColor(from hex: String) -> NSColor {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6 else { return .white }
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        return NSColor(
            red: CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >> 8) & 0xFF) / 255,
            blue: CGFloat(int & 0xFF) / 255,
            alpha: 1.0
        )
    }

    static func hexFromNSColor(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        return String(format: "#%02X%02X%02X",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }
}

// MARK: - Settings Draft (临时配置，保存/应用/取消)

struct SettingsDraft {
    var floatWidth: Double
    var floatHeight: Double
    var floatFontSize: Double
    var floatSubFontSize: Double
    var floatCornerRadius: Double
    var floatBgOpacity: Double
    var floatAlignH: String
    var floatAlignV: String
    var floatAlignPaddingH: Double
    var floatAlignPaddingV: Double
    var floatPauseOnHover: Bool
    var floatResizable: Bool
    var floatScrollInterval: Double
    var floatScrollMode: String
    var floatAnimMode: String
    var floatAnimDuration: Double
    var floatAnimSpeed: Double
    var floatItemsPerPage: Int
    var floatShowInput: Bool
    var floatAllowComplete: Bool
    var floatWidgetEnabled: Bool
    var floatWidgetPosition: String
    var floatWidgetContent: String
    var floatWidgetFontSize: Double
    var floatWidgetColorHex: String
    var floatWidgetOpacity: Double
    var floatLayoutTitleFields: String
    var floatLayoutSubtitleFields: String
    var floatLayoutBadgeField: String
    var floatFilterMode: String
    var floatBgColorHex: String
    var floatTextColorHex: String
    var floatAccentColorHex: String
    var floatFlagColorHex: String
    var floatDueDateColorHex: String
    var statusBarIconName: String
    var listFontSize: Double
    var showNotes: Bool
    var showLocation: Bool
    var showDueDate: Bool
    var showListName: Bool
    var aiMultiMode: Bool

    // Work mode
    var workWidth: Double
    var workHeight: Double
    var workFontSize: Double
    var workSubFontSize: Double
    var workCornerRadius: Double
    var workBgOpacity: Double
    var workBgColorHex: String
    var workTextColorHex: String
    var workAccentColorHex: String
    var workCurrentBgColorHex: String
    var workCurrentTextColorHex: String
    var workDoneBgColorHex: String
    var workDoneTextColorHex: String
    var workPendingBgColorHex: String
    var workRowHeight: Double
    var workRowSpacing: Double
    var workShowIndex: Bool
    var workShowSubtitle: Bool
    var workResizable: Bool
    var workHeaderText: String
    var workHeaderFontSize: Double

    init(from config: AppearanceConfig) {
        floatWidth = config.floatWidth
        floatHeight = config.floatHeight
        floatFontSize = config.floatFontSize
        floatSubFontSize = config.floatSubFontSize
        floatCornerRadius = config.floatCornerRadius
        floatBgOpacity = config.floatBgOpacity
        floatAlignH = config.floatAlignH
        floatAlignV = config.floatAlignV
        floatAlignPaddingH = config.floatAlignPaddingH
        floatAlignPaddingV = config.floatAlignPaddingV
        floatPauseOnHover = config.floatPauseOnHover
        floatResizable = config.floatResizable
        floatScrollInterval = config.floatScrollInterval
        floatScrollMode = config.floatScrollMode
        floatAnimMode = config.floatAnimMode
        floatAnimDuration = config.floatAnimDuration
        floatAnimSpeed = config.floatAnimSpeed
        floatItemsPerPage = config.floatItemsPerPage
        floatShowInput = config.floatShowInput
        floatAllowComplete = config.floatAllowComplete
        floatWidgetEnabled = config.floatWidgetEnabled
        floatWidgetPosition = config.floatWidgetPosition
        floatWidgetContent = config.floatWidgetContent
        floatWidgetFontSize = config.floatWidgetFontSize
        floatWidgetColorHex = config.floatWidgetColorHex
        floatWidgetOpacity = config.floatWidgetOpacity
        floatLayoutTitleFields = config.floatLayoutTitleFields
        floatLayoutSubtitleFields = config.floatLayoutSubtitleFields
        floatLayoutBadgeField = config.floatLayoutBadgeField
        floatFilterMode = config.floatFilterMode
        floatBgColorHex = config.floatBgColorHex
        floatTextColorHex = config.floatTextColorHex
        floatAccentColorHex = config.floatAccentColorHex
        floatFlagColorHex = config.floatFlagColorHex
        floatDueDateColorHex = config.floatDueDateColorHex
        statusBarIconName = config.statusBarIconName
        listFontSize = config.listFontSize
        showNotes = config.showNotes
        showLocation = config.showLocation
        showDueDate = config.showDueDate
        showListName = config.showListName
        aiMultiMode = config.aiMultiMode
        // Work mode
        workWidth = config.workWidth
        workHeight = config.workHeight
        workFontSize = config.workFontSize
        workSubFontSize = config.workSubFontSize
        workCornerRadius = config.workCornerRadius
        workBgOpacity = config.workBgOpacity
        workBgColorHex = config.workBgColorHex
        workTextColorHex = config.workTextColorHex
        workAccentColorHex = config.workAccentColorHex
        workCurrentBgColorHex = config.workCurrentBgColorHex
        workCurrentTextColorHex = config.workCurrentTextColorHex
        workDoneBgColorHex = config.workDoneBgColorHex
        workDoneTextColorHex = config.workDoneTextColorHex
        workPendingBgColorHex = config.workPendingBgColorHex
        workRowHeight = config.workRowHeight
        workRowSpacing = config.workRowSpacing
        workShowIndex = config.workShowIndex
        workShowSubtitle = config.workShowSubtitle
        workResizable = config.workResizable
        workHeaderText = config.workHeaderText
        workHeaderFontSize = config.workHeaderFontSize
    }

    func apply(to config: AppearanceConfig) {
        config.floatWidth = floatWidth
        config.floatHeight = floatHeight
        config.floatFontSize = floatFontSize
        config.floatSubFontSize = floatSubFontSize
        config.floatCornerRadius = floatCornerRadius
        config.floatBgOpacity = floatBgOpacity
        config.floatAlignH = floatAlignH
        config.floatAlignV = floatAlignV
        config.floatAlignPaddingH = floatAlignPaddingH
        config.floatAlignPaddingV = floatAlignPaddingV
        config.floatPauseOnHover = floatPauseOnHover
        config.floatResizable = floatResizable
        config.floatScrollInterval = floatScrollInterval
        config.floatScrollMode = floatScrollMode
        config.floatAnimMode = floatAnimMode
        config.floatAnimDuration = floatAnimDuration
        config.floatAnimSpeed = floatAnimSpeed
        config.floatItemsPerPage = floatItemsPerPage
        config.floatShowInput = floatShowInput
        config.floatAllowComplete = floatAllowComplete
        config.floatWidgetEnabled = floatWidgetEnabled
        config.floatWidgetPosition = floatWidgetPosition
        config.floatWidgetContent = floatWidgetContent
        config.floatWidgetFontSize = floatWidgetFontSize
        config.floatWidgetColorHex = floatWidgetColorHex
        config.floatWidgetOpacity = floatWidgetOpacity
        config.floatLayoutTitleFields = floatLayoutTitleFields
        config.floatLayoutSubtitleFields = floatLayoutSubtitleFields
        config.floatLayoutBadgeField = floatLayoutBadgeField
        config.floatFilterMode = floatFilterMode
        config.floatBgColorHex = floatBgColorHex
        config.floatTextColorHex = floatTextColorHex
        config.floatAccentColorHex = floatAccentColorHex
        config.floatFlagColorHex = floatFlagColorHex
        config.floatDueDateColorHex = floatDueDateColorHex
        config.statusBarIconName = statusBarIconName
        config.listFontSize = listFontSize
        config.showNotes = showNotes
        config.showLocation = showLocation
        config.showDueDate = showDueDate
        config.showListName = showListName
        config.aiMultiMode = aiMultiMode
        // Work mode
        config.workWidth = workWidth
        config.workHeight = workHeight
        config.workFontSize = workFontSize
        config.workSubFontSize = workSubFontSize
        config.workCornerRadius = workCornerRadius
        config.workBgOpacity = workBgOpacity
        config.workBgColorHex = workBgColorHex
        config.workTextColorHex = workTextColorHex
        config.workAccentColorHex = workAccentColorHex
        config.workCurrentBgColorHex = workCurrentBgColorHex
        config.workCurrentTextColorHex = workCurrentTextColorHex
        config.workDoneBgColorHex = workDoneBgColorHex
        config.workDoneTextColorHex = workDoneTextColorHex
        config.workPendingBgColorHex = workPendingBgColorHex
        config.workRowHeight = workRowHeight
        config.workRowSpacing = workRowSpacing
        config.workShowIndex = workShowIndex
        config.workShowSubtitle = workShowSubtitle
        config.workResizable = workResizable
        config.workHeaderText = workHeaderText
        config.workHeaderFontSize = workHeaderFontSize
    }
}
