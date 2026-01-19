<?php
// ============================
// DOMAIN DETECTION
// ============================
$host = $_SERVER['HTTP_HOST'] ?? 'localhost';
$host = preg_replace('/:\d+$/', '', $host); // strip port if any

// ============================
// SERVICE DEFINITIONS
// ============================
$services = [
    'Traefik' => [
        'sub' => 'traefik',
        'icon' => 'fa-network-wired',
        'color' => 'text-success',
        'desc' => 'Reverse Proxy & Router',
    ],
    'Portainer' => [
        'sub' => 'portainer',
        'icon' => 'fa-diagram-project',
        'color' => 'text-info',
        'desc' => 'Docker Management UI',
    ],
    'phpMyAdmin' => [
        'sub' => 'pma',
        'icon' => 'fa-database',
        'color' => 'text-warning',
        'desc' => 'MySQL Administration',
    ],
    'Jellyfin' => [
        'sub' => 'jellyfin',
        'icon' => 'fa-film',
        'color' => 'text-danger',
        'desc' => 'Media Streaming Server',
    ],
    'qBittorrent' => [
        'sub' => 'seedbox',
        'icon' => 'fa-download',
        'color' => 'text-warning',
        'desc' => 'Torrent Client',
    ],
    'Immich' => [
        'sub' => 'immich',
        'icon' => 'fa-images',
        'color' => 'text-success',
        'desc' => 'Photo & Video Backup',
    ],
    'Mail' => [
        'sub' => 'mail',
        'icon' => 'fa-envelope-open-text',
        'color' => 'text-primary',
        'desc' => 'Mail Server',
    ],
    'Webmail' => [
        'sub' => 'webmail',
        'icon' => 'fa-inbox',
        'color' => 'text-primary',
        'desc' => 'Roundcube Webmail',
    ],
	'AI Stack' => [
        'sub' => 'ai',
        'icon' => 'fa-brain',
        'color' => 'text-success',
        'desc' => 'AI Models & Chat UI',
    ],
];

// ============================
// URL CHECK FUNCTION
// ============================
function checkService(string $url, int $timeout = 2): bool
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_NOBODY => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => $timeout,
        CURLOPT_CONNECTTIMEOUT => $timeout,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_SSL_VERIFYHOST => false,
    ]);

    curl_exec($ch);
    $ok = !curl_errno($ch);
    curl_close($ch);

    return $ok;
}

// Runtime info (safe, no shell_exec)
$phpVersion   = phpversion();
$phpSapi      = php_sapi_name();
$serverSoft   = $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown';
$serverIP     = $_SERVER['SERVER_ADDR'] ?? 'Unknown';
$docRoot      = $_SERVER['DOCUMENT_ROOT'] ?? 'Unknown';
$os           = PHP_OS_FAMILY;
$loadedExt    = count(get_loaded_extensions());
$memoryLimit  = ini_get('memory_limit');
$uploadMax    = ini_get('upload_max_filesize');
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>GingerStack — System Online</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <!-- Bootstrap 5.3.3 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

    <!-- Font Awesome -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">

    <style>
        html, body {
            height: 100%;
            margin: 0;
        }

        body {
            background-color: #0b0e14;
            color: #e5e7eb;
        }

        main {
            min-height: 100vh;
            padding: 3rem;
            display: flex;
            flex-direction: column;
            gap: 3rem;
        }

        .panel {
            background-color: #111827;
            border: 1px solid #1f2937;
            border-radius: 0.75rem;
            padding: 2rem;
        }

        .panel-title {
            font-weight: 600;
            letter-spacing: 0.04em;
            text-transform: uppercase;
            font-size: 0.85rem;
            color: #9ca3af;
            margin-bottom: 1.5rem;
        }

        .logo {
            max-width: 320px;
            width: 100%;
        }

        .icon {
            width: 1.5rem;
            text-align: center;
        }

        .service-card {
            background-color: #0b1220;
            border: 1px solid #1f2937;
            border-radius: 0.5rem;
            padding: 1.5rem;
            height: 100%;
            transition: border-color 0.15s ease, background-color 0.15s ease;
        }

        .service-card:hover {
            background-color: #0e1628;
            border-color: #374151;
        }

        .service-title {
            font-weight: 600;
        }

        .service-meta {
            font-size: 0.85rem;
            color: #9ca3af;
        }

        .muted {
            color: #9ca3af;
        }
    </style>
</head>
<body>

<main>

    <!-- LOGO -->
    <div class="text-center mb-2">
        <img src="logo.png" alt="GingerStack Logo" class="logo">
    </div>

    <!-- HEADER -->
    <section class="panel d-flex align-items-center justify-content-between flex-wrap gap-3">
        <div>
            <h1 class="h4 mb-1">
                <i class="fa-solid fa-server text-success me-2"></i>
                GingerStack Online
            </h1>
            <div class="muted small">
                Modular self-hosted server stack
            </div>
        </div>

        <span class="badge bg-success fs-6 px-3 py-2">
            <i class="fa-solid fa-circle-check me-2"></i>
            System Ready
        </span>
    </section>

    <!-- RUNTIME INFO -->
    <section class="panel">
        <div class="panel-title">
            <i class="fa-solid fa-microchip me-2"></i>
            Runtime Environment
        </div>

        <div class="row g-3">
            <div class="col-md-4">
                <i class="fa-brands fa-php icon text-info me-2"></i>
                PHP <strong><?= htmlspecialchars($phpVersion) ?></strong> (<?= htmlspecialchars($phpSapi) ?>)
            </div>
            <div class="col-md-4">
                <i class="fa-solid fa-server icon text-primary me-2"></i>
                <?= htmlspecialchars($serverSoft) ?>
            </div>
            <div class="col-md-4">
                <i class="fa-solid fa-desktop icon text-secondary me-2"></i>
                <?= htmlspecialchars($os) ?>
            </div>
            <div class="col-md-4">
                <i class="fa-solid fa-network-wired icon text-warning me-2"></i>
                IP <?= htmlspecialchars($serverIP) ?> <span class="muted">(Docker internal)</span>
            </div>
            <div class="col-md-4">
                <i class="fa-solid fa-puzzle-piece icon text-danger me-2"></i>
                <?= $loadedExt ?> PHP extensions
            </div>
            <div class="col-md-4">
                <i class="fa-solid fa-memory icon text-info me-2"></i>
                Memory limit <?= htmlspecialchars($memoryLimit) ?>
            </div>
            <div class="col-md-4">
                <i class="fa-solid fa-upload icon text-primary me-2"></i>
                Upload max <?= htmlspecialchars($uploadMax) ?>
            </div>
			<div class="col-md-4">
                <i class="fa-solid fa-folder-open icon text-success me-2"></i>
                /root/apps/lamp/www
            </div>
			<div class="col-md-4">
                <i class="fa-solid fa-gear icon text-success me-2"></i>
                /root/apps/lamp/php/conf.d/custom.ini
            </div>
        </div>
    </section>

<!-- SERVICES -->
<section class="panel">
    <div class="panel-title">
        <i class="fa-solid fa-layer-group me-2"></i>
        Services
    </div>

    <div class="row g-4">

        <?php foreach ($services as $name => $svc): ?>
            <?php
                $url = "https://{$svc['sub']}.$host";
                $online = checkService($url);
            ?>
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid <?= $svc['icon'] ?> icon <?= $svc['color'] ?> me-2"></i>
                        <span class="service-title"><?= htmlspecialchars($name) ?></span>
                    </div>

                    <p class="service-meta mb-2">
                        <?= htmlspecialchars($svc['desc']) ?>
                    </p>

                    <p class="mb-3">
                        <a href="<?= htmlspecialchars($url) ?>" target="_blank" class="text-decoration-none">
                            <?= htmlspecialchars($url) ?>
                        </a>
                    </p>

                    <?php if ($online): ?>
                        <span class="badge bg-success">
                            <i class="fa-solid fa-circle-check me-1"></i>
                            Active
                        </span>
                    <?php else: ?>
                        <span class="badge bg-danger">
                            <i class="fa-solid fa-circle-xmark me-1"></i>
                            Offline
                        </span>
                    <?php endif; ?>
                </div>
            </div>
        <?php endforeach; ?>

    </div>
</section>


    <!-- FOOTER -->
    <footer class="text-end muted small">
        <i class="fa-solid fa-mug-hot me-2"></i>
        Built with Docker & Traefik · MIT License · GingerDev0
    </footer>

</main>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
