const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const fmtBytes = n => {
  n = Number(n)||0; const u=['B','KB','MB','GB','TB']; let i=0;
  while(n>=1024 && i<u.length-1){n/=1024;i++}
  return `${n.toFixed(i?1:0)} ${u[i]}`;
};
const fmtRate = n => {
  n = Number(n)||0;
  if(n>=1e9) return (n/1e9).toFixed(2)+' Gbps';
  if(n>=1e6) return (n/1e6).toFixed(1)+' Mbps';
  if(n>=1e3) return (n/1e3).toFixed(1)+' Kbps';
  return Math.round(n)+' bps';
};
const uptime = s => {
  s=Number(s)||0; const d=Math.floor(s/86400); s%=86400; const h=Math.floor(s/3600); s%=3600; const m=Math.floor(s/60);
  return `${d?d+'d ':''}${h}h ${m}m`;
};
const pct = n => Math.max(0,Math.min(100,Number(n)||0));

function loadClass(v){ return v < 50 ? ['low','LOW'] : v < 80 ? ['mid','MID'] : ['high','HIGH']; }

function render(nodes){
  const el=document.getElementById('nodes');
  document.getElementById('totalCount').textContent=nodes.length;
  document.getElementById('onlineCount').textContent=nodes.filter(n=>Number(n.online)).length;
  if(!nodes.length){el.innerHTML='<div class="empty">No nodes registered yet. Install the agent on a machine to add it automatically.</div>';return}
  el.innerHTML=nodes.map(n=>{
    const m=n.metrics||{}, cpu=pct(m.cpu_usage), ram=pct(m.ram_percent), disk=pct(m.disk_percent);
    const load=Number(m.load_percent ?? cpu); const [lc,lt]=loadClass(load);
    const loc=[n.location_city,n.location_country].filter(Boolean).join(', ') || 'Location unavailable';
    const net=n.network_name||'Network';
    return `<article class="node ${n.online?'online':'offline'}">
      <div class="nodehead"><div><div class="node-name">${esc(n.name)}</div><div class="location">${esc(loc)} · ${esc(net)}</div></div><div class="status">${n.online?'● ONLINE':'● OFFLINE'}</div></div>
      <div class="cpu"><div class="model">${esc(n.cpu_model||'CPU information unavailable')}</div>
        <div class="meta">${esc(n.cpu_vendor||'Unknown')} · ${n.cpu_cores||0} cores · ${n.cpu_threads||0} threads · ${Number(n.cpu_mhz||0).toFixed(0)} MHz</div>
      </div>
      <div class="metrics">
        <div class="metric"><div class="label">CPU</div><div class="value">${cpu.toFixed(0)}%</div><div class="bar"><i style="width:${cpu}%"></i></div></div>
        <div class="metric"><div class="label">RAM</div><div class="value">${ram.toFixed(0)}%</div><div class="bar"><i style="width:${ram}%"></i></div></div>
        <div class="metric"><div class="label">Storage</div><div class="value">${disk.toFixed(0)}%</div><div class="bar"><i style="width:${disk}%"></i></div></div>
        <div class="metric"><div class="label">Ping</div><div class="value">${Number(m.ping_ms||0).toFixed(0)} ms</div><div class="meta">${Number(m.packet_loss||0).toFixed(0)}% loss</div></div>
      </div>
      <div class="load"><span>Load <b class="${lc}">${lt}</b></span><span>${load.toFixed(0)}% · avg ${Number(m.load_avg||0).toFixed(2)}</span></div>
      <div class="details">
        <div>RAM <b>${fmtBytes(m.ram_used_bytes)} / ${fmtBytes(n.ram_total_bytes)}</b></div>
        <div>Storage <b>${fmtBytes(m.disk_used_bytes)} / ${fmtBytes(n.storage_total_bytes)}</b></div>
        <div>Network ↓ <b>${fmtRate(m.rx_bps)}</b></div>
        <div>Network ↑ <b>${fmtRate(m.tx_bps)}</b></div>
        <div>Link <b>${esc(m.link_speed||'Unknown')}</b></div>
        <div>Uptime <b>${uptime(m.uptime_seconds)}</b></div>
        <div>OS <b>${esc(n.os_name||'Unknown')}</b></div>
        <div>Kernel <b>${esc(n.kernel||'Unknown')}</b></div>
        <div>Architecture <b>${esc(n.architecture||'Unknown')}</b></div>
        <div>IP <b>${esc(n.ip_address||'Hidden')}</b></div>
      </div>
    </article>`;
  }).join('');
}
async function refresh(){
  try{
    const r=await fetch('/api.php?action=nodes',{cache:'no-store'}); const d=await r.json();
    if(d.ok){render(d.nodes);document.getElementById('updated').textContent=new Date().toLocaleTimeString();}
  }catch(e){document.getElementById('updated').textContent='Connection error'}
}
refresh(); setInterval(refresh,2000);
