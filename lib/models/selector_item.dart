class SelectorItem {
  final String name;
  final String image;
  final String logo;
  final String redirectionUrl;

  const SelectorItem({
    required this.name,
    required this.image,
    required this.logo,
    required this.redirectionUrl,
  });

  factory SelectorItem.fromMap(Map<String, dynamic> map) {
    return SelectorItem(
      name: map['name'] as String? ?? '',
      image: map['image'] as String? ?? '',
      logo: map['logo'] as String? ?? '',
      redirectionUrl: map['redirection_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image': image,
      'logo': logo,
      'redirection_url': redirectionUrl,
    };
  }
}
