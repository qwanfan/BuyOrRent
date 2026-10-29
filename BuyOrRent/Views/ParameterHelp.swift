import SwiftUI

enum ParameterHelp {
    static let country = "选择国家后，会按该国自住普通住宅的代表情况更新贷款利率、贷款年限、保险、物业费和房产成本。金额不会按汇率换算，只更换货币符号。联网数据失败时继续使用上次缓存或内置值。"
    static let housingType = "选择房型后，只调整物业费、房屋维修和房屋保险：公寓物业费最高，联排较低，独栋默认没有物业费但维修和保险略高。"
    static let updateRate = "联网向官方数据源获取该国最新房贷利率并填入。中国大陆直接采用 5 年期以上 LPR，不再加减利差。香港和新加坡取定价基准加预设利差。获取结果只作参考，不是银行报价，仍可手动修改。"
    static let updatePropertyCosts = "从项目的 GitHub Pages 数据表检查地税、买入和卖出成本。数据表每季度依据政府及公共机构来源校验；App 在本地缺数据或距上次成功检查满 30 天时自动联网，也可在此强制检查。"
    static let homePrice = "计划购买的房屋总价，是贷款、首付、维修和税费等计算的基准。"
    static let downPayment = "首付占房价的比例。买入时实际付出的现金 = 首付 + 房价 × 买入费率。"
    static let loanYears = "按揭贷款的还款年限，用于计算月供和贷款余额。"
    static let interestRate = "按揭贷款的年利率。月供按名义年利率除以 12 计息。启动时会联网更新当前国家的利率；中国大陆用 5 年期以上 LPR 原值。手动改过之后，自动更新不会覆盖，需点「更新利率」才重新获取。"
    static let horizonYears = "比较买房与租房时，假设持有并在第 N 年末卖掉的年限。也会决定结论区和曲线上的选中点。"
    static let investmentReturn = "把首付、买入费用等现金拿去投资时，预期的税后年化回报。所有现金流都按这个回报复利到期末再比较。"
    static let appreciation = "房价每年上涨的假设比例。用上下箭头调节时，若「租金升值」未被手动改成不同值，会联动成相同数值。"
    static let rentGrowth = "房租每年上涨的假设比例。用上下箭头调节时，若「房产增值」未被手动改成不同值，会联动成相同数值。"
    static let monthlyRent = "当前可比住房的月租金。买房时，相当于每月省下的这笔钱，会按投资回报复利到期末。启动和切换国家时，按内置国家级代表租售比自动计算：月租 = 房价 ÷ (租售比 × 12)。未手动修改时，改房价也会按同一公式重算；手动改过后，改房价不再覆盖，切换国家或恢复默认会重新按种子计算。"
    static let maintenance = "房屋维修保养的年费率，按当月房价计收，并摊入每月持有成本。"
    static let propertyTax = "自住普通住宅年度房产税折算为房屋市值的代表性有效费率，并摊入每月持有成本。各国实际计税基础可能是评估价、年度租值、面积或档位，且地方差异很大；联网默认值只作起点，可按实际税单修改。"
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

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
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
        }
        .accessibilityLabel("\(title)的说明")
        .accessibilityHint("显示参数含义")
    }
}

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
