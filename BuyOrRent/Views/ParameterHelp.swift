import SwiftUI
#if os(iOS)
import UIKit
#endif

enum ParameterHelp {
    static let country = "选择国家后，会按该国自住普通住宅的代表情况更新贷款利率、贷款年限、保险、物业费和房产成本。金额不会按汇率换算，只更换货币符号。联网数据失败时继续使用上次缓存或内置值。"
    static let housingType = "选择房型后，只调整物业费、房屋维修和房屋保险：公寓物业费最高，联排较低，独栋默认没有物业费但维修和保险略高。"
    static let homePrice = "计划购买的房屋总价，是贷款、首付、维修和税费等计算的基准。"
    static let downPayment = "首付占房价的比例。买入时实际付出的现金 = 首付 + 房价 × 买入费率。"
    static let loanYears = "按揭贷款的还款年限，用于计算月供和贷款余额。"
    static let interestRate = "按揭贷款的年利率。月供按名义年利率除以 12 计息。这个利率写在房产成本表里，并随这张表每 30 天从 GitHub 更新。抓取失败时继续用本机已有的表，表里没有可用值时才用出厂种子。手动改过之后，自动更新不会覆盖。"
    static let horizonYears = "比较买房与租房时，假设持有并在第 N 年末卖掉的年限。也会决定结论区和曲线上的选中点。"
    static let investmentReturn = "把首付、买入费用等现金拿去投资时使用的年化回报。默认值是标普 500 指数（SPX）过去 10 年的价格年化回报，不含股息。这个数写在内置数据里，并随房产成本表每 30 天从 GitHub 更新；恢复默认参数时会立即重新获取。手动改过之后，自动更新不会覆盖。"
    static let appreciation = "房价每年的涨跌，可以为负。这个数是最近 10 年名义房价指数的复合年化，写在房产成本表里，并随这张表每 30 天从 GitHub 更新。抓取失败时继续用本机已有的表，表里没有可用值时才用出厂种子。手动改过之后，自动更新不会覆盖。调节它不会改变租金升值。"
    static let rentGrowth = "房租每年上涨的假设。这个数写在房产成本表里，并随这张表每 30 天从 GitHub 更新。抓取失败时继续用本机已有的表，表里没有可用值时才用出厂种子。手动改过之后，自动更新不会覆盖。调节它不会改变房价增值。"
    static let monthlyRent = "当前可比住房的月租金。买房时，相当于每月省下的这笔钱，会按投资回报复利到期末。月租按 Numbeo 市中心和市郊租售比的平均值计算：月租 = 房价 ÷ (租售比 × 12)。App 启动时直接向 Numbeo 抓取这个比值。抓取失败时继续用上次成功的结果，没有时才用出厂种子。未手动修改时会按这个比值重算；手动改过后，自动更新不再覆盖。请按实际租金修改。"
    static let maintenance = "房屋维修保养的年费率，按当月房价计收，并摊入每月持有成本。"
    static let propertyTax = "自住普通住宅年度房产税折算为房屋市值的代表性有效费率，并摊入每月持有成本。各国实际计税基础可能是评估价、年度租值、面积或档位，且地方差异很大。点「恢复默认参数」会和买卖成本一起从数据表重新获取，也可按实际税单修改。"
    static let insurance = "房屋保险的年费率，按当月房价计收，并摊入每月持有成本。"
    static let hoa = "每月固定物业费或 HOA 费用，直接计入持有成本。"
    static let pmi = "贷款保险（如 PMI）的年费率。只在首付低于 20%，且剩余贷款仍高于当时房价 80% 时，按贷款余额收取。"
    static let buyingCost = "买入时一次性交易成本占房价的代表性比例，包括适用的转让税、登记、公证、法律和常见服务费用。默认值按本国居民购买自住普通住宅估算，不包含外国买家、多套房或豪宅附加税；请按实际报价修改。"
    static let sellingCost = "卖出时交易成本占当时房价的代表性比例，例如代理、法律和登记费用。卖出净得 = 期末房价 × (1 − 卖出费率) − 贷款余额。税务和服务费因地区、持有期及交易方式不同，请按实际报价修改。"

    static let advantage = "买房相对租房，在持有期末多出的净财富。正数表示买房更优，负数表示租房更优。等于卖出净得减去买入现金终值和持有成本终值，再加上省下房租的终值。"
    static let saleProceeds = "持有期末卖掉房子、还完贷款后口袋里还剩多少：期末房价 × (1 − 卖出费率) − 当时贷款余额。期末房价由买价按「房产增值」滚到期末。"
    static let initialCashFV = "买房时先掏出去的现金（首付 + 房价 × 买入费率）。这笔钱若不买房、按「投资回报」复利滚到期末会值多少。买房等于放弃了这笔机会，所以是减项。"
    static let holdingCostFV = "持有期间每月实际掏的钱（月供 + 维修 + 地税 + 保险 + 物业费 + 贷款保险）若按「投资回报」复利到期末的合计。维修、地税、保险按当月房价计收。"
    static let savedRentFV = "因为买房不必再交房租。每月省下的房租（并按「租金升值」逐年调整）若按「投资回报」复利到期末的合计。这是买房相对租房多出来的好处，所以是加项。"
}

struct ParameterHelpButton: View {
    let title: String
    let help: String
    @State private var isPresented = false
    #if os(iOS)
    @State private var buttonFrame: CGRect = .zero
    @State private var arrowEdge: Edge = .bottom
    #endif
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        Button {
            #if os(iOS)
            arrowEdge = preferredArrowEdge
            #endif
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        #if os(iOS)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: HelpAnchorFrameKey.self, value: geo.frame(in: .global))
            }
        }
        .onPreferenceChange(HelpAnchorFrameKey.self) { buttonFrame = $0 }
        .popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
            helpPopover
        }
        #else
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            helpPopover
        }
        #endif
        .accessibilityLabel(L10n(language: appLanguage).helpAccessibility(title))
        .accessibilityHint(L10n(language: appLanguage).helpHint)
    }

    private var helpPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(help)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 280, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
    }

    #if os(iOS)
    /// 上方放得下时仍在参数上面；靠近屏幕顶端放不下时，改到参数下面。
    private var preferredArrowEdge: Edge {
        guard buttonFrame != .zero else { return .bottom }
        let needed = estimatedPopoverHeight + 24
        let spaceAbove = buttonFrame.minY - Self.topInset
        guard spaceAbove < needed else { return .bottom }
        let spaceBelow = Self.screenHeight - buttonFrame.maxY
        return spaceBelow >= spaceAbove ? .top : .bottom
    }

    private var estimatedPopoverHeight: CGFloat {
        let width: CGFloat = 252
        let titleHeight = Self.textHeight(title, font: .preferredFont(forTextStyle: .headline), width: width)
        let bodyHeight = Self.textHeight(help, font: .preferredFont(forTextStyle: .callout), width: width)
        return titleHeight + bodyHeight + 36
    }

    private static func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }

    private static var screenHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .map(\.screen.bounds.height)
            .max() ?? 0
    }

    private static var topInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }
    #endif
}

#if os(iOS)
private struct HelpAnchorFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
#endif

struct ParameterLabel: View {
    let title: String
    let help: String

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(title)
            ParameterHelpButton(title: title, help: help)
        }
    }
}
