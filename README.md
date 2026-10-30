# BuyOrRent

SwiftUI 买房与租房净财富比较工具，支持 macOS 和 iOS。

## 房产成本数据

App 以个人购买并自住普通住宅为统一口径，内置14个国家的房产税、买入成本、卖出成本、房贷利率、租金升值和房价涨跌代表值，以及标普 500 过去 10 年的价格年化回报，用作投资回报默认值。租售比不在这张表里，App 启动时直接向 Numbeo 抓取市中心和市郊租售比的平均值。实际税费可能受城市、房屋价格、面积、首套资格和持有年限影响，界面中的默认值可手动修改。

远程数据发布在：

- `https://qwanfan.github.io/BuyOrRent/v1/property-costs.json`
- `https://qwanfan.github.io/BuyOrRent/v1/property-costs-v1.schema.json`
- `https://qwanfan.github.io/BuyOrRent/v1/sources.json`

App 随包内置完整的 14 国数据表，启动后即可离线计算。距内置表或上次成功检查已满 30 天，或当前国家两边都没有时，才会访问 GitHub Pages。下载、解析或校验失败不会清除最后成功数据。

## 每月更新

`.github/workflows/update-property-costs.yml` 在每月 1 日运行，也支持手动触发。工作流会重新计算标普 500 过去 10 年的价格年化回报，抓取房贷利率、租金升值和房价涨跌，并复查房产成本来源。步骤：

1. 校验14国覆盖、HTTPS 来源、日期和费率范围。
2. 检查来源可访问性。
3. 拒绝超过阈值的未审核费率跳变。
4. 运行生成器测试和 JSON Schema 校验。
5. 校验全部通过后使用 GitHub Pages 发布；失败时保留线上旧版本。

源数据和口径维护在 `Data/property-cost-sources.json`。生成命令：

```sh
python3 Scripts/update_property_costs.py
python3 Scripts/validate_property_costs.py
```

## 测试

```sh
python3 -m unittest discover -s Scripts -p 'test_*.py'
xcodebuild test \
  -project BuyOrRent.xcodeproj \
  -scheme BuyOrRent \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData
```
