import 'dart:convert';
import 'dart:typed_data';

import 'package:aster_hotel/core/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Map<String, dynamic> data, int status) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  test('Room upload retries with fresh multipart after refresh and resolves media against API host', () async {
    final transport = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000/api/v1/'));
    final refreshTransport = Dio(
      BaseOptions(baseUrl: 'http://10.0.2.2:8000/api/v1/'),
    );
    final forms = <FormData>[];
    transport.httpClientAdapter = StubAdapter((request) async {
      expect(request.method, 'PATCH');
      expect(request.path, 'rooms/1/');
      final form = request.data as FormData;
      forms.add(form);
      expect(
        jsonDecode(form.fields.single.value)['description'],
        'Phòng có ban công',
      );
      expect(form.files.single.key, 'upload_images');
      expect(form.files.single.value.length, 3);
      if (forms.length == 1) return jsonBody({}, 401);
      expect(request.headers['Authorization'], 'Bearer new-access');
      return jsonBody({
        'id': 1,
        'number': '101',
        'floor': 1,
        'condition': 'ready',
        'notes': '',
        'description': 'Phòng có ban công',
        'area': '32.50',
        'bed_count': 1,
        'bed_type': 'queen',
        'view': 'Vườn',
        'amenities': ['Wi-Fi'],
        'images': [
          {'id': 1, 'url': '/media/rooms/1/photo.png', 'position': 0},
        ],
        'room_type': {
          'id': 1,
          'name': 'Deluxe',
          'description': '',
          'capacity': 2,
          'base_rate': '950000',
        },
      }, 200);
    });
    refreshTransport.httpClientAdapter = StubAdapter(
      (request) async =>
          jsonBody({'access': 'new-access', 'refresh': 'new-refresh'}, 200),
    );
    final store = MemorySessionStore()..token = 'old-refresh';
    final api = ApiClient(
      store: store,
      transport: transport,
      refreshTransport: refreshTransport,
    );
    final saved = await api.saveRoom(
      {'description': 'Phòng có ban công'},
      id: 1,
      images: [
        Uint8List.fromList([1, 2, 3]),
      ],
    );
    expect(saved.area, 32.5);
    expect(saved.amenities, ['Wi-Fi']);
    expect(forms, hasLength(2));
    expect(identical(forms[0], forms[1]), isFalse);
    expect(
      api.roomImageUrl(saved.images.single.url),
      'http://10.0.2.2:8000/media/rooms/1/photo.png',
    );
    expect(store.token, 'new-refresh');
  });

  test('Service API preserves request key, quoted price, cancellation reason and server totals', () async {
    final transport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    final usage = <String, dynamic>{
      'id': 21,
      'service_id': 1,
      'name': 'Giặt ủi',
      'unit': 'kg',
      'unit_price': '30000',
      'quantity': 2,
      'total': '60000',
      'status': 'active',
      'created_at': '2026-10-24T09:00:00Z',
      'created_by': 'Minh Anh',
      'cancelled_at': null,
      'cancelled_by': null,
      'cancel_reason': '',
    };
    transport.httpClientAdapter = StubAdapter((request) async {
      if (request.method == 'GET') {
        expect(request.queryParameters['page'], 2);
        return jsonBody({
          'count': 31,
          'next': null,
          'results': [usage],
          'room_total': '1900000',
          'service_total': '1860000',
          'estimated_total': '3760000',
          'can_edit': false,
        }, 200);
      }
      if (request.path.endsWith('cancel/')) {
        expect(request.data['reason'], 'Nhập nhầm');
        return jsonBody({
          ...usage,
          'status': 'cancelled',
          'cancel_reason': 'Nhập nhầm',
          'cancelled_at': '2026-10-24T10:00:00Z',
          'cancelled_by': 'Anh Nhân',
        }, 200);
      }
      expect(
        request.headers['Idempotency-Key'],
        '6ee20a58-137f-4f6f-92ba-1a68c0f3940a',
      );
      expect(request.data['expected_unit_price'], 30000);
      return jsonBody(usage, 201);
    });
    final api = ApiClient(store: MemorySessionStore(), transport: transport);
    final saved = await api.addServiceUsage(11, {
      'service_id': 1,
      'quantity': 2,
      'expected_unit_price': 30000,
    }, '6ee20a58-137f-4f6f-92ba-1a68c0f3940a');
    expect(saved.total, 60000);
    expect(saved.createdBy, 'Minh Anh');
    final cancelled = await api.cancelServiceUsage(11, 21, 'Nhập nhầm');
    expect(cancelled.cancelled, isTrue);
    expect(cancelled.cancelReason, 'Nhập nhầm');
    final page = await api.stayServices((bookingId: 11, page: 2));
    expect(page.count, 31);
    expect(page.serviceTotal, 1860000);
    expect(page.estimatedTotal, 3760000);
    expect(page.canEdit, isFalse);
  });

  test(
    'Guest save returns the server identity without a second lookup',
    () async {
      final transport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
      transport.httpClientAdapter = StubAdapter(
        (request) async => jsonBody({
          'id': 42,
          'full_name': 'Minh An',
          'phone': '0901234567',
          'email': '',
          'notes': '',
        }, 201),
      );
      final api = ApiClient(store: MemorySessionStore(), transport: transport);
      final saved = await api.saveGuest({
        'full_name': 'Minh An',
        'phone': '0901234567',
        'email': '',
        'notes': '',
      });
      expect(saved.id, 42);
      expect(saved.name, 'Minh An');
    },
  );

  test(
    'API validation preserves all field messages for inline display',
    () async {
      final transport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
      transport.httpClientAdapter = StubAdapter(
        (request) async => jsonBody({
          'error': {
            'message': 'Dữ liệu chưa hợp lệ.',
            'fields': {
              'phone': ['Điện thoại đã tồn tại.'],
              'email': ['Email chưa hợp lệ.'],
            },
          },
        }, 400),
      );
      final api = ApiClient(store: MemorySessionStore(), transport: transport);
      try {
        await api.saveGuest({});
        fail('Expected validation failure');
      } on ApiFailure catch (error) {
        expect(error.fields['phone'], 'Điện thoại đã tồn tại.');
        expect(error.fields['email'], 'Email chưa hợp lệ.');
      }
    },
  );

  test('Concurrent unauthorized requests rotate refresh only once', () async {
    final store = MemorySessionStore()..token = 'old-refresh';
    var refreshCount = 0;
    final transport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    transport.httpClientAdapter = StubAdapter((request) async {
      if (request.headers['Authorization'] != 'Bearer new-access') {
        return jsonBody({'detail': 'expired'}, 401);
      }
      return jsonBody({
        'id': 1,
        'username': 'admin',
        'display_name': 'Anh Nhân',
        'role': 'admin',
        'role_label': 'Quản trị viên',
      }, 200);
    });
    final refreshTransport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    refreshTransport.httpClientAdapter = StubAdapter((request) async {
      refreshCount++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return jsonBody({'access': 'new-access', 'refresh': 'new-refresh'}, 200);
    });
    final api = ApiClient(
      store: store,
      transport: transport,
      refreshTransport: refreshTransport,
    );
    final users = await Future.wait([api.me(), api.me()]);
    expect(users.every((user) => user.username == 'admin'), isTrue);
    expect(refreshCount, 1);
    expect(store.token, 'new-refresh');
  });

  test('Revoked refresh clears local session and signals expiry', () async {
    final store = MemorySessionStore()..token = 'revoked';
    final transport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    transport.httpClientAdapter = StubAdapter(
      (_) async => jsonBody({'detail': 'expired'}, 401),
    );
    final refreshTransport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    refreshTransport.httpClientAdapter = StubAdapter(
      (_) async => jsonBody({'detail': 'revoked'}, 401),
    );
    var expired = false;
    final api = ApiClient(
      store: store,
      transport: transport,
      refreshTransport: refreshTransport,
    )..onExpired = () => expired = true;
    await expectLater(api.me(), throwsA(isA<ApiFailure>()));
    expect(store.token, isNull);
    expect(expired, isTrue);
  });
}
