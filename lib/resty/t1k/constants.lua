local t = {}

t.T1K_MODE_OFF = "off"
t.T1K_MODE_BLOCK = "block"
t.T1K_MODE_MONITOR = "monitor"

t.T1K_HEADER_SIZE = 5

t.TAG_HEAD = 0x01
t.TAG_BODY = 0x02
t.TAG_EXTRA = 0x03
t.TAG_VERSION = 0x20
t.TAG_EXTRA_BODY = 0x24

t.MASK_FIRST = 0x40
t.MASK_LAST = 0x80

t.NGX_HTTP_HEADER_PREFIX = "http_"

t.ERR_TOO_MANY_HEADERS = "truncated"

t.BLOCK_CONTENT_TYPE = "application/json"
t.BLOCK_CONTENT_FORMAT = [[
{"code": %s, "success":false, "message": "blocked by Chaitin SafeLine Web Application Firewall", "event_id": "%s"}]]

return t
