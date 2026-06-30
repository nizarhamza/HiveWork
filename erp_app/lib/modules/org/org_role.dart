/// Mirrors the Supabase `org_role` enum: owner / admin / manager / technical / guest.
enum OrgRole {
  owner,
  admin,
  manager,
  technical,
  guest;

  bool get canManageMembers => this == OrgRole.owner || this == OrgRole.admin;
  bool get canEdit => this != OrgRole.guest;

  String get label => switch (this) {
        OrgRole.owner     => 'Owner',
        OrgRole.admin     => 'Admin',
        OrgRole.manager   => 'Manager',
        OrgRole.technical => 'Technical',
        OrgRole.guest     => 'Guest',
      };

  static OrgRole fromString(String value) => OrgRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => OrgRole.guest,
      );
}

/// Lightweight membership record returned by [OrgRepository.fetchUserOrgs].
class OrgMembership {
  const OrgMembership({
    required this.orgId,
    required this.orgName,
    required this.role,
    this.orgLogoUrl,
  });

  final String  orgId;
  final String  orgName;
  final OrgRole role;
  final String? orgLogoUrl;

  factory OrgMembership.fromJson(Map<String, dynamic> json) {
    final org = json['organizations'] as Map<String, dynamic>?;
    return OrgMembership(
      orgId:      json['org_id']   as String,
      orgName:    org?['name']     as String? ?? '',
      role:       OrgRole.fromString(json['org_role'] as String),
      orgLogoUrl: org?['logo_url'] as String?,
    );
  }
}
