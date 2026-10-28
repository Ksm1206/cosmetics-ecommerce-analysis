# 데이터 받는 법

1. Kaggle에 로그인한 뒤 데이터셋 페이지로 갑니다.
   https://www.kaggle.com/datasets/mkechinov/ecommerce-events-history-in-cosmetics-shop
2. 오른쪽 위 **Download** 버튼으로 zip을 받습니다 (약 500MB 압축, 풀면 2GB 이상).
3. 압축을 풀어서 CSV 5개를 `data/raw/` 폴더에 넣습니다.

```
data/raw/
├── 2019-Oct.csv
├── 2019-Nov.csv
├── 2019-Dec.csv
├── 2020-Jan.csv
└── 2020-Feb.csv
```

Kaggle CLI를 쓴다면 이렇게 받을 수도 있습니다 (API 토큰 설정 필요).

```bash
kaggle datasets download -d mkechinov/ecommerce-events-history-in-cosmetics-shop -p data/raw --unzip
```

`data/raw/`는 `.gitignore`에 들어 있어서 GitHub에 올라가지 않습니다.
