class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorArgb,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String icon;
  final int colorArgb;
  final int createdAt;
}

/// `parent` is a built-in category name ("FOOD") or `custom:<id>`.
class CustomSubcategory {
  const CustomSubcategory({
    required this.id,
    required this.parent,
    required this.name,
    required this.icon,
    required this.createdAt,
  });

  final int id;
  final String parent;
  final String name;
  final String icon;
  final int createdAt;
}
