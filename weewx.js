/* javascript for weewx.com web site */
/* author: matthew wall, 2013 */

/* list of weather stations displayed on the showcase page. */
/* for each station specify a description, url, and screenshot. */
var sites = [
  { description: 'Hood River, Oregon',
    url: 'http://www.threefools.org/weewx/',
    screenshot: 'hoodriver.png' },
  { description: 'ruskers.com',
    url: 'http://wx.ruskers.com/',
    screenshot: 'ruskers.png' },
  { description: 'Royston, UK',
    url: 'http://www.dajda.net/',
    screenshot: 'royston.png' },
  { description: 'Wetter-Pattensen',
    url: 'http://wetter-pattensen.de',
    screenshot: 'pattensen.png' },
  { description: 'Solås, Ålgård, Norway',
    url: 'http://www.kanonbra.com/veret/',
    screenshot: 'solas.png' },
  { description: 'AmatYr - Naustvika',
    url: 'http://yr.hveem.no',
    screenshot: 'amatyr.png' },
  { description: 'Keswick, Cumbria',
    url: 'http://www.ehideaway.plus.com/weather',
    screenshot: 'keswick.png' },
  { description: 'Schoenau, Bavaria',
    url: 'http://mayerh.no-ip.org/',
    screenshot: 'mayers.png' },
  { description: 'Moni, Limassol, Cyprus',
    url: 'http://asrm.dyndns-pics.com/weewxweather/smartphone/index.html',
    screenshot: 'monicyprus.png' },
  { description: 'Nishinomiya Hyogo Japan',
    url: 'http://www.swetake.com/weather/site/index.html',
    screenshot: 'nishinomiya.png' },
  { description: 'tino',
    url: 'http://tino.cc/wetter/aktuelles-wetter/',
    screenshot: 'tino.png' },
  { description: 'Yubileyny Moscow',
    url: 'http://yubileyny.meteoweb.ru/',
    screenshot: 'yubileyny.png' },
  { description: 'Sunbury on Thames',
    url: 'http://www.stumpey.co.uk/',
    screenshot: 'sunbury.png' },
  { description: 'Narangba, Queensland, Australia',
    url: 'http://www.therodericks.id.au/saratoga/wxindex.php',
    screenshot: 'narangba.png' },
  { description: 'Ballymote, Sligo, Ireland',
    url: 'http://goodsquishy.com/weather/',
    screenshot: 'ballymote.png' },
  { description: 'Berkeley, California',
    url: 'http://weather.mindfart.com/',
    screenshot: 'berkeley.png' },
  { description: 'Klettur í Geiradal',
    url: 'http://www.alta.is/klettur/',
    screenshot: 'klettur.png' },
  { description: 'Palo Alto, California',
    url: 'http://kj6etn.palo-alto.ca.us/',
    screenshot: 'paloalto.png' },
  { description: 'Palomino Valley, Nevada',
    url: 'http://www.palominovalleyweather.com/',
    screenshot: 'palominovalley.png' },
  { description: 'Penfield, New York',
    url: 'http://weather.mulveyfamily.com/',
    screenshot: 'penfield.png' },
  { description: 'Sønderstrand, Sæby, Danmark',
    url: 'http://jensjk.dk/saeby/',
    screenshot: 'sonderstrand.png' },
  { description: 'Kongsvinger, Norway',
    url: 'http://www.bogeraasen.net/index-en.php',
    screenshot: 'kongsvinger.png' },
  { description: 'Trout River, Quebec',
    url: 'http://www.scratchypants.com/wx/',
    screenshot: 'troutriver.png' },
  { description: 'eMBeZon, Ypenburg, Holland',
    url: 'http://www.embezon.nl/embezon/WEATHER_data/',
    screenshot: 'ypenburg.png' },
  { description: 'Meteo Saint-Sulpice',
    url: 'http://meteosaintsulpice.free.fr/now.php',
    screenshot: 'meteosaintsulpice.png' },
  { description: 'Harper, Texas',
    url: 'http://weather.janeandjohn.org/',
    screenshot: 'harper.png' },
  { description: 'Grayson Highlands, Virginia',
    url: 'http://weather.graysonfriends.org/',
    screenshot: 'grayson-highlands.png' },
  { description: 'East Uniacke, NS',
    url: 'http://camera.neutronstar.ca/weewx/index.html',
    screenshot: 'uniacke.png' },
  { description: 'Surry, Virginia',
    url: 'http://weather.chippokes.com/',
    screenshot: 'surry.png' },
  { description: 'Bacchus Marsh, Victoria, AU',
    url: 'http://wotid.dyndns.org/weather/',
    screenshot: 'bacchusmarsh.png' },
             ];

/* inject navigation links into the navigation div */
function populate_header(page) {
    var navbar = document.getElementById('navigation');
    if(navbar) {
        var navbar_html = "\
<div class='navitem'>\
<a href='/'><img src='weewx-logo-128x128.png' class='logo' alt='weewx' /></a>\
</div>\
<div class='navitem'>\
<a href='stations.html'>MAP</a>\
</div>\
<div class='navitem'>\
<a href='showcase.html'>SHOWCASE</a>\
</div>\
<div class='navitem'>\
<a href='code.html'>CODE</a>\
</div>\
<div class='navitem'>\
<a href='hardware.html'>HARDWARE</a>\
</div>\
<div class='navitem'>\
<a href='support.html'>SUPPORT</a>\
</div>\
<div class='navitem'>\
<a href='news.html'>NEWS</a>\
</div>\
<div class='navitem'>\
<a href='docs.html'>DOCS</a>\
</div>\
<div class='navitem'>\
<a href='https://sourceforge.net/projects/weewx/files/'>DOWNLOAD</a>\
</div>";
        tmp = document.createElement('div');
        tmp.setAttribute('class', 'nav');
        tmp.innerHTML = navbar_html;
        navbar.appendChild(tmp);
    }
}

/* inject the showcase web sites into the showcase div */
function populate_showcase() {
    var elem = document.getElementById('showcase');
    if(!elem) {
        return;
    }
    html = '';
    for(var i=0; i<sites.length; i++) {
        html += "<div class='showcase_item'>";
        html += "<a href='" + sites[i].url + "'>" + sites[i].description;
        html += "</a><br/>";
        html += "<a href='screenshots/" + sites[i].screenshot + "'>";
        html += "<img src='screenshots/" + sites[i].screenshot + "'";
        html += " class='screenshot' /></a>";
        html += "</div>";
    }
    elem.innerHTML = html;
}

/* inject a subset of showcase web sites into the screenshots div. */
/* maxnum is the maximum number of thumbnails to display. */
/* if rnd is specified, then choose randomly. */
function populate_screenshots(maxnum, rnd) {
    var elem = document.getElementById('screenshots');
    if(!elem) {
        return;
    }
    if(!maxnum) {
        maxnum = sites.length;
    }
    var indices = Array();
    if(rnd) {
        var n = 0;
        for(var i=0; i<sites.length && n<maxnum; i++) {
            if(Math.random() > 0.5) {
                indices[n] = i;
                n += 1;
            }
        }
    } else {
        for(var i=0; i<maxnum; i++) {
            indices[i] = i;
        }
    }
    html = '';
    for(var i=0; i<indices.length; i++) {
        html += "<a href='screenshots/"+sites[indices[i]].screenshot+"'>";
        html += "<img src='screenshots/"+sites[indices[i]].screenshot+"'";
        html += " class='screenshot' /></a><br/>";
    }
    elem.innerHTML = html;
}
