class Company {
  final String id;
  final String name;
  final String logo;
  final String backgroundAttImage;
  final String slug;
  final String title;
  final String subtitle;
  final String primaryColor;
  final String secondaryColor;
  final String buttonColor;
  final String planId;
  final int planConsumption;
  final int plansTotal;
  final bool isInative;
  final String terms;
  final int termsVersion;
  final bool requireUserLogin;

  const Company({
    required this.id,
    required this.name,
    required this.logo,
    required this.backgroundAttImage,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.buttonColor,
    required this.planId,
    required this.planConsumption,
    required this.plansTotal,
    required this.isInative,
    required this.terms,
    required this.termsVersion,
    required this.requireUserLogin,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      backgroundAttImage: json['backgroundAttImage']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      primaryColor: json['primaryColor']?.toString() ?? '#000000',
      secondaryColor: json['secondaryColor']?.toString() ?? '#FFFFFF',
      buttonColor: json['buttonColor']?.toString() ?? '#000000',
      planId: json['planId']?.toString() ?? '',
      planConsumption: _int(json['planConsumption']),
      plansTotal: _int(json['plansTotal']),
      isInative: json['isInative'] == true,
      terms: json['terms']?.toString() ?? '',
      termsVersion: _int(json['termsVersion']),
      requireUserLogin: json['requireUserLogin'] == true,
    );
  }
}

class CompanyPlanOption {
  final String id;
  final String name;

  const CompanyPlanOption({
    required this.id,
    required this.name,
  });
}

int _int(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
