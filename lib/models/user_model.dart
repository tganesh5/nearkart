enum UserRole {
  customer,
  storeManager,
  admin,
  deliveryPartner;

  static UserRole fromStoredValue(Object? value) {
    return switch (value) {
      'storeManager' || 'vendor' => UserRole.storeManager,
      'admin' => UserRole.admin,
      'deliveryPartner' => UserRole.deliveryPartner,
      _ => UserRole.customer,
    };
  }

  String get label => switch (this) {
    UserRole.customer => 'Customer',
    UserRole.storeManager => 'Store Manager',
    UserRole.admin => 'Admin',
    UserRole.deliveryPartner => 'Delivery Partner',
  };
}

enum AccountStatus {
  active,
  pending,
  rejected,

  /// Access withdrawn from an account that was previously approved. Kept
  /// separate from [rejected] so the person is told the truth about why.
  suspended;

  static AccountStatus fromStoredValue(Object? value) {
    return switch (value) {
      'pending' => AccountStatus.pending,
      'rejected' => AccountStatus.rejected,
      'suspended' => AccountStatus.suspended,
      _ => AccountStatus.active,
    };
  }

  String get label => switch (this) {
    AccountStatus.active => 'Active',
    AccountStatus.pending => 'Pending approval',
    AccountStatus.rejected => 'Rejected',
    AccountStatus.suspended => 'Deactivated',
  };
}

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final UserRole role;
  final AccountStatus status;
  final String? profileImage;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.status = AccountStatus.active,
    this.profileImage,
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    AccountStatus? status,
    String? profileImage,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
