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
    /// 租售比种子（年）。GitHub 表和安装包里的表都没有时使用。
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
    case unitedStates
    case chinaMainland
    case germany
    case japan
    case india
    case unitedKingdom
    case france
    case italy
    case russia
    case canada
    case brazil
    case mexico
    case southKorea
    case spain
    case australia
    case netherlands
    case saudiArabia
    case turkey
    case indonesia
    case switzerland

    var id: String { rawValue }

    /// 用系统地区代码匹配列表中的国家。不在列表里时用美国，界面语言随之变为英语。
    static func matching(regionCode: String?) -> Country {
        switch regionCode?.uppercased() {
        case "US": .unitedStates
        case "CN": .chinaMainland
        case "DE": .germany
        case "JP": .japan
        case "IN": .india
        case "GB", "UK": .unitedKingdom
        case "FR": .france
        case "IT": .italy
        case "RU": .russia
        case "CA": .canada
        case "BR": .brazil
        case "MX": .mexico
        case "KR": .southKorea
        case "ES": .spain
        case "AU": .australia
        case "NL": .netherlands
        case "SA": .saudiArabia
        case "TR": .turkey
        case "ID": .indonesia
        case "CH": .switzerland
        default: .unitedStates
        }
    }

    var displayName: String {
        switch self {
        case .unitedStates: "美国"
        case .chinaMainland: "中国大陆"
        case .germany: "德国"
        case .japan: "日本"
        case .india: "印度"
        case .unitedKingdom: "英国"
        case .france: "法国"
        case .italy: "意大利"
        case .russia: "俄罗斯"
        case .canada: "加拿大"
        case .brazil: "巴西"
        case .mexico: "墨西哥"
        case .southKorea: "韩国"
        case .spain: "西班牙"
        case .australia: "澳大利亚"
        case .netherlands: "荷兰"
        case .saudiArabia: "沙特阿拉伯"
        case .turkey: "土耳其"
        case .indonesia: "印度尼西亚"
        case .switzerland: "瑞士"
        }
    }

    /// 英文国名，用于数据来源和诊断信息。
    var englishName: String {
        switch self {
        case .unitedStates: "United States"
        case .chinaMainland: "China"
        case .germany: "Germany"
        case .japan: "Japan"
        case .india: "India"
        case .unitedKingdom: "United Kingdom"
        case .france: "France"
        case .italy: "Italy"
        case .russia: "Russia"
        case .canada: "Canada"
        case .brazil: "Brazil"
        case .mexico: "Mexico"
        case .southKorea: "South Korea"
        case .spain: "Spain"
        case .australia: "Australia"
        case .netherlands: "Netherlands"
        case .saudiArabia: "Saudi Arabia"
        case .turkey: "Turkey"
        case .indonesia: "Indonesia"
        case .switzerland: "Switzerland"
        }
    }

    var currencyCode: String {
        switch self {
        case .unitedStates: "USD"
        case .chinaMainland: "CNY"
        case .germany, .france, .italy, .spain, .netherlands: "EUR"
        case .japan: "JPY"
        case .india: "INR"
        case .unitedKingdom: "GBP"
        case .russia: "RUB"
        case .canada: "CAD"
        case .brazil: "BRL"
        case .mexico: "MXN"
        case .southKorea: "KRW"
        case .australia: "AUD"
        case .saudiArabia: "SAR"
        case .turkey: "TRY"
        case .indonesia: "IDR"
        case .switzerland: "CHF"
        }
    }

    var currencySymbol: String {
        switch self {
        case .unitedStates: "$"
        case .chinaMainland: "¥"
        case .germany, .france, .italy, .spain, .netherlands: "€"
        case .japan: "¥"
        case .india: "₹"
        case .unitedKingdom: "£"
        case .russia: "₽"
        case .canada: "C$"
        case .brazil: "R$"
        case .mexico: "MX$"
        case .southKorea: "₩"
        case .australia: "A$"
        case .saudiArabia: "SAR "
        case .turkey: "₺"
        case .indonesia: "Rp"
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
        case .unitedStates:
            MarketPreset(loanYears: 30, pmiRate: 0.005,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.005, apartmentHOA: 250,
                         priceToRentYears: 16)
        case .chinaMainland:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 300,
                         priceToRentYears: 38)
        case .germany:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 31)
        case .japan:
            MarketPreset(loanYears: 35, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 15_000,
                         priceToRentYears: 24)
        case .india:
            MarketPreset(loanYears: 20, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 5_000,
                         priceToRentYears: 19)
        case .unitedKingdom:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 15)
        case .france:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 23)
        case .italy:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 15)
        case .russia:
            MarketPreset(loanYears: 20, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 5_000,
                         priceToRentYears: 18)
        case .canada:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 350,
                         priceToRentYears: 18)
        case .brazil:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 800,
                         priceToRentYears: 20)
        case .mexico:
            MarketPreset(loanYears: 20, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 2_000,
                         priceToRentYears: 17)
        case .southKorea:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200_000,
                         priceToRentYears: 67)
        case .spain:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 150,
                         priceToRentYears: 18)
        case .australia:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.004, apartmentHOA: 300,
                         priceToRentYears: 23)
        case .netherlands:
            MarketPreset(loanYears: 30, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 200,
                         priceToRentYears: 15)
        case .saudiArabia:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 800,
                         priceToRentYears: 17)
        case .turkey:
            MarketPreset(loanYears: 15, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 2_000,
                         priceToRentYears: 14)
        case .indonesia:
            MarketPreset(loanYears: 20, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 500_000,
                         priceToRentYears: 12)
        case .switzerland:
            MarketPreset(loanYears: 25, pmiRate: 0,
                         baseMaintenanceRate: 0.010, baseInsuranceRate: 0.003, apartmentHOA: 400,
                         priceToRentYears: 35)
        }
    }
}
