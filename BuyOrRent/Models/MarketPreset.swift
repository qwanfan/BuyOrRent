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

/// 一个国家的参考参数。贷款年限、贷款保险、维修、房屋保险和物业费是内置预设。
/// 房贷利率、租金升值、房价涨跌、地税和买卖成本在房产成本表里。
struct MarketPreset: Equatable {
    var loanYears: Int
    var pmiRate: Double
    var baseMaintenanceRate: Double
    var baseInsuranceRate: Double
    /// 公寓的典型月物业费（当地货币，不换汇）；联排按四成估算，独栋为 0。
    var apartmentHOA: Double
    /// 租售比种子：Numbeo 市中心与市郊租售比的平均值（年），四舍五入到 0.1 年。直接抓取失败且没有上次结果时使用。
    var priceToRentYears: Double

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

    /// 用系统地区代码匹配列表中的国家。不在列表里时用美国，界面语言随之变为英语。
    static func matching(regionCode: String?) -> Country {
        switch regionCode?.uppercased() {
        case "CN": .chinaMainland
        case "HK": .hongKong
        case "US": .unitedStates
        case "CA": .canada
        case "SG": .singapore
        case "AU": .australia
        case "JP": .japan
        case "GB", "UK": .unitedKingdom
        case "DE": .germany
        case "FR": .france
        case "NL": .netherlands
        case "ES": .spain
        case "IT": .italy
        case "CH": .switzerland
        default: .unitedStates
        }
    }

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
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 300,
                         priceToRentYears: 47.8)
        case .hongKong:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.008, baseInsuranceRate: 0.003, apartmentHOA: 2_500,
                         priceToRentYears: 47.4)
        case .unitedStates:
            MarketPreset(loanYears: 30, pmiRate: 0.005,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.005, apartmentHOA: 250,
                         priceToRentYears: 9.6)
        case .canada:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 350,
                         priceToRentYears: 17.0)
        case .singapore:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.008, baseInsuranceRate: 0.003, apartmentHOA: 300,
                         priceToRentYears: 36.0)
        case .australia:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 300,
                         priceToRentYears: 23.0)
        case .japan:
            MarketPreset(loanYears: 35, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 15_000,
                         priceToRentYears: 39.2)
        case .unitedKingdom:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 19.7)
        case .germany:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 28.1)
        case .france:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 27.0)
        case .netherlands:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 19.2)
        case .spain:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 18.2)
        case .italy:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 19.0)
        case .switzerland:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 400,
                         priceToRentYears: 41.8)
        }
    }
}
