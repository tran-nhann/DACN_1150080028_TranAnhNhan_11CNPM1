"""Room allocations and frozen rates for a single booking, including same-day moves."""


def room_segments(booking):
    moves = list(booking.room_moves.all())
    if moves:
        first = moves[0]
        room = (first.from_room_id, first.from_number, first.from_type_id, first.from_type_name, first.old_rate)
    else:
        room = (booking.room_id, booking.room.number, booking.room.room_type_id, booking.room.room_type.name, booking.nightly_rate)
    start = booking.start_date
    rows = []
    for move in moves:
        rows.append(segment(room, start, move.effective_date))
        room = (move.to_room_id, move.to_number, move.to_type_id, move.to_type_name, move.new_rate)
        start = move.effective_date
    rows.append(segment(room, start, booking.end_date))
    return [row for row in rows if row["nights"] > 0]


def segment(room, start, end):
    nights = (end - start).days
    return {"room_id": room[0], "room_number": room[1], "room_type_id": room[2], "room_type": room[3],
        "start_date": start, "end_date": end, "nightly_rate": room[4], "nights": nights, "total": nights * room[4]}


def room_type_at(booking, timestamp):
    moves = list(booking.room_moves.all())
    if not moves:
        return booking.room.room_type_id, booking.room.room_type.name
    result = moves[0].from_type_id, moves[0].from_type_name
    for move in moves:
        if move.created_at > timestamp:
            break
        result = move.to_type_id, move.to_type_name
    return result
