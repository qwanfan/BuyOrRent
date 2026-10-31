import Foundation

extension L10n {
    var helpCountry: String {
        pick(
            "选择国家后，会按该国自住普通住宅的代表情况更新贷款利率、租售比、物业税、和房产买卖费率。",
            "選擇國家後，會按該國自住普通住宅的代表情況更新貸款利率、物業稅和房屋買賣費率。",
            "After you choose a country, the mortgage rate, property tax, and buying and selling rates are updated for a typical owner-occupied home there.",
            "国を選ぶと、その国の持ち家の代表的な条件で、ローン金利、固定資産税、売買費用率を更新します。",
            "Nach der Länderwahl werden Darlehenszins, Grundsteuer sowie Kauf- und Verkaufssätze für ein typisches selbstgenutztes Zuhause aktualisiert.",
            "Après le choix du pays, le taux du prêt, la taxe foncière et les taux d'achat et de vente sont mis à jour pour un logement ordinaire occupé par son propriétaire.",
            "Na het kiezen van een land worden hypotheekrente, onroerendezaakbelasting en aan- en verkooptarieven bijgewerkt voor een gewone eigen woning.",
            "Al elegir un país se actualizan el tipo de interés, el impuesto sobre la vivienda y las tasas de compra y venta de una vivienda habitual ordinaria.",
            "Scegliendo un paese si aggiornano il tasso del mutuo, l'imposta sulla casa e le aliquote di acquisto e vendita di un'abitazione ordinaria occupata dal proprietario."
        )
    }

    var helpHousingType: String {
        pick(
            "选择房型后，只调整物业费、房屋维修和房屋保险：公寓物业费最高，联排较低，独栋默认没有物业费但维修和保险略高。",
            "選擇房型後，只調整物業費、房屋維修和房屋保險：公寓物業費最高，排屋較低，獨立屋預設沒有物業費，但維修和保險略高。",
            "Choosing a home type only adjusts the service charge, maintenance, and home insurance: apartments have the highest service charge, townhouses a lower one, and detached houses have none by default but slightly higher maintenance and insurance.",
            "住宅タイプを選ぶと、管理費、修繕、住宅保険だけが変わります。マンションの管理費が最も高く、テラスハウスは低め、一戸建ては管理費なしが既定で、修繕と保険はやや高めです。",
            "Die Wohnform ändert nur Hausgeld, Instandhaltung und Gebäudeversicherung: Wohnungen haben das höchste Hausgeld, Reihenhäuser ein niedrigeres, Einfamilienhäuser standardmäßig keines, aber etwas höhere Instandhaltung und Versicherung.",
            "Le type de logement ne change que les charges, l'entretien et l'assurance : l'appartement a les charges les plus élevées, la maison mitoyenne des charges plus faibles, et la maison individuelle n'en a pas par défaut, mais un entretien et une assurance un peu plus élevés.",
            "Het woningtype wijzigt alleen servicekosten, onderhoud en opstalverzekering: een appartement heeft de hoogste servicekosten, een tussenwoning lagere, en een vrijstaand huis standaard geen, maar iets hoger onderhoud en verzekering.",
            "El tipo de vivienda solo ajusta la comunidad, el mantenimiento y el seguro: el piso tiene la comunidad más alta, el adosado una más baja, y el chalet no tiene comunidad por defecto, pero un mantenimiento y un seguro algo mayores.",
            "Il tipo di abitazione modifica solo le spese condominiali, la manutenzione e l'assicurazione: l'appartamento ha le spese più alte, la villetta a schiera più basse, e la casa indipendente non ne ha per impostazione, ma manutenzione e assicurazione un po' più alte."
        )
    }

    var helpHomePrice: String {
        pick(
            "计划购买的房屋总价，是贷款、首付、维修和税费等计算的基准。",
            "計劃購買的房屋總價，是貸款、首期、維修和稅費等計算的基準。",
            "The total price of the home you plan to buy. It is the base for the loan, down payment, maintenance, taxes, and similar calculations.",
            "購入予定の住宅の総額です。ローン、頭金、修繕、税などの計算の基準になります。",
            "Der Gesamtkaufpreis der geplanten Immobilie. Er ist die Grundlage für Darlehen, Eigenkapital, Instandhaltung, Steuern und ähnliche Berechnungen.",
            "Prix total du logement que vous comptez acheter. Il sert de base au prêt, à l'apport, à l'entretien, aux taxes et aux calculs similaires.",
            "De totale prijs van de woning die u wilt kopen. Dit is de basis voor lening, eigen inleg, onderhoud, belastingen en vergelijkbare berekeningen.",
            "Precio total de la vivienda que piensa comprar. Es la base del préstamo, la entrada, el mantenimiento, los impuestos y cálculos similares.",
            "Prezzo totale dell'abitazione che si intende acquistare. È la base di mutuo, anticipo, manutenzione, imposte e calcoli simili."
        )
    }

    var helpDownPayment: String {
        pick(
            "首付占房价的比例。买入时实际付出的现金 = 首付 + 房价 × 买入费率。",
            "首期佔樓價的比例。買入時實際付出的現金 = 首期 + 樓價 × 買入費率。",
            "The down payment as a share of the price. Cash actually paid at purchase = down payment + price × buying-cost rate.",
            "頭金が価格に占める割合です。購入時に実際に出す現金 = 頭金 + 価格 × 購入時費用率。",
            "Der Eigenkapitalanteil am Preis. Tatsächlich beim Kauf gezahltes Geld = Eigenkapital + Preis × Kaufkostensatz.",
            "L'apport en part du prix. Espèces réellement versées à l'achat = apport + prix × taux de frais d'achat.",
            "De eigen inleg als deel van de prijs. Contant dat u bij aankoop werkelijk betaalt = eigen inleg + prijs × aankoopkostentarief.",
            "La entrada como parte del precio. Efectivo que se paga realmente al comprar = entrada + precio × tasa de costes de compra.",
            "L'anticipo come quota del prezzo. Contanti effettivamente pagati all'acquisto = anticipo + prezzo × aliquota dei costi di acquisto."
        )
    }

    var helpLoanYears: String {
        pick(
            "按揭贷款的还款年限，用于计算月供和贷款余额。",
            "按揭貸款的還款年期，用於計算月供和貸款餘額。",
            "The repayment term of the mortgage, used to calculate the monthly payment and the loan balance.",
            "住宅ローンの返済年数です。毎月の返済額とローン残高の計算に使います。",
            "Die Rückzahlungsdauer des Darlehens, verwendet für die Monatsrate und die Restschuld.",
            "La durée de remboursement du prêt, utilisée pour calculer la mensualité et le capital restant.",
            "De looptijd van de hypotheek, gebruikt om de maandlast en de restschuld te berekenen.",
            "El plazo de amortización del préstamo, usado para calcular la cuota y el saldo.",
            "La durata di rimborso del mutuo, usata per calcolare la rata e il debito residuo."
        )
    }

    var helpInterestRate: String {
        pick(
            "按揭贷款的年利率。月供按名义年利率除以 12 计息。这个利率写在房产成本表里，并随这张表每 30 天从 GitHub 更新。抓取失败时继续用本机已有的表。手动改过之后，自动更新不会覆盖。",
            "按揭貸款的年利率。月供按名義年利率除以 12 計息。這個利率寫在房產成本表裡，並隨這張表每 30 天從 GitHub 更新。抓取失敗時繼續用本機已有的表。手動改過之後，自動更新不會覆蓋。",
            "The annual mortgage rate. The monthly payment uses the nominal annual rate divided by 12. This rate is stored in the property-cost table and refreshes from GitHub with that table every 30 days. If the fetch fails, the app keeps the table already on the device. A manual edit is not overwritten by automatic updates.",
            "住宅ローンの年利です。毎月の返済は名目年利を 12 で割って計算します。この金利は不動産コスト表にあり、その表とともに 30 日ごとに GitHub から更新します。取得に失敗したときは端末にある表を使い続けます。手で変えたあとは、自動更新では上書きしません。",
            "Der Jahreszins des Darlehens. Die Monatsrate rechnet mit dem Nominalzins geteilt durch 12. Dieser Zins steht in der Immobilienkostentabelle und wird mit ihr alle 30 Tage von GitHub aktualisiert. Schlägt das fehl, bleibt die Tabelle auf dem Gerät. Eine manuelle Änderung wird nicht automatisch überschrieben.",
            "Le taux annuel du prêt. La mensualité utilise le taux nominal divisé par 12. Ce taux est dans le tableau des coûts immobiliers et se met à jour avec lui depuis GitHub tous les 30 jours. En cas d'échec, l'app garde le tableau déjà sur l'appareil. Une modification manuelle n'est pas écrasée.",
            "De jaarlijkse hypotheekrente. De maandlast rekent met de nominale rente gedeeld door 12. Deze rente staat in de vastgoedkostentabel en wordt daarmee elke 30 dagen van GitHub bijgewerkt. Mislukt dat, dan blijft de tabel op het apparaat. Een handmatige wijziging wordt niet overschreven.",
            "El tipo anual del préstamo. La cuota usa el tipo nominal dividido entre 12. Este tipo está en la tabla de costes de la vivienda y se actualiza con ella desde GitHub cada 30 días. Si falla, se sigue usando la tabla que ya está en el dispositivo. Un cambio manual no se sobrescribe.",
            "Il tasso annuo del mutuo. La rata usa il tasso nominale diviso per 12. Questo tasso è nella tabella dei costi immobiliari e si aggiorna con essa da GitHub ogni 30 giorni. Se il recupero fallisce, resta la tabella già sul dispositivo. Una modifica manuale non viene sovrascritta."
        )
    }

    var helpHorizonYears: String {
        pick(
            "持有房产的年限",
            "持有房產的年期。",
            "The number of years you hold the property.",
            "住宅を保有する年数です。",
            "Die Anzahl der Jahre, in denen Sie die Immobilie halten.",
            "Le nombre d'années pendant lesquelles vous détenez le bien.",
            "Het aantal jaren dat u de woning aanhoudt.",
            "Los años que conserva la vivienda.",
            "Gli anni in cui si tiene l'immobile."
        )
    }

    var helpInvestmentReturn: String {
        pick(
            "如果不买房，把首付、买入费用等现金拿去投资时使用的年化回报。默认值是标普 500 指数（SPX）过去 10 年的价格年化回报，不含股息，启动时会联网更新。也可以改成你认为合适的值",
            "如果不買樓，把首期、買入費用等現金拿去投資時使用的年化回報。預設值是標普 500 指數（SPX）過去 10 年的價格年化回報，不含股息，啟動時會聯網更新。也可以改成你認為合適的值。",
            "The annual return used if, instead of buying, you invested the down payment, buying costs, and similar cash. The default is the S&P 500 (SPX) price return over the past 10 years, excluding dividends, and it is updated online at launch. You can also change it to a value you consider appropriate.",
            "買わない場合に、頭金や購入時費用などの現金を投資するときに使う年率です。既定値は S&P 500（SPX）の過去 10 年の価格年率で、配当は含みません。起動時にネットで更新します。適切だと思う値に変えることもできます。",
            "Die Jahresrendite, falls Sie statt zu kaufen Eigenkapital, Kaufkosten und ähnliches Geld anlegen. Der Vorgabewert ist die Kursrendite des S&P 500 (SPX) der letzten 10 Jahre ohne Dividenden und wird beim Start online aktualisiert. Sie können ihn auch auf einen Wert ändern, den Sie für passend halten.",
            "Le rendement annualisé utilisé si, au lieu d'acheter, vous placiez l'apport, les frais d'achat et cet argent. La valeur par défaut est le rendement en prix du S&P 500 (SPX) sur 10 ans, hors dividendes, et elle est mise à jour en ligne au lancement. Vous pouvez aussi la remplacer par une valeur qui vous convient.",
            "Het jaarlijkse rendement als u, in plaats van te kopen, de eigen inleg, aankoopkosten en dat geld belegt. De standaard is het koersrendement van de S&P 500 (SPX) over 10 jaar, zonder dividend, en wordt bij het starten online bijgewerkt. U kunt het ook wijzigen in een waarde die u passend vindt.",
            "La rentabilidad anual si, en lugar de comprar, invierte la entrada, los costes de compra y ese dinero. El valor predeterminado es la rentabilidad del precio del S&P 500 (SPX) de los últimos 10 años, sin dividendos, y se actualiza en línea al abrir. También puede cambiarlo por un valor que considere adecuado.",
            "Il rendimento annuo se, invece di comprare, si investono anticipo, costi di acquisto e quel denaro. Il valore predefinito è il rendimento del prezzo dell'S&P 500 (SPX) degli ultimi 10 anni, senza dividendi, e si aggiorna online all'avvio. Si può anche sostituire con un valore ritenuto adatto."
        )
    }

    var helpAppreciation: String {
        pick(
            "房价每年的涨跌，可以为负。这个数是最近 10 年名义房价指数的复合年化，写在房产成本表里，并随这张表每 30 天从 GitHub 更新。抓取失败时继续用本机已有的表。手动改过之后，自动更新不会覆盖。调节它不会改变租金升值。",
            "樓價每年的升跌，可以為負。這個數是最近 10 年名義樓價指數的複合年化，寫在房產成本表裡，並隨這張表每 30 天從 GitHub 更新。抓取失敗時繼續用本機已有的表。手動改過之後，自動更新不會覆蓋。調節它不會改變租金升值。",
            "How much the home price rises or falls each year. A negative number means the price falls. This figure is the compound annual change in the nominal home-price index over the most recent 10 years. It is stored in the property-cost table and refreshes from GitHub with that table every 30 days. If the fetch fails, the app keeps the table already on the device. A manual edit is not overwritten. Changing it does not change rent growth.",
            "住宅価格が毎年どれだけ上がるか下がるかです。負の値は下落です。この値は最近 10 年の名目住宅価格指数の複利年率です。不動産コスト表にあり、その表とともに 30 日ごとに GitHub から更新します。取得に失敗したときは端末にある表を使い続けます。手で変えた後は自動更新で上書きしません。変えても家賃上昇は変わりません。",
            "Wie stark der Preis jedes Jahr steigt oder fällt. Ein negativer Wert bedeutet einen Rückgang. Die Zahl ist die jährliche Verzinsung des nominalen Hauspreisindex der letzten 10 Jahre. Sie steht in der Immobilienkostentabelle und wird mit ihr alle 30 Tage von GitHub aktualisiert. Schlägt das fehl, bleibt die Tabelle auf dem Gerät. Eine manuelle Änderung wird nicht überschrieben. Sie lässt die Mietsteigerung unverändert.",
            "La variation annuelle du prix. Un nombre négatif signifie une baisse. Ce chiffre est la variation annuelle composée de l'indice nominal des prix sur les 10 dernières années. Il est dans le tableau des coûts immobiliers et se met à jour avec lui depuis GitHub tous les 30 jours. En cas d'échec, l'app garde le tableau déjà sur l'appareil. Une modification manuelle n'est pas écrasée. Elle ne change pas la hausse du loyer.",
            "Hoeveel de prijs per jaar stijgt of daalt. Een negatief getal betekent een daling. Dit getal is de samengestelde jaarlijkse verandering van de nominale prijsindex over de meest recente 10 jaar. Het staat in de vastgoedkostentabel en wordt daarmee elke 30 dagen van GitHub bijgewerkt. Mislukt dat, dan blijft de tabel op het apparaat. Een handmatige wijziging wordt niet overschreven. Ze laat de huurstijging ongemoeid.",
            "Cuánto sube o baja el precio cada año. Un número negativo significa una bajada. Esta cifra es la variación anual compuesta del índice nominal de precios de los últimos 10 años. Está en la tabla de costes de la vivienda y se actualiza con ella desde GitHub cada 30 días. Si falla, se sigue usando la tabla que ya está en el dispositivo. Un cambio manual no se sobrescribe. No modifica la subida del alquiler.",
            "Quanto il prezzo sale o scende ogni anno. Un numero negativo indica un calo. Questo valore è la variazione annua composta dell'indice nominale dei prezzi degli ultimi 10 anni. È nella tabella dei costi immobiliari e si aggiorna con essa da GitHub ogni 30 giorni. Se il recupero fallisce, resta la tabella già sul dispositivo. Una modifica manuale non viene sovrascritta. Non cambia l'aumento dell'affitto."
        )
    }

    var helpRentGrowth: String {
        pick(
            "房租每年上涨的假设。除中国大陆外，这个数是租金指数最近 10 年的复合年化；中国大陆用最新一年的同比。它写在房产成本表里，并随这张表每 30 天从 GitHub 更新。抓取失败时继续用本机已有的表。手动改过之后，自动更新不会覆盖。调节它不会改变房价增值。",
            "租金每年上升的假設。除中國大陸外，這個數是租金指數最近 10 年的複合年化；中國大陸用最新一年的同比。它寫在房產成本表裡，並隨這張表每 30 天從 GitHub 更新。抓取失敗時繼續用本機已有的表。手動改過之後，自動更新不會覆蓋。調節它不會改變樓價升值。",
            "The assumed annual rate at which rent rises. Outside mainland China, this figure is the compound annual change in the rent index over the most recent 10 years. Mainland China uses the latest one-year change. It is stored in the property-cost table and refreshes from GitHub with that table every 30 days. If the fetch fails, the app keeps the table already on the device. A manual edit is not overwritten. Changing it does not change home appreciation.",
            "家賃が毎年上がる前提です。中国本土以外では、この値は家賃指数の最近 10 年の複利年率です。中国本土は最新の 1 年の変化を使います。不動産コスト表にあり、その表とともに 30 日ごとに GitHub から更新します。取得に失敗したときは端末にある表を使い続けます。手で変えた後は自動更新で上書きしません。変えても住宅価格上昇は変わりません。",
            "Die angenommene jährliche Mietsteigerung. Außerhalb des chinesischen Festlands ist die Zahl die jährliche Verzinsung des Mietindex der letzten 10 Jahre. Das chinesische Festland nutzt die Veränderung des letzten Jahres. Die Zahl steht in der Immobilienkostentabelle und wird mit ihr alle 30 Tage von GitHub aktualisiert. Schlägt das fehl, bleibt die Tabelle auf dem Gerät. Eine manuelle Änderung wird nicht überschrieben. Sie lässt die Wertsteigerung unverändert.",
            "La hausse annuelle supposée du loyer. Hors Chine continentale, ce chiffre est la variation annuelle composée de l'indice des loyers sur les 10 dernières années. La Chine continentale utilise la variation de la dernière année. Ce chiffre est dans le tableau des coûts immobiliers et se met à jour avec lui depuis GitHub tous les 30 jours. En cas d'échec, l'app garde le tableau déjà sur l'appareil. Une modification manuelle n'est pas écrasée. Elle ne change pas la plus-value.",
            "De veronderstelde jaarlijkse huurstijging. Buiten het Chinese vasteland is dit getal de samengestelde jaarlijkse verandering van de huurindex over de meest recente 10 jaar. Het Chinese vasteland gebruikt de verandering van het laatste jaar. Dit getal staat in de vastgoedkostentabel en wordt daarmee elke 30 dagen van GitHub bijgewerkt. Mislukt dat, dan blijft de tabel op het apparaat. Een handmatige wijziging wordt niet overschreven. Ze laat de waardestijging ongemoeid.",
            "La subida anual supuesta del alquiler. Fuera de China continental, esta cifra es la variación anual compuesta del índice de alquileres de los últimos 10 años. China continental usa la variación del último año. Esta cifra está en la tabla de costes de la vivienda y se actualiza con ella desde GitHub cada 30 días. Si falla, se sigue usando la tabla que ya está en el dispositivo. Un cambio manual no se sobrescribe. No modifica la revalorización.",
            "L'aumento annuo ipotizzato dell'affitto. Fuori dalla Cina continentale, questo valore è la variazione annua composta dell'indice degli affitti degli ultimi 10 anni. La Cina continentale usa la variazione dell'ultimo anno. Questo valore è nella tabella dei costi immobiliari e si aggiorna con essa da GitHub ogni 30 giorni. Se il recupero fallisce, resta la tabella già sul dispositivo. Una modifica manuale non viene sovrascritta. Non cambia la rivalutazione."
        )
    }

    var helpMonthlyRent: String {
        pick(
            "当前可比住房的月租金。按 Numbeo 市中心和市郊租售比的平均值计算：月租 = 房价 ÷ (租售比 × 12)。App 启动时直接向 Numbeo 抓取这个比值。抓取失败时继续用上次成功的结果，没有时才用出厂种子。未手动修改时会按这个比值重算；手动改过后，自动更新不再覆盖。请按实际租金修改。",
            "目前可比住宅的月租。按 Numbeo 市中心和市郊租售比的平均值計算：月租 = 樓價 ÷（租售比 × 12）。App 啟動時直接向 Numbeo 抓取這個比值。抓取失敗時繼續用上次成功的結果，沒有時才用出廠種子。未手動修改時會按這個比值重算；手動改過後，自動更新不再覆蓋。請按實際租金修改。",
            "The current monthly rent of a comparable home. It uses the average of Numbeo's city-centre and outside-centre price-to-rent ratios: monthly rent = price ÷ (years × 12). The app fetches this ratio directly from Numbeo at launch. If that fails, it keeps the last successful result, and uses the built-in seed only when there is none. Until you edit it by hand, it is recalculated from this ratio. A manual edit is not overwritten. Change it to your actual rent.",
            "比べられる住宅の現在の月額家賃です。Numbeo の都心と郊外の価格家賃倍率の平均で計算します。月額家賃 = 価格 ÷（倍率 × 12）。起動時に Numbeo からこの倍率を直接取得します。取得に失敗したときは前回成功した結果を使い、それがなければ初期値を使います。手で変えるまではこの倍率で再計算します。手で変えたあとは自動更新で上書きしません。実際の家賃に合わせて変更してください。",
            "Die aktuelle Monatsmiete einer vergleichbaren Wohnung. Sie wird aus dem Mittel von Numbeos Kaufpreis-Miet-Verhältnis in der Innenstadt und außerhalb berechnet: Monatsmiete = Preis ÷ (Jahre × 12). Die App holt dieses Verhältnis beim Start direkt von Numbeo. Schlägt das fehl, bleibt das letzte erfolgreiche Ergebnis; der eingebaute Ausgangswert gilt nur, wenn keines vorliegt. Solange Sie sie nicht von Hand ändern, wird sie aus diesem Verhältnis neu berechnet. Eine manuelle Änderung wird nicht überschrieben. Bitte tragen Sie die tatsächliche Miete ein.",
            "Le loyer mensuel actuel d'un logement comparable. Il est calculé à partir de la moyenne des ratios prix/loyer Numbeo au centre-ville et en périphérie : loyer = prix ÷ (années × 12). L'app récupère ce ratio directement sur Numbeo au lancement. En cas d'échec, elle garde le dernier résultat réussi, et n'utilise la valeur d'origine que s'il n'y en a pas. Tant qu'il n'est pas modifié à la main, il est recalculé avec ce ratio. Une modification manuelle n'est pas écrasée. Indiquez le loyer réel.",
            "De huidige maandhuur van een vergelijkbare woning. Die wordt berekend uit het gemiddelde van Numbeo's koop-huurverhouding in het centrum en daarbuiten: maandhuur = prijs ÷ (jaren × 12). De app haalt deze verhouding bij het starten rechtstreeks van Numbeo. Mislukt dat, dan blijft het laatst geslaagde resultaat gelden; de ingebouwde beginwaarde geldt alleen als die er niet is. Tot u hem met de hand wijzigt, wordt hij uit deze verhouding herberekend. Een handmatige wijziging wordt niet overschreven. Vul de werkelijke huur in.",
            "El alquiler mensual actual de una vivienda comparable. Se calcula con la media de la relación precio-alquiler de Numbeo en el centro y fuera del centro: alquiler = precio ÷ (años × 12). La app obtiene esta relación directamente de Numbeo al abrirse. Si falla, se conserva el último resultado correcto, y el valor de fábrica solo si no hay ninguno. Hasta que lo cambie a mano, se recalcula con esta relación. Un cambio manual no se sobrescribe. Cámbielo según el alquiler real.",
            "L'affitto mensile attuale di un'abitazione comparabile. Si calcola dalla media dei rapporti prezzo-affitto Numbeo in centro e fuori centro: affitto = prezzo ÷ (anni × 12). All'avvio l'app recupera questo rapporto direttamente da Numbeo. Se il recupero fallisce, resta l'ultimo risultato riuscito; il valore di fabbrica si usa solo se non ce n'è uno. Finché non lo si modifica a mano, viene ricalcolato con questo rapporto. Una modifica manuale non viene sovrascritta. Inserite l'affitto reale."
        )
    }

    var helpMaintenance: String {
        pick(
            "房屋维修保养的年费率。",
            "房屋維修保養的年費率。",
            "The annual maintenance rate.",
            "住宅の修繕・維持の年率です。",
            "Der jährliche Instandhaltungssatz.",
            "Le taux annuel d'entretien.",
            "Het jaarlijkse onderhoudstarief.",
            "La tasa anual de mantenimiento.",
            "L'aliquota annua di manutenzione."
        )
    }

    var helpPropertyTax: String {
        pick(
            "自住普通住宅年度房产税。各国实际计税基础可能是评估价、年度租值、面积或档位，且地方差异很大。请按实际税单修改。",
            "自住普通住宅的年度物業稅。各地實際計稅基礎可能是評估價、年度租值、面積或檔次，而且地區差異很大。請按實際稅單修改。",
            "The annual property tax on an ordinary owner-occupied home. The actual tax base may be an assessed value, an annual rental value, floor area, or a band, and it varies widely by place. Please change it to match your tax bill.",
            "持ち家の年間固定資産税です。実際の課税標準は評価額、年間賃料、面積、区分などで、地域差が大きくあります。実際の税額通知に合わせて変更してください。",
            "Die jährliche Grundsteuer für ein gewöhnliches selbstgenutztes Zuhause. Die tatsächliche Bemessung kann ein Einheitswert, ein Jahresmietwert, die Fläche oder eine Stufe sein und unterscheidet sich stark nach Ort. Bitte passen Sie sie an Ihren Steuerbescheid an.",
            "La taxe foncière annuelle d'un logement ordinaire occupé par son propriétaire. L'assiette réelle peut être une valeur évaluée, une valeur locative annuelle, une surface ou une tranche, et elle varie beaucoup selon l'endroit. Modifiez-la d'après votre avis d'imposition.",
            "De jaarlijkse onroerendezaakbelasting van een gewone eigen woning. De echte grondslag kan een taxatiewaarde, een jaarlijkse huurwaarde, oppervlakte of een schijf zijn en verschilt sterk per plaats. Pas hem aan op uw aanslag.",
            "El impuesto anual de una vivienda habitual ordinaria. La base real puede ser un valor catastral, un valor de alquiler anual, la superficie o un tramo, y varía mucho según el lugar. Cámbielo según su recibo.",
            "L'imposta annua su un'abitazione ordinaria occupata dal proprietario. La base reale può essere un valore stimato, un valore locativo annuo, la superficie o una fascia, e varia molto da un luogo all'altro. Modificatela in base all'avviso."
        )
    }

    var helpInsurance: String {
        pick(
            "房屋保险的年费率。",
            "房屋保險的年費率。",
            "The annual home-insurance rate.",
            "住宅保険の年率です。",
            "Der jährliche Gebäudeversicherungssatz.",
            "Le taux annuel d'assurance habitation.",
            "Het jaarlijkse tarief van de opstalverzekering.",
            "La tasa anual del seguro del hogar.",
            "L'aliquota annua dell'assicurazione sulla casa."
        )
    }

    var helpHOA: String {
        pick(
            "每月固定物业费或 HOA 费用。",
            "每月固定物業費或 HOA 費用。",
            "The fixed monthly service charge or HOA fee.",
            "毎月固定の管理費または HOA 費用です。",
            "Das feste monatliche Hausgeld oder die HOA-Gebühr.",
            "Les charges fixes mensuelles ou les frais de copropriété.",
            "De vaste maandelijkse servicekosten of HOA-bijdrage.",
            "La comunidad fija mensual o la cuota de la asociación.",
            "Le spese condominiali fisse mensili o la quota HOA."
        )
    }

    var helpPMI: String {
        pick(
            "贷款保险（如 PMI）的年费率。只在首付低于 20%，且剩余贷款仍高于当时房价 80% 时，按贷款余额收取。",
            "按揭保險（如 PMI）的年費率。只在首期低於 20%，而且剩餘貸款仍高於當時樓價 80% 時，按貸款餘額收取。",
            "The annual mortgage-insurance rate, such as PMI. It is charged on the loan balance only when the down payment is below 20% and the remaining loan is still above 80% of the home value at the time.",
            "PMI のようなローン保証料の年率です。頭金が 20% 未満で、残債がその時点の住宅価格の 80% をまだ超えているときだけ、残高に対してかかります。",
            "Der jährliche Satz einer Darlehensversicherung wie PMI. Er wird auf die Restschuld erhoben, nur wenn das Eigenkapital unter 20 % liegt und die Restschuld noch über 80 % des damaligen Immobilienwerts liegt.",
            "Le taux annuel d'une assurance emprunteur, comme le PMI. Il porte sur le capital restant seulement si l'apport est inférieur à 20 % et que le prêt restant dépasse encore 80 % de la valeur du bien à ce moment.",
            "Het jaarlijkse tarief van een hypotheekverzekering zoals PMI. Het wordt op de restschuld berekend alleen als de eigen inleg onder 20% ligt en de restschuld nog boven 80% van de toenmalige woningwaarde ligt.",
            "La tasa anual de un seguro del préstamo, como el PMI. Se cobra sobre el saldo solo si la entrada es inferior al 20% y el préstamo pendiente sigue por encima del 80% del valor de la vivienda en ese momento.",
            "L'aliquota annua di un'assicurazione sul mutuo, come il PMI. Si applica al debito residuo solo se l'anticipo è sotto il 20% e il debito restante è ancora sopra l'80% del valore dell'abitazione in quel momento."
        )
    }

    var helpBuyingCost: String {
        pick(
            "买入时一次性交易成本占房价的代表性比例，包括适用的转让税、登记、公证、法律和常见服务费用。默认值按本国居民购买自住普通住宅估算，不包含外国买家、多套房或豪宅附加税；请按实际报价修改。",
            "買入時一次性交易成本佔樓價的代表性比例，包括適用的轉讓稅、登記、公證、法律和常見服務費用。預設值按本地居民購買自住普通住宅估算，不包括外來買家、多一套住宅或豪宅附加稅；請按實際報價修改。",
            "A representative share of the price for one-time buying costs, including applicable transfer tax, registration, notary, legal, and common service fees. The default estimates a resident buying an ordinary owner-occupied home. It excludes surcharges for foreign buyers, additional homes, or luxury property. Please adjust it to a real quote.",
            "購入時に一度かかる費用が価格に占める代表的な割合です。かかる譲渡税、登記、公正証書、法律、一般的な手数料を含みます。既定値は居住者が普通の持ち家を買う場合の見積もりで、外国人買い手、複数住宅、高級住宅の追加税は含みません。実際の見積もりに合わせて変更してください。",
            "Ein repräsentativer Anteil am Preis für einmalige Kaufkosten, einschließlich anfallender Grunderwerbsteuer, Eintragung, Notar, Recht und üblicher Dienstleister. Der Vorgabewert schätzt einen Einwohner, der ein gewöhnliches selbstgenutztes Zuhause kauft. Zuschläge für ausländische Käufer, weitere Wohnungen oder Luxus fehlen. Bitte passen Sie ihn an ein echtes Angebot an.",
            "Part représentative du prix pour les frais d'achat payés une fois, y compris les droits de mutation, l'enregistrement, le notaire, les frais juridiques et les services courants qui s'appliquent. La valeur par défaut estime un résident qui achète un logement ordinaire pour l'occuper. Elle exclut les majorations pour acheteur étranger, logement supplémentaire ou bien de luxe. Ajustez-la à un devis réel.",
            "Een representatief aandeel van de prijs voor eenmalige aankoopkosten, inclusief overdrachtsbelasting, registratie, notaris, juridische kosten en gebruikelijke diensten die gelden. De standaard schat een inwoner die een gewone eigen woning koopt. Toeslagen voor buitenlandse kopers, extra woningen of luxe ontbreken. Pas het aan op een echte offerte.",
            "Una parte representativa del precio de los costes de compra que se pagan una vez, incluidos el impuesto de transmisiones, el registro, el notario, los gastos jurídicos y los servicios habituales que correspondan. El valor predeterminado estima a un residente que compra una vivienda habitual ordinaria. No incluye recargos de comprador extranjero, vivienda adicional o lujo. Ajústelo a un presupuesto real.",
            "Una quota rappresentativa del prezzo per i costi di acquisto pagati una volta, comprese imposta di trasferimento, registrazione, notaio, spese legali e servizi comuni applicabili. Il valore predefinito stima un residente che compra un'abitazione ordinaria per viverci. Esclude maggiorazioni per acquirente estero, altra casa o immobile di lusso. Adattatelo a un preventivo reale."
        )
    }

    var helpSellingCost: String {
        pick(
            "卖出时交易成本占当时房价的代表性比例，例如代理、法律和登记费用。卖出净得 = 期末房价 × (1 − 卖出费率) − 贷款余额。税务和服务费因地区、持有期及交易方式不同，请按实际报价修改。",
            "賣出時交易成本佔當時樓價的代表性比例，例如代理、法律和登記費用。賣出淨得 = 期末樓價 ×（1 − 賣出費率）− 貸款餘額。稅務和服務費因地區、持有期及交易方式不同，請按實際報價修改。",
            "A representative share of the then home price for selling costs, such as agent, legal, and registration fees. Net sale proceeds = ending home value × (1 − selling-cost rate) − loan balance. Taxes and service fees vary by region, holding period, and how the sale is done. Please adjust them to a real quote.",
            "売却時の費用がその時点の住宅価格に占める代表的な割合です。仲介、法律、登記などを含みます。売却手取り = 期末価格 ×（1 − 売却時費用率）− ローン残高。税や手数料は地域、保有期間、取引の仕方で変わります。実際の見積もりに合わせて変更してください。",
            "Ein repräsentativer Anteil am damaligen Immobilienwert für Verkaufskosten, etwa Makler, Recht und Eintragung. Nettoerlös = Endwert × (1 − Verkaufskostensatz) − Restschuld. Steuern und Gebühren hängen von Ort, Haltedauer und Art des Verkaufs ab. Bitte passen Sie sie an ein echtes Angebot an.",
            "Part représentative du prix d'alors pour les frais de vente, par exemple agence, droit et enregistrement. Produit net = valeur finale × (1 − taux de frais de vente) − capital restant. Impôts et frais varient selon l'endroit, la durée et le mode de vente. Ajustez-les à un devis réel.",
            "Een representatief aandeel van de toenmalige woningwaarde voor verkoopkosten, zoals makelaar, juridische kosten en registratie. Netto-opbrengst = eindwaarde × (1 − verkoopkostentarief) − restschuld. Belasting en kosten verschillen per plaats, bezitsduur en wijze van verkoop. Pas ze aan op een echte offerte.",
            "Una parte representativa del precio de entonces para los costes de venta, como agencia, gastos jurídicos y registro. Ingreso neto = valor final × (1 − tasa de costes de venta) − saldo. Impuestos y honorarios varían según el lugar, el tiempo de tenencia y la forma de la venta. Ajústelos a un presupuesto real.",
            "Una quota rappresentativa del prezzo di allora per i costi di vendita, come agenzia, spese legali e registrazione. Ricavo netto = valore finale × (1 − aliquota dei costi di vendita) − debito residuo. Imposte e commissioni variano per luogo, durata e modalità della vendita. Adattatele a un preventivo reale."
        )
    }

    var helpAdvantage: String {
        pick(
            "买房相对租房，在持有期末多出的净财富。正数表示买房更优，负数表示租房更优。等于卖出净得减去买入现金终值和持有成本终值，再加上省下房租的终值。",
            "買樓相對租樓，在持有期末多出的淨財富。正數表示買樓更優，負數表示租樓更優。等於賣出淨得減去買入現金終值和持有成本終值，再加上省下租金的終值。",
            "The extra net worth of buying versus renting at the end of the holding period. A positive number means buying is ahead; a negative number means renting is ahead. It equals net sale proceeds, minus the future value of the cash paid to buy and the future value of holding costs, plus the future value of rent saved.",
            "保有期末に、購入が賃貸より多い純資産です。正なら購入が有利、負なら賃貸が有利です。売却手取りから、購入時に出した現金の将来価値と保有コストの将来価値を引き、節約した家賃の将来価値を足したものです。",
            "Das zusätzliche Vermögen von Kaufen gegenüber Mieten am Ende der Haltungsdauer. Positiv liegt Kaufen vorn, negativ Mieten. Es ist der Nettoverkaufserlös minus dem Endwert des Kaufgeldes und dem Endwert der Haltekosten, plus dem Endwert der gesparten Miete.",
            "Le patrimoine en plus de l'achat par rapport à la location à la fin de la détention. Positif, l'achat est devant ; négatif, la location est devant. C'est le produit net de vente moins la valeur future de l'argent versé à l'achat et la valeur future des coûts de détention, plus la valeur future du loyer économisé.",
            "Het extra vermogen van kopen tegenover huren aan het einde van de bezitstermijn. Positief ligt kopen voor, negatief huren. Het is de netto-verkoopopbrengst min de toekomstige waarde van het aankoopgeld en de toekomstige waarde van de bezitkosten, plus de toekomstige waarde van de bespaarde huur.",
            "El patrimonio de más de comprar frente a alquilar al final de la tenencia. Positivo significa que comprar va por delante; negativo, que alquilar va por delante. Es el ingreso neto de venta menos el valor futuro del dinero pagado al comprar y el valor futuro de los costes de tenencia, más el valor futuro del alquiler ahorrado.",
            "Il patrimonio in più dell'acquisto rispetto all'affitto alla fine del possesso. Positivo: comprare è avanti; negativo: l'affitto è avanti. È il ricavo netto di vendita meno il valore futuro del denaro versato per comprare e il valore futuro dei costi di possesso, più il valore futuro dell'affitto risparmiato."
        )
    }

    var helpSaleProceeds: String {
        pick(
            "持有期末卖掉房子、还完贷款后口袋里还剩多少：期末房价 × (1 − 卖出费率) − 当时贷款余额。期末房价由买价按「房产增值」滚到期末计算。",
            "持有期末賣掉房子、還完貸款後口袋裏還剩多少：期末樓價 ×（1 − 賣出費率）− 當時貸款餘額。期末樓價由買價按「樓價升值」滾到期末計算。",
            "How much cash is left after selling the home at the end and paying off the loan: ending home value × (1 − selling-cost rate) − the loan balance then. The ending home value is calculated by compounding the purchase price to the end at the home-appreciation rate.",
            "期末に売ってローンを返したあとに残る現金です。期末価格 ×（1 − 売却時費用率）− そのときの残高。期末価格は、買値を「住宅価格上昇」で期末まで伸ばして計算します。",
            "Was nach Verkauf am Ende und Tilgung übrig bleibt: Endwert × (1 − Verkaufskostensatz) − die Restschuld dann. Der Endwert wird berechnet, indem der Kaufpreis mit der Wertsteigerung bis zum Ende hochgerechnet wird.",
            "Ce qui reste après avoir vendu à la fin et remboursé le prêt : valeur finale × (1 − taux de frais de vente) − le capital restant. La valeur finale se calcule en faisant croître le prix d'achat jusqu'à la fin selon la plus-value.",
            "Wat overblijft na verkoop aan het einde en aflossing: eindwaarde × (1 − verkoopkostentarief) − de restschuld dan. De eindwaarde wordt berekend door de koopprijs met de waardestijging tot het einde door te rekenen.",
            "Cuánto queda tras vender al final y pagar el préstamo: valor final × (1 − tasa de costes de venta) − el saldo entonces. El valor final se calcula haciendo crecer el precio de compra hasta el final con la revalorización.",
            "Quanto resta dopo aver venduto alla fine e estinto il mutuo: valore finale × (1 − aliquota dei costi di vendita) − il debito residuo. Il valore finale si calcola portando il prezzo d'acquisto fino alla fine con la rivalutazione."
        )
    }

    var helpInitialCashFV: String {
        pick(
            "买房时先掏出去的现金（首付 + 房价 × 买入费率）若按「投资回报」复利到期末的合计。",
            "買樓時先掏出去的現金（首期 + 樓價 × 買入費率）若按「投資回報」複利到期末的合計。",
            "The future value, compounded to the end at the investment return, of the cash paid up front to buy (down payment + price × buying-cost rate).",
            "購入時に先に出す現金（頭金 + 価格 × 購入時費用率）を、投資利回りで期末まで複利にした合計です。",
            "Der Endwert, zur Anlagerendite aufgezinst, des Geldes, das beim Kauf zuerst gezahlt wird (Eigenkapital + Preis × Kaufkostensatz).",
            "La valeur future, capitalisée jusqu'à la fin au rendement des placements, de l'argent versé d'abord pour acheter (apport + prix × taux de frais d'achat).",
            "De toekomstige waarde, tot het einde samengesteld tegen het beleggingsrendement, van het geld dat bij de koop eerst wordt betaald (eigen inleg + prijs × aankoopkostentarief).",
            "El valor futuro, capitalizado hasta el final a la rentabilidad, del dinero que se paga primero al comprar (entrada + precio × tasa de costes de compra).",
            "Il valore futuro, capitalizzato fino alla fine al rendimento, del denaro pagato subito per comprare (anticipo + prezzo × aliquota dei costi di acquisto)."
        )
    }

    var helpHoldingCostFV: String {
        pick(
            "持有期间实际掏的钱（月供 + 维修 + 地税 + 保险 + 物业费 + 贷款保险）若按「投资回报」复利到期末的合计。",
            "持有期間實際掏的錢（月供 + 維修 + 地稅 + 保險 + 物業費 + 按揭保險）若按「投資回報」複利到期末的合計。",
            "The future value, compounded to the end at the investment return, of the money actually paid while you hold the home (monthly payment + maintenance + property tax + insurance + service charge + mortgage insurance).",
            "保有中に実際に出すお金（毎月の返済 + 修繕 + 固定資産税 + 保険 + 管理費 + ローン保証料）を、投資利回りで期末まで複利にした合計です。",
            "Der Endwert, zur Anlagerendite aufgezinst, des Geldes, das während des Haltens tatsächlich gezahlt wird (Monatsrate + Instandhaltung + Grundsteuer + Versicherung + Hausgeld + Darlehensversicherung).",
            "La valeur future, capitalisée jusqu'à la fin au rendement, de l'argent réellement payé pendant la détention (mensualité + entretien + taxe foncière + assurance + charges + assurance emprunteur).",
            "De toekomstige waarde, tot het einde samengesteld tegen het beleggingsrendement, van het geld dat tijdens het bezit werkelijk wordt betaald (maandlast + onderhoud + onroerendezaakbelasting + verzekering + servicekosten + hypotheekverzekering).",
            "El valor futuro, capitalizado hasta el final a la rentabilidad, del dinero que se paga realmente durante la tenencia (cuota + mantenimiento + impuesto + seguro + comunidad + seguro del préstamo).",
            "Il valore futuro, capitalizzato fino alla fine al rendimento, del denaro effettivamente pagato durante il possesso (rata + manutenzione + imposta + assicurazione + spese condominiali + assicurazione sul mutuo)."
        )
    }

    var helpSavedRentFV: String {
        pick(
            "因为买房不必再交房租。每月省下的房租（并按「租金升值」逐年调整）若按「投资回报」复利到期末的合计。",
            "因為買樓不必再交租金。每月省下的租金（並按「租金升值」逐年調整）若按「投資回報」複利到期末的合計。",
            "Because buying means you no longer pay rent. The future value, compounded to the end at the investment return, of the rent saved each month, adjusted year by year at the rent-growth rate.",
            "購入すると家賃を払わずに済むからです。毎月節約する家賃（家賃上昇で年ごとに調整）を、投資利回りで期末まで複利にした合計です。",
            "Weil Sie beim Kauf keine Miete mehr zahlen. Der Endwert, zur Anlagerendite aufgezinst, der jeden Monat gesparten Miete, jährlich mit der Mietsteigerung angepasst.",
            "Parce qu'acheter signifie ne plus payer de loyer. La valeur future, capitalisée jusqu'à la fin au rendement, du loyer économisé chaque mois, ajusté chaque année selon la hausse du loyer.",
            "Omdat kopen betekent dat u geen huur meer betaalt. De toekomstige waarde, tot het einde samengesteld tegen het beleggingsrendement, van de huur die u elke maand bespaart, jaarlijks aangepast met de huurstijging.",
            "Porque comprar significa dejar de pagar alquiler. El valor futuro, capitalizado hasta el final a la rentabilidad, del alquiler ahorrado cada mes, ajustado año a año con la subida del alquiler.",
            "Perché comprare significa non pagare più l'affitto. Il valore futuro, capitalizzato fino alla fine al rendimento, dell'affitto risparmiato ogni mese, corretto anno per anno con l'aumento dell'affitto."
        )
    }

    private func pick(
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
