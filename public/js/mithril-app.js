var blogroll = {};
blogroll.subscription = function(c) {
    return(
    m('div', { class:"list-group-item" }, [
      m('div', { class:"list-group-item-heading" }, [
                    m('a', { href: c.xmlUrl },
                      m('i', { class: "fa fa-rss" } ),
                      'rss' ),
                    m('a', { href: c.htmlUrl, dir: 'ltr' },
                    c.title ),
                    m('a', { href : '/feed/src=' + window.encodeURIComponent(c.xmlUrl),
                             title: ((c.last && c.last > 0) ? 'Latest item: ' +
                                  moment(c.last).fromNow() : '...' ),
                                  'data-toggle': "tooltip",
                                  config: route_func,
                                  ref: 'itemCount',
                                  class: "badge" },
                                  ( (c.items) ? c.items : 0)
                                  )] ),
      m('div', { class:"list-group-item-text" },
                    ( (c.categories)
                        ?  $.map(c.categories, function(v,i) {
                            return m('span', {
                              class: "label label-default",
                              key: v }, v); })
                        : m('span', { class: "label label-default" },
                        'uncategorized') ),
                   ( (c.last_modified) ? ' Last Modified: ' +
                   moment(c.last_modified).fromNow() : '' ),
                   ( (c.etag) ? ' Etag: ' + c.etag : '' ) ),

     ((!c.active || !c.active)
        ? ( m('span', { class:"label label-warning",
           title : ((c.error) ?  c.error : 'Not Active'),
           config: tooltip_func,
          'data-toggle' :"tooltip" },
          m('span', {class: "glyphicon glyphicon-warning-sign"})) )
        : '' )
    ] ));
};

var tooltip_func = function(el, isInitialized) {
    if (isInitialized)
      return;
    $(el).tooltip();
};

var route_func = function(el, isinit, ctx) {
  m.route(el, isinit, ctx);
  tooltip_func(el, isinit, ctx);
};

blogroll.get_subs = function() {
  return m.request({method: 'GET', url: '/settings/blogroll', data: { js: 1 } })
              .then(function(res){ return res.subs; });
};

blogroll.controller = function() {
    this.items = blogroll.get_subs();
};

blogroll.view = function(ctrl) {
     var items = ctrl.items().map(function(item, i){
        return blogroll.subscription( item );
     });
   return m('div', {}, items);
};

var Feeds = {};
Feeds.ItemView = function(c) {
  return (
    m('div.entry.panel.panel-default', [
      m('div.panel-heading', [
        m('h4.title.panel-title', { dir: c.title.dir }, [
          m('a', {href: c.link },  c.title.content ),
          m('span', {className:"author"},  c.author ? c.author : '' )
        ]),
        m('span', {className:"tim"},  moment(c.published).fromNow() ),
        m('a', {href: "/feed/debug/?_id=" + c._id }, "debug"),
        m('a', {className:"origin fa fa-rss", href: c.origin,  title:"Source: " + c.origin },  " " ),
        (c.tags) ? c.tags.map(function(t){return m('a', {className:"tag label label-default",
        href:"?tag=" + window.encodeURIComponent(t),  key: t },  t ) }) : m('span', '' )
       ]
      ),
      m("div.panel-body", [
        ((c.content))
        ?  m('div', {className:"content", dir: c.content.dir },
             m.trust( c.content.content ) )
        : '',

        (!c.content && c.description)
        ?  m('div', {className:"well", dir: c.description.dir },
             m.trust( c.description.content ) )
        : ''
        ]
      )
    ])
    );
};

Feeds.items = function() {
  if (m.route.param('feed')) {
    arg = query_str_to_obj(m.route.param('feed'));
  }
//  arg = { js: 1 }; // query_str_to_obj(r);
  return m.request( {method: 'GET', url:'/feed/river', data: arg } )
                 .then(function(resp) {
                  var items = resp.items;
                  last_on_page = items[items.length-1].published;
                  first_on_page = items[0].published;
                  return items;
                  });
};

Feeds.controller = function() {
    arg = query_str_to_obj(window.location.hash.substr(1));
    this.items = Feeds.items(arg);
};

Feeds.view = function(ctrl) {
     var items = ctrl.items().map(function(item, i){
        return Feeds.ItemView( item );
     });
     return m('div', items);
};

m.route.mode = 'hash';
m.route( document.getElementById('feeds'), '/feed/river',
         { '/feed/:feed...' : Feeds } );
m.module(document.getElementById('sublist'), blogroll);

/*
 $( window ).on('hashchange', function() { feeds.handleLoad(); });


  var last_on_page = new Date().getTime();
  var first_on_page = 0;
   function initFeeds() {
        $('#before a').attr('title', 'items earlier than ' + todate(last_on_page));
        var toc = $('#sidebar ul.toc');
        toc.empty();
        $.each(items, function(i, val) {
            var link = $('<a>').text(val.title.content).attr('href', '#c' + val._id).attr('dir', val.title.dir);
            $('<li>').appendTo(toc).append(link);
      });
        $(document.body).scrollspy('refresh');
        $('#feeds .origin').tooltip();

    $(document.body).scrollspy({target: '#sidebar', offset: 80});
    // $('#feeds').scrollspy({target: '#sidebar'});
      $('#before a').click(earlier);
   //   $('#feeds').on('click', 'a.origin', load_feed);
   };

*/

  function query_str_to_obj(q, o) {
    if (o === undefined) {
      o = { js : 1 };
    }
    var arg_pairs = q.split('&');
    for(var i=0; i < arg_pairs.length; i++) {
      // do this instead of split so we can keep embedded search strings (with a single arg)
      // why isn't encodeURIComponent hiding those embedded search strings?
      var sep = arg_pairs[i].indexOf('=');
      if (sep != -1) {
        var k = window.decodeURIComponent(arg_pairs[i].substring(0, sep));
        var v = window.decodeURIComponent(arg_pairs[i].substring(sep+1));
        o[k] = v;
      }
    }
    return o;
  }
  function obj_to_query_str(o) {
    var s = '';
    var args = [];
    for(var k in o) {
      args.push(window.encodeURIComponent(k) + '=' + window.encodeURIComponent(o[k]));
    }
    s += args.join('&');
    return s;
  }
/*
  function earlier() {
      window.location.hash = obj_to_query_str( { before: last_on_page } );
  //  feeds.load(feeds.url, { before: last_on_page });
//    hadashot.subsLoad('#feeds', 'feed_tmpl', '/feed/river/?js=1&before=' + last_on_page, 'items');
    return false;
  }

  function later() {
      window.location.hash = obj_to_query_str( { after: first_on_page } );
      return false();
  }
  function load_feed(ev) {
    ev.preventDefault();
    feeds.load(feeds.url, { src: this.href });
    // hadashot.subsLoad('#feeds', 'feed_tmpl', '/feed/river/?js=1&src=' + this.href, 'items');
    return false;
  }

*/

