/// The owner's single, permanent "family gallery" link.
///
/// One per owner. Sharing [token] lets everyone (grandma, auntie…) open the
/// same link and browse every photo — no login. [active] is the revoke switch:
/// flip it off to disable the link, on to re-enable. [babyName] and [birthdate]
/// feed the gallery header and per-photo age labels.
class FamilyGallery {
  final String token;
  final String babyName;
  final DateTime? birthdate;
  final bool active;

  const FamilyGallery({
    required this.token,
    this.babyName = '',
    this.birthdate,
    this.active = true,
  });

  FamilyGallery copyWith({
    String? babyName,
    DateTime? birthdate,
    bool? active,
    bool clearBirthdate = false,
  }) =>
      FamilyGallery(
        token: token,
        babyName: babyName ?? this.babyName,
        birthdate: clearBirthdate ? null : (birthdate ?? this.birthdate),
        active: active ?? this.active,
      );
}
