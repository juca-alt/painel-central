/* Painel Central — service worker (PWA) */
/* HTML = network-first (sempre fresco online, cai pro cache offline); demais assets = cache-first. */
var CACHE = "painel-central-v13";
var ASSETS = ["./", "./index.html", "./manifest.json", "./icon-192.png", "./icon-512.png"];

self.addEventListener("install", function(e){
  e.waitUntil(
    caches.open(CACHE).then(function(c){ return c.addAll(ASSETS); }).then(function(){ return self.skipWaiting(); })
  );
});

self.addEventListener("activate", function(e){
  e.waitUntil(
    caches.keys().then(function(ks){
      return Promise.all(ks.filter(function(k){ return k !== CACHE; }).map(function(k){ return caches.delete(k); }));
    }).then(function(){ return self.clients.claim(); })
  );
});

self.addEventListener("fetch", function(e){
  if(e.request.method !== "GET") return;
  var req = e.request;
  var isNav = req.mode === "navigate" || (req.headers.get("accept") || "").indexOf("text/html") >= 0;
  if(isNav){
    e.respondWith(
      fetch(req).then(function(res){
        var cp = res.clone();
        caches.open(CACHE).then(function(c){ c.put(req, cp); });
        return res;
      }).catch(function(){
        return caches.match(req).then(function(h){ return h || caches.match("./index.html"); });
      })
    );
    return;
  }
  e.respondWith(
    caches.match(req).then(function(hit){
      return hit || fetch(req).then(function(res){
        if(res && res.status === 200 && res.type === "basic"){
          var cp = res.clone();
          caches.open(CACHE).then(function(c){ c.put(req, cp); });
        }
        return res;
      }).catch(function(){ return caches.match("./index.html"); });
    })
  );
});
