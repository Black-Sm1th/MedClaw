pragma Singleton
import QtQuick 2.15

// 全局浅色/深色主题单例：由 main.cpp 以 qmlRegisterSingletonType 注册为
// `import MedClaw.Theme 1.0` 下的 `Theme`。切换 `Theme.dark` 全局联动。
//
// 浅色值 = 现状硬编码字面量（保证浅色观感 100% 不变）；
// 深色值按 Figma 深色态设计稿（窗口 #14171A、侧栏 #1A1D20、卡片 #242627、
// 选中 #262B30、边框 #33363A、主文字 #FFFFFF、强调色沿用 #006BFF）。
QtObject {
    property bool dark: false

    // ── 背景 ──
    property color windowBg:         dark ? "#14171A" : "#FFFFFF"
    property color sidebarBg:        dark ? "#1A1D20" : "#F7F9FA"
    property color surface:          dark ? "#242627" : "#FFFFFF"
    property color surfaceAlt:       dark ? "#1E1F21" : "#F4F6F9"   // #F4F6F9 / #F0F2F5 / #F2F3F5 / #F3F4F6
    property color surfaceMuted:     dark ? "#1E1F21" : "#F7F8FA"   // #F7F8FA / #F7F9FC / #F5F6F8
    property color surfaceHover:     dark ? "#0AFFFFFF" : "#0A000000"
    property color surfacePressed:   dark ? "#14FFFFFF" : "#14000000"
    property color surfaceSelected:  dark ? "#262B30" : "#E6E7EB"
    property color surfaceSelectedAlt: dark ? "#262B30" : "#EBEDF0"
    property color disabledTrack:    dark ? "#3A434C" : "#D9D9D9"
    property color tooltipBg:        dark ? "#262B30" : "#A6000000"

    // ── 边框 / 分割线 ──
    property color border:           dark ? "#33363A" : "#E6E7EB"
    property color borderLight:      dark ? "#262B30" : "#E1E3E8"   // #E1E3E8 / #E8EBF0 / #E8E9ED / #E5E7EB
    property color borderInput:      dark ? "#33363A" : "#D9DCE1"   // #D9DCE1 / #D7D9DE / #D7DCE3 / #D5D9DF
    property color borderStrong:     dark ? "#3A434C" : "#B8BEC8"   // #B8BEC8
    property color divider:          dark ? "#14FFFFFF" : "#14000000"
    property color dividerTopbar:    dark ? "#1FFFFFFF" : "#1F000000"

    // ── 文本 ──
    property color textPrimary:      dark ? "#FFFFFF" : "#D9000000"
    property color textSecondary:    dark ? "#A6FFFFFF" : "#A6000000"
    property color textTertiary:     dark ? "#73FFFFFF" : "#73000000"
    property color textFaint:        dark ? "#40FFFFFF" : "#40000000"
    property color textDim:          dark ? "#80FFFFFF" : "#80000000"
    property color textTitle:        dark ? "#FFFFFF" : "#1F2329"   // #1F2329 / #323842
    property color textMutedSolid:   dark ? "#8A939C" : "#646A73"   // #646A73 / #4E5662 / #8A9099
    property color textSolid:        dark ? "#FFFFFF" : "#000000"
    property color textInverse:      "#FFFFFF"                       // 蓝底白字，两态都是白

    // ── 强调色（品牌蓝） ──
    property color accent:           dark ? "#006BFF" : "#006BFF"
    property color accentHover:      dark ? "#55A4FF" : "#1677FF"
    property color accentPressed:    dark ? "#4493FF" : "#0058D6"
    property color accentTintBg:     dark ? "#1F006BFF" : "#0F006BFF"
    property color accentTintSoft:   dark ? "#0F006BFF" : "#0A006BFF"
    property color accentSoftBg:     dark ? "#16283D" : "#EAF2FF"   // #EAF2FF / #F0F5FF / #F0F7FF / #EAF4FF

    // ── 状态色 ──
    property color danger:           dark ? "#FF5C5F" : "#FF3D40"
    property color dangerSoft:       dark ? "#FF5C5F" : "#FF4D4F"
    property color dangerSoftBg:     dark ? "#3A1F20" : "#FFF1F1"
    property color dangerTint:       dark ? "#14FF5C5F" : "#0FFF3D40"
    property color warning:          dark ? "#FFA733" : "#FF9800"
    property color warningTint:      dark ? "#14FFA733" : "#0FFF8800"
    property color success:          dark ? "#5BD629" : "#56CA00"
    property color successTint:      dark ? "#145BD629" : "#0F22C55E"

    // ── 遮罩 / 覆盖 ──
    property color scrim:            dark ? "#A6000000" : "#59000000"
    property color scrimSoft:        dark ? "#A6000000" : "#40000000"
    property color scrimMedium:      dark ? "#A6000000" : "#66000000"
    property color scrimHeavy:       "#CC000000"
    property color overlayVeil:      dark ? "#E60B0D0F" : "#E6FFFFFF"

    // ── 图标（黑色线框图标 → 深色下转浅） ──
    property color iconColor:        dark ? "#D7DDE3" : "#000000"

    function toggle() { dark = !dark }
}
