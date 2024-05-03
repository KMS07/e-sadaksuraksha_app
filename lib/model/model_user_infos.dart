import 'dart:convert';

class ModelUserInfo {
  ModelUserInfo({
    this.userEmail,
    this.userId,
    this.user_type,
    this.userName,
    this.latitude,
    this.longitude,
    this.sign_in,
  });

  ModelUserInfo.fromJson(dynamic json) {
    userEmail = json['user_email'];
    userId = json['user_id'];
    user_type = json['user_type'];
    userName = json['user_name'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    sign_in = json['Sign_in'];
  }
  String? userEmail;
  String? userId;
  String? user_type;
  String? userName;
  num? latitude;
  num? longitude;
  String? sign_in;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['user_email'] = userEmail;
    map['user_id'] = userId;
    map['user_type'] = user_type;
    map['user_name'] = userName;
    map['latitude'] = latitude;
    map['longitude'] = longitude;
    map['sign_in'] = sign_in;
    return map;
  }
}
