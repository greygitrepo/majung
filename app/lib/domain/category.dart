/// 데이터 상의 시설 분류 (docs/policy/data.md 스키마).
enum FacilityCategory {
  meal,
  shelter,
  foodbank,
  foodmarket,
  shower,
  laundry,
  clinic,
  counseling;

  static FacilityCategory? tryParse(String? value) {
    for (final c in values) {
      if (c.name == value) return c;
    }
    return null;
  }
}

/// 사용자에게 보이는 큰 묶음. 홈 화면 버튼 하나가 묶음 하나다.
enum CategoryGroup {
  meal({FacilityCategory.meal}),
  sleep({FacilityCategory.shelter}),
  wash({FacilityCategory.shower, FacilityCategory.laundry}),
  clinic({FacilityCategory.clinic}),
  groceries({FacilityCategory.foodbank, FacilityCategory.foodmarket});

  const CategoryGroup(this.categories);
  final Set<FacilityCategory> categories;

  /// 1차 출시 범위: 밥 + 잠자리 + 아플 때 (docs/decisions.md #5, #15).
  static const enabled = [CategoryGroup.meal, CategoryGroup.sleep, CategoryGroup.clinic];

  bool contains(FacilityCategory c) => categories.contains(c);
}
