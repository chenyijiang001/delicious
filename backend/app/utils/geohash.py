"""轻量级 geohash 编码。
geohash5 精度约 4.9km × 4.9km，足够 V1.1 购物建议的片区缓存粒度。
不依赖第三方库以保持 backend 启动开销最低。
"""

_BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"


def encode(lat: float, lng: float, precision: int = 5) -> str:
    """Encode 经纬度为 geohash 字符串。"""
    lat_lo, lat_hi = -90.0, 90.0
    lng_lo, lng_hi = -180.0, 180.0
    bits = [16, 8, 4, 2, 1]
    out = []
    bit = 0
    ch = 0
    even = True

    while len(out) < precision:
        if even:
            mid = (lng_lo + lng_hi) / 2
            if lng > mid:
                ch |= bits[bit]
                lng_lo = mid
            else:
                lng_hi = mid
        else:
            mid = (lat_lo + lat_hi) / 2
            if lat > mid:
                ch |= bits[bit]
                lat_lo = mid
            else:
                lat_hi = mid
        even = not even
        if bit < 4:
            bit += 1
        else:
            out.append(_BASE32[ch])
            bit = 0
            ch = 0
    return "".join(out)


def truncate_coords(lat: float, lng: float, precision_digits: int = 3) -> tuple[float, float]:
    """坐标精度截断。3 位小数 ≈ 110m，用于位置脱敏后落库。"""
    factor = 10 ** precision_digits
    return round(lat * factor) / factor, round(lng * factor) / factor
