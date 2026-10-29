import Foundation

/// 住房类型。只影响持有成本（物业费、维修、保险），不影响房价与租金假设。
enum HousingType: String, CaseIterable, Identifiable, Equatable {
    case apartment
    case townhouse
    case detached

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apartment: "公寓"
        case .townhouse: "联排"
        case .detached: "独栋"
        }
    }
}

/// 某个国家在某种房型下的持有成本参数。
struct HousingPreset: Equatable {
    var monthlyHOA: Double
    var maintenanceRate: Double
    var insuranceRate: Double
}

/// 一个国家的参考参数。贷款年限、缺省利率、保险和物业费仍是内置预设。
/// 地税与买卖费率不在这里，改由 `PropertyCostService` 的出厂种子提供。
struct MarketPreset: Equatable {
    var loanYears: Int
    /// 联网失败时使用的房贷年利率（小数）。
    var defaultMortgageRate: Double
    /// 基准定价国家的利差（小数，可为负）；其他国家为 0。
    var benchmarkSpread: Double
    var pmiRate: Double
    var baseMaintenanceRate: Double
    var baseInsuranceRate: Double
    /// 公寓的典型月物业费（当地货币，不换汇）；联排按四成估算，独栋为 0。
    var apartmentHOA: Double
    /// 租售比种子值：多少年年租金等于房价。是国家级代表性假设，用户可用实际租金覆盖。
    var priceToRentYears: Double
    /// 利率来源名称，用于界面标注。
    var rateSourceName: String

    /// 年租金收益率（年租金 ÷ 房价），与租售比互为倒数。
    var grossRentalYield: Double { 1 / priceToRentYears }

    func housingPreset(for type: HousingType) -> HousingPreset {
        switch type {
        case .apartment:
            HousingPreset(
                monthlyHOA: apartmentHOA,
                maintenanceRate: baseMaintenanceRate,
                insuranceRate: baseInsuranceRate * 0.8
            )
        case .townhouse:
            HousingPreset(
                monthlyHOA: (apartmentHOA * 0.4 / 10).rounded() * 10,
                maintenanceRate: baseMaintenanceRate * 1.1,
                insuranceRate: baseInsuranceRate
            )
        case .detached:
            HousingPreset(
                monthlyHOA: 0,
                maintenanceRate: baseMaintenanceRate * 1.3,
                insuranceRate: baseInsuranceRate * 1.2
            )
        }
    }
}

enum Country: String, CaseIterable, Identifiable, Equatable {
    case chinaMainland
    case hongKong
    case unitedStates
    case canada
    case singapore
    case australia
    case japan
    case unitedKingdom
    case germany
    case france
    case netherlands
    case spain
    case italy
    case switzerland

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinaMainland: "中国大陆"
        case .hongKong: "中国香港"
        case .unitedStates: "美国"
        case .canada: "加拿大"
        case .singapore: "新加坡"
        case .australia: "澳大利亚"
        case .japan: "日本"
        case .unitedKingdom: "英国"
        case .germany: "德国"
        case .france: "法国"
        case .netherlands: "荷兰"
        case .spain: "西班牙"
        case .italy: "意大利"
        case .switzerland: "瑞士"
        }
    }

    /// 英文国名，用于数据来源和诊断信息。
    var englishName: String {
        switch self {
        case .chinaMainland: "China"
        case .hongKong: "Hong Kong"
        case .unitedStates: "United States"
        case .canada: "Canada"
        case .singapore: "Singapore"
        case .australia: "Australia"
        case .japan: "Japan"
        case .unitedKingdom: "United Kingdom"
        case .germany: "Germany"
        case .france: "France"
        case .netherlands: "Netherlands"
        case .spain: "Spain"
        case .italy: "Italy"
        case .switzerland: "Switzerland"
        }
    }

    var currencyCode: String {
        switch self {
        case .chinaMainland: "CNY"
        case .hongKong: "HKD"
        case .unitedStates: "USD"
        case .canada: "CAD"
        case .singapore: "SGD"
        case .australia: "AUD"
        case .japan: "JPY"
        case .unitedKingdom: "GBP"
        case .germany, .france, .netherlands, .spain, .italy: "EUR"
        case .switzerland: "CHF"
        }
    }

    var currencySymbol: String {
        switch self {
        case .chinaMainland: "¥"
        case .hongKong: "HK$"
        case .unitedStates: "$"
        case .canada: "C$"
        case .singapore: "S$"
        case .australia: "A$"
        case .japan: "¥"
        case .unitedKingdom: "£"
        case .germany, .france, .netherlands, .spain, .italy: "€"
        case .switzerland: "CHF "
        }
    }

    /// ECB MIR 系列使用的国家代码；非欧元区统计国家返回 nil。
    var ecbCountryCode: String? {
        switch self {
        case .germany: "DE"
        case .france: "FR"
        case .netherlands: "NL"
        case .spain: "ES"
        case .italy: "IT"
        default: nil
        }
    }

    var preset: MarketPreset {
        switch self {
        case .chinaMainland:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.035, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 300,
                         priceToRentYears: 38,
                         rateSourceName: "5 年期以上 LPR")
        case .hongKong:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.035, benchmarkSpread: 0.013,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.008, baseInsuranceRate: 0.003, apartmentHOA: 2_500,
                         priceToRentYears: 28,
                         rateSourceName: "1 个月 HIBOR + 预设利差估算")
        case .unitedStates:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.065, benchmarkSpread: 0,
                         pmiRate: 0.005,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.005, apartmentHOA: 250,
                         priceToRentYears: 16,
                         rateSourceName: "Freddie Mac 30 年固定房贷利率")
        case .canada:
            MarketPreset(loanYears: 25, defaultMortgageRate: 0.050, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 350,
                         priceToRentYears: 18,
                         rateSourceName: "加拿大央行 5 年期按揭挂牌利率")
        case .singapore:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.025, benchmarkSpread: 0.010,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.008, baseInsuranceRate: 0.003, apartmentHOA: 300,
                         priceToRentYears: 31,
                         rateSourceName: "3 个月 SORA + 预设利差估算")
        case .australia:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.060, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 300,
                         priceToRentYears: 23,
                         rateSourceName: "澳洲央行新发放自住房贷利率")
        case .japan:
            MarketPreset(loanYears: 35, defaultMortgageRate: 0.035, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 15_000,
                         priceToRentYears: 24,
                         rateSourceName: "Flat 35 当月利率")
        case .unitedKingdom:
            MarketPreset(loanYears: 25, defaultMortgageRate: 0.045, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 15,
                         rateSourceName: "英格兰银行房贷报价利率")
        case .germany:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.038, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 31,
                         rateSourceName: "ECB 新发放住房贷款利率")
        case .france:
            MarketPreset(loanYears: 25, defaultMortgageRate: 0.034, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 23,
                         rateSourceName: "ECB 新发放住房贷款利率")
        case .netherlands:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.038, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 15,
                         rateSourceName: "ECB 新发放住房贷款利率")
        case .spain:
            MarketPreset(loanYears: 30, defaultMortgageRate: 0.035, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 18,
                         rateSourceName: "ECB 新发放住房贷款利率")
        case .italy:
            MarketPreset(loanYears: 25, defaultMortgageRate: 0.036, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 15,
                         rateSourceName: "ECB 新发放住房贷款利率")
        case .switzerland:
            MarketPreset(loanYears: 25, defaultMortgageRate: 0.018, benchmarkSpread: 0,
                         pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 400,
                         priceToRentYears: 35,
                         rateSourceName: "瑞士央行公布的新业务房贷利率")
        }
    }
}
