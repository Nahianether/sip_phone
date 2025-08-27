// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AuthResponseModelAdapter extends TypeAdapter<AuthResponseModel> {
  @override
  final int typeId = 1;

  @override
  AuthResponseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuthResponseModel(
      message: fields[0] as String?,
      intUserId: fields[1] as int?,
      intErpUserId: fields[2] as int?,
      intFarmerUserId: fields[3] as int?,
      strLoginId: fields[4] as String?,
      intAccountId: fields[5] as int?,
      intUrlId: fields[6] as int?,
      intBusinessUnitId: fields[7] as int?,
      strBusinessUnit: fields[8] as String?,
      intSupplierId: fields[9] as int?,
      intCustomerId: fields[10] as int?,
      intEmployeeId: fields[11] as int?,
      strDisplayName: fields[12] as String?,
      intProfileImageUrl: fields[13] as int?,
      intLogoUrlId: fields[14] as int?,
      intDefaultDashboardId: fields[15] as int?,
      intDepartmentId: fields[16] as int?,
      strDepartment: fields[17] as String?,
      intDesignationId: fields[18] as int?,
      strDesignation: fields[19] as String?,
      intUserTypeId: fields[20] as int?,
      intUserType: fields[21] as String?,
      intRefferenceId: fields[22] as int?,
      isOfficeAdmin: fields[23] as bool?,
      isSuperuser: fields[24] as bool?,
      isOwner: fields[25] as bool?,
      isSupNLMORManagement: fields[26] as int?,
      dteLastLogin: fields[27] as String?,
      isLoggedIn: fields[28] as bool?,
      token: fields[29] as String?,
      refreshToken: fields[30] as String?,
      isLoggedInWithOtp: fields[31] as bool?,
      strOfficeMail: fields[32] as String?,
      strPersonalMail: fields[33] as String?,
      connectionKEY: fields[34] as String?,
      evaluationCriteriaOfPms: fields[35] as String?,
      workPlaceId: fields[36] as int?,
      workPlaceName: fields[37] as String?,
      businessPartnerClass: fields[38] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AuthResponseModel obj) {
    writer
      ..writeByte(39)
      ..writeByte(0)
      ..write(obj.message)
      ..writeByte(1)
      ..write(obj.intUserId)
      ..writeByte(2)
      ..write(obj.intErpUserId)
      ..writeByte(3)
      ..write(obj.intFarmerUserId)
      ..writeByte(4)
      ..write(obj.strLoginId)
      ..writeByte(5)
      ..write(obj.intAccountId)
      ..writeByte(6)
      ..write(obj.intUrlId)
      ..writeByte(7)
      ..write(obj.intBusinessUnitId)
      ..writeByte(8)
      ..write(obj.strBusinessUnit)
      ..writeByte(9)
      ..write(obj.intSupplierId)
      ..writeByte(10)
      ..write(obj.intCustomerId)
      ..writeByte(11)
      ..write(obj.intEmployeeId)
      ..writeByte(12)
      ..write(obj.strDisplayName)
      ..writeByte(13)
      ..write(obj.intProfileImageUrl)
      ..writeByte(14)
      ..write(obj.intLogoUrlId)
      ..writeByte(15)
      ..write(obj.intDefaultDashboardId)
      ..writeByte(16)
      ..write(obj.intDepartmentId)
      ..writeByte(17)
      ..write(obj.strDepartment)
      ..writeByte(18)
      ..write(obj.intDesignationId)
      ..writeByte(19)
      ..write(obj.strDesignation)
      ..writeByte(20)
      ..write(obj.intUserTypeId)
      ..writeByte(21)
      ..write(obj.intUserType)
      ..writeByte(22)
      ..write(obj.intRefferenceId)
      ..writeByte(23)
      ..write(obj.isOfficeAdmin)
      ..writeByte(24)
      ..write(obj.isSuperuser)
      ..writeByte(25)
      ..write(obj.isOwner)
      ..writeByte(26)
      ..write(obj.isSupNLMORManagement)
      ..writeByte(27)
      ..write(obj.dteLastLogin)
      ..writeByte(28)
      ..write(obj.isLoggedIn)
      ..writeByte(29)
      ..write(obj.token)
      ..writeByte(30)
      ..write(obj.refreshToken)
      ..writeByte(31)
      ..write(obj.isLoggedInWithOtp)
      ..writeByte(32)
      ..write(obj.strOfficeMail)
      ..writeByte(33)
      ..write(obj.strPersonalMail)
      ..writeByte(34)
      ..write(obj.connectionKEY)
      ..writeByte(35)
      ..write(obj.evaluationCriteriaOfPms)
      ..writeByte(36)
      ..write(obj.workPlaceId)
      ..writeByte(37)
      ..write(obj.workPlaceName)
      ..writeByte(38)
      ..write(obj.businessPartnerClass);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthResponseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}