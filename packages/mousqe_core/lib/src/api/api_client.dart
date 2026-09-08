import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'api_exception.dart';
import 'token_store.dart';

part 'api_client.g.dart';

/// يحقن التوكن من [TokenStore] في كل طلب، ويترجم استجابات الخطأ إلى
/// [ApiException] مصنَّفة — [API.md §5](../../../../docs/API.md).
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenStore);

  final TokenStore _tokenStore;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response == null) {
      handler.next(err);
      return;
    }

    final body = response.data;
    final message = body is Map ? body['message'] as String? : null;

    switch (response.statusCode) {
      case 401:
        handler.next(_wrap(err, UnauthenticatedException(message ?? 'Unauthenticated.')));
      case 403:
        final locked = message?.contains('مقفل') ?? false;
        handler.next(_wrap(
          err,
          locked ? AccountLockedException(message!) : ForbiddenException(message ?? 'Forbidden'),
        ));
      case 404:
        handler.next(_wrap(err, ForbiddenException(message ?? 'Not found')));
      case 422:
        final rawErrors = body is Map ? body['errors'] as Map<String, dynamic>? : null;
        final errors = <String, List<String>>{
          if (rawErrors != null)
            for (final entry in rawErrors.entries) entry.key: List<String>.from(entry.value as List),
        };
        handler.next(_wrap(err, ValidationException(message ?? 'Validation failed', errors)));
      default:
        handler.next(_wrap(err, UnknownApiException(message ?? err.message ?? 'Unknown error')));
    }
  }

  DioException _wrap(DioException original, ApiException exception) {
    return original.copyWith(error: exception);
  }
}

/// عميل REST على `/api/v1` — نقاط 5.2 الكافية لنطاق تطبيق الأستاذ في 5.3،
/// وسطحُ إدارة الديسكتوب مضافاً في م.6.2
/// ([mousqe_core plan §2.3](../../../../.claude/plans/reactive-sauteeing-island.md)).
@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  factory ApiClient.create({
    required TokenStore tokenStore,
    required String baseUrl,
    Dio? dio,
  }) {
    final client = dio ?? Dio();
    client.options.baseUrl = baseUrl;
    client.interceptors.add(_AuthInterceptor(tokenStore));
    return ApiClient(client, baseUrl: baseUrl);
  }

  @POST('/auth/login')
  Future<HttpResponse<dynamic>> login(@Body() Map<String, dynamic> body);

  @POST('/auth/logout')
  Future<HttpResponse<dynamic>> logout();

  @GET('/auth/me')
  Future<HttpResponse<dynamic>> me();

  @POST('/devices/register')
  Future<HttpResponse<dynamic>> registerDevice(@Body() Map<String, dynamic> body);

  @GET('/bootstrap')
  Future<HttpResponse<dynamic>> bootstrap();

  @GET('/sync/pull')
  Future<HttpResponse<dynamic>> syncPull(
    @Query('since') int since,
    @Query('app') String app,
    @Query('device_uuid') String? deviceUuid,
  );

  @POST('/sync/push')
  Future<HttpResponse<dynamic>> syncPush(@Body() Map<String, dynamic> body);

  @GET('/institutes')
  Future<HttpResponse<dynamic>> institutes();

  @GET('/sync/conflicts')
  Future<HttpResponse<dynamic>> syncConflicts(@Query('status') String status);

  @POST('/sync/conflicts/{uuid}/resolve')
  Future<HttpResponse<dynamic>> resolveSyncConflict(
    @Path('uuid') String uuid,
    @Body() Map<String, dynamic> body,
  );

  // ── سطحُ الإدارة ✅ م.6.2 — [API.md §3.10] ───────────────────────────────────
  // كلُّها REST مباشر لا أنواعَ عملياتٍ في الطابور: حسابٌ ودورٌ وكلمةُ مرور، وبنيةُ
  // دورةٍ تُهيَّأ مرّةً في الفصل — كتاباتٌ متّصلةٌ بطبعها ([PHASE-6-STAGES.MD §3.1]).
  // وما يُكتب في المسجد بلا شبكة (تسجيلُ طالب، والتسجيلُ في حلقة، والنقل، ومراجعةُ
  // الأعذار) يمرّ بـ[SyncEngine.enqueue] لا هنا.

  @PUT('/admin/institute')
  Future<HttpResponse<dynamic>> updateInstitute(@Body() Map<String, dynamic> body);

  @POST('/admin/institutes')
  Future<HttpResponse<dynamic>> createInstitute(@Body() Map<String, dynamic> body);

  @PUT('/admin/institutes/{uuid}')
  Future<HttpResponse<dynamic>> updateInstituteByUuid(
    @Path('uuid') String uuid,
    @Body() Map<String, dynamic> body,
  );

  @GET('/admin/roles')
  Future<HttpResponse<dynamic>> adminRoles();

  @GET('/admin/users')
  Future<HttpResponse<dynamic>> adminUsers(
    @Query('q') String? search,
    @Query('role') String? role,
    @Query('scope') String? scope,
  );

  @POST('/admin/users')
  Future<HttpResponse<dynamic>> inviteUser(@Body() Map<String, dynamic> body);

  @POST('/admin/users/{id}/roles')
  Future<HttpResponse<dynamic>> assignUserRole(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/admin/users/{id}/roles')
  Future<HttpResponse<dynamic>> revokeUserRole(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @POST('/admin/users/{id}/password')
  Future<HttpResponse<dynamic>> resetUserPassword(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @POST('/admin/users/{id}/activation')
  Future<HttpResponse<dynamic>> setUserActivation(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @GET('/admin/credentials')
  Future<HttpResponse<dynamic>> adminCredentials(
    @Query('role') String? role,
    @Query('q') String? search,
  );

  @POST('/admin/courses')
  Future<HttpResponse<dynamic>> createCourse(@Body() Map<String, dynamic> body);

  @PUT('/admin/courses/{uuid}')
  Future<HttpResponse<dynamic>> updateCourse(
    @Path('uuid') String uuid,
    @Body() Map<String, dynamic> body,
  );

  @POST('/admin/courses/{uuid}/activate')
  Future<HttpResponse<dynamic>> activateCourse(@Path('uuid') String uuid);

  @POST('/admin/shifts')
  Future<HttpResponse<dynamic>> createShift(@Body() Map<String, dynamic> body);

  @PUT('/admin/shifts/{uuid}')
  Future<HttpResponse<dynamic>> updateShift(
    @Path('uuid') String uuid,
    @Body() Map<String, dynamic> body,
  );

  @POST('/admin/circles')
  Future<HttpResponse<dynamic>> createCircle(@Body() Map<String, dynamic> body);

  @PUT('/admin/circles/{uuid}')
  Future<HttpResponse<dynamic>> updateCircle(
    @Path('uuid') String uuid,
    @Body() Map<String, dynamic> body,
  );

  @POST('/admin/circles/{uuid}/run')
  Future<HttpResponse<dynamic>> runCircleInCourse(
    @Path('uuid') String uuid,
    @Body() Map<String, dynamic> body,
  );

  @GET('/teacher/circles')
  Future<HttpResponse<dynamic>> teacherCircles();

  @GET('/teacher/sessions/{date}')
  Future<HttpResponse<dynamic>> teacherSession(
    @Path('date') String date,
    @Query('course_circle_uuid') String courseCircleUuid,
  );
}
