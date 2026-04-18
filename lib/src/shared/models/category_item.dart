class CategoryItem {
  final String id;           // slug stored in DB e.g. 'design'
  final String displayName;  // human label e.g. 'Design'
  final int sortOrder;

  const CategoryItem({
    required this.id,
    required this.displayName,
    this.sortOrder = 0,
  });

  factory CategoryItem.fromMap(Map<String, dynamic> map) => CategoryItem(
        id: map['id'] as String,
        displayName: map['display_name'] as String,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}
