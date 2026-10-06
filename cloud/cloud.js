var ENGINE_VERSION = 10;
function md5(s){return sendMessage('md5',String(s));}
function sha1(s){return sendMessage('sha1',String(s));}
function b64d(s){return sendMessage('b64decode',String(s));}
function now(){return parseInt(sendMessage('now',''));}
function dev(){return JSON.parse(sendMessage('device',''));}
function ck(){return sendMessage('cookie','');}
function mode(){return sendMessage('mode','');}
function cacheGet(k){var v=sendMessage('cacheGet',k);return v?v:null;}
function cacheSet(k,v,ttl){sendMessage('cacheSet',JSON.stringify({k:k,v:v,ttl:ttl||600}));}
function log(l,m){sendMessage('log',JSON.stringify({l:l,m:m}));}
function qs(o){return Object.keys(o).filter(k=>o[k]!==null&&o[k]!==undefined&&o[k]!=='').map(k=>encodeURIComponent(k)+'='+encodeURIComponent(o[k])).join('&');}
function pick(o,ks){for(var i=0;i<ks.length;i++){if(o[ks[i]]!==undefined&&o[ks[i]]!==null&&o[ks[i]]!=='')return o[ks[i]];}return '';}

var SIGNERS = {
  md5_concat:function(p,cfg){
    var ks=Object.keys(p).filter(k=>k!=='signature'&&k!==cfg.signKey&&p[k]!==null&&p[k]!==undefined).sort();
    var s=cfg.salt; ks.forEach(k=>{s+=k+'='+p[k];}); s+=cfg.salt;
    var v=md5(s); return cfg.uppercase!==false?v.toUpperCase():v;
  },
  sha1_concat:function(p,cfg){
    var ks=Object.keys(p).filter(k=>k!=='signature'&&p[k]!==null&&p[k]!==undefined).sort();
    var s=cfg.salt; ks.forEach(k=>{s+=k+'='+p[k];}); s+=cfg.salt;
    return sha1(s);
  },
  none:function(){return null;}
};
function applySign(p,cfg){
  if(!cfg.signType)return p;
  var fn=SIGNERS[cfg.signType]; if(!fn)return p;
  var v=fn(p,cfg); if(v)p[cfg.signKey||'signature']=v;
  return p;
}

var SEARCH_SOURCES = [
  {id:'web_v2',host:'complexsearch.kugou.com',path:'/v2/search/song',
    signType:'md5_concat',signKey:'signature',
    salt:'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt',
    platform:'WebFilter',appid:'1014',clientver:'2000',srcappid:'2919',platid:'4',priority:100},
  {id:'web_v2_alt1',host:'complexsearch.kugou.com',path:'/v2/search/song',
    signType:'md5_concat',signKey:'signature',
    salt:'LnT6xpN3khm36zse0QzvmgTZ3waWdRSA',
    platform:'WebFilter',appid:'1014',clientver:'2000',srcappid:'2919',platid:'4',priority:90},
  {id:'web_v2_alt2',host:'complexsearch.kugou.com',path:'/v2/search/song',
    signType:'md5_concat',signKey:'signature',
    salt:'Fdk7zq9khefm5oa1wsz3j8hb4c0eixqt',
    platform:'WebFilter',appid:'1014',clientver:'2000',srcappid:'2919',platid:'4',priority:80},
  {id:'mobile_v3',host:'mobilecdn.kugou.com',path:'/api/v3/search/song',
    signType:'none',platform:'AndroidFilter',appid:'1005',clientver:'11530',
    srcappid:'2919',platid:'4',priority:70},
  {id:'lite_v2',host:'complexsearch.kugou.com',path:'/v2/search/song',
    signType:'md5_concat',signKey:'signature',
    salt:'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt',
    platform:'lite',appid:'1014',clientver:'2000',srcappid:'2919',platid:'4',
    priority:110,onlyMode:'lite'}
];
function getSourceScore(id){var raw=cacheGet('score_'+id);if(!raw)return{ok:0,fail:0};try{return JSON.parse(raw);}catch(_){return{ok:0,fail:0};}}
function updateScore(id,ok){var s=getSourceScore(id);if(ok)s.ok=(s.ok||0)+1;else s.fail=(s.fail||0)+1;cacheSet('score_'+id,JSON.stringify(s),86400);}
function orderSources(list,modeId){
  return list.filter(s=>!s.onlyMode||s.onlyMode===modeId)
    .map(s=>{var sc=getSourceScore(s.id);var rate=sc.ok/Math.max(1,sc.ok+sc.fail);
      var score=(s.priority||50)*0.6+rate*100*0.4;return Object.assign({},s,{_score:score});})
    .sort((a,b)=>b._score-a._score);
}

var MODES = {
  standard:{id:'standard',name:'普通版',icon:'music_note',desc:'标准酷狗，曲库最全',
    platform:'WebFilter',appid:'1014',clientver:'2000',srcappid:'2919',platid:'4',
    guestParams:{userid:'0',token:''}},
  lite:{id:'lite',name:'概念版',icon:'diamond',desc:'概念版，VIP 权益更友好',
    platform:'lite',appid:'1014',clientver:'2000',srcappid:'2919',platid:'4',
    guestParams:{userid:'0',token:''}}
};
function modeCfg(id){var m=MODES[id]||MODES.standard;return{id:m.id,name:m.name,icon:m.icon,desc:m.desc,hasCookie:ck().length>0,isGuest:ck().length===0};}
function user(cfg){var c=ck();if(!c||!c.length)return cfg.guestParams;var u='',t='';c.split(';').forEach(function(p){var kv=p.trim().split('=');if(kv[0]==='userid')u=kv[1]||'';if(kv[0]==='token')t=kv[1]||'';});return{userid:u||cfg.guestParams.userid,token:t||cfg.guestParams.token};}
function ckh(){var c=ck();if(c&&c.length)return c;var d=dev();return 'kg_mid='+d.mid+'; kg_dfid='+d.dfid;}

function buildSearch(src,input){
  var d=dev(),cfg=MODES[mode()]||MODES.standard,u=user(cfg);
  var p={srcappid:src.srcappid,clientver:src.clientver,appid:src.appid,platid:src.platid,
    userid:u.userid,token:u.token,mid:d.mid,dfid:d.dfid,uuid:d.uuid,
    clienttime:String(Math.floor(now()/1000)),keyword:input.keyword,
    page:String(input.page||1),pagesize:String(input.pagesize||30),
    bitrate:'0',isfuzzy:'0',inputtype:'0',platform:src.platform,filter:'10'};
  applySign(p,src);
  return{sourceId:src.id,url:'https://'+src.host+src.path+'?'+qs(p),method:'GET',
    headers:{'Cookie':ckh(),'Referer':'https://www.kugou.com/'}};
}
function parseSearch(raw){
  try{var d=typeof raw==='string'?JSON.parse(raw):raw;
    var list=(d.data&&(d.data.lists||d.data.info))||[];
    return list.map(function(j){
      var cover=pick(j,['img','cover','Image'])||'';
      if(cover.indexOf('{size}')>=0)cover=cover.replace('{size}','400');
      var dur=parseInt(pick(j,['duration','timelength'])||0);
      if(dur>10000)dur=Math.floor(dur/1000);
      return{hash:pick(j,['hash','FileHash','filehash']),name:pick(j,['songname','name','SongName']),
        singer:pick(j,['singername','singer','SingerName']),album:pick(j,['album_name','albumName']),
        albumId:String(pick(j,['album_id','AlbumID'])),duration:dur,cover:cover};
    }).filter(s=>s.hash);
  }catch(e){return null;}
}

function buildSongUrl(input){
  var d=dev(),cfg=MODES[mode()]||MODES.standard,u=user(cfg);
  var p={r:'play/getdata',hash:input.hash,album_id:input.albumId||'',dfid:d.dfid,mid:d.mid,
    platid:cfg.platid,userid:u.userid,token:u.token,_:String(now())};
  if(cfg.platform==='lite'){p.platform='lite';p.appid='1014';p.clientver='2000';}
  return{url:'https://wwwapi.kugou.com/yy/index.php?'+qs(p),method:'GET',
    headers:{'Cookie':ckh(),'Referer':'https://www.kugou.com/'}};
}
function parseSongUrl(raw){
  var d=JSON.parse(raw);
  if(d.data&&d.data.play_url)return{url:d.data.play_url};
  if(d.err_code===20028||(d.data&&d.data.play_url===''))
    return{error:'VIP_ONLY',message:'该歌曲需要 VIP'};
  return null;
}

var _lc=null;
function buildLyric(input){
  if(!_lc){var d=dev();
    var p={ver:'1',man:'yes',client:'mobi',hash:input.hash,album_id:input.albumId||'',
      duration:String((input.duration||0)*1000),mid:d.mid};
    return{url:'https://krcs.kugou.com/search?'+qs(p),method:'GET',headers:{}};}
  var p2={ver:'1',client:'mobi',id:String(_lc.id),accesskey:String(_lc.accesskey),fmt:'lrc',charset:'utf8'};
  return{url:'https://krcs.kugou.com/download?'+qs(p2),method:'GET',headers:{}};
}
function parseLyric(raw){
  var d=JSON.parse(raw);
  if(d.candidates){var c=d.candidates[0];if(!c)return null;_lc=c;return{__continue:true};}
  _lc=null;if(!d.content)return null;return b64d(d.content);
}

function buildRanks(){
  return{url:'http://mobilecdnbj.kugou.com/api/v3/rank/list?'+qs({
    version:'9108',plat:'0',showtype:'2',parentid:'0',apiver:'6',
    area_code:'1',msg_override:'1',withsong:'1'}),method:'GET',headers:{}};
}
function parseRanks(raw){
  var d=JSON.parse(raw),list=(d.data&&d.data.info)||[];
  return list.map(function(r){
    var cover=r.imgurl?r.imgurl.replace('{size}','400'):'';
    return{id:String(r.rankid),name:r.rankname,cover:cover,
      updateTime:r.update_time||'',songCount:r.songcount||0};
  });
}
function buildRankSongs(input){
  return{url:'http://mobilecdnbj.kugou.com/api/v3/rank/song?'+qs({
    version:'9108',plat:'0',pagesize:'100',area_code:'1',page:'1',
    rankid:input.rankId,with_cover:'1',apiver:'6',msg_override:'1',withsong:'1'}),method:'GET',headers:{}};
}
function parseRankSongs(raw){
  var d=JSON.parse(raw),list=(d.data&&d.data.info)||[];
  return list.map(function(j,i){
    var cover=j.cover||j.img||'';
    if(cover.indexOf('{size}')>=0)cover=cover.replace('{size}','400');
    var dur=parseInt(j.duration||0);
    if(dur>10000)dur=Math.floor(dur/1000);
    return{hash:j.hash||'',name:j.songname||j.filename||'',
      singer:j.singername||j.author_name||'',album:j.album_name||'',
      albumId:String(j.album_id||''),duration:dur,cover:cover,rank:i+1};
  }).filter(s=>s.hash);
}
function parseLrc(raw){
  try{var lines=raw.split('\n'),out=[],re=/\[(\d+):(\d+)(?:[.:](\d+))?\]/g;
    for(var i=0;i<lines.length;i++){var line=lines[i];
      var txt=line.replace(re,'').trim();if(!txt)continue;re.lastIndex=0;
      var times=[],m;
      while((m=re.exec(line))!==null){
        var min=parseInt(m[1]),sec=parseInt(m[2]);
        var ms=m[3]?parseInt(m[3].padEnd(3,'0').slice(0,3)):0;
        times.push(min*60000+sec*1000+ms);}
      for(var k=0;k<times.length;k++)out.push({t:times[k],text:txt});}
    out.sort((a,b)=>a.t-b.t);return out;
  }catch(e){return[];}
}

function handle(op,stage,arg){
  try{
    if(op==='list_modes')return Object.keys(MODES).map(k=>modeCfg(k));
    if(op==='mode_config')return modeCfg(arg&&arg.mode);
    if(op==='search'){
      if(stage==='build'){
        var ordered=orderSources(SEARCH_SOURCES,mode());
        var ckKey='search_'+mode()+'_'+arg.keyword+'_'+(arg.page||1);
        var cached=cacheGet(ckKey);
        if(cached){try{var parsed=JSON.parse(cached);if(parsed&&parsed.length)return{__cache:parsed};}catch(_){}}
        return ordered.map(s=>buildSearch(s,arg));
      }
      if(stage==='parse'){
        var sid=arg.sourceId,parsed=parseSearch(arg.raw);
        if(parsed&&parsed.length){
          updateScore(sid,true);
          var k='search_'+mode()+'_'+arg.keyword+'_'+(arg.page||1);
          cacheSet(k,JSON.stringify(parsed),600);
          return parsed;
        }
        updateScore(sid,false);return null;
      }
    }
    if(op==='song_url'){
      if(stage==='build')return[buildSongUrl(arg)];
      if(stage==='parse')return parseSongUrl(arg.raw);
    }
    if(op==='lyric')return stage==='build'?buildLyric(arg):parseLyric(arg);
    if(op==='ranks')return stage==='build'?buildRanks():parseRanks(arg);
    if(op==='rank_songs')return stage==='build'?buildRankSongs(arg):parseRankSongs(arg);
    if(op==='parse_lrc')return parseLrc(arg);
  }catch(e){log('error',String(e));return{error:String(e)};}
  return null;
}
