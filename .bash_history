
if (isset($_GET['reset'])) {
    $code = $_GET['reset'];
    $stmt = $db->prepare("SELECT mac FROM vouchers WHERE code = :code");
    $stmt->bindValue(':code', $code, SQLITE3_TEXT);
    $res = $stmt->execute()->fetchArray(SQLITE3_ASSOC);
    if ($res && !empty($res['mac']) && $res['mac'] !== 'UNKNOWN') {
        $mac = $res['mac'];
        exec("iptables -t nat -D PREROUTING -m mac --mac-source $mac -j ACCEPT");
    }
    $stmt = $db->prepare("UPDATE vouchers SET used = 0, mac = NULL, session_id = NULL, used_at = NULL WHERE code = :code");
    $stmt->bindValue(':code', $code, SQLITE3_TEXT);
    $stmt->execute();
    header("Location: admin.php");
    exit;
}

if (isset($_GET['delete'])) {
    $code = $_GET['delete'];
    $stmt = $db->prepare("DELETE FROM vouchers WHERE code = :code");
    $stmt->bindValue(':code', $code, SQLITE3_TEXT);
    $stmt->execute();
    header("Location: admin.php");
    exit;
}

$vouchers = $db->query("SELECT * FROM vouchers ORDER BY rowid DESC");
?>
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard</title>
    <style>
        body { font-family: sans-serif; background: #0f172a; color: #f8fafc; padding: 20px; margin: 0; }
        .container { max-width: 900px; margin: 0 auto; }
        .card { background: #1e293b; border: 1px solid #334155; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        input[type="text"], input[type="number"] { background: #0f172a; border: 1px solid #334155; color: #fff; padding: 8px; border-radius: 6px; }
        .btn { background: #3b82f6; color: white; padding: 8px 16px; border: none; border-radius: 6px; text-decoration: none; cursor: pointer; }
        .btn-danger { background: #ef4444; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { text-align: left; padding: 10px; border-bottom: 1px solid #334155; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div style="display:flex; justify-content:space-between; align-items:center;">
            <h2>Portal Control Panel</h2>
            <a href="admin.php?logout=1" class="btn btn-danger">Logout</a>
        </div>
        <div class="card">
            <h3>Generate Vouchers</h3>
            <form method="POST">
                <input type="text" name="prefix" placeholder="Prefix (e.g. VIP)" maxlength="6">
                <input type="number" name="qty" value="5" min="1" max="50">
                <input type="submit" name="generate" value="Create Vouchers" class="btn">
            </form>
        </div>
        <div class="card">
            <h3>Active Registry</h3>
            <table>
                <tr><th>Voucher</th><th>Status</th><th>Session ID</th><th>Actions</th></tr>
                <?php while ($row = $vouchers->fetchArray(SQLITE3_ASSOC)): ?>
                <tr>
                    <td><code><?= htmlspecialchars($row['code']) ?></code></td>
                    <td><?= $row['used'] == 1 ? 'USED' : 'UNUSED' ?></td>
                    <td><code><?= $row['session_id'] ? $row['session_id'] : '-' ?></code></td>
                    <td>
                        <?php if ($row['used'] == 1): ?>
                            <a href="admin.php?reset=<?= urlencode($row['code']) ?>" class="btn">Unbind</a>
                        <?php endif; ?>
                        <a href="admin.php?delete=<?= urlencode($row['code']) ?>" class="btn btn-danger">Delete</a>
                    </td>
                </tr>
                <?php endwhile; ?>
            </table>
        </div>
    </div>
</body>
</html>
EOF

cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/sh

export PATH="/data/data/com.termux/files/usr/bin:$PATH"

echo "[+] Turning Hotspot ON..."
cmd wifi start-softap
sleep 3

IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]' | head -n 1)
[ -z "$IFACE" ] && IFACE="ap0"

echo "[+] Interface: $IFACE"
sysctl -w net.ipv4.ip_forward=1 > /dev/null

iptables -t nat -F
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080

echo "[+] Starting Web Engine..."
php -S 0.0.0.0:8080 -t /sdcard/termux_portal/
EOF

chmod +x ~/start.sh
su
clear
pkg update && pkg install -y php sqlite tsu
mkdir -p /sdcard/termux_portal
# Unpack index.php
echo "PD9waHAKJGRiID0gbmV3IFNRTGl0ZTNvdXRwdXQgPSAnL3NkY2FyZC90ZXJtdXhfcG9ydGFsL3N5c3RlbS5kYicpOwokZGItPmV4ZWMoIkNSRUFURSBUQUJMRSBJRiBOT1QgRVhJU1RTIHZvdWNoZXJzIChjb2RlIFRFWFQgUFJJTUFSWSBLRVksIHVzZWQgSU5URUdFUiBERUZBVUxUIDAsIG1hYyBURVhUIERFRkFVTFQgTlVMTCwgc2Vzc2lvbl9pZCBURVhUIERFRkFVTFQgTlVMTCwgdXNlZF9hdCBEQVRFVElNRSkiKTsKCiRjbGllbnRfaXAgPSAkX1NFUlZFUlsnUkVNT1RFX0FERFInXTsKJGNsaWVudF9tYWMgPSAiVU5LTk9XTiI7CgokYXJwX2RhdGEgPSBAZmlsZV9nZXRfY29udGVudHMoJy9wcm9jL25ldC9hcnAnKTsKaWYgKCRhcnBfZGF0YSkgewogICAgZm9yZWFjaCAoZXhwbG9kZSgiXG4iLCAkYXJwX2RhdGEpIGFzICRsaW5lKSB7CiAgICAgICAgJGNvbHMgPSBwcmVnX3NwbGl0KCcvXHMrLycsIHRyaW0oJGxpbmUpKTsKICAgICAgICBpZiAoaXNzZXQoJGNvbHNbMF0pICYmICRjb2xzWzBdID09PSAkY2xpZW50X2lwKSB7CiAgICAgICAgICAgICRjbGllbnRfbWFjID0gc3RydG91cHBlcigkY29sc1szXSk7CiAgICAgICAgICAgIGJyZWFrOwogICAgICAgIH0KICAgIH0KfQoKJG1hc2tlZF9zZXNzaW9uX2lkID0gc3RydG91cHBlcihzdWJzdHIobWQ1KCRjbGllbnRfaXAgLiAkY2xpZW50X21hYyksIDAsIDEwKSk7CiRtZXNzYWdlID0gIiI7CiRzdGF0dXMgPSAiIjsKCmlmIChpc3NldCgkX1BPU1RbJ3ZvdWNoZXInXSkpIHsKICAgICRpbnB1dF9jb2RlID0gc3RydG91cHBlcih0cmltKCRfUE9TVFsndm91Y2hlciddKSk7CiAgICAkc3RtdCA9ICRkYi0+cHJlcGFyZSgiU0VMRUNUICogRlJPTSB2b3VjaGVycyBXSEVSRSBjb2RlID0gOmNvZGUiKTsKICAgICRzdG10LT5iaW5kVmFsdWUoJzpjb2RlJywgJGlucHV0X2NvZGUsIFNRTElURTNfVEVYVCk7CiAgICAKICAgICRyZXN1bHQgPSAkc3RtdC0+ZXhlY3V0ZSgpLT5mZXRjaEFycmF5KFNRTElURTNfQVNTT2MpOwoKICAgIGlmICghJHJlc3VsdCkgewogICAgICAgICRtZXNzYWdlID0gIkludmFsaWQgYWNjZXNzIHZvdWNoZXIuIjsKICAgICAgICAkc3RhdHVzID0gImVycm9yIjsKICAgIH0gZWxzZWlmICgkcmVzdWx0Wyd1c2VkJ10gPT0gMSAmJiAkcmVzdWx0WydtYWMnXSAhPT0gJGNsaWVudF9tYWMpIHsKICAgICAgICAkbWVzc2FnZSA9ICJWb3VjaGVyIGFscmVhZHkgYm91bmQgdG8gYW5vdGhlciBkZXZpY2UuIjsKICAgICAgICAkc3RhdHVzID0gImVycm9yIjsKICAgIH0gZWxzZSB7CiAgICAgICAgaWYgKCRyZXN1bHRbJ3VzZWQnXSA9PSAwKSB7CiAgICAgICAgICAgICR1cGRhdGUgPSAkZGItPnByZXBhcmUoIlVQREFURSB2b3VjaGVycyBTRVQgdXNlZCA9IDEsIG1hYyA9IDptYWMsIHNlc3Npb25faWQgPSA6c2lkLCB1c2VkX2F0ID0gREFURVRJTUUoJ25vdycpIFdIRVJFIGNvZGUgPSA6Y29kZSIpOwogICAgICAgICAgICAkdXBkYXRlLT5iaW5kVmFsdWUoJzptYWMnLCAkY2xpZW50X21hYywgU1FMSVRFM19URVhUKTsKICAgICAgICAgICAgJHVwZGF0ZS0+YmluZFZhbHVlKCc6c2lkJywgJG1hc2tlZF9zZXNzaW9uX2lkLCBTUUxJVEUzX1RFWFQpOwogICAgICAgICAgICAkdXBkYXRlLT5iaW5kVmFsdWUoJzpjb2RlJywgJGlucHV0X2NvZGUsIFNRTElURTNfVEVYVCk7CiAgICAgICAgICAgICR1cGRhdGUtPmV4ZWN1dGUoKTsKICAgICAgICB9CgogICAgICAgIGlmICgkY2xpZW50X21hYyAhPT0gIlVOS05PV04iKSB7CiAgICAgICAgICAgIGV4ZWMoImlwdGFibGVzIC10IG5hdCAtSSBQUkVST1VUSU5HIC1tIG1hYyAtLW1hYy1zb3VyY2UgJGNsaWVudF9tYWMgLWogQUNDRVBUIik7CiAgICAgICAgICAgICRtZXNzYWdlID0gIkF1dGhlbnRpY2F0ZWQhIFNlc3Npb24gSUQ6ICIgLiAkbWFza2VkX3Nlc3Npb25faWQ7CiAgICAgICAgICAgICRzdGF0dXMgPSAic3VjY2VzcyI7CiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJG1lc3NhZ2UgPSAiVW5hYmxlIHRvIHJlc29sdmUgaGFyZHdhcmUgbGF5ZXIuIjsKICAgICAgICAgICAgJHN0YXR1cyA9ICJlcnJvciI7CiAgICAgICAgfQogICAgfQp9Cj8+CjCEVE1MIG9taXR0ZWQgZm9yIGJyZXZpdHk=" | base64 -d > /sdcard/termux_portal/index.php
# Create Index File Directly
cat << 'EOF' > /sdcard/termux_portal/index.php
<?php
$db = new SQLite3('/sdcard/termux_portal/system.db');
$db->exec("CREATE TABLE IF NOT EXISTS vouchers (code TEXT PRIMARY KEY, used INTEGER DEFAULT 0, mac TEXT DEFAULT NULL, session_id TEXT DEFAULT NULL, used_at DATETIME)");
$client_ip = $_SERVER['REMOTE_ADDR'];
$client_mac = "UNKNOWN";
$arp_data = @file_get_contents('/proc/net/arp');
if ($arp_data) {
    foreach (explode("\n", $arp_data) as $line) {
        $cols = preg_split('/\s+/', trim($line));
        if (isset($cols[0]) && $cols[0] === $client_ip) { $client_mac = strtoupper($cols[3]); break; }
    }
}
$masked_session_id = strtoupper(substr(md5($client_ip . $client_mac), 0, 10));
$message = ""; $status = "";
if (isset($_POST['voucher'])) {
    $input_code = strtoupper(trim($_POST['voucher']));
    $stmt = $db->prepare("SELECT * FROM vouchers WHERE code = :code");
    $stmt->bindValue(':code', $input_code, SQLITE3_TEXT);
    $result = $stmt->execute()->fetchArray(SQLITE3_ASSOC);
    if (!$result) { $message = "Invalid access voucher."; $status = "error"; }
    elseif ($result['used'] == 1 && $result['mac'] !== $client_mac) { $message = "Voucher bound to another device."; $status = "error"; }
    else {
        if ($result['used'] == 0) {
            $update = $db->prepare("UPDATE vouchers SET used = 1, mac = :mac, session_id = :sid, used_at = DATETIME('now') WHERE code = :code");
            $update->bindValue(':mac', $client_mac, SQLITE3_TEXT);
            $update->bindValue(':sid', $masked_session_id, SQLITE3_TEXT);
            $update->bindValue(':code', $input_code, SQLITE3_TEXT);
            $update->execute();
        }
        if ($client_mac !== "UNKNOWN") {
            exec("iptables -t nat -I PREROUTING -m mac --mac-source $client_mac -j ACCEPT");
            $message = "Authenticated! Session ID: " . $masked_session_id; $status = "success";
        } else { $message = "Unable to resolve hardware layer."; $status = "error"; }
    }
}
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Wi-Fi Access</title><style>body{font-family:sans-serif;background:#0d1117;color:#c9d1d9;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;}.card{background:#161b22;padding:30px;border-radius:12px;border:1px solid #30363d;width:90%;max-width:360px;text-align:center;}input[type="text"]{width:100%;padding:12px;margin:15px 0;border:1px solid #30363d;background:#0d1117;color:#fff;border-radius:6px;box-sizing:border-box;text-align:center;font-size:18px;text-transform:uppercase;}input[type="submit"]{width:100%;background:#238636;color:white;border:none;padding:12px;border-radius:6px;font-weight:bold;font-size:16px;cursor:pointer;}.alert{padding:10px;margin-bottom:15px;border-radius:6px;font-size:13px;}.error{background:rgba(248,81,73,0.15);color:#f85149;}.success{background:rgba(46,160,67,0.15);color:#3fb950;}</style></head><body><div class="card"><h2>Network Gateway</h2><?php if(!empty($message)):?><div class="alert <?=$status?>"><?=htmlspecialchars($message)?></div><?php endif;?><form method="POST"><input type="text" name="voucher" placeholder="VOUCHER CODE" required autocomplete="off"><input type="submit" value="Connect Device"></form></div></body></html>
EOF

cat << 'EOF' > /sdcard/termux_portal/admin.php
<?php
session_start();
$ADMIN_PASS = "admin123";
$db = new SQLite3('/sdcard/termux_portal/system.db');
if (isset($_POST['login'])) { if ($_POST['password'] === $ADMIN_PASS) { $_SESSION['authenticated'] = true; } }
if (isset($_GET['logout'])) { session_destroy(); header("Location: admin.php"); exit; }
if (!isset($_SESSION['authenticated'])) {
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Admin Login</title><style>body{font-family:sans-serif;background:#0f172a;color:#fff;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;}.panel{background:#1e293b;padding:30px;border-radius:12px;border:1px solid #334155;width:90%;max-width:320px;text-align:center;}input[type="password"]{width:100%;padding:10px;margin:15px 0;border-radius:6px;border:1px solid #475569;background:#0f172a;color:#fff;box-sizing:border-box;text-align:center;}input[type="submit"]{width:100%;padding:10px;border-radius:6px;border:none;background:#3b82f6;color:white;font-weight:bold;cursor:pointer;}</style></head><body><div class="panel"><h3>Control Center</h3><form method="POST"><input type="password" name="password" placeholder="Passcode" required><input type="submit" name="login" value="Unlock Dashboard"></form></div></body></html>
<?php exit; }
if (isset($_POST['generate'])) {
    $qty = (int)$_POST['qty']; $prefix = strtoupper(trim($_POST['prefix']));
    for ($i = 0; $i < $qty; $i++) {
        $code = !empty($prefix) ? $prefix . "-" . substr(md5(uniqid()), 0, 5) : strtoupper(substr(md5(uniqid()), 0, 6));
        $stmt = $db->prepare("INSERT INTO vouchers (code) VALUES (:code)");
        $stmt->bindValue(':code', $code, SQLITE3_TEXT); $stmt->execute();
    }
    header("Location: admin.php"); exit;
}
if (isset($_GET['reset'])) {
    $code = $_GET['reset'];
    $stmt = $db->prepare("SELECT mac FROM vouchers WHERE code = :code");
    $stmt->bindValue(':code', $code, SQLITE3_TEXT);
    $res = $stmt->execute()->fetchArray(SQLITE3_ASSOC);
    if ($res && !empty($res['mac']) && $res['mac'] !== 'UNKNOWN') {
        $mac = $res['mac']; exec("iptables -t nat -D PREROUTING -m mac --mac-source $mac -j ACCEPT");
    }
    $stmt = $db->prepare("UPDATE vouchers SET used = 0, mac = NULL, session_id = NULL, used_at = NULL WHERE code = :code");
    $stmt->bindValue(':code', $code, SQLITE3_TEXT); $stmt->execute();
    header("Location: admin.php"); exit;
}
if (isset($_GET['delete'])) {
    $code = $_GET['delete']; $stmt = $db->prepare("DELETE FROM vouchers WHERE code = :code");
    $stmt->bindValue(':code', $code, SQLITE3_TEXT); $stmt->execute();
    header("Location: admin.php"); exit;
}
$vouchers = $db->query("SELECT * FROM vouchers ORDER BY rowid DESC");
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Admin Dashboard</title><style>body{font-family:sans-serif;background:#0f172a;color:#f8fafc;padding:20px;margin:0;}.container{max-width:900px;margin:0 auto;}.card{background:#1e293b;border:1px solid #334155;padding:20px;border-radius:8px;margin-bottom:20px;}input[type="text"],input[type="number"]{background:#0f172a;border:1px solid #334155;color:#fff;padding:8px;border-radius:6px;}.btn{background:#3b82f6;color:white;padding:8px 16px;border:none;border-radius:6px;text-decoration:none;cursor:pointer;}.btn-danger{background:#ef4444;}table{width:100%;border-collapse:collapse;margin-top:15px;}th,td{text-align:left;padding:10px;border-bottom:1px solid #334155;font-size:14px;}</style></head><body><div class="container"><div style="display:flex;justify-content:space-between;align-items:center;"><h2>Portal Control Panel</h2><a href="admin.php?logout=1" class="btn btn-danger">Logout</a></div><div class="card"><h3>Generate Vouchers</h3><form method="POST"><input type="text" name="prefix" placeholder="Prefix (e.g. VIP)" maxlength="6"><input type="number" name="qty" value="5" min="1" max="50"><input type="submit" name="generate" value="Create Vouchers" class="btn"></form></div><div class="card"><h3>Active Registry</h3><table><tr><th>Voucher</th><th>Status</th><th>Session ID</th><th>Actions</th></tr><?php while($row = $vouchers->fetchArray(SQLITE3_ASSOC)):?><tr><td><code><?=htmlspecialchars($row['code'])?></code></td><td><?=$row['used']==1?'USED':'UNUSED'?></td><td><code><?=$row['session_id']?$row['session_id']:'-'?></code></td><td><?php if($row['used']==1):?><a href="admin.php?reset=<?=urlencode($row['code'])?>" class="btn">Unbind</a><?php endif;?><a href="admin.php?delete=<?=urlencode($row['code'])?>" class="btn btn-danger">Delete</a></td></tr><?php endwhile;?></table></div></div></body></html>
EOF

cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

echo "[+] Detecting Network Interface..."
IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]' | head -n 1)
[ -z "$IFACE" ] && IFACE="ap0"

echo "[+] Hotspot Interface: $IFACE"
sysctl -w net.ipv4.ip_forward=1 > /dev/null

iptables -t nat -F
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080

echo "[+] Launching PHP Web Server..."
$PREFIX/bin/php -S 0.0.0.0:8080 -t /sdcard/termux_portal/
EOF

chmod +x ~/start.sh
su
exit
su
ls
cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

echo "[+] Forcing Android Hotspot State via System Intent..."
am start -n com.android.settings/.TetherSettings > /dev/null 2>&1
sleep 1
input keyevent 20 > /dev/null 2>&1

echo "[+] Waiting for Hotspot Interface to Initialize..."
COUNTER=0
IFACE=""

while [ $COUNTER -lt 10 ]; do
    IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]|rndis[0-9]' | head -n 1)
    if [ -n "$IFACE" ]; then
        break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if [ -z "$IFACE" ]; then
    echo "[!] Automatic trigger timed out. Please toggle the hotspot switch once manually."
    IFACE="ap0"
else
    echo "[+] Successfully bound to Hotspot Interface: $IFACE"
fi

sysctl -w net.ipv4.ip_forward=1 > /dev/null
iptables -t nat -F
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080

echo "[+] Portal Engine Active on http://0.0.0.0:8080"
$PREFIX/bin/php -S 0.0.0.0:8080 -t /sdcard/termux_portal/
EOF

chmod +x ~/start.sh
su
clear
cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

echo "[+] Triggering Android Hotspot..."
am start -n com.android.settings/.TetherSettings > /dev/null 2>&1
sleep 1
input keyevent 20 > /dev/null 2>&1

echo "[+] Waiting for Hotspot Interface..."
COUNTER=0
IFACE=""

while [ $COUNTER -lt 10 ]; do
    IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]|rndis[0-9]' | head -n 1)
    if [ -n "$IFACE" ]; then
        break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if [ -z "$IFACE" ]; then
    IFACE="ap0"
fi

echo "[+] Bound to Interface: $IFACE"

sysctl -w net.ipv4.ip_forward=1 > /dev/null
iptables -t nat -F

# Route all web traffic directly to port 80
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 80

echo "[+] Portal Engine Active on Port 80"
$PREFIX/bin/php -S 0.0.0.0:80 -t /sdcard/termux_portal/
EOF

chmod +x ~/start.sh
su
clear
cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

echo "[+] Triggering Android Hotspot..."
am start -n com.android.settings/.TetherSettings > /dev/null 2>&1
sleep 1
input keyevent 20 > /dev/null 2>&1

echo "[+] Waiting for Hotspot Interface..."
COUNTER=0
IFACE=""

while [ $COUNTER -lt 10 ]; do
    IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]|rndis[0-9]' | head -n 1)
    if [ -n "$IFACE" ]; then
        break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if [ -z "$IFACE" ]; then
    IFACE="ap0"
fi

echo "[+] Bound to Interface: $IFACE"

sysctl -w net.ipv4.ip_forward=1 > /dev/null
iptables -t nat -F

# Intercept port 80 and redirect to our PHP server on port 8080
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080

echo "[+] Portal Engine Active on Port 8080 (Redirected)"
$PREFIX/bin/php -S 0.0.0.0:8080 -t /sdcard/termux_portal/
EOF

chmod +x ~/start.sh
su
clear
pkg install -y dnsmasq
cat << 'EOF' > /sdcard/termux_portal/index.php
<?php
// Handle Android / Apple captive portal background probes instantly
$uri = $_SERVER['REQUEST_URI'] ?? '';
if (strpos($uri, 'generate_204') !== false || strpos($uri, 'gen_204') !== false || strpos($uri, 'ncsi.txt') !== false) {
    header("HTTP/1.1 302 Moved Temporarily");
    header("Location: http://" . $_SERVER['HTTP_HOST'] . "/index.php");
    exit;
}

$db = new SQLite3('/sdcard/termux_portal/system.db');
$db->exec("CREATE TABLE IF NOT EXISTS vouchers (code TEXT PRIMARY KEY, used INTEGER DEFAULT 0, mac TEXT DEFAULT NULL, session_id TEXT DEFAULT NULL, used_at DATETIME)");
$client_ip = $_SERVER['REMOTE_ADDR'];
$client_mac = "UNKNOWN";
$arp_data = @file_get_contents('/proc/net/arp');
if ($arp_data) {
    foreach (explode("\n", $arp_data) as $line) {
        $cols = preg_split('/\s+/', trim($line));
        if (isset($cols[0]) && $cols[0] === $client_ip) { $client_mac = strtoupper($cols[3]); break; }
    }
}
$masked_session_id = strtoupper(substr(md5($client_ip . $client_mac), 0, 10));
$message = ""; $status = "";
if (isset($_POST['voucher'])) {
    $input_code = strtoupper(trim($_POST['voucher']));
    $stmt = $db->prepare("SELECT * FROM vouchers WHERE code = :code");
    $stmt->bindValue(':code', $input_code, SQLITE3_TEXT);
    $result = $stmt->execute()->fetchArray(SQLITE3_ASSOC);
    if (!$result) { $message = "Invalid access voucher."; $status = "error"; }
    elseif ($result['used'] == 1 && $result['mac'] !== $client_mac) { $message = "Voucher bound to another device."; $status = "error"; }
    else {
        if ($result['used'] == 0) {
            $update = $db->prepare("UPDATE vouchers SET used = 1, mac = :mac, session_id = :sid, used_at = DATETIME('now') WHERE code = :code");
            $update->bindValue(':mac', $client_mac, SQLITE3_TEXT);
            $update->bindValue(':sid', $masked_session_id, SQLITE3_TEXT);
            $update->bindValue(':code', $input_code, SQLITE3_TEXT);
            $update->execute();
        }
        if ($client_mac !== "UNKNOWN") {
            exec("iptables -t nat -I PREROUTING -m mac --mac-source $client_mac -j ACCEPT");
            $message = "Authenticated! You can now browse the internet."; $status = "success";
        } else { $message = "Unable to resolve hardware layer."; $status = "error"; }
    }
}
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Wi-Fi Access</title><style>body{font-family:sans-serif;background:#0d1117;color:#c9d1d9;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;}.card{background:#161b22;padding:30px;border-radius:12px;border:1px solid #30363d;width:90%;max-width:360px;text-align:center;}input[type="text"]{width:100%;padding:12px;margin:15px 0;border:1px solid #30363d;background:#0d1117;color:#fff;border-radius:6px;box-sizing:border-box;text-align:center;font-size:18px;text-transform:uppercase;}input[type="submit"]{width:100%;background:#238636;color:white;border:none;padding:12px;border-radius:6px;font-weight:bold;font-size:16px;cursor:pointer;}.alert{padding:10px;margin-bottom:15px;border-radius:6px;font-size:13px;}.error{background:rgba(248,81,73,0.15);color:#f85149;}.success{background:rgba(46,160,67,0.15);color:#3fb950;}</style></head><body><div class="card"><h2>Network Gateway</h2><?php if(!empty($message)):?><div class="alert <?=$status?>"><?=htmlspecialchars($message)?></div><?php endif;?><form method="POST"><input type="text" name="voucher" placeholder="VOUCHER CODE" required autocomplete="off"><input type="submit" value="Connect Device"></form></div></body></html>
EOF

cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

echo "[+] Triggering Android Hotspot..."
am start -n com.android.settings/.TetherSettings > /dev/null 2>&1
sleep 1
input keyevent 20 > /dev/null 2>&1

echo "[+] Waiting for Hotspot Interface..."
COUNTER=0
IFACE=""

while [ $COUNTER -lt 10 ]; do
    IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]|rndis[0-9]' | head -n 1)
    if [ -n "$IFACE" ]; then
        break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if [ -z "$IFACE" ]; then
    IFACE="ap0"
fi

echo "[+] Bound to Interface: $IFACE"

# Get Gateway IP assigned to the interface
GW_IP=$(ip addr show "$IFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
[ -z "$GW_IP" ] && GW_IP="192.168.43.1"

echo "[+] Gateway IP: $GW_IP"

sysctl -w net.ipv4.ip_forward=1 > /dev/null
iptables -t nat -F

# Redirect HTTP (port 80) and DNS (port 53) to local handlers
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 53 -j REDIrell 2>/dev/null || true

# Start Dnsmasq to answer all domain lookups instantly with our gateway IP
pkill dnsmasq 2>/dev/null
echo "address=/#/$GW_IP" > /data/data/com.termux/files/home/dnsmasq.conf
dnsmasq -C /data/data/com.termux/files/home/dnsmasq.conf -i "$IFACE" --except-interface=lo > /dev/null 2>&1

echo "[+] Portal Engine Active. Press CTRL+C to stop."
$PREFIX/bin/php -S 0.0.0.0:8080 -t /sdcard/termux_portal/
EOF

chmod +x ~/start.sh
su
exit
su
exit
cat << 'EOF' > ~/start.sh
#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

echo "[+] Waiting for Active Hotspot Interface..."
echo "[*] Please make sure Mobile Hotspot is turned ON in your phone settings."

IFACE=""
while [ -z "$IFACE" ]; do
    IFACE=$(ip link | grep -E -o 'ap[0-9]|swlan[0-9]|wlan[0-9]|rndis[0-9]' | head -n 1)
    sleep 1
done

echo "[+] Detected Active Interface: $IFACE"

sysctl -w net.ipv4.ip_forward=1 > /dev/null
iptables -t nat -F

# Intercept port 80 traffic and redirect to PHP on port 8080
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080

echo "[+] Portal Engine Active on Port 8080 (Redirected)"
echo "[+] Clients will now get IP addresses from Android and see the portal instantly."
$PREFIX/bin/php -S 0.0.0.0:8080 -t /sdcard/termux_portal/
EOF

chmod +x ~/start.sh
su
exit
su
settings put global captive_portal_mode 0
settings put global tether_offload_disabled 1
settings put global captive_portal_detection_enabled 0
am force-stop com.android.settings
exit
su
settings put global captive_portal_mode 0
settings put global tether_offload_disabled 1
settings put global captive_portal_detection_enabled 0
am force-stop com.android.settings
exit
su
la
ls
exit
