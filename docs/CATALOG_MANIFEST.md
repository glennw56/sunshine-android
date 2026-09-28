# Verified catalog manifest

Sources (not guessed):

- bakery-drinks `GET /order/api/menu` sampled 2026-09-20 (8 live drink variations + Square ids)
- `assets/generated/menu/square_photos.json` fetched 2026-09-13 (67 customer-facing names + Square/Square Online photos)
- Official site origin `https://www.sunshinebakeshop.com/`

Names are copied as stored. Do not rename. Trivial recolors are not counted as extra products.

## Counts

| Bucket | Count |
| --- | --- |
| Verified named products (photo map) | 67 |
| Live drinks API rows this sample | 8 |
| Modeled 3D table props (top sellers) | 10 |
| Integrated in Explore tables | 10 |
| Outstanding 3D meshes | 57+ (use `no_photo` / no fake pastry) |

## 3D integrated (10)

`prop_cream_cheese_danish`, `prop_vietnamese_coffee`, `prop_feta_spinach_danish`, `prop_nutella_croissant`, `prop_sausage_croissant`, `prop_mango_entrement`, `prop_birthday_cake_macaron`, `prop_fruit_tea`, `prop_cinnamon_roll`, `prop_chocolate_chip_cookie`.

## Live drinks IDs (2026-09-20)

| Name | variation_id | item_id |
| --- | --- | --- |
| Biscoff Coffee | QASHH4IWRCAJWUVJEVKGO4VA | VLYSUPIJKKN6OVVZFOT3GA2X |
| Coffee | GY2UPS2SHSKEJPQ6B4XKWGVV | F7FYGPSTZYGECY4DKJNDHFLA |
| Vietnamese Coffee | 22BNXC6JLRBJ23FWCL5VJTZF | UNGLWFJNHPWURKE7VRFSZZDU |
| Water | TNLTVE7ZJEWXGPYPOOWX7ZNK | JECKNNKEMOACMCM75YYOKZYB |
| Fruit Tea | LW7DLYZFKSZAYE453HUPQTTR | Y4JWSZOZFTJWEE4ALDKUREMV |
| Lemonade | ENPPBKRFCID6EBTBPADANVZL | QMMDJEP6HC3MKQBLABXSYSGH |
| Matcha Latte | G4IIAXZGK6J664MVF5QPSTZX | UZ26ZKE4DA3DTGVXTSDY7VSG |
| Milk Tea | GYWHCSUORPB2CDKVFRINODTI | IZQQKLQI4O5CUXMZEUWBCDXR |

## Historical aliases

cookie croissant → Chocolate Chip Cookie Croissant; japanese milk bread → Milk Bread; cajun blossom → Cajun Bloom.

## Inventory note

Drinks payload has **no** ATS/tracking fields. Shopping uses provider `sold_out` flags until bakery-drinks adds InventoryCounts for `L4CK6YWGT5XQX`.
