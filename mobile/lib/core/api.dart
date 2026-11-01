import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';
import 'billing_models.dart';
import 'revenue_models.dart';
import 'room_move_models.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.fields = const {}});
  final String message;
  final Map<String, String> fields;
  @override
  String toString() => message;
}

abstract interface class SessionStore {
  Future<String?> readRefresh();
  Future<void> writeRefresh(String token);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<String?> readRefresh() => _storage.read(key: 'aster_refresh');
  @override
  Future<void> writeRefresh(String token) =>
      _storage.write(key: 'aster_refresh', value: token);
  @override
  Future<void> clear() => _storage.delete(key: 'aster_refresh');
}

String defaultApiUrl() {
  const custom = String.fromEnvironment('API_BASE_URL');
  if (custom.isNotEmpty) return custom;
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000/api/v1/'
      : 'http://127.0.0.1:8000/api/v1/';
}

class ApiClient {
  ApiClient({
    required this.store,
    String? baseUrl,
    Dio? transport,
    Dio? refreshTransport,
  }) {
    final options = BaseOptions(
      baseUrl: baseUrl ?? defaultApiUrl(),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    );
    _dio = transport ?? Dio(options);
    _refreshDio = refreshTransport ?? Dio(options);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (_access != null) {
            request.headers['Authorization'] = 'Bearer $_access';
          }
          handler.next(request);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isAuth = request.path.startsWith('auth/');
          if (error.response?.statusCode == 401 &&
              !isAuth &&
              request.extra['retried'] != true) {
            try {
              await refresh();
              request.extra['retried'] = true;
              request.headers['Authorization'] = 'Bearer $_access';
              final roomForm = request.extra['roomForm'];
              if (roomForm is FormData Function()) request.data = roomForm();
              handler.resolve(await _dio.fetch<dynamic>(request));
              return;
            } catch (refreshError) {
              // A network outage must not silently erase a valid stored session.
              if (refreshError is DioException &&
                  refreshError.response == null) {
                handler.next(error);
                return;
              }
              await clearSession();
              onExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final SessionStore store;
  late final Dio _dio, _refreshDio;
  String? _access;
  Future<void>? _refreshing;
  VoidCallback? onExpired;

  Future<void> refresh() async {
    if (_refreshing != null) return _refreshing!;
    final task = _refresh();
    _refreshing = task;
    try {
      await task;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _refresh() async {
    final refreshToken = await store.readRefresh();
    if (refreshToken == null) {
      throw const ApiFailure('Phiên đăng nhập đã kết thúc.');
    }
    final response = await _refreshDio.post<Map<String, dynamic>>(
      'auth/refresh/',
      data: {'refresh': refreshToken},
    );
    final data = response.data!;
    _access = data['access'] as String;
    await store.writeRefresh(data['refresh'] as String);
  }

  Future<StaffUser> login(String username, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/login/',
        data: {'username': username, 'password': password},
      );
      _access = response.data!['access'] as String;
      await store.writeRefresh(response.data!['refresh'] as String);
      return StaffUser.fromJson(response.data!['user'] as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const ApiFailure('Tên đăng nhập hoặc mật khẩu không đúng.');
      }
      throw failureFrom(error);
    }
  }

  Future<StaffUser> me() async => StaffUser.fromJson(await _get('me/'));

  Future<bool> logout() async {
    var revoked = false;
    try {
      final token = await store.readRefresh();
      if (token != null) {
        await _dio.post<dynamic>('auth/logout/', data: {'refresh': token});
        revoked = true;
      }
    } on DioException {
      revoked = false;
    } finally {
      await clearSession();
    }
    return revoked;
  }

  Future<void> clearSession() async {
    _access = null;
    await store.clear();
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    try {
      return (await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      )).data!;
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<DashboardData> dashboard() async =>
      DashboardData.fromJson(await _get('dashboard/'));

  Future<RevenueEstimate> revenueEstimate(RevenueQuery query) async =>
      RevenueEstimate.fromJson(
        await _get('reports/revenue-estimate/', {
          'start_date': query.start,
          'end_date': query.end,
        }),
      );

  Future<PagedResult<HotelRoom>> rooms(RoomQuery query) async {
    final data = await _get('rooms/', {
      'search': query.search,
      if (query.condition.isNotEmpty) 'status': query.condition,
      if (query.floor != null) 'floor': query.floor,
      if (query.roomType != null) 'room_type': query.roomType,
      'page': query.page,
    });
    return PagedResult(
      items: (data['results'] as List)
          .map((item) => HotelRoom.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: data['count'] as int,
      hasNext: data['next'] != null,
    );
  }

  Future<List<RoomType>> roomTypes() async {
    final types = <RoomType>[];
    var page = 1;
    while (true) {
      final data = await _get('room-types/', {'page': page});
      types.addAll(
        (data['results'] as List).map(
          (item) => RoomType.fromJson(item as Map<String, dynamic>),
        ),
      );
      if (data['next'] == null) return types;
      page++;
    }
  }

  Future<PagedResult<Guest>> guests(GuestQuery query) async {
    final data = await _get('customers/', {
      'search': query.search,
      'page': query.page,
    });
    return PagedResult(
      items: (data['results'] as List)
          .map((item) => Guest.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: data['count'] as int,
      hasNext: data['next'] != null,
    );
  }

  Future<void> changeCondition(int id, String condition) async =>
      _post('rooms/$id/condition/', {'condition': condition});

  Future<Guest> guest(int id) async =>
      Guest.fromJson(await _get('customers/$id/'));

  Future<PagedResult<HotelBooking>> lookupBookings(BookingLookup query) async {
    final data = await _get('bookings/', {
      'page': query.page,
      'ordering': query.kind == null ? '-created_at' : 'start_date',
      if (query.roomId != null) 'room': query.roomId,
      if (query.customerId != null) 'customer': query.customerId,
      if (query.kind == 'arrivals') ...{
        'status': 'confirmed',
        'arrival_on': query.day,
      },
      if (query.kind == 'departures') ...{
        'status': 'checked_in',
        'departure_on': query.day,
      },
      if (query.kind == 'guests') 'status': 'checked_in',
    });
    return PagedResult(
      items: (data['results'] as List)
          .map((item) => HotelBooking.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: data['count'] as int,
      hasNext: data['next'] != null,
    );
  }

  Future<PagedResult<HotelBooking>> bookings(BookingQuery query) async {
    final data = await _get('bookings/', {
      'search': query.search,
      if (query.status.isNotEmpty) 'status': query.status,
      'page': query.page,
    });
    return PagedResult(
      items: (data['results'] as List)
          .map((item) => HotelBooking.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: data['count'] as int,
      hasNext: data['next'] != null,
    );
  }

  Future<PagedResult<HotelRoom>> availability(AvailabilityQuery query) async {
    final items = <HotelRoom>[];
    var page = 1;
    while (true) {
      final data = await _get('rooms/availability/', {
        'start_date': query.start,
        'end_date': query.end,
        'guests': query.guests,
        'page': page,
        if (query.exclude != null) 'exclude_booking': query.exclude,
      });
      items.addAll(
        (data['results'] as List).map(
          (item) => HotelRoom.fromJson(item as Map<String, dynamic>),
        ),
      );

      if (data['next'] == null) break;
      page++;
    }
    return PagedResult(items: items, count: items.length, hasNext: false);
  }

  Future<HotelRoom> getRoom(int id) async =>
      HotelRoom.fromJson(await _get('rooms/$id/'));

  Future<RoomMoveOptions> roomMoveOptions(int bookingId) async =>
      RoomMoveOptions.fromJson(
        await _get('bookings/$bookingId/transfer-options/'),
      );

  Future<RoomMoveQuote> roomMoveQuote(
    int bookingId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$bookingId/transfer-quote/',
        data: data,
      );
      return RoomMoveQuote.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<HotelBooking> moveRoom(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$bookingId/transfer/',
        data: data,
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return HotelBooking.fromJson(
        response.data!['booking'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<HotelBooking> createBooking(
    Map<String, dynamic> data,
    String key,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/',
        data: data,
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return HotelBooking.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<HotelBooking> bookingAction(
    int id,
    String action, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$id/$action/',
        data: data ?? {},
      );
      return HotelBooking.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  String roomImageUrl(String url) =>
      Uri.parse(_dio.options.baseUrl).resolve(url).toString();

  Future<HotelBooking> getBooking(int id) async {
    final data = await _get('bookings/$id/', {});
    return HotelBooking.fromJson(data);
  }

  Future<TimelineData> roomTimeline({
    String? startDate,
    int days = 7,
    int? floor,
  }) async {
    final query = <String, dynamic>{'days': days};
    if (startDate != null) query['start_date'] = startDate;
    if (floor != null && floor > 0) query['floor'] = floor;
    final data = await _get('rooms/timeline/', query);
    return TimelineData.fromJson(data);
  }

  Future<HotelRoom> saveRoom(
    Map<String, dynamic> room, {
    int? id,
    List<Uint8List> images = const [],
  }) async {
    try {
      final path = id == null ? 'rooms/' : 'rooms/$id/';
      // Build fresh FormData for every attempt, including a token-refresh retry.
      FormData form() => FormData.fromMap({
        'data': jsonEncode(room),
        'upload_images': [
          for (var i = 0; i < images.length; i++)
            MultipartFile.fromBytes(images[i], filename: 'room-$i.jpg'),
        ],
      });
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: images.isEmpty ? room : form(),
        options: Options(
          method: id == null ? 'POST' : 'PATCH',
          contentType: images.isEmpty
              ? Headers.jsonContentType
              : Headers.multipartFormDataContentType,
          extra: images.isEmpty ? null : {'roomForm': form},
        ),
      );
      return HotelRoom.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<PagedResult<HotelService>> services(ServiceQuery query) async {
    final data = await _get('services/', {
      'search': query.search,
      'page': query.page,
      if (query.active != null) 'active': query.active.toString(),
    });
    return PagedResult(
      items: (data['results'] as List)
          .map((item) => HotelService.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: data['count'] as int,
      hasNext: data['next'] != null,
    );
  }

  Future<List<ServiceUnit>> serviceUnits() async {
    final data = await _get('service-units/');
    return (data['units'] as List)
        .map((item) => ServiceUnit.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<HotelService> saveService(
    Map<String, dynamic> data, {
    int? id,
    Uint8List? image,
  }) async {
    try {
      FormData form() => FormData.fromMap({
        ...data,
        'image': MultipartFile.fromBytes(image!, filename: 'service.jpg'),
      });
      final response = await _dio.request<Map<String, dynamic>>(
        id == null ? 'services/' : 'services/$id/',
        data: image == null ? data : form(),
        options: Options(
          method: id == null ? 'POST' : 'PATCH',
          contentType: image == null
              ? Headers.jsonContentType
              : Headers.multipartFormDataContentType,
          extra: image == null ? null : {'roomForm': form},
        ),
      );
      return HotelService.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<void> deleteService(int id) async {
    try {
      await _dio.delete<dynamic>('services/$id/');
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<HotelService> getService(int id) async =>
      HotelService.fromJson(await _get('services/$id/'));

  Future<ServiceUsage> addPlannedService(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$bookingId/planned-services/',
        data: data,
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return ServiceUsage.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<ServiceUsage> cancelPlannedService(
    int bookingId,
    int planId,
    String reason,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$bookingId/planned-services/$planId/cancel/',
        data: {'reason': reason},
      );
      return ServiceUsage.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<BillingState> folio(int bookingId) async =>
      BillingState.fromJson(await _get('bookings/$bookingId/folio/'));

  Future<CheckoutResult> checkout(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$bookingId/check-out/',
        data: data,
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return CheckoutResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<HotelRoom> confirmCleaned(int roomId, DateTime version) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'rooms/$roomId/confirm-cleaned/',
        data: {'expected_updated_at': version.toUtc().toIso8601String()},
      );
      return HotelRoom.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<PagedResult<HotelInvoice>> invoices(InvoiceQuery query) async {
    final data = await _get('invoices/', {
      'search': query.search,
      if (query.method.isNotEmpty) 'method': query.method,
      'page': query.page,
    });
    return PagedResult(
      items: (data['results'] as List)
          .map((row) => HotelInvoice.fromJson(row as Map<String, dynamic>))
          .toList(),
      count: data['count'] as int,
      hasNext: data['next'] != null,
    );
  }

  Future<StayServices> stayServices(StayServiceQuery query) async =>
      StayServices.fromJson(
        await _get('bookings/${query.bookingId}/services/', {
          'page': query.page,
        }),
      );

  Future<ServiceUsage> addServiceUsage(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$bookingId/services/',
        data: data,
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return ServiceUsage.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<ServiceUsage> cancelServiceUsage(
    int bookingId,
    int usageId,
    String reason,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'bookings/$bookingId/services/$usageId/cancel/',
        data: {'reason': reason},
      );
      return ServiceUsage.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<Guest> saveGuest(Map<String, dynamic> guest, {int? id}) async {
    try {
      final response = id == null
          ? await _dio.post<Map<String, dynamic>>('customers/', data: guest)
          : await _dio.patch<Map<String, dynamic>>(
              'customers/$id/',
              data: guest,
            );
      return Guest.fromJson(response.data!);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  Future<void> _post(String path, Map<String, dynamic> data) async {
    try {
      await _dio.post<dynamic>(path, data: data);
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }

  static ApiFailure failureFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final detail = data['error'] as Map;
      final fields = detail['fields'];
      if (fields is Map && fields.isNotEmpty) {
        final first = fields.values.first;
        return ApiFailure(
          first is List ? first.join(' ') : first.toString(),
          fields: {
            for (final entry in fields.entries)
              entry.key.toString(): entry.value is List
                  ? (entry.value as List).join(' ')
                  : entry.value.toString(),
          },
        );
      }
      return ApiFailure(
        detail['message']?.toString() ?? 'Không thể xử lý yêu cầu.',
      );
    }
    if (error.response == null) {
      return const ApiFailure(
        'Không kết nối được máy chủ. Kiểm tra kết nối rồi thử lại.',
      );
    }
    return const ApiFailure('Không thể xử lý yêu cầu. Vui lòng thử lại.');
  }
}
