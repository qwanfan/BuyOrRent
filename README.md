# BuyOrRent

SwiftUI 买房与租房净财富比较工具，支持 macOS 和 iOS。

## 房产成本数据

App 以个人购买并自住普通住宅为统一口径，内置14个国家的房产税、买入成本和卖出成本代表值。实际税费可能受城市、房屋价格、面积、首套资格和持有年限影响，界面中的默认值可手动修改。

远程数据发布在：

- `https://qwanfan.github.io/BuyOrRent/v1/property-costs.json`
- `https://qwanfan.github.io/BuyOrRent/v1/property-costs-v1.schema.json`
- `https://qwanfan.github.io/BuyOrRent/v1/sources.json`

App 启动时立即使用最后成功缓存或内置种子。当前国家没有缓存，或距上次成功检查已满30天时，才会访问 GitHub Pages。下载、解析或校验失败不会清除最后成功数据。

## 季度更新

`.github/workflows/update-property-costs.yml` 在每年 1、4、7、10 月运行，也支持手动触发。工作流：

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
python3 -m unittest Scripts/test_update_property_costs.py
xcodebuild test \
  -project BuyOrRent.xcodeproj \
  -scheme BuyOrRent \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData
```
