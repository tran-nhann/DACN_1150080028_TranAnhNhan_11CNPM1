from rest_framework.views import exception_handler


def api_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is None:
        return None
    data = response.data
    codes = {
        400: "validation_error",
        401: "unauthenticated",
        403: "permission_denied",
        404: "not_found",
        409: "conflict",
        429: "rate_limited",
    }
    fallback = {
        400: "Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.",
        401: "Vui lòng đăng nhập để tiếp tục.",
        403: "Bạn không có quyền thực hiện thao tác này.",
        404: "Không tìm thấy dữ liệu yêu cầu.",
        429: "Bạn thao tác quá nhanh. Vui lòng thử lại sau.",
    }
    message = (
        data.get("detail", fallback.get(response.status_code, "Không thể xử lý yêu cầu."))
        if isinstance(data, dict)
        else fallback.get(response.status_code)
    )
    request = context.get("request")
    response.data = {
        "error": {
            "code": codes.get(response.status_code, "request_error"),
            "message": str(message),
            "fields": data if isinstance(data, dict) and "detail" not in data else {},
            "request_id": getattr(request, "request_id", ""),
        }
    }
    return response
