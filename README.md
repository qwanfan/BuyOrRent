# BuyOrRent property costs

本仓库只维护并发布买/租成本表到 GitHub Pages，不包含 Swift 客户端源码。

远程数据：

- https://qwanfan.github.io/BuyOrRent/v1/property-costs.json
- https://qwanfan.github.io/BuyOrRent/v1/property-costs-v1.schema.json
- https://qwanfan.github.io/BuyOrRent/v1/sources.json

## 目录

- `Data/property-cost-sources.json`：人工维护源表
- `Data/property-costs-v1.schema.json`：schema
- `Data/housing-defaults/`：各国房型房价与物业费溯源
- `Scripts/`：生成、校验与月更抓取
- `public/v1/`：GitHub Pages 发布内容

## 每月更新

`.github/workflows/update-property-costs.yml` 在每月 1 日运行，也支持手动触发。

```sh
python3 Scripts/update_property_costs.py
python3 Scripts/validate_property_costs.py
python3 -m unittest discover -s Scripts -p 'test_*.py'
```
