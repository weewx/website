/* javascript for weewx.com web site */
/* author: matthew wall, 2013 */

/* list of weather stations displayed on the showcase page. */
/* for each station specify a description, url, and screenshot. */
var sites = [
    {
        description: 'Hood River, Oregon',
        url: 'http://www.threefools.org/weewx/',
        screenshot: 'hoodriver.png'
    },
    {
        description: 'Belchertown, MA',
        url: 'http://belchertownweather.com/',
        screenshot: 'belchertown.png'
    },
    {
        description: 'Claydons, UK',
        url: 'https://claydonsweather.org.uk/',
        screenshot: 'claydons.png'
    },
    {
        description: 'Royston, UK',
        url: 'http://www.dajda.net/',
        screenshot: 'royston.png'
    },
    {
        description: 'ruskers.com',
        url: 'http://wx.ruskers.com/',
        screenshot: 'ruskers.png'
    },
    {
        description: 'Wetter-Pattensen',
        url: 'http://wetter-pattensen.de',
        screenshot: 'pattensen.png'
    },
    {
        description: 'Solås, Ålgård, Norway',
        url: 'http://www.kanonbra.com/veret/',
        screenshot: 'solas.png'
    },
    {
        description: 'AmatYr - Naustvika',
        url: 'http://yr.hveem.no',
        screenshot: 'amatyr.png'
    },
    {
        description: 'Meteo Saint-Sulpice',
        url: 'http://meteosaintsulpice.free.fr/now.php',
        screenshot: 'meteosaintsulpice.png'
    },
    {
        description: 'Nishinomiya Hyogo Japan',
        url: 'http://www.swetake.com/weather/site/index.html',
        screenshot: 'nishinomiya.png'
    },
    {
        description: 'Tinos Wetterseite',
        url: 'https://tino.cc',
        screenshot: 'tino.png'
    },
    {
        description: 'Yubileyny Moscow',
        url: 'http://yubileyny.meteoweb.ru/',
        screenshot: 'yubileyny.png'
    },
    {
        description: 'Narangba, Queensland, Australia',
        url: 'http://www.therodericks.id.au/saratoga/wxindex.php',
        screenshot: 'narangba.png'
    },
    {
        description: 'Ballymote, Sligo, Ireland',
        url: 'http://goodsquishy.com/weather/',
        screenshot: 'ballymote.png'
    },
    {
        description: 'Berkeley, California',
        url: 'http://weather.mindfart.com/',
        screenshot: 'berkeley.png'
    },
    {
        description: 'Palo Alto, California',
        url: 'http://kj6etn.palo-alto.ca.us/',
        screenshot: 'paloalto.png'
    },
    {
        description: 'Palomino Valley, Nevada',
        url: 'http://www.palominovalleyweather.com/',
        screenshot: 'palominovalley.png'
    },
    {
        description: 'Penfield, New York',
        url: 'http://weather.mulveyfamily.com/',
        screenshot: 'penfield.png'
    },
    {
        description: 'Sønderstrand, Sæby, Danmark',
        url: 'http://jensjk.dk/saeby/',
        screenshot: 'sonderstrand.png'
    },
    {
        description: 'Kongsvinger, Norway',
        url: 'http://www.bogeraasen.net/index-en.php',
        screenshot: 'kongsvinger.png'
    },
    {
        description: 'Trout River, Quebec',
        url: 'http://www.scratchypants.com/wx/',
        screenshot: 'troutriver.png'
    },
    {
        description: 'eMBeZon, Ypenburg, Holland',
        url: 'http://www.embezon.nl/embezon/WEATHER_data/',
        screenshot: 'ypenburg.png'
    },
    {
        description: 'Harper, Texas',
        url: 'http://weather.janeandjohn.org/',
        screenshot: 'harper.png'
    },
    {
        description: 'Grayson Highlands, Virginia',
        url: 'http://weather.graysonfriends.org/',
        screenshot: 'grayson-highlands.png'
    },
    {
        description: 'Surry, Virginia',
        url: 'http://weather.chippokes.com/',
        screenshot: 'surry.png'
    },
    {
        description: 'Bacchus Marsh, Victoria, AU',
        url: 'http://wotid.dyndns.org/weather/',
        screenshot: 'bacchusmarsh.png'
    },
    {
        description: 'Мичуринское',
        url: 'http://meteo.slaval.ru/',
        screenshot: 'slavalru.png'
    },
];

/* inject navigation links into the navigation div */
function populate_header(page) {
    var navbar = document.getElementById('navigation');
    if (navbar) {
        var navbar_html = "\
<div class='navitem'>\
<a href='/'><img src='/images/weewx-logo-128x128.png' class='logo' alt='weewx' /></a>\
</div>\
<div class='navitem'>\
<a href='/stations.html'>MAP</a>\
</div>\
<div class='navitem'>\
<a href='/showcase.html'>SHOWCASE</a>\
</div>\
<div class='navitem'>\
<a href='/code.html'>CODE</a>\
</div>\
<div class='navitem'>\
<a href='/hardware.html'>HARDWARE</a>\
</div>\
<div class='navitem'>\
<a href='/support.html'>SUPPORT</a>\
</div>\
<div class='navitem'>\
<a href='/docs.html'>DOCS</a>\
</div>\
<div class='navitem'>\
<a href='/downloads'>DOWNLOAD</a>\
</div>";
        var tmp = document.createElement('div');
        tmp.setAttribute('class', 'nav');
        tmp.innerHTML = navbar_html;
        navbar.appendChild(tmp);
    }
}

/* inject the showcase web sites into the showcase div */
function populate_showcase() {
    var elem = document.getElementById('showcase');
    if (!elem) {
        return;
    }
    var html = '';
    for (var i = 0; i < sites.length; i++) {
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
    var i;
    if (!elem) {
        return;
    }
    if (!maxnum) {
        maxnum = sites.length;
    }
    var indices = Array();
    if (rnd) {
        var n = 0;
        for (i = 0; i < sites.length && n < maxnum; i++) {
            if (Math.random() > 0.5) {
                indices[n] = i;
                n += 1;
            }
        }
    } else {
        for (i = 0; i < maxnum; i++) {
            indices[i] = i;
        }
    }
    var html = '';
    for (i = 0; i < indices.length; i++) {
        html += "<a href='screenshots/" + sites[indices[i]].screenshot + "'>";
        html += "<img src='screenshots/" + sites[indices[i]].screenshot + "'";
        html += " class='screenshot' /></a><br/>";
    }
    elem.innerHTML = html;
}

function compare(x, y) {
    return x < y ? -1 : x > y ? 1 : 0;
}

