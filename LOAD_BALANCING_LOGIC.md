# 🔧 Load Balancing Logic Implementation (Option B)

## 📋 **LOGIC OVERVIEW**

Đã implement logic điều kiện cho load balancing dựa trên 2 biến môi trường:

### **Biến Chính: MOODLE_REVERSEPROXY**
- `yes`: Kích hoạt load balancing mode
- `no`: Sử dụng direct connection mode

### **Biến Phụ: MOODLE_SSLPROXY** 
- Chỉ có hiệu lực khi `MOODLE_REVERSEPROXY=yes`
- `yes`: Xử lý SSL termination tại load balancer
- `no`: Không xử lý SSL termination

## 🔄 **CÁC SCENARIO**

### **Scenario 1: MOODLE_REVERSEPROXY=no**
```bash
MOODLE_REVERSEPROXY=no
MOODLE_SSLPROXY=any_value  # Bị bỏ qua
```
**Kết quả:**
- ✅ Sử dụng `000-default-direct.conf`
- ✅ Không trust proxy headers
- ✅ Không xử lý X-Forwarded-* headers
- ✅ Log format: `combined` (standard)
- ✅ Bảo mật: Không có lỗ hổng proxy spoofing

### **Scenario 2: MOODLE_REVERSEPROXY=yes + MOODLE_SSLPROXY=no**
```bash
MOODLE_REVERSEPROXY=yes
MOODLE_SSLPROXY=no
```
**Kết quả:**
- ✅ Sử dụng `000-default-lb.conf`
- ✅ Trust proxy headers (RemoteIP)
- ❌ Không xử lý X-Forwarded-Proto
- ✅ Log format: `combined_lb` (với X-Forwarded headers)
- ⚠️ Phù hợp cho: HTTP-only load balancer

### **Scenario 3: MOODLE_REVERSEPROXY=yes + MOODLE_SSLPROXY=yes**
```bash
MOODLE_REVERSEPROXY=yes
MOODLE_SSLPROXY=yes
```
**Kết quả:**
- ✅ Sử dụng `000-default-lb.conf`
- ✅ Trust proxy headers (RemoteIP)
- ✅ Xử lý X-Forwarded-Proto cho HTTPS
- ✅ Log format: `combined_lb`
- ✅ Phù hợp cho: Full load balancer với SSL termination

## 📁 **FILES ĐƯỢC TẠO/CẬP NHẬT**

### **New Templates:**
- `config/apache/sites/000-default-lb.conf` - Load balancer template
- `config/apache/sites/000-default-direct.conf` - Direct connection template

### **Updated Files:**
- `scripts/setup/apache.sh` - Logic điều kiện Option B
- `config/apache/apache2.conf` - Dynamic log format
- `Dockerfile` - Copy new templates

## 🔍 **LOGIC FLOW**

```bash
if [[ "$MOODLE_REVERSEPROXY" == "yes" ]]; then
    # Load Balancer Mode
    cp 000-default-lb.conf -> 000-default.conf
    LOG_FORMAT="combined_lb"
    
    if [[ "$MOODLE_SSLPROXY" == "yes" ]]; then
        # Enable SSL proxy handling
        SSL_PROXY_HEADERS='SetEnvIf X-Forwarded-Proto "https" HTTPS=on'
        SSL_PROXY_REWRITE_RULES='RewriteCond %{HTTP:X-Forwarded-Proto} =https...'
    else
        # Disable SSL proxy handling
        SSL_PROXY_HEADERS='# SSL proxy disabled'
        SSL_PROXY_REWRITE_RULES='# SSL proxy disabled'
    fi
else
    # Direct Connection Mode
    cp 000-default-direct.conf -> 000-default.conf
    LOG_FORMAT="combined"
    # No proxy handling at all
fi
```

## ✅ **TESTING SCENARIOS**

### **Test 1: Direct Connection**
```bash
export MOODLE_REVERSEPROXY=no
export MOODLE_SSLPROXY=yes  # Should be ignored
# Expected: Direct config, no proxy trust
```

### **Test 2: Load Balancer without SSL**
```bash
export MOODLE_REVERSEPROXY=yes
export MOODLE_SSLPROXY=no
# Expected: LB config, no HTTPS handling
```

### **Test 3: Full Load Balancer**
```bash
export MOODLE_REVERSEPROXY=yes
export MOODLE_SSLPROXY=yes
# Expected: LB config with HTTPS handling
```

## 🛡️ **SECURITY BENEFITS**

1. **No Proxy Spoofing**: Khi `MOODLE_REVERSEPROXY=no`, không trust bất kỳ proxy headers nào
2. **Conditional Trust**: Chỉ trust proxy khi explicitly enable
3. **Granular Control**: Tách biệt proxy trust và SSL handling
4. **Audit Trail**: Clear logging về mode nào được sử dụng

## 📝 **DEPLOYMENT NOTES**

- Default values trong `config.sh`: `MOODLE_REVERSEPROXY=no`, `MOODLE_SSLPROXY=no`
- Để enable load balancing: Set cả 2 biến trong `.env` file
- Container sẽ log rõ ràng mode nào được sử dụng
- Health check tự động adapt dựa trên `MOODLE_SSLPROXY`
