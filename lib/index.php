<?php
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
                <i class="fa-solid fa-folder-open icon text-success me-2"></i>
                <?= htmlspecialchars($docRoot) ?>
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
        </div>
    </section>

    <!-- SERVICES -->
    <section class="panel">
        <div class="panel-title">
            <i class="fa-solid fa-layer-group me-2"></i>
            Services
        </div>

        <div class="row g-4">

            <!-- LAMP -->
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid fa-globe icon text-success me-2"></i>
                        <span class="service-title">LAMP Stack</span>
                    </div>
                    <p class="service-meta mb-2">Apache · PHP · MySQL</p>
                    <p class="mb-3">
                        Core web stack serving this page.
                    </p>
                    <span class="badge bg-success">
                        <i class="fa-solid fa-circle-check me-1"></i>
                        Active
                    </span>
                </div>
            </div>

            <!-- Portainer -->
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid fa-diagram-project icon text-info me-2"></i>
                        <span class="service-title">Portainer</span>
                    </div>
                    <p class="service-meta mb-2">Docker Management UI</p>
                    <p class="mb-3">Manage containers and volumes.</p>
                    <span class="badge bg-secondary">
                        <i class="fa-solid fa-circle-minus me-1"></i>
                        Optional
                    </span>
                </div>
            </div>

            <!-- Jellyfin -->
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid fa-film icon text-danger me-2"></i>
                        <span class="service-title">Jellyfin</span>
                    </div>
                    <p class="service-meta mb-2">Media Streaming Server</p>
                    <p class="mb-3">Stream movies, TV, and music.</p>
                    <span class="badge bg-secondary">
                        <i class="fa-solid fa-circle-minus me-1"></i>
                        Optional
                    </span>
                </div>
            </div>

            <!-- qBittorrent -->
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid fa-download icon text-warning me-2"></i>
                        <span class="service-title">qBittorrent</span>
                    </div>
                    <p class="service-meta mb-2">Seedbox / Download Manager</p>
                    <p class="mb-3">Web-based torrent client.</p>
                    <span class="badge bg-secondary">
                        <i class="fa-solid fa-circle-minus me-1"></i>
                        Optional
                    </span>
                </div>
            </div>

            <!-- Immich -->
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid fa-images icon text-success me-2"></i>
                        <span class="service-title">Immich</span>
                    </div>
                    <p class="service-meta mb-2">Photo & Video Backup</p>
                    <p class="mb-3">Self-hosted Google Photos alternative.</p>
                    <span class="badge bg-secondary">
                        <i class="fa-solid fa-circle-minus me-1"></i>
                        Optional
                    </span>
                </div>
            </div>

            <!-- Mail -->
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid fa-envelope-open-text icon text-primary me-2"></i>
                        <span class="service-title">Mail Stack</span>
                    </div>
                    <p class="service-meta mb-2">poste.io · Roundcube</p>
                    <p class="mb-3">Full mail server and webmail.</p>
                    <span class="badge bg-secondary">
                        <i class="fa-solid fa-circle-minus me-1"></i>
                        Optional
                    </span>
                </div>
            </div>

            <!-- Cowrie -->
            <div class="col-md-4">
                <div class="service-card">
                    <div class="d-flex align-items-center mb-2">
                        <i class="fa-solid fa-user-secret icon text-danger me-2"></i>
                        <span class="service-title">Cowrie Honeypot</span>
                    </div>
                    <p class="service-meta mb-2">SSH Attack Detection</p>
                    <p class="mb-3">Logs and traps malicious SSH attempts.</p>
                    <span class="badge bg-secondary">
                        <i class="fa-solid fa-circle-minus me-1"></i>
                        Optional
                    </span>
                </div>
            </div>

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
