import Foundation
import SwiftUI

/// 界面语言跟着所选国家走，不跟系统语言走。
enum AppLanguage: Equatable {
    case zhHans
    case zhHant
    case en
    case ja
    case de
    case fr
    case nl
    case es
    case it
}

extension Country {
    /// 该国用来显示界面的语言。多官方语言的国家用使用人口最多的一种。
    var appLanguage: AppLanguage {
        switch self {
        case .chinaMainland: .zhHans
        case .hongKong: .zhHant
        case .japan: .ja
        case .germany, .switzerland: .de
        case .france: .fr
        case .netherlands: .nl
        case .spain: .es
        case .italy: .it
        case .unitedStates, .canada, .singapore, .australia, .unitedKingdom: .en
        }
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.zhHans
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

struct L10n {
    let language: AppLanguage

    init(_ country: Country) {
        language = country.appLanguage
    }

    init(language: AppLanguage) {
        self.language = language
    }

    var locale: Locale {
        switch language {
        case .zhHans: Locale(identifier: "zh_CN")
        case .zhHant: Locale(identifier: "zh_HK")
        case .en: Locale(identifier: "en_US")
        case .ja: Locale(identifier: "ja_JP")
        case .de: Locale(identifier: "de_DE")
        case .fr: Locale(identifier: "fr_FR")
        case .nl: Locale(identifier: "nl_NL")
        case .es: Locale(identifier: "es_ES")
        case .it: Locale(identifier: "it_IT")
        }
    }

    func countryName(_ country: Country) -> String {
        switch country {
        case .chinaMainland: t("中国大陆", "中國大陸", "Mainland China", "中国大陸", "Festlandchina", "Chine continentale", "Vasteland China", "China continental", "Cina continentale")
        case .hongKong: t("中国香港", "中國香港", "Hong Kong", "香港", "Hongkong", "Hong Kong", "Hongkong", "Hong Kong", "Hong Kong")
        case .unitedStates: t("美国", "美國", "United States", "アメリカ", "Vereinigte Staaten", "États-Unis", "Verenigde Staten", "Estados Unidos", "Stati Uniti")
        case .canada: t("加拿大", "加拿大", "Canada", "カナダ", "Kanada", "Canada", "Canada", "Canadá", "Canada")
        case .singapore: t("新加坡", "新加坡", "Singapore", "シンガポール", "Singapur", "Singapour", "Singapore", "Singapur", "Singapore")
        case .australia: t("澳大利亚", "澳洲", "Australia", "オーストラリア", "Australien", "Australie", "Australië", "Australia", "Australia")
        case .japan: t("日本", "日本", "Japan", "日本", "Japan", "Japon", "Japan", "Japón", "Giappone")
        case .unitedKingdom: t("英国", "英國", "United Kingdom", "イギリス", "Vereinigtes Königreich", "Royaume-Uni", "Verenigd Koninkrijk", "Reino Unido", "Regno Unito")
        case .germany: t("德国", "德國", "Germany", "ドイツ", "Deutschland", "Allemagne", "Duitsland", "Alemania", "Germania")
        case .france: t("法国", "法國", "France", "フランス", "Frankreich", "France", "Frankrijk", "Francia", "Francia")
        case .netherlands: t("荷兰", "荷蘭", "Netherlands", "オランダ", "Niederlande", "Pays-Bas", "Nederland", "Países Bajos", "Paesi Bassi")
        case .spain: t("西班牙", "西班牙", "Spain", "スペイン", "Spanien", "Espagne", "Spanje", "España", "Spagna")
        case .italy: t("意大利", "意大利", "Italy", "イタリア", "Italien", "Italie", "Italië", "Italia", "Italia")
        case .switzerland: t("瑞士", "瑞士", "Switzerland", "スイス", "Schweiz", "Suisse", "Zwitserland", "Suiza", "Svizzera")
        }
    }

    func housingName(_ type: HousingType) -> String {
        switch type {
        case .apartment: t("公寓", "公寓", "Apartment", "マンション", "Wohnung", "Appartement", "Appartement", "Piso", "Appartamento")
        case .townhouse: t("联排", "排屋", "Townhouse", "テラスハウス", "Reihenhaus", "Maison mitoyenne", "Tussenwoning", "Adosado", "Villetta a schiera")
        case .detached: t("独栋", "獨立屋", "Detached house", "一戸建て", "Einfamilienhaus", "Maison individuelle", "Vrijstaand huis", "Chalet", "Casa indipendente")
        }
    }

    var sectionCountry: String { t("国别和房型", "國家和房型", "Country and home type", "国と住宅タイプ", "Land und Wohnform", "Pays et type de logement", "Land en woningtype", "País y tipo de vivienda", "Paese e tipo di abitazione") }
    var sectionPrice: String { t("房价与贷款", "樓價與貸款", "Price and loan", "価格とローン", "Preis und Darlehen", "Prix et prêt", "Prijs en lening", "Precio e hipoteca", "Prezzo e mutuo") }
    var sectionMarket: String { t("市场假设", "市場假設", "Market assumptions", "市場の前提", "Marktannahmen", "Hypothèses de marché", "Marktaannames", "Supuestos de mercado", "Ipotesi di mercato") }
    var sectionHolding: String { t("持有成本", "持有成本", "Ownership costs", "保有コスト", "Haltekosten", "Coûts de détention", "Bezitkosten", "Costes de tenencia", "Costi di possesso") }
    var sectionTransaction: String { t("交易成本", "交易成本", "Transaction costs", "取引コスト", "Transaktionskosten", "Frais de transaction", "Transactiekosten", "Costes de transacción", "Costi di transazione") }

    var country: String { t("国家", "國家", "Country", "国", "Land", "Pays", "Land", "País", "Paese") }
    var homeType: String { t("房型", "房型", "Home type", "住宅タイプ", "Wohnform", "Type de logement", "Woningtype", "Tipo de vivienda", "Tipo di abitazione") }
    var purchasePrice: String { t("买房款", "樓價", "Purchase price", "購入価格", "Kaufpreis", "Prix d'achat", "Koopprijs", "Precio de compra", "Prezzo di acquisto") }
    var downPayment: String { t("首付比例", "首期比例", "Down payment", "頭金比率", "Eigenkapitalanteil", "Apport", "Eigen inleg", "Entrada", "Anticipo") }
    var loanTerm: String { t("贷款年限", "貸款年期", "Loan term", "返済年数", "Darlehenslaufzeit", "Durée du prêt", "Looptijd", "Plazo del préstamo", "Durata del mutuo") }
    var mortgageRate: String { t("贷款利率（年）", "貸款利率（年）", "Mortgage rate (annual)", "ローン金利（年）", "Darlehenszins (jährlich)", "Taux du prêt (annuel)", "Hypotheekrente (per jaar)", "Tipo de interés (anual)", "Tasso del mutuo (annuo)") }
    var holdingPeriod: String { t("持有年限", "持有年期", "Holding period", "保有年数", "Haltungsdauer", "Durée de détention", "Bezitstermijn", "Años de tenencia", "Anni di possesso") }
    var investmentReturn: String { t("投资回报（年）", "投資回報（年）", "Investment return (annual)", "投資利回り（年）", "Anlagerendite (jährlich)", "Rendement des placements (annuel)", "Beleggingsrendement (per jaar)", "Rentabilidad de la inversión (anual)", "Rendimento degli investimenti (annuo)") }
    var appreciation: String { t("房产增值（年）", "樓價升值（年）", "Home appreciation (annual)", "住宅価格上昇（年）", "Wertsteigerung (jährlich)", "Plus-value du bien (annuelle)", "Waardestijging (per jaar)", "Revalorización (anual)", "Rivalutazione (annua)") }
    var rentGrowth: String { t("租金升值（年）", "租金升值（年）", "Rent growth (annual)", "家賃上昇（年）", "Mietsteigerung (jährlich)", "Hausse du loyer (annuelle)", "Huurstijging (per jaar)", "Subida del alquiler (anual)", "Aumento dell'affitto (annuo)") }
    var monthlyRent: String { t("月房租", "月租", "Monthly rent", "月額家賃", "Monatsmiete", "Loyer mensuel", "Maandhuur", "Alquiler mensual", "Affitto mensile") }
    var maintenance: String { t("房屋维修（年）", "維修（年）", "Maintenance (annual)", "修繕費（年）", "Instandhaltung (jährlich)", "Entretien (annuel)", "Onderhoud (per jaar)", "Mantenimiento (anual)", "Manutenzione (annua)") }
    var propertyTax: String { t("房产税（年）", "物業稅（年）", "Property tax (annual)", "固定資産税（年）", "Grundsteuer (jährlich)", "Taxe foncière (annuelle)", "Onroerendezaakbelasting (per jaar)", "Impuesto sobre la vivienda (anual)", "Imposta sulla casa (annua)") }
    var insurance: String { t("房屋保险（年）", "房屋保險（年）", "Home insurance (annual)", "住宅保険（年）", "Gebäudeversicherung (jährlich)", "Assurance habitation (annuelle)", "Opstalverzekering (per jaar)", "Seguro del hogar (anual)", "Assicurazione casa (annua)") }
    var hoa: String { t("物业费（月）", "管理費（月）", "Service charge (monthly)", "管理費（月）", "Hausgeld (monatlich)", "Charges (mensuelles)", "Servicekosten (per maand)", "Comunidad (mensual)", "Spese condominiali (mensili)") }
    var mortgageInsurance: String { t("贷款保险（年）", "按揭保險（年）", "Mortgage insurance (annual)", "ローン保証料（年）", "Darlehensversicherung (jährlich)", "Assurance emprunteur (annuelle)", "Hypotheekverzekering (per jaar)", "Seguro del préstamo (anual)", "Assicurazione sul mutuo (annua)") }
    var buyingCost: String { t("买入费率", "買入成本", "Buying costs", "購入時費用", "Kaufnebenkosten", "Frais d'achat", "Aankoopkosten", "Costes de compra", "Costi di acquisto") }
    var sellingCost: String { t("卖出费率", "賣出成本", "Selling costs", "売却時費用", "Verkaufskosten", "Frais de vente", "Verkoopkosten", "Costes de venta", "Costi di vendita") }
    var resetDefaults: String { t("恢复默认参数", "恢復預設參數", "Reset to defaults", "既定値に戻す", "Standardwerte wiederherstellen", "Rétablir les valeurs par défaut", "Standaardwaarden herstellen", "Restablecer valores predeterminados", "Ripristina i valori predefiniti") }
    var resetFooter: String {
        t(
            "房价、首付和持有年限回到默认值。贷款利率、房产增值、租金升值、投资回报、房产税和买卖成本随房产成本表从 GitHub 刷新。",
            "樓價、首期和持有年期回到預設值。貸款利率、樓價升值、租金升值、投資回報、物業稅和買賣成本隨房產成本表從 GitHub 重新取得。",
            "Price, down payment, and holding period return to their defaults. The mortgage rate, home appreciation, rent growth, investment return, property tax, and buying and selling costs refresh with the property-cost table from GitHub.",
            "価格、頭金、保有年数は既定値に戻ります。ローン金利、住宅価格の上昇、家賃上昇、投資利回り、固定資産税、売買費用は GitHub の不動産コスト表とともに更新します。",
            "Preis, Eigenkapital und Haltungsdauer kehren auf die Vorgaben zurück. Darlehenszins, Wertsteigerung, Mietsteigerung, Anlagerendite, Grundsteuer und Kauf- sowie Verkaufskosten werden mit der Immobilienkostentabelle von GitHub aktualisiert.",
            "Le prix, l'apport et la durée de détention reviennent aux valeurs par défaut. Le taux du prêt, la plus-value, la hausse du loyer, le rendement, la taxe foncière et les frais d'achat et de vente sont actualisés avec le tableau des coûts immobiliers depuis GitHub.",
            "Prijs, eigen inleg en bezitstermijn gaan terug naar de standaard. Hypotheekrente, waardestijging, huurstijging, beleggingsrendement, onroerendezaakbelasting en aan- en verkoopkosten worden met de vastgoedkostentabel van GitHub ververst.",
            "El precio, la entrada y los años de tenencia vuelven a los valores predeterminados. El tipo de interés, la revalorización, la subida del alquiler, la rentabilidad, el impuesto y los costes de compra y venta se actualizan con la tabla de costes de la vivienda desde GitHub.",
            "Prezzo, anticipo e anni di possesso tornano ai valori predefiniti. Il tasso, la rivalutazione, l'aumento dell'affitto, il rendimento, l'imposta e i costi di acquisto e vendita si aggiornano con la tabella dei costi immobiliari da GitHub."
        )
    }

    var yearUnit: String { t("年", "年", "yr", "年", "Jahre", "ans", "jaar", "años", "anni") }
    func perMonth(_ symbol: String) -> String {
        symbol + t("/月", "/月", "/mo", "/月", "/Monat", "/mois", "/mnd", "/mes", "/mese")
    }

    var resultsTitle: String { t("结论", "結論", "Results", "結果", "Ergebnis", "Résultat", "Resultaat", "Resultado", "Risultato") }
    var parametersTitle: String { t("参数", "參數", "Inputs", "条件", "Eingaben", "Paramètres", "Invoer", "Datos", "Parametri") }
    var cannotCalculate: String { t("无法计算", "無法計算", "Can't calculate", "計算できません", "Berechnung nicht möglich", "Calcul impossible", "Kan niet berekenen", "No se puede calcular", "Impossibile calcolare") }
    var enterPurchasePrice: String { t("请输入大于 0 的买房款。", "請輸入大於 0 的樓價。", "Enter a purchase price greater than 0.", "0 より大きい購入価格を入力してください。", "Geben Sie einen Kaufpreis größer als 0 ein.", "Saisissez un prix d'achat supérieur à 0.", "Voer een koopprijs groter dan 0 in.", "Introduzca un precio de compra mayor que 0.", "Inserisci un prezzo di acquisto maggiore di 0.") }

    var expanded: String { t("已展开", "已展開", "Expanded", "展開", "Ausgeklappt", "Déplié", "Uitgevouwen", "Expandido", "Espanso") }
    var collapsed: String { t("已折叠", "已摺疊", "Collapsed", "折りたたみ", "Eingeklappt", "Replié", "Ingevouwen", "Contraído", "Compresso") }
    var helpHint: String { t("显示参数含义", "顯示參數含義", "Shows what this input means", "入力の意味を表示", "Zeigt die Bedeutung der Eingabe", "Affiche la signification", "Toont wat deze invoer betekent", "Muestra qué significa este dato", "Mostra il significato") }

    func helpAccessibility(_ title: String) -> String {
        switch language {
        case .zhHans: "\(title)的说明"
        case .zhHant: "\(title)的說明"
        case .en: "Help for \(title)"
        case .ja: "\(title)の説明"
        case .de: "Erklärung zu \(title)"
        case .fr: "Aide : \(title)"
        case .nl: "Uitleg bij \(title)"
        case .es: "Ayuda de \(title)"
        case .it: "Spiegazione di \(title)"
        }
    }

    func verdictWord(_ verdict: Verdict) -> String {
        switch verdict {
        case .buy: t("买房", "買樓", "Buy", "購入", "Kauf", "Achat", "Kopen", "Comprar", "Acquisto")
        case .rent: t("租房", "租樓", "Rent", "賃貸", "Miete", "Location", "Huren", "Alquilar", "Affitto")
        case .tie: t("持平", "持平", "Tie", "同等", "Gleich", "Égalité", "Gelijk", "Empate", "Pari")
        }
    }

    func verdictDetail(_ verdict: Verdict) -> String {
        switch verdict {
        case .buy, .rent: t("更划算", "更划算", "better deal", "が有利", "günstiger", "plus avantageux", "voordeliger", "conviene más", "conviene di più")
        case .tie: t("大致相当", "大致相當", "roughly even", "ほぼ同額", "ungefähr gleich", "à peu près", "ongeveer gelijk", "casi empate", "quasi pari")
        }
    }

    var endingGap: String { t("期末净财富差额", "期末淨財富差額", "Ending net-worth gap", "期末の純資産差", "Vermögensunterschied am Ende", "Écart de patrimoine en fin de période", "Vermogensverschil aan het einde", "Diferencia de patrimonio al final", "Differenza di patrimonio finale") }
    var endingGapCaption: String { t("买房相对租房，在持有期末多出的净财富。正数表示买房更优，负数表示租房更优", "買樓相對租樓，在持有期末多出的淨財富。正數表示買樓更優，負數表示租樓更優", "The extra net worth of buying versus renting at the end of the holding period. A positive number means buying is ahead, and a negative number means renting is ahead.", "保有期末に、購入が賃貸より多い純資産。正なら購入が有利、負なら賃貸が有利。", "Das zusätzliche Vermögen von Kaufen gegenüber Mieten am Ende der Haltungsdauer. Positiv liegt Kaufen vorn, negativ Mieten.", "Le patrimoine en plus de l'achat par rapport à la location à la fin de la détention. Positif, l'achat est devant ; négatif, la location est devant.", "Het extra vermogen van kopen tegenover huren aan het einde van de bezitstermijn. Positief ligt kopen voor, negatief huren.", "El patrimonio de más de comprar frente a alquilar al final de la tenencia. Positivo significa que comprar va por delante; negativo, que alquilar va por delante.", "Il patrimonio in più dell'acquisto rispetto all'affitto alla fine del possesso. Positivo: comprare è avanti; negativo: l'affitto è avanti.") }
    var monthlyPayment: String { t("月供", "月供", "Monthly payment", "毎月の返済", "Monatsrate", "Mensualité", "Maandlast", "Cuota mensual", "Rata mensile") }
    var endingHomeValue: String { t("期末房价", "期末樓價", "Ending home value", "期末の住宅価格", "Immobilienwert am Ende", "Valeur finale du bien", "Woningwaarde aan het einde", "Valor final de la vivienda", "Valore finale dell'abitazione") }
    var loanBalance: String { t("贷款余额", "貸款餘額", "Loan balance", "ローン残高", "Restschuld", "Capital restant dû", "Restschuld", "Saldo del préstamo", "Debito residuo") }

    var chartTitle: String { t("期末净财富优势", "期末淨財富優勢", "Ending net-worth advantage", "期末の純資産優位", "Vermögensvorsprung am Ende", "Avantage patrimonial en fin de période", "Vermogensvoordeel aan het einde", "Ventaja patrimonial al final", "Vantaggio patrimoniale finale") }
    var chartCaption: String {
        t(
            "纵轴是买房相对租房的期末财富差额。高于 0 表示买房更优。可按住曲线上的圆点左右拖动（每年一步），或调节下面四项。",
            "縱軸是買樓相對租樓的期末財富差額。高於 0 表示買樓更優。可按住曲線上的圓點左右拖動（每年一步），或調節下面四項。",
            "The vertical axis is how much more ending wealth buying has than renting. Above 0 means buying is ahead. Drag the dot on the curve left or right, one year per step, or adjust the four controls below.",
            "縦軸は購入が賃貸より期末に多い純資産です。0 より上なら購入が有利。曲線上の点を左右にドラッグすると 1 年ずつ動きます。下の 4 項目でも調節できます。",
            "Die senkrechte Achse zeigt, wie viel mehr Vermögen Kaufen am Ende gegenüber Mieten hat. Über 0 liegt Kaufen vorn. Ziehen Sie den Punkt auf der Kurve nach links oder rechts, ein Jahr pro Schritt, oder stellen Sie die vier Werte unten ein.",
            "L'axe vertical montre combien de patrimoine l'achat a de plus que la location en fin de période. Au-dessus de 0, l'achat est devant. Faites glisser le point sur la courbe, une année par pas, ou réglez les quatre valeurs ci-dessous.",
            "De verticale as is hoeveel meer vermogen kopen aan het einde heeft dan huren. Boven 0 ligt kopen voor. Sleep de stip op de curve naar links of rechts, één jaar per stap, of stel de vier waarden hieronder bij.",
            "El eje vertical es cuánta más riqueza final tiene comprar que alquilar. Por encima de 0, comprar va por delante. Arrastre el punto de la curva a izquierda o derecha, un año por paso, o ajuste los cuatro valores de abajo.",
            "L'asse verticale è quanta più ricchezza finale ha l'acquisto rispetto all'affitto. Sopra 0, comprare è avanti. Trascina il punto sulla curva a sinistra o a destra, un anno per passo, oppure regola i quattro valori sotto."
        )
    }
    var chartAccessibility: String { t("1 到 30 年的期末净财富优势曲线，可拖动选择持有年限", "1 到 30 年的期末淨財富優勢曲線，可拖動選擇持有年期", "Ending net-worth advantage from year 1 to 30. Drag to choose the holding period.", "1年目から30年目までの期末純資産優位の曲線。ドラッグして保有年数を選べます。", "Vermögensvorsprung von Jahr 1 bis 30. Ziehen, um die Haltungsdauer zu wählen.", "Avantage patrimonial de l'année 1 à 30. Faites glisser pour choisir la durée.", "Vermogensvoordeel van jaar 1 tot 30. Sleep om de bezitstermijn te kiezen.", "Ventaja patrimonial del año 1 al 30. Arrastre para elegir los años de tenencia.", "Vantaggio patrimoniale dall'anno 1 al 30. Trascina per scegliere gli anni di possesso.") }
    var formulaAccessibility: String { t("期末净财富差额公式", "期末淨財富差額公式", "Formula for the ending net-worth gap", "期末の純資産差の式", "Formel für den Vermögensunterschied am Ende", "Formule de l'écart de patrimoine", "Formule voor het vermogensverschil", "Fórmula de la diferencia de patrimonio", "Formula della differenza di patrimonio") }

    func markedYear(_ year: Int) -> String {
        switch language {
        case .zhHans: "第 \(year) 年"
        case .zhHant: "第 \(year) 年"
        case .en: "Year \(year)"
        case .ja: "\(year)年目"
        case .de: "Jahr \(year)"
        case .fr: "An \(year)"
        case .nl: "Jaar \(year)"
        case .es: "Año \(year)"
        case .it: "Anno \(year)"
        }
    }

    func axisYear(_ year: Int) -> String {
        switch language {
        case .zhHans, .zhHant, .ja: "\(year)年"
        case .en: "\(year) yr"
        case .de: "\(year) J."
        case .fr: "\(year) ans"
        case .nl: "\(year) jr"
        case .es, .it: "\(year) a"
        }
    }

    func selectedYear(_ year: Int) -> String {
        switch language {
        case .zhHans, .zhHant: "\(year) 年"
        case .en: "\(year) yr"
        case .ja: "\(year)年"
        case .de: "\(year) J."
        case .fr: "\(year) ans"
        case .nl: "\(year) jr"
        case .es: "\(year) a"
        case .it: "\(year) a"
        }
    }

    func crossover(_ crossover: Crossover) -> String {
        switch (crossover.favorableFromYear, crossover.unfavorableFromYear) {
        case (nil, _):
            return t(
                "在 1–30 年内，买房的期末净财富都没有超过租房。",
                "在 1–30 年內，買樓的期末淨財富都沒有超過租樓。",
                "Over years 1–30, buying never has more ending net worth than renting.",
                "1年目から30年目まで、購入の期末純資産が賃貸を上回ることはありません。",
                "In den Jahren 1–30 hat Kaufen nie ein höheres Endvermögen als Mieten.",
                "De l'année 1 à 30, l'achat n'a jamais plus de patrimoine final que la location.",
                "In de jaren 1–30 heeft kopen nooit meer eindvermogen dan huren.",
                "Entre los años 1 y 30, comprar nunca tiene más patrimonio final que alquilar.",
                "Negli anni da 1 a 30, l'acquisto non ha mai più patrimonio finale dell'affitto."
            )
        case (1, nil):
            return t(
                "从第 1 年起，买房的期末净财富就更高。",
                "從第 1 年起，買樓的期末淨財富就更高。",
                "From year 1, buying has higher ending net worth.",
                "1年目から、購入の期末純資産のほうが高くなります。",
                "Ab Jahr 1 hat Kaufen das höhere Endvermögen.",
                "Dès l'année 1, l'achat a un patrimoine final plus élevé.",
                "Vanaf jaar 1 heeft kopen een hoger eindvermogen.",
                "Desde el año 1, comprar tiene más patrimonio final.",
                "Dall'anno 1, l'acquisto ha un patrimonio finale più alto."
            )
        case (let year?, nil):
            return crossoverFrom(year)
        case (1, let later?):
            return crossoverEarlyThenRent(later)
        case (let year?, let later?):
            return crossoverWindow(year, later)
        }
    }

    var saleProceeds: String { t("卖出净得", "賣出淨得", "Net sale proceeds", "売却手取り", "Nettoverkaufserlös", "Produit net de vente", "Netto-verkoopopbrengst", "Ingreso neto de venta", "Ricavo netto di vendita") }
    var initialCashFV: String { t("买入现金的终值", "買入現金的終值", "Future value of cash paid", "購入時現金の将来価値", "Endwert des eingesetzten Geldes", "Valeur future de l'apport en espèces", "Toekomstige waarde van ingelegd geld", "Valor futuro del dinero pagado", "Valore futuro del denaro versato") }
    var holdingCostFV: String { t("持有成本的终值", "持有成本的終值", "Future value of holding costs", "保有コストの将来価値", "Endwert der Haltekosten", "Valeur future des coûts de détention", "Toekomstige waarde van bezitkosten", "Valor futuro de los costes de tenencia", "Valore futuro dei costi di possesso") }
    var savedRentFV: String { t("省下房租的终值", "省下租金的終值", "Future value of rent saved", "節約した家賃の将来価値", "Endwert der gesparten Miete", "Valeur future du loyer économisé", "Toekomstige waarde van bespaarde huur", "Valor futuro del alquiler ahorrado", "Valore futuro dell'affitto risparmiato") }

    func source(_ name: String) -> String {
        let shown = localizedSourceName(name)
        switch language {
        case .zhHans: return "来源：\(shown)"
        case .zhHant: return "來源：\(shown)"
        case .en: return "Source: \(shown)"
        case .ja: return "出典：\(shown)"
        case .de: return "Quelle: \(shown)"
        case .fr: return "Source : \(shown)"
        case .nl: return "Bron: \(shown)"
        case .es: return "Fuente: \(shown)"
        case .it: return "Fonte: \(shown)"
        }
    }

    func source(_ name: String, period: String) -> String {
        "\(source(name)) · \(period)"
    }

    func source(_ name: String, from start: String, to end: String) -> String {
        let range: String
        switch language {
        case .zhHans, .zhHant: range = "\(start) 至 \(end)"
        case .en: range = "\(start) to \(end)"
        case .ja: range = "\(start)から\(end)"
        case .de: range = "\(start) bis \(end)"
        case .fr: range = "du \(start) au \(end)"
        case .nl: range = "\(start) tot \(end)"
        case .es: range = "\(start) a \(end)"
        case .it: range = "\(start) a \(end)"
        }
        return "\(source(name)) · \(range)"
    }

    func sourceAndOthers(_ name: String) -> String {
        let shown = localizedSourceName(name)
        switch language {
        case .zhHans: return "来源：\(shown) 等"
        case .zhHant: return "來源：\(shown) 等"
        case .en: return "Source: \(shown) et al."
        case .ja: return "出典：\(shown) など"
        case .de: return "Quelle: \(shown) u. a."
        case .fr: return "Source : \(shown) et autres"
        case .nl: return "Bron: \(shown) e.a."
        case .es: return "Fuente: \(shown) y otros"
        case .it: return "Fonte: \(shown) e altri"
        }
    }

    struct CompactScale {
        var divisor: Double
        var suffix: String
    }

    func compactScale(for magnitude: Double) -> CompactScale? {
        switch language {
        case .zhHans:
            if magnitude >= 100_000_000 { return CompactScale(divisor: 100_000_000, suffix: "亿") }
            if magnitude >= 10_000 { return CompactScale(divisor: 10_000, suffix: "万") }
        case .zhHant:
            if magnitude >= 100_000_000 { return CompactScale(divisor: 100_000_000, suffix: "億") }
            if magnitude >= 10_000 { return CompactScale(divisor: 10_000, suffix: "萬") }
        case .ja:
            if magnitude >= 100_000_000 { return CompactScale(divisor: 100_000_000, suffix: "億") }
            if magnitude >= 10_000 { return CompactScale(divisor: 10_000, suffix: "万") }
        case .en:
            if magnitude >= 1_000_000_000 { return CompactScale(divisor: 1_000_000_000, suffix: "B") }
            if magnitude >= 1_000_000 { return CompactScale(divisor: 1_000_000, suffix: "M") }
            if magnitude >= 1_000 { return CompactScale(divisor: 1_000, suffix: "K") }
        case .de:
            if magnitude >= 1_000_000_000 { return CompactScale(divisor: 1_000_000_000, suffix: " Mrd.") }
            if magnitude >= 1_000_000 { return CompactScale(divisor: 1_000_000, suffix: " Mio.") }
            if magnitude >= 1_000 { return CompactScale(divisor: 1_000, suffix: " Tsd.") }
        case .fr:
            if magnitude >= 1_000_000_000 { return CompactScale(divisor: 1_000_000_000, suffix: " Md") }
            if magnitude >= 1_000_000 { return CompactScale(divisor: 1_000_000, suffix: " M") }
            if magnitude >= 1_000 { return CompactScale(divisor: 1_000, suffix: " k") }
        case .nl:
            if magnitude >= 1_000_000_000 { return CompactScale(divisor: 1_000_000_000, suffix: " mld") }
            if magnitude >= 1_000_000 { return CompactScale(divisor: 1_000_000, suffix: " mln") }
            if magnitude >= 1_000 { return CompactScale(divisor: 1_000, suffix: " k") }
        case .es:
            if magnitude >= 1_000_000_000 { return CompactScale(divisor: 1_000_000_000, suffix: " mil M") }
            if magnitude >= 1_000_000 { return CompactScale(divisor: 1_000_000, suffix: " M") }
            if magnitude >= 1_000 { return CompactScale(divisor: 1_000, suffix: " mil") }
        case .it:
            if magnitude >= 1_000_000_000 { return CompactScale(divisor: 1_000_000_000, suffix: " mld") }
            if magnitude >= 1_000_000 { return CompactScale(divisor: 1_000_000, suffix: " mln") }
            if magnitude >= 1_000 { return CompactScale(divisor: 1_000, suffix: " mila") }
        }
        return nil
    }

    private func localizedSourceName(_ raw: String) -> String {
        guard language != .zhHans, let translated = Self.sourceNames[raw] else { return raw }
        return translated[language] ?? raw
    }

    /// 内置利率来源说明。简体中文保持原文，测试和中国界面都对得上。
    private static let sourceNames: [String: [AppLanguage: String]] = [
        "5 年期以上 LPR": [
            .zhHant: "5 年期以上 LPR",
            .en: "LPR for terms over 5 years",
            .ja: "5年超 LPR",
            .de: "LPR über 5 Jahre",
            .fr: "LPR à plus de 5 ans",
            .nl: "LPR langer dan 5 jaar",
            .es: "LPR a más de 5 años",
            .it: "LPR oltre 5 anni"
        ],
        "1 个月 HIBOR": [
            .zhHant: "1 個月 HIBOR",
            .en: "1-month HIBOR",
            .ja: "1か月 HIBOR",
            .de: "1-Monats-HIBOR",
            .fr: "HIBOR 1 mois",
            .nl: "1-maands HIBOR",
            .es: "HIBOR a 1 mes",
            .it: "HIBOR a 1 mese"
        ],
        "1 个月 HIBOR + 预设利差估算": [
            .zhHant: "1 個月 HIBOR + 預設利差估算",
            .en: "1-month HIBOR plus a preset spread",
            .ja: "1か月 HIBOR ＋ 所定の上乗せ",
            .de: "1-Monats-HIBOR plus vorgegebener Aufschlag",
            .fr: "HIBOR 1 mois plus un écart prédéfini",
            .nl: "1-maands HIBOR plus een vaste opslag",
            .es: "HIBOR a 1 mes más un diferencial prefijado",
            .it: "HIBOR a 1 mese più uno spread predefinito"
        ],
        "Freddie Mac 30 年固定房贷利率": [
            .zhHant: "Freddie Mac 30 年固定按揭利率",
            .en: "Freddie Mac 30-year fixed mortgage rate",
            .ja: "Freddie Mac 30年固定住宅ローン金利",
            .de: "Freddie Mac, 30-jährige Festhypothek",
            .fr: "Taux fixe à 30 ans Freddie Mac",
            .nl: "Freddie Mac 30-jarige vaste hypotheekrente",
            .es: "Tipo fijo a 30 años de Freddie Mac",
            .it: "Tasso fisso a 30 anni Freddie Mac"
        ],
        "加拿大央行 5 年期按揭挂牌利率": [
            .zhHant: "加拿大央行 5 年期按揭掛牌利率",
            .en: "Bank of Canada 5-year posted mortgage rate",
            .ja: "カナダ銀行 5年住宅ローン提示金利",
            .de: "Bank of Canada, ausgehängter 5-Jahres-Hypothekenzins",
            .fr: "Taux hypothécaire affiché à 5 ans de la Banque du Canada",
            .nl: "Bank of Canada 5-jarige geposte hypotheekrente",
            .es: "Tipo hipotecario anunciado a 5 años del Banco de Canadá",
            .it: "Tasso ipotecario pubblicato a 5 anni della Banca del Canada"
        ],
        "3 个月 SORA": [
            .zhHant: "3 個月 SORA",
            .en: "3-month SORA",
            .ja: "3か月 SORA",
            .de: "3-Monats-SORA",
            .fr: "SORA 3 mois",
            .nl: "3-maands SORA",
            .es: "SORA a 3 meses",
            .it: "SORA a 3 mesi"
        ],
        "3 个月 SORA + 预设利差估算": [
            .zhHant: "3 個月 SORA + 預設利差估算",
            .en: "3-month SORA plus a preset spread",
            .ja: "3か月 SORA ＋ 所定の上乗せ",
            .de: "3-Monats-SORA plus vorgegebener Aufschlag",
            .fr: "SORA 3 mois plus un écart prédéfini",
            .nl: "3-maands SORA plus een vaste opslag",
            .es: "SORA a 3 meses más un diferencial prefijado",
            .it: "SORA a 3 mesi più uno spread predefinito"
        ],
        "澳洲央行新发放自住房贷利率": [
            .zhHant: "澳洲央行新批出自住按揭利率",
            .en: "RBA rate on new owner-occupier housing loans",
            .ja: "豪州準備銀行の新規持ち家ローン金利",
            .de: "RBA-Zins für neue Selbstnutzer-Wohnungsdarlehen",
            .fr: "Taux RBA des nouveaux prêts au logement occupé par le propriétaire",
            .nl: "RBA-rente op nieuwe hypotheken voor eigen bewoning",
            .es: "Tipo del RBA para nuevos préstamos de vivienda habitual",
            .it: "Tasso RBA sui nuovi mutui per abitazione principale"
        ],
        "Flat 35 当月利率": [
            .zhHant: "Flat 35 當月利率",
            .en: "Flat 35 rate for the month",
            .ja: "フラット35 当月金利",
            .de: "Flat-35-Zins des Monats",
            .fr: "Taux Flat 35 du mois",
            .nl: "Flat 35-rente van de maand",
            .es: "Tipo Flat 35 del mes",
            .it: "Tasso Flat 35 del mese"
        ],
        "英格兰银行房贷报价利率": [
            .zhHant: "英倫銀行按揭報價利率",
            .en: "Bank of England quoted mortgage rate",
            .ja: "イングランド銀行の住宅ローン提示金利",
            .de: "Von der Bank of England veröffentlichter Hypothekenzins",
            .fr: "Taux hypothécaire publié par la Banque d'Angleterre",
            .nl: "Door de Bank of England gepubliceerde hypotheekrente",
            .es: "Tipo hipotecario publicado por el Banco de Inglaterra",
            .it: "Tasso ipotecario pubblicato dalla Banca d'Inghilterra"
        ],
        "ECB 新发放住房贷款利率": [
            .zhHant: "ECB 新批出住房貸款利率",
            .en: "ECB rate on new housing loans",
            .ja: "ECB の新規住宅ローン金利",
            .de: "EZB-Zins für neue Wohnungsdarlehen",
            .fr: "Taux BCE des nouveaux prêts au logement",
            .nl: "ECB-rente op nieuwe woningleningen",
            .es: "Tipo del BCE para nuevos préstamos de vivienda",
            .it: "Tasso BCE sui nuovi mutui per la casa"
        ],
        "瑞士央行公布的新业务房贷利率": [
            .zhHant: "瑞士央行公布的新造按揭利率",
            .en: "SNB rate on new mortgage business",
            .ja: "スイス国立銀行が公表する新規住宅ローン金利",
            .de: "Von der SNB veröffentlichter Zins für neues Hypothekengeschäft",
            .fr: "Taux BNS sur les nouveaux crédits hypothécaires",
            .nl: "Door de SNB gepubliceerde rente op nieuwe hypotheken",
            .es: "Tipo del BNS para nuevas hipotecas",
            .it: "Tasso BNS sui nuovi mutui"
        ],
        "OECD 实际房租": [
            .zhHant: "OECD 實際房租",
            .en: "OECD actual rentals",
            .ja: "OECD の実際家賃",
            .de: "OECD-Ist-Mieten",
            .fr: "Loyers effectifs OCDE",
            .nl: "OESO werkelijke huren",
            .es: "Alquileres efectivos de la OCDE",
            .it: "Affitti effettivi OCSE"
        ],
        "国家统计局租赁房房租": [
            .zhHant: "國家統計局租賃房房租",
            .en: "NBS rent of rental housing",
            .ja: "国家統計局の賃貸住宅家賃",
            .de: "Miete für Mietwohnungen (NBS)",
            .fr: "Loyer des logements locatifs (NBS)",
            .nl: "Huur van huurwoningen (NBS)",
            .es: "Alquiler de vivienda en alquiler (NBS)",
            .it: "Affitto delle abitazioni in locazione (NBS)"
        ],
        "统计处私人住宅租金": [
            .zhHant: "統計處私人住宅租金",
            .en: "C&SD private housing rent",
            .ja: "統計処の民間住宅家賃",
            .de: "Private Wohnungsmiete (C&SD)",
            .fr: "Loyer des logements privés (C&SD)",
            .nl: "Huur van particuliere woningen (C&SD)",
            .es: "Alquiler de vivienda privada (C&SD)",
            .it: "Affitto di abitazioni private (C&SD)"
        ],
        "市区重建局私人住宅租金指数": [
            .zhHant: "市區重建局私人住宅租金指數",
            .en: "URA private residential rental index",
            .ja: "URA の民間住宅賃料指数",
            .de: "URA-Mietindex für Privatwohnungen",
            .fr: "Indice des loyers résidentiels privés de l'URA",
            .nl: "URA-huurindex voor particuliere woningen",
            .es: "Índice de alquiler residencial privado de la URA",
            .it: "Indice degli affitti residenziali privati URA"
        ],
        "总务省民营房租": [
            .zhHant: "總務省民營房租",
            .en: "Statistics Bureau private rent",
            .ja: "総務省の民営家賃",
            .de: "Private Miete (Statistikamt)",
            .fr: "Loyer privé (bureau des statistiques)",
            .nl: "Particuliere huur (statistiekbureau)",
            .es: "Alquiler privado (oficina de estadística)",
            .it: "Affitto privato (ufficio di statistica)"
        ],
        "国际清算银行选定住宅房价": [
            .zhHant: "國際清算銀行選定住宅樓價",
            .en: "BIS selected residential property prices",
            .ja: "BIS の選定住宅価格",
            .de: "Ausgewählte Wohnimmobilienpreise der BIZ",
            .fr: "Prix résidentiels sélectionnés de la BRI",
            .nl: "Geselecteerde woningprijzen van de BIS",
            .es: "Precios residenciales seleccionados del BPI",
            .it: "Prezzi residenziali selezionati della BRI"
        ]
    ]

    private func crossoverFrom(_ year: Int) -> String {
        switch language {
        case .zhHans: "大约从第 \(year) 年起，买房转为更划算。"
        case .zhHant: "大約從第 \(year) 年起，買樓轉為更划算。"
        case .en: "From about year \(year), buying becomes the better deal."
        case .ja: "およそ\(year)年目から、購入のほうが有利になります。"
        case .de: "Etwa ab Jahr \(year) wird Kaufen günstiger."
        case .fr: "Vers l'année \(year), l'achat devient plus avantageux."
        case .nl: "Ongeveer vanaf jaar \(year) wordt kopen voordeliger."
        case .es: "Aproximadamente desde el año \(year), comprar compensa más."
        case .it: "Circa dall'anno \(year), comprare conviene di più."
        }
    }

    private func crossoverEarlyThenRent(_ later: Int) -> String {
        switch language {
        case .zhHans: "第 1 年买房更优，但从第 \(later) 年起转为租房更划算。"
        case .zhHant: "第 1 年買樓更優，但從第 \(later) 年起轉為租樓更划算。"
        case .en: "Buying is ahead in year 1, but from year \(later) renting becomes the better deal."
        case .ja: "1年目は購入が有利ですが、\(later)年目からは賃貸のほうが有利になります。"
        case .de: "Im Jahr 1 liegt Kaufen vorn, aber ab Jahr \(later) wird Mieten günstiger."
        case .fr: "L'achat est devant l'année 1, mais à partir de l'année \(later) la location devient plus avantageuse."
        case .nl: "In jaar 1 ligt kopen voor, maar vanaf jaar \(later) wordt huren voordeliger."
        case .es: "En el año 1 comprar va por delante, pero desde el año \(later) alquilar compensa más."
        case .it: "Nell'anno 1 comprare è avanti, ma dall'anno \(later) affittare conviene di più."
        }
    }

    private func crossoverWindow(_ year: Int, _ later: Int) -> String {
        let through = later - 1
        return switch language {
        case .zhHans: "大约从第 \(year) 年到第 \(through) 年，买房更划算；第 \(later) 年起转为租房。"
        case .zhHant: "大約從第 \(year) 年到第 \(through) 年，買樓更划算；第 \(later) 年起轉為租樓。"
        case .en: "Buying is the better deal from about year \(year) through year \(through); from year \(later), renting is ahead."
        case .ja: "およそ\(year)年目から\(through)年目までは購入が有利で、\(later)年目からは賃貸が有利になります。"
        case .de: "Etwa von Jahr \(year) bis Jahr \(through) ist Kaufen günstiger; ab Jahr \(later) liegt Mieten vorn."
        case .fr: "L'achat est plus avantageux vers les années \(year) à \(through) ; à partir de l'année \(later), la location est devant."
        case .nl: "Kopen is voordeliger van ongeveer jaar \(year) tot en met jaar \(through); vanaf jaar \(later) ligt huren voor."
        case .es: "Comprar compensa más aproximadamente del año \(year) al \(through); desde el año \(later), alquilar va por delante."
        case .it: "Comprare conviene di più circa dall'anno \(year) all'anno \(through); dall'anno \(later) l'affitto è avanti."
        }
    }

    private func t(
        _ zhHans: String, _ zhHant: String, _ en: String, _ ja: String,
        _ de: String, _ fr: String, _ nl: String, _ es: String, _ it: String
    ) -> String {
        switch language {
        case .zhHans: zhHans
        case .zhHant: zhHant
        case .en: en
        case .ja: ja
        case .de: de
        case .fr: fr
        case .nl: nl
        case .es: es
        case .it: it
        }
    }
}
