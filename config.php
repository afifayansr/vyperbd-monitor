<?php
declare(strict_types=1);

const VYPERBD_DATA_DIR = __DIR__ . '/data';
const VYPERBD_DB = VYPERBD_DATA_DIR . '/monitor.sqlite';

// Set to false if you do not want the dashboard to display public IP addresses.
const SHOW_PUBLIC_IP = true;

// A node is considered offline after this many seconds without a heartbeat.
const OFFLINE_AFTER = 10;

if (!is_dir(VYPERBD_DATA_DIR)) {
    mkdir(VYPERBD_DATA_DIR, 0750, true);
}

function db(): PDO {
    static $pdo = null;
    if ($pdo instanceof PDO) return $pdo;

    $pdo = new PDO('sqlite:' . VYPERBD_DB, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $pdo->exec('PRAGMA journal_mode=WAL;');
    $pdo->exec('PRAGMA busy_timeout=5000;');

    $schema = file_get_contents(__DIR__ . '/schema.sql');
    $pdo->exec($schema);

    return $pdo;
}

function json_input(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw ?: '{}', true);
    return is_array($data) ? $data : [];
}

function out(array $data, int $status = 200): never {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function token_hash(string $token): string {
    return hash('sha256', $token);
}

function clean_string(mixed $v, int $max = 500): string {
    $s = trim((string)$v);
    return mb_substr($s, 0, $max);
}

function number_value(mixed $v, float $default = 0): float {
    return is_numeric($v) ? (float)$v : $default;
}

function int_value(mixed $v, int $default = 0): int {
    return is_numeric($v) ? (int)$v : $default;
}
