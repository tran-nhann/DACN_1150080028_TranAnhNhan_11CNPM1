import 'models.dart';

int _amount(dynamic value) => int.parse(value.toString().split('.').first);
typedef InvoiceQuery = ({String search, String method, int page});

class BillLine {
  const BillLine({
    required this.kind,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.total,
  });
  final String kind, name, unit;
  final int quantity, price, total;
  factory BillLine.fromJson(Map<String, dynamic> json) => BillLine(
    kind: json['kind'] as String,
    name: json['name'] as String,
    unit: json['unit'] as String,
    quantity: json['quantity'] as int,
    price: _amount(json['unit_price']),
    total: _amount(json['total']),
  );
}

class BillPayment {
  const BillPayment({
    required this.code,
    required this.method,
    required this.methodLabel,
    required this.amount,
    required this.date,
    required this.cashier,
    this.reference = '',
    this.notes = '',
  });
  final String code, method, methodLabel, cashier, reference, notes;
  final int amount;
  final DateTime date;
  factory BillPayment.fromJson(Map<String, dynamic> json) => BillPayment(
    code: json['code'] as String,
    method: json['method'] as String,
    methodLabel: json['method_label'] as String,
    amount: _amount(json['amount']),
    date: DateTime.parse(json['received_at'] as String),
    cashier: json['received_by'] as String,
    reference: json['reference'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
  );
}

class HotelInvoice {
  const HotelInvoice({
    required this.id,
    required this.code,
    required this.bookingId,
    required this.bookingCode,
    required this.guest,
    required this.phone,
    required this.roomNumber,
    required this.roomType,
    required this.start,
    required this.end,
    required this.roomTotal,
    required this.serviceTotal,
    required this.total,
    required this.issuedAt,
    required this.issuedBy,
    required this.lines,
    required this.payment,
  });
  final int id, bookingId, roomTotal, serviceTotal, total;
  final String code, bookingCode, guest, phone, roomNumber, roomType, issuedBy;
  final DateTime start, end, issuedAt;
  final List<BillLine> lines;
  final BillPayment payment;
  factory HotelInvoice.fromJson(Map<String, dynamic> json) => HotelInvoice(
    id: json['id'] as int,
    code: json['code'] as String,
    bookingId: json['booking_id'] as int,
    bookingCode: json['booking_code'] as String,
    guest: json['guest_name'] as String,
    phone: json['guest_phone'] as String,
    roomNumber: json['room_number'] as String,
    roomType: json['room_type'] as String,
    start: DateTime.parse(json['start_date'] as String),
    end: DateTime.parse(json['end_date'] as String),
    roomTotal: _amount(json['room_total']),
    serviceTotal: _amount(json['service_total']),
    total: _amount(json['total']),
    issuedAt: DateTime.parse(json['issued_at'] as String),
    issuedBy: json['issued_by'] as String,
    lines: (json['lines'] as List)
        .map((row) => BillLine.fromJson(row as Map<String, dynamic>))
        .toList(),
    payment: BillPayment.fromJson(json['payment'] as Map<String, dynamic>),
  );
}

class StayFolio {
  const StayFolio({
    required this.quote,
    required this.guest,
    required this.roomNumber,
    required this.start,
    required this.end,
    required this.roomTotal,
    required this.serviceTotal,
    required this.total,
    required this.lines,
    required this.canCheckout,
    required this.blockedReason,
    required this.policy,
  });
  final String quote, guest, roomNumber, blockedReason, policy;
  final DateTime start, end;
  final int roomTotal, serviceTotal, total;
  final bool canCheckout;
  final List<BillLine> lines;
  factory StayFolio.fromJson(Map<String, dynamic> json) => StayFolio(
    quote: json['quote_token'] as String,
    guest: json['guest_name'] as String,
    roomNumber: json['room_number'] as String,
    start: DateTime.parse(json['start_date'] as String),
    end: DateTime.parse(json['end_date'] as String),
    roomTotal: _amount(json['room_total']),
    serviceTotal: _amount(json['service_total']),
    total: _amount(json['total']),
    lines: (json['lines'] as List)
        .map((row) => BillLine.fromJson(row as Map<String, dynamic>))
        .toList(),
    canCheckout: json['can_checkout'] as bool,
    blockedReason: json['blocked_reason'] as String,
    policy: json['billing_policy'] as String,
  );
}

class BillingState {
  const BillingState({this.folio, this.invoice});
  final StayFolio? folio;
  final HotelInvoice? invoice;
  factory BillingState.fromJson(Map<String, dynamic> json) => BillingState(
    folio: json['folio'] == null
        ? null
        : StayFolio.fromJson(json['folio'] as Map<String, dynamic>),
    invoice: json['invoice'] == null
        ? null
        : HotelInvoice.fromJson(json['invoice'] as Map<String, dynamic>),
  );
}

class CheckoutResult {
  const CheckoutResult({required this.invoice, required this.booking});
  final HotelInvoice invoice;
  final HotelBooking booking;
  factory CheckoutResult.fromJson(Map<String, dynamic> json) => CheckoutResult(
    invoice: HotelInvoice.fromJson(json['invoice'] as Map<String, dynamic>),
    booking: HotelBooking.fromJson(json['booking'] as Map<String, dynamic>),
  );
}
