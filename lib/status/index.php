<?php
// ==================================================
// Helpers
// ==================================================
function readFileSafe($path) {
    return is_readable($path) ? trim(file_get_contents($path)) : null;
}

function bytes($b) {
    $u = ['B','KB','MB','GB','TB'];
    for ($i = 0; $b >= 1024 && $i < count($u)-1; $i++) {
        $b /= 1024;
    }
    return round($b, 2);
}

// ==================================================
// Collect stats
// ==================================================
function getStats() {
    // Hostname
    $hostname = readFileSafe('/host/hostname') ?? gethostname();

    // Uptime
    $uptime = 'N/A';
    if ($u = readFileSafe('/host/proc/uptime')) {
        $s = (int)explode(' ', $u)[0];
        $uptime = sprintf('%dd %02dh %02dm', $s/86400, ($s/3600)%24, ($s/60)%60);
    }

    // CPU
    $load = sys_getloadavg();
    $cores = substr_count(readFileSafe('/host/proc/cpuinfo') ?? '', 'processor');

    // Memory
    $mem = [];
    foreach (file('/host/proc/meminfo') as $line) {
        if (preg_match('/^(\w+):\s+(\d+)/', $line, $m)) {
            $mem[$m[1]] = $m[2] * 1024;
        }
    }
    $memTotal = $mem['MemTotal'] ?? 0;
    $memFree  = $mem['MemAvailable'] ?? 0;
    $memUsed  = $memTotal - $memFree;

    // Disk
    $diskTotal = disk_total_space('/host/root');
    $diskFree  = disk_free_space('/host/root');
    $diskUsed  = $diskTotal - $diskFree;

    // Network
    $rx = $tx = 0;
    foreach (file('/host/proc/net/dev') as $line) {
        if (strpos($line, ':') === false) continue;
        [$iface, $data] = explode(':', $line);
        if (trim($iface) === 'lo') continue;
        $stats = preg_split('/\s+/', trim($data));
        $rx += (int)$stats[0];
        $tx += (int)$stats[8];
    }

    return [
        'hostname' => $hostname,
        'uptime'   => $uptime,
        'cpu'      => $load,
        'cores'    => $cores,
        'memory'   => [
            'used'  => bytes($memUsed),
            'total' => bytes($memTotal)
        ],
        'disk'     => [
            'used'  => bytes($diskUsed),
            'total' => bytes($diskTotal)
        ],
        'network'  => [
            'rx' => bytes($rx),
            'tx' => bytes($tx)
        ],
        'updated'  => date('Y-m-d H:i:s')
    ];
}

// ==================================================
// JSON endpoint (GET auto-refresh)
// ==================================================
if (isset($_GET['data'])) {
    header('Content-Type: application/json');
    echo json_encode(getStats());
    exit;
}

$stats = getStats();
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Status – <?= htmlspecialchars($stats['hostname']) ?></title>

<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<style>
body { background:#0e1117; color:#e6edf3; }
.card { background:#161b22; border:1px solid #222; }
</style>
</head>
<body class="container py-4">

<div class="d-flex align-items-center gap-3 mb-4">
    <img src="logo.png"
         alt="Logo"
         style="height:48px"
         class="img-fluid">

    <h1 class="mb-0">
        <i class="fa-solid fa-server text-secondary"></i>
        <?= htmlspecialchars($stats['hostname']) ?>
    </h1>
</div>

<div class="row g-4">

    <div class="col-md-6">
        <div class="card p-3">
            <h6><i class="fa-solid fa-microchip"></i> CPU Load</h6>
            <canvas id="cpuChart"></canvas>
            <small><?= $stats['cores'] ?> cores</small>
        </div>
    </div>

    <div class="col-md-6">
        <div class="card p-3">
            <h6><i class="fa-solid fa-memory"></i> Memory</h6>
            <canvas id="memChart"></canvas>
        </div>
    </div>

    <div class="col-md-6">
        <div class="card p-3">
            <h6><i class="fa-solid fa-hard-drive"></i> Disk</h6>
            <canvas id="diskChart"></canvas>
        </div>
    </div>

    <div class="col-md-6">
        <div class="card p-3">
            <h6><i class="fa-solid fa-network-wired"></i> Network</h6>
            <canvas id="netChart"></canvas>
        </div>
    </div>

</div>

<div class="text-muted mt-4">
    <i class="fa-regular fa-clock"></i>
    Uptime: <span id="uptime"><?= $stats['uptime'] ?></span> |
    Updated <span id="updated"><?= $stats['updated'] ?></span>
</div>

<script>
const cpuChart = new Chart(cpuChartCanvas = document.getElementById('cpuChart'), {
    type: 'bar',
    data: { labels: ['1m','5m','15m'], datasets: [{ data: <?= json_encode($stats['cpu']) ?> }] }
});

const memChart = new Chart(document.getElementById('memChart'), {
    type: 'doughnut',
    data: { labels: ['Used','Free'], datasets: [{ data: [
        <?= $stats['memory']['used'] ?>,
        <?= $stats['memory']['total'] - $stats['memory']['used'] ?>
    ]}]}
});

const diskChart = new Chart(document.getElementById('diskChart'), {
    type: 'doughnut',
    data: { labels: ['Used','Free'], datasets: [{ data: [
        <?= $stats['disk']['used'] ?>,
        <?= $stats['disk']['total'] - $stats['disk']['used'] ?>
    ]}]}
});

const netChart = new Chart(document.getElementById('netChart'), {
    type: 'bar',
    data: { labels: ['RX','TX'], datasets: [{ data: [
        <?= $stats['network']['rx'] ?>,
        <?= $stats['network']['tx'] ?>
    ]}]}
});

// Auto-refresh via GET
async function refresh() {
    const r = await fetch('?data=1');
    const d = await r.json();

    cpuChart.data.datasets[0].data = d.cpu;
    memChart.data.datasets[0].data = [d.memory.used, d.memory.total - d.memory.used];
    diskChart.data.datasets[0].data = [d.disk.used, d.disk.total - d.disk.used];
    netChart.data.datasets[0].data = [d.network.rx, d.network.tx];

    cpuChart.update();
    memChart.update();
    diskChart.update();
    netChart.update();

    document.getElementById('uptime').textContent = d.uptime;
    document.getElementById('updated').textContent = d.updated;
}

setInterval(refresh, 5000);
</script>

</body>
</html>