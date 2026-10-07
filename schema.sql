CREATE TABLE IF NOT EXISTS nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_uuid TEXT NOT NULL UNIQUE,
    node_token_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    hostname TEXT NOT NULL,
    location_country TEXT DEFAULT '',
    location_city TEXT DEFAULT '',
    region TEXT DEFAULT '',
    network_name TEXT DEFAULT '',
    cpu_model TEXT DEFAULT '',
    cpu_vendor TEXT DEFAULT '',
    cpu_cores INTEGER DEFAULT 0,
    cpu_threads INTEGER DEFAULT 0,
    cpu_mhz REAL DEFAULT 0,
    ram_total_bytes INTEGER DEFAULT 0,
    storage_total_bytes INTEGER DEFAULT 0,
    os_name TEXT DEFAULT '',
    kernel TEXT DEFAULT '',
    architecture TEXT DEFAULT '',
    ip_address TEXT DEFAULT '',
    first_seen INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    online INTEGER DEFAULT 0,
    latest_json TEXT DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_nodes_uuid ON nodes(node_uuid);
CREATE INDEX IF NOT EXISTS idx_nodes_last_seen ON nodes(last_seen);
