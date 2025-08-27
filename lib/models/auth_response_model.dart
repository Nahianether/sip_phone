import 'package:hive/hive.dart';

part 'auth_response_model.g.dart';

@HiveType(typeId: 1)
class AuthResponseModel {
  @HiveField(0)
  final String? message;

  @HiveField(1)
  final int? intUserId;

  @HiveField(2)
  final int? intErpUserId;

  @HiveField(3)
  final int? intFarmerUserId;

  @HiveField(4)
  final String? strLoginId;

  @HiveField(5)
  final int? intAccountId;

  @HiveField(6)
  final int? intUrlId;

  @HiveField(7)
  final int? intBusinessUnitId;

  @HiveField(8)
  final String? strBusinessUnit;

  @HiveField(9)
  final int? intSupplierId;

  @HiveField(10)
  final int? intCustomerId;

  @HiveField(11)
  final int? intEmployeeId;

  @HiveField(12)
  final String? strDisplayName;

  @HiveField(13)
  final int? intProfileImageUrl;

  @HiveField(14)
  final int? intLogoUrlId;

  @HiveField(15)
  final int? intDefaultDashboardId;

  @HiveField(16)
  final int? intDepartmentId;

  @HiveField(17)
  final String? strDepartment;

  @HiveField(18)
  final int? intDesignationId;

  @HiveField(19)
  final String? strDesignation;

  @HiveField(20)
  final int? intUserTypeId;

  @HiveField(21)
  final String? intUserType;

  @HiveField(22)
  final int? intRefferenceId;

  @HiveField(23)
  final bool? isOfficeAdmin;

  @HiveField(24)
  final bool? isSuperuser;

  @HiveField(25)
  final bool? isOwner;

  @HiveField(26)
  final int? isSupNLMORManagement;

  @HiveField(27)
  final String? dteLastLogin;

  @HiveField(28)
  final bool? isLoggedIn;

  @HiveField(29)
  final String? token;

  @HiveField(30)
  final String? refreshToken;

  @HiveField(31)
  final bool? isLoggedInWithOtp;

  @HiveField(32)
  final String? strOfficeMail;

  @HiveField(33)
  final String? strPersonalMail;

  @HiveField(34)
  final String? connectionKEY;

  @HiveField(35)
  final String? evaluationCriteriaOfPms;

  @HiveField(36)
  final int? workPlaceId;

  @HiveField(37)
  final String? workPlaceName;

  @HiveField(38)
  final String? businessPartnerClass;

  AuthResponseModel({
    this.message,
    this.intUserId,
    this.intErpUserId,
    this.intFarmerUserId,
    this.strLoginId,
    this.intAccountId,
    this.intUrlId,
    this.intBusinessUnitId,
    this.strBusinessUnit,
    this.intSupplierId,
    this.intCustomerId,
    this.intEmployeeId,
    this.strDisplayName,
    this.intProfileImageUrl,
    this.intLogoUrlId,
    this.intDefaultDashboardId,
    this.intDepartmentId,
    this.strDepartment,
    this.intDesignationId,
    this.strDesignation,
    this.intUserTypeId,
    this.intUserType,
    this.intRefferenceId,
    this.isOfficeAdmin,
    this.isSuperuser,
    this.isOwner,
    this.isSupNLMORManagement,
    this.dteLastLogin,
    this.isLoggedIn,
    this.token,
    this.refreshToken,
    this.isLoggedInWithOtp,
    this.strOfficeMail,
    this.strPersonalMail,
    this.connectionKEY,
    this.evaluationCriteriaOfPms,
    this.workPlaceId,
    this.workPlaceName,
    this.businessPartnerClass,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      message: json['message'] as String?,
      intUserId: json['intUserId'] as int?,
      intErpUserId: json['intErpUserId'] as int?,
      intFarmerUserId: json['intFarmerUserId'] as int?,
      strLoginId: json['strLoginId'] as String?,
      intAccountId: json['intAccountId'] as int?,
      intUrlId: json['intUrlId'] as int?,
      intBusinessUnitId: json['intBusinessUnitId'] as int?,
      strBusinessUnit: json['strBusinessUnit'] as String?,
      intSupplierId: json['intSupplierId'] as int?,
      intCustomerId: json['intCustomerId'] as int?,
      intEmployeeId: json['intEmployeeId'] as int?,
      strDisplayName: json['strDisplayName'] as String?,
      intProfileImageUrl: json['intProfileImageUrl'] as int?,
      intLogoUrlId: json['intLogoUrlId'] as int?,
      intDefaultDashboardId: json['intDefaultDashboardId'] as int?,
      intDepartmentId: json['intDepartmentId'] as int?,
      strDepartment: json['strDepartment'] as String?,
      intDesignationId: json['intDesignationId'] as int?,
      strDesignation: json['strDesignation'] as String?,
      intUserTypeId: json['intUserTypeId'] as int?,
      intUserType: json['intUserType'] as String?,
      intRefferenceId: json['intRefferenceId'] as int?,
      isOfficeAdmin: json['isOfficeAdmin'] as bool?,
      isSuperuser: json['isSuperuser'] as bool?,
      isOwner: json['isOwner'] as bool?,
      isSupNLMORManagement: json['isSupNLMORManagement'] as int?,
      dteLastLogin: json['dteLastLogin'] as String?,
      isLoggedIn: json['isLoggedIn'] as bool?,
      token: json['token'] as String?,
      refreshToken: json['refreshToken'] as String?,
      isLoggedInWithOtp: json['isLoggedInWithOtp'] as bool?,
      strOfficeMail: json['strOfficeMail'] as String?,
      strPersonalMail: json['strPersonalMail'] as String?,
      connectionKEY: json['connectionKEY'] as String?,
      evaluationCriteriaOfPms: json['evaluationCriteriaOfPms'] as String?,
      workPlaceId: json['workPlaceId'] as int?,
      workPlaceName: json['workPlaceName'] as String?,
      businessPartnerClass: json['businessPartnerClass'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'intUserId': intUserId,
      'intErpUserId': intErpUserId,
      'intFarmerUserId': intFarmerUserId,
      'strLoginId': strLoginId,
      'intAccountId': intAccountId,
      'intUrlId': intUrlId,
      'intBusinessUnitId': intBusinessUnitId,
      'strBusinessUnit': strBusinessUnit,
      'intSupplierId': intSupplierId,
      'intCustomerId': intCustomerId,
      'intEmployeeId': intEmployeeId,
      'strDisplayName': strDisplayName,
      'intProfileImageUrl': intProfileImageUrl,
      'intLogoUrlId': intLogoUrlId,
      'intDefaultDashboardId': intDefaultDashboardId,
      'intDepartmentId': intDepartmentId,
      'strDepartment': strDepartment,
      'intDesignationId': intDesignationId,
      'strDesignation': strDesignation,
      'intUserTypeId': intUserTypeId,
      'intUserType': intUserType,
      'intRefferenceId': intRefferenceId,
      'isOfficeAdmin': isOfficeAdmin,
      'isSuperuser': isSuperuser,
      'isOwner': isOwner,
      'isSupNLMORManagement': isSupNLMORManagement,
      'dteLastLogin': dteLastLogin,
      'isLoggedIn': isLoggedIn,
      'token': token,
      'refreshToken': refreshToken,
      'isLoggedInWithOtp': isLoggedInWithOtp,
      'strOfficeMail': strOfficeMail,
      'strPersonalMail': strPersonalMail,
      'connectionKEY': connectionKEY,
      'evaluationCriteriaOfPms': evaluationCriteriaOfPms,
      'workPlaceId': workPlaceId,
      'workPlaceName': workPlaceName,
      'businessPartnerClass': businessPartnerClass,
    };
  }

  @override
  String toString() {
    return 'AuthResponseModel(userId: $intUserId, loginId: $strLoginId, displayName: $strDisplayName, isLoggedIn: $isLoggedIn)';
  }

  // Convenience getters for commonly used fields
  String get displayName => strDisplayName?.trim() ?? 'Unknown User';
  String get department => strDepartment ?? 'Unknown Department';
  String get designation => strDesignation ?? 'Unknown Designation';
  String get businessUnit => strBusinessUnit ?? 'Unknown Business Unit';
  String get workPlace => workPlaceName ?? 'Unknown Workplace';
  String get loginId => strLoginId ?? '';
  String get userToken => token ?? '';
  bool get isUserLoggedIn => isLoggedIn ?? false;
}