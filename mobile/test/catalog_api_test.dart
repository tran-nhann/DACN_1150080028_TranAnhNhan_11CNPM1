import 'dart:typed_data';

import 'package:aster_hotel/core/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test.dart' show StubAdapter, jsonBody;
import 'support.dart';

void main() {
  test(
    'Room catalog reads every type page and sends combined room filters',
    () async {
      final transport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
      final pages = <int>[];
      transport.httpClientAdapter = StubAdapter((request) async {
        if (request.path == 'room-types/') {
          final page = request.queryParameters['page'] as int;
          pages.add(page);
          return jsonBody({
            'next': page == 1
                ? 'https://example.test/room-types/?page=2'
                : null,
            'results': [
              {
                'id': page,
                'name': 'Type $page',
                'description': '',
                'capacity': 2,
                'base_rate': '650000',
              },
            ],
          }, 200);
        }
        expect(request.path, 'rooms/');
        expect(request.queryParameters, {
          'search': '20',
          'room_type': 2,
          'floor': 2,
          'status': 'ready',
          'page': 1,
        });
        return jsonBody({'results': [], 'count': 0, 'next': null}, 200);
      });
      final api = ApiClient(store: MemorySessionStore(), transport: transport);
      expect((await api.roomTypes()).map((type) => type.id), [1, 2]);
      expect(pages, [1, 2]);
      await api.rooms((
        search: '20',
        roomType: 2,
        floor: 2,
        condition: 'ready',
        page: 1,
      ));
    },
  );

  test('Service photo and metadata survive token refresh with a fresh multipart body', () async {
    final transport = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    final refresh = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    final forms = <FormData>[];
    transport.httpClientAdapter = StubAdapter((request) async {
      expect(request.path, 'services/7/');
      expect(request.method, 'PATCH');
      final form = request.data as FormData;
      forms.add(form);
      expect(Map.fromEntries(form.fields)['category'], 'laundry');
      expect(Map.fromEntries(form.fields)['description'], 'Giặt theo cân');
      expect(form.files.single.key, 'image');
      expect(form.files.single.value.length, 3);
      if (forms.length == 1) return jsonBody({}, 401);
      expect(request.headers['Authorization'], 'Bearer new-access');
      return jsonBody({
        'id': 7,
        'name': 'Giặt ủi',
        'unit': 'kg',
        'unit_price': '30000',
        'is_active': true,
        'category': 'laundry',
        'description': 'Giặt theo cân',
        'image_url': '/media/services/photo.jpg',
      }, 200);
    });
    refresh.httpClientAdapter = StubAdapter(
      (_) async =>
          jsonBody({'access': 'new-access', 'refresh': 'new-refresh'}, 200),
    );
    final api = ApiClient(
      store: MemorySessionStore()..token = 'old-refresh',
      transport: transport,
      refreshTransport: refresh,
    );
    final saved = await api.saveService(
      {'category': 'laundry', 'description': 'Giặt theo cân'},
      id: 7,
      image: Uint8List.fromList([1, 2, 3]),
    );
    expect(saved.category, 'laundry');
    expect(saved.imageUrl, '/media/services/photo.jpg');
    expect(forms, hasLength(2));
    expect(identical(forms.first, forms.last), isFalse);
  });
}
