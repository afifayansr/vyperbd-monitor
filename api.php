<?php
declare(strict_types=1);
require __DIR__ . '/config.php';

$action = $_GET['action'] ?? '';

if ($action === 'register') {
    $d = json_input();

    $uuid = clean_string($d['node_uuid'] ?? '', 100);
    $name = clean_string($d['name'] ?? ($d['hostname'] ?? 'Unknown Node'), 100);
    $token = clean_string($d['token'] ?? '', 200);

    if ($uuid === '' || $token === '') out(['ok'=>false,'error'=>'node_uuid and token are required'], 400);

    $pdo = db();
    $now = time();
    $stmt = $pdo->prepare('SELECT id FROM nodes WHERE node_uuid = ? LIMIT 1');
    $stmt->execute([$uuid]);
    $existing = $stmt->fetch();

    if ($existing) {
        $stmt = $pdo->prepare('UPDATE nodes SET name=?, hostname=?, node_token_hash=?, last_seen=?, online=1 WHERE node_uuid=?');
        $stmt->execute([$name, $name, token_hash($token), $now, $uuid]);
    } else {
        $stmt = $pdo->prepare('INSERT INTO nodes (node_uuid,node_token_hash,name,hostname,first_seen,last_seen,online) VALUES (?,?,?,?,?,?,1)');
        $stmt->execute([$uuid, token_hash($token), $name, $name, $now, $now]);
    }

    out(['ok'=>true,'message'=>'Node registered']);
}

if ($action === 'heartbeat') {
    $d = json_input();
    $uuid = clean_string($d['node_uuid'] ?? '', 100);
    $token = clean_string($d['token'] ?? '', 200);

    if ($uuid === '' || $token === '') out(['ok'=>false,'error'=>'authentication required'], 401);

    $pdo = db();
    $stmt = $pdo->prepare('SELECT * FROM nodes WHERE node_uuid=? LIMIT 1');
    $stmt->execute([$uuid]);
    $node = $stmt->fetch();

    if (!$node || !hash_equals($node['node_token_hash'], token_hash($token))) {
        out(['ok'=>false,'error'=>'invalid node credentials'], 403);
    }

    $allowed = [
        'name','hostname','location_country','location_city','region','network_name',
        'cpu_model','cpu_vendor','cpu_cores','cpu_threads','cpu_mhz',
        'ram_total_bytes','storage_total_bytes','os_name','kernel','architecture','ip_address'
    ];

    $set = ['last_seen = ?', 'online = 1', 'latest_json = ?'];
    $values = [time(), json_encode($d, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)];

    foreach ($allowed as $key) {
        if (array_key_exists($key, $d)) {
            $set[] = "$key = ?";
            $values[] = is_string($d[$key]) ? clean_string($d[$key]) : (is_numeric($d[$key]) ? $d[$key] : '');
        }
    }
    $values[] = $uuid;

    $sql = 'UPDATE nodes SET ' . implode(', ', $set) . ' WHERE node_uuid = ?';
    $pdo->prepare($sql)->execute($values);

    out(['ok'=>true]);
}

if ($action === 'nodes') {
    $pdo = db();
    $rows = $pdo->query('SELECT * FROM nodes ORDER BY name COLLATE NOCASE')->fetchAll();
    $now = time();

    foreach ($rows as &$row) {
        $row['online'] = (($now - (int)$row['last_seen']) <= OFFLINE_AFTER) ? 1 : 0;
        $latest = json_decode($row['latest_json'] ?: '{}', true);
        $row['metrics'] = is_array($latest) ? $latest : [];
        unset($row['latest_json'], $row['node_token_hash']);
        if (!SHOW_PUBLIC_IP) $row['ip_address'] = '';
    }

    out([
        'ok'=>true,
        'server_time'=>time(),
        'nodes'=>$rows
    ]);
}

out(['ok'=>false,'error'=>'unknown action'], 404);
