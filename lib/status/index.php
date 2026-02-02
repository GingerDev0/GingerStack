<?php
function humanBytes($b){
  $u=['B','KB','MB','GB','TB'];
  for($i=0;$b>=1024&&$i<count($u)-1;$i++) $b/=1024;
  return round($b,2).' '.$u[$i];
}

function uptimeHuman($s){
  $d=floor($s/86400); $s%=86400;
  $h=floor($s/3600);  $s%=3600;
  $m=floor($s/60);
  return ($d?"{$d}d ":"").sprintf('%02dh %02dm',$h,$m);
}

if(isset($_GET['stats'])){
  header('Content-Type: application/json');

  /* ================= HOST INFO ================= */

  $hostname = trim(file_get_contents('/host/hostname'));

  $uptime = (int)explode(' ', trim(file_get_contents('/host/proc/uptime')))[0];

  /* ================= CPU ================= */

  $load = sys_getloadavg();
  $cores = (int)trim(shell_exec("nproc 2>/dev/null")) ?: 1;
  $cpuPct = min(100, round(($load[0] / $cores) * 100));

  /* ================= RAM ================= */

  $mem=[];
  foreach(file('/host/proc/meminfo') as $l){
    [$k,$v]=explode(':',$l,2);
    $mem[$k]=(int)filter_var($v,FILTER_SANITIZE_NUMBER_INT)*1024;
  }

  $ramUsed = $mem['MemTotal'] - $mem['MemAvailable'];
  $ramPct  = round($ramUsed / $mem['MemTotal'] * 100);

  /* ================= DISK ================= */

  $diskTotal = disk_total_space('/host/root');
  $diskUsed  = $diskTotal - disk_free_space('/host/root');
  $diskPct   = round($diskUsed / $diskTotal * 100);

  /* ================= NETWORK ================= */

  $rx = $tx = 0;

  foreach(file('/host/proc/net/dev') as $l){
    if(strpos($l,':') === false) continue;

    [$iface,$data] = explode(':',$l,2);
    $iface = trim($iface);

    if($iface === 'lo' || str_starts_with($iface,'docker') || str_starts_with($iface,'veth')) continue;

    $d = preg_split('/\s+/', trim($data));
    $rx += (int)$d[0];
    $tx += (int)$d[8];
  }

  $f = sys_get_temp_dir().'/net.json';
  $now = time();

  $prev = file_exists($f)
    ? json_decode(file_get_contents($f),true)
    : ['rx'=>$rx,'tx'=>$tx,'t'=>$now];

  $dt = max(1, $now - $prev['t']);

  file_put_contents($f, json_encode(['rx'=>$rx,'tx'=>$tx,'t'=>$now]));

  /* ================= OUTPUT ================= */

  echo json_encode([
    'hostname'  => $hostname,
    'uptime'    => uptimeHuman($uptime),
    'load'      => array_map(fn($v)=>round($v,2), $load),
    'cpu'       => $cpuPct,

    'ramPct'    => $ramPct,
    'ramUsed'   => humanBytes($ramUsed),
    'ramTotal'  => humanBytes($mem['MemTotal']),

    'diskPct'   => $diskPct,
    'diskUsed'  => humanBytes($diskUsed),
    'diskTotal' => humanBytes($diskTotal),

    'rx'        => ($rx - $prev['rx']) / $dt,
    'tx'        => ($tx - $prev['tx']) / $dt
  ]);

  exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Server Dashboard</title>
<meta name="viewport" content="width=device-width,initial-scale=1">

<!-- Tailwind -->
<script src="https://cdn.tailwindcss.com"></script>

<!-- Chart.js -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<!-- Font Awesome -->
<link
  rel="stylesheet"
  href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"
  crossorigin="anonymous"
/>

<style>
:root {
  --panel: #0f172a;
  --panel-border: #1e293b;
}
.glass {
  background: linear-gradient(180deg, rgba(15,23,42,.85), rgba(15,23,42,.65));
  border: 1px solid var(--panel-border);
}
.chart-sm { max-height: 120px }
</style>
</head>

<body class="bg-slate-950 text-slate-100 min-h-screen flex flex-col">

<!-- ================= HEADER ================= -->
<header class="border-b border-slate-800 bg-slate-950/80 backdrop-blur">
  <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">

    <div class="flex items-center gap-4">
      <img src="logo.png" class="h-9 w-auto" alt="Logo">
      <div>
        <h1 class="text-lg font-semibold tracking-wide">
          Infrastructure Dashboard
        </h1>
        <div class="text-xs text-slate-400">
          <span id="hostLabel"></span> · uptime <span id="uptimeLabel"></span>
        </div>
      </div>
    </div>

    <div class="text-right">
      <div class="text-xs text-slate-400 uppercase tracking-wider">System Load</div>
      <div id="loadLabel" class="font-mono text-sm"></div>
    </div>

  </div>
</header>

<!-- ================= MAIN ================= -->
<main class="flex-grow max-w-7xl mx-auto px-6 py-6 space-y-6">

<!-- ================= KPI ROW ================= -->
<section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">

<!-- CPU -->
<div class="glass rounded-xl p-4">
  <div class="flex items-center justify-between mb-2">
    <div class="flex items-center gap-2 text-sm text-slate-400">
      <i class="fa-solid fa-microchip"></i> CPU Utilization
    </div>
    <span class="text-xs text-slate-500">%</span>
  </div>
  <canvas id="cpuChart" class="chart-sm mx-auto"></canvas>
  <div id="cpuLabel" class="text-center text-xl font-semibold mt-2"></div>
</div>

<!-- Memory -->
<div class="glass rounded-xl p-4">
  <div class="flex items-center gap-2 text-sm text-slate-400 mb-1">
    <i class="fa-solid fa-memory"></i> Memory Usage
  </div>
  <div id="ramLabel" class="text-sm mb-2"></div>
  <canvas id="ramChart" class="chart-sm"></canvas>
</div>

<!-- Disk -->
<div class="glass rounded-xl p-4">
  <div class="flex items-center gap-2 text-sm text-slate-400 mb-1">
    <i class="fa-solid fa-hard-drive"></i> Disk Usage
  </div>
  <div id="diskLabel" class="text-sm mb-2"></div>
  <canvas id="diskChart" class="chart-sm"></canvas>
</div>

<!-- Network -->
<div class="glass rounded-xl p-4">
  <div class="flex items-center gap-2 text-sm text-slate-400 mb-1">
    <i class="fa-solid fa-network-wired"></i> Network Throughput
  </div>
  <div class="flex justify-between text-sm mb-2">
    <span id="rxLabel">
      <i class="fa-solid fa-arrow-down text-cyan-400"></i>
    </span>
    <span id="txLabel">
      <i class="fa-solid fa-arrow-up text-rose-400"></i>
    </span>
  </div>
  <canvas id="netChart" class="chart-sm"></canvas>
</div>

</section>

<!-- ================= META ================= -->
<section class="flex items-center justify-between text-xs text-slate-500">
  <span>
    <i class="fa-solid fa-rotate-right mr-1"></i>
    Auto refresh every 1 second
  </span>
  <span class="font-mono">
    Live host telemetry
  </span>
</section>

</main>

<!-- ================= FOOTER ================= -->
<footer class="border-t border-slate-800 bg-slate-950/80 backdrop-blur">
  <div class="max-w-7xl mx-auto px-6 py-4 text-xs text-slate-500 flex items-center justify-between">

    <span>
      Powered by <span class="font-semibold text-slate-300">GingerStack</span>
    </span>

    <a
      href="https://github.com/GingerDev0/GingerStack"
      target="_blank"
      class="flex items-center gap-2 hover:text-slate-300 transition"
    >
      <i class="fa-brands fa-github"></i>
      GitHub
    </a>

  </div>
</footer>

<script>
const cpuChart=new Chart(cpuChartCtx=document.getElementById('cpuChart'),{
 type:'doughnut',
 data:{datasets:[{data:[0,100],backgroundColor:['#22d3ee','#020617'],borderWidth:0}]},
 options:{cutout:'75%',plugins:{legend:{display:false}}}
});

function miniLine(ctx,color){
 return new Chart(ctx,{
  type:'line',
  data:{labels:[],datasets:[{data:[],borderColor:color,tension:.4}]},
  options:{animation:false,plugins:{legend:{display:false}},scales:{x:{display:false},y:{display:false}}}
 });
}

const ramChart=miniLine(document.getElementById('ramChart'),'#38bdf8');
const diskChart=miniLine(document.getElementById('diskChart'),'#facc15');

const netChart=new Chart(document.getElementById('netChart'),{
 type:'line',
 data:{labels:[],datasets:[
  {data:[],borderColor:'#22d3ee',tension:.4},
  {data:[],borderColor:'#f43f5e',tension:.4}
 ]},
 options:{animation:false,plugins:{legend:{display:false}},scales:{x:{display:false},y:{display:false}}}
});

function hb(b){
 const u=['B','KB','MB','GB']; let i=0;
 while(b>=1024&&i<u.length-1){b/=1024;i++}
 return b.toFixed(1)+' '+u[i]+'/s';
}

async function refresh(){
 const d=await (await fetch('?stats=1')).json();

 hostLabel.textContent=d.hostname;
 uptimeLabel.textContent=d.uptime;
 loadLabel.textContent=d.load.join(' ');

 cpuChart.data.datasets[0].data=[d.cpu,100-d.cpu];
 cpuChart.update();
 cpuLabel.textContent=d.cpu+'%';

 ramLabel.textContent=`${d.ramUsed} / ${d.ramTotal} (${d.ramPct}%)`;
 diskLabel.textContent=`${d.diskUsed} / ${d.diskTotal} (${d.diskPct}%)`;

 ramChart.data.datasets[0].data.push(d.ramPct);
 diskChart.data.datasets[0].data.push(d.diskPct);
 netChart.data.datasets[0].data.push(d.rx);
 netChart.data.datasets[1].data.push(d.tx);

 rxLabel.textContent='RX '+hb(d.rx);
 txLabel.textContent='TX '+hb(d.tx);

 [ramChart,diskChart,netChart].forEach(c=>{
  c.data.labels.push('');
  if(c.data.labels.length>20){
    c.data.labels.shift();
    c.data.datasets.forEach(ds=>ds.data.shift());
  }
  c.update();
 });
}

refresh();
setInterval(refresh,1000);
</script>
</body>
</html>
