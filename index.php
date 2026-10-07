<?php
declare(strict_types=1);
require __DIR__ . '/config.php';
db();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="theme-color" content="#07090d">
    <title>VyperBD Live Monitor</title>
    <link rel="stylesheet" href="/public/style.css">
</head>
<body>
<header class="topbar">
    <div>
        <div class="brand">VyperBD <span>LIVE MONITOR</span></div>
        <div class="subtitle">Real-time infrastructure status</div>
    </div>
    <div class="topstats">
        <div><b id="onlineCount">0</b><small>ONLINE</small></div>
        <div><b id="totalCount">0</b><small>NODES</small></div>
        <div class="live"><i></i> LIVE</div>
    </div>
</header>

<main>
    <section class="hero">
        <div>
            <h1>Infrastructure Overview</h1>
            <p>Live CPU, RAM, storage, network, uptime, load and hardware information.</p>
        </div>
        <div class="updated">Updated <b id="updated">—</b></div>
    </section>

    <section id="nodes" class="grid">
        <div class="empty">Loading nodes…</div>
    </section>
</main>

<footer>Made by Afifayan | afifayan.fun</footer>
<script src="/public/app.js"></script>
</body>
</html>
