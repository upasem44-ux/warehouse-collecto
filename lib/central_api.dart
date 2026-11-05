import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class CentralApi {
  CentralApi._();
  static final CentralApi instance = CentralApi._();
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'central_api_url';
  static const _tokenKey = 'central_api_token';
  static const _usernameKey = 'central_api_username';
  static const _timeout = Duration(seconds: 15);
  String? _baseUrl, _token, _username;
  String? get baseUrl => _baseUrl;
  String? get username => _username;
  bool get configured => _baseUrl != null && _baseUrl!.isNotEmpty;
  bool get authenticated => _token != null && _token!.isNotEmpty;
  Future<void> initialize() async { _baseUrl=await _storage.read(key:_urlKey); _token=await _storage.read(key:_tokenKey); _username=await _storage.read(key:_usernameKey); }
  bool _privateHost(String host) {
    if(host=='localhost'||host=='127.0.0.1') return true;
    final p=host.split('.'); if(p.length!=4) return false;
    final n=p.map(int.tryParse).toList(); if(n.any((x)=>x==null||x<0||x>255)) return false;
    final a=n[0]!, b=n[1]!;
    return a==10 || (a==192&&b==168) || (a==172&&b>=16&&b<=31) || (a==169&&b==254);
  }
  Future<void> configure(String url) async {
    final value=url.trim().replaceFirst(RegExp(r'/+$'), ''); final uri=Uri.tryParse(value);
    if(uri==null||!uri.hasAuthority||(uri.scheme!='https'&&uri.scheme!='http')) throw Exception('أدخل عنوان خادم صحيحاً');
    if(uri.scheme=='http'&&!_privateHost(uri.host)) throw Exception('الاتصال خارج شبكة المحل يجب أن يستخدم HTTPS');
    _baseUrl=value; _token=null; _username=null;
    await _storage.write(key:_urlKey,value:value); await _storage.delete(key:_tokenKey); await _storage.delete(key:_usernameKey);
  }
  Uri _uri(String path) { if(!configured) throw Exception('لم يتم إعداد الخادم المركزي'); return Uri.parse('$_baseUrl$path'); }
  Map<String,String> _headers({bool auth=false})=>{'Content-Type':'application/json','Accept':'application/json',if(auth&&authenticated)'Authorization':'Bearer $_token'};
  dynamic _decode(http.Response r) {
    final body=r.body.isEmpty?null:jsonDecode(r.body);
    if(r.statusCode>=200&&r.statusCode<300)return body;
    if(r.statusCode==401)throw Exception('بيانات الدخول غير صحيحة أو انتهت الجلسة');
    if(r.statusCode==403)throw Exception('ليس لديك صلاحية');
    if(r.statusCode==409)throw Exception('تعارض بيانات: ' + (body is Map ? (body['message']?.toString()??'السجل موجود مسبقاً') : 'السجل موجود مسبقاً'));
    throw Exception('الخادم رفض الطلب (${r.statusCode})');
  }
  Future<void> health() async { _decode(await http.get(_uri('/health')).timeout(_timeout)); }
  Future<void> bootstrap({required String bootstrapKey,required String username,required String displayName,required String distributorCode,required String password}) async {
    final r=await http.post(_uri('/api/auth/bootstrap'),headers:_headers(),body:jsonEncode({'bootstrapKey':bootstrapKey,'username':username.trim(),'displayName':displayName.trim(),'distributorCode':distributorCode.trim(),'password':password})).timeout(_timeout); _decode(r);
  }
  Future<Map<String,dynamic>> login(String username,String password) async {
    final r=await http.post(_uri('/api/auth/login'),headers:_headers(),body:jsonEncode({'username':username.trim(),'password':password})).timeout(_timeout);
    final d=_decode(r) as Map<String,dynamic>; _token=d['accessToken'] as String?; _username=d['username'] as String?;
    if(_token==null||_token!.isEmpty)throw Exception('استجابة تسجيل الدخول غير مكتملة');
    await _storage.write(key:_tokenKey,value:_token); await _storage.write(key:_usernameKey,value:_username); return d;
  }
  Future<void> logout() async { _token=null;_username=null;await _storage.delete(key:_tokenKey);await _storage.delete(key:_usernameKey); }
  Future<List<Map<String,dynamic>>> users() async { final r=await http.get(_uri('/api/admin/users'),headers:_headers(auth:true)).timeout(_timeout);return (_decode(r) as List).cast<Map<String,dynamic>>(); }
  Future<void> createUser({required String username,required String displayName,required String distributorCode,required String password,String role='distributor'}) async { final r=await http.post(_uri('/api/admin/users'),headers:_headers(auth:true),body:jsonEncode({'username':username,'displayName':displayName,'distributorCode':distributorCode,'password':password,'role':role})).timeout(_timeout);_decode(r); }
  Future<void> setUserActive(int id,bool active) async { final r=await http.patch(_uri('/api/admin/users/$id/active'),headers:_headers(auth:true),body:jsonEncode({'isActive':active})).timeout(_timeout);_decode(r); }
  Future<void> resetUserPassword(int id,String password) async { final r=await http.post(_uri('/api/admin/users/$id/reset-password'),headers:_headers(auth:true),body:jsonEncode({'newPassword':password})).timeout(_timeout);_decode(r); }
  Future<List<Map<String,dynamic>>> customers() async { final r=await http.get(_uri('/api/customers'),headers:_headers(auth:true)).timeout(_timeout);return (_decode(r) as List).cast<Map<String,dynamic>>(); }
  Future<List<String>> syncReceipts(List<Map<String,dynamic>> receipts) async { final r=await http.post(_uri('/api/sync/receipts'),headers:_headers(auth:true),body:jsonEncode({'receipts':receipts})).timeout(_timeout);final d=_decode(r) as Map<String,dynamic>;return (d['acceptedOperationIds'] as List).cast<String>(); }
}