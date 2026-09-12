enum CurrencyType { coins, gems }

class ShopItem {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int price;
  final CurrencyType currency;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    required this.currency,
  });
}