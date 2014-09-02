
var Subscription = {
  controller: function(config) { $.extend(this, config); return this; },
  view: function(c) {
    return(
    m('div', { class:"list-group-item" }, [
      m('div', { class:"list-group-item-heading" }, [
                    m('a', { href: c.xmlUrl },
                      m('i', { class: "fa fa-rss" } ),
                      'rss' ),
                    m('a', { href: c.htmlUrl, dir: 'ltr' },
                    c.title ),
                    m('a', { href : "#" + obj_to_query_str({src : c.xmlUrl}),
                                  title: ((c.last && c.last > 0) ? 'Latest item: ' +
                                  moment(c.last).fromNow() : '...' ),
                                  'data-toggle': "tooltip",
                                  config: tooltip_config(c),
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
           config: tooltip_config(c),
          'data-toggle' :"tooltip" },
          m('span', {class: "glyphicon glyphicon-warning-sign"})) )
        : '' )
    ] ));
} };

var tooltip_config = function(ctrl) {
  return function(el, isInitialized) {
    if (isInitialized)
      return;
    $(el).tooltip();
  }
};

var blogreq = m.request({
            method: 'GET',
            url: '/settings/blogroll',
            data: { js: 1}
            });
var blogroll = {
  controller: function() {
    this.items = m.request({method: 'GET', url: '/settings/blogroll', data: { js: 1 } }).then(function(res){ return res.subs; });
  },
  view: function(ctrl) {
     var items = ctrl.items().map(function(item, i){
        var sc = new Subscription.controller({  error: item.error, active: item.active,
          xmlUrl: item.xmlUrl, htmlUrl: item.htmlUrl, title: item.title,
          last: item.last, items: item.items, categories: item.categories,
          last_modified: item.last_modified, etag: item.etag, key: item._id });
        return Subscription.view(sc);
     });
   return m('div', {}, items);
  }
};

/*
var FeedItem = React.createClass({displayName: 'FeedItem',
  render: function() {
  return (
    React.DOM.div( {className:"entry panel panel-default", key: this.props.key },
      React.DOM.div( {className:"panel-heading"},
        React.DOM.h4( {className: "title panel-title ", dir: this.props.title.dir },
        React.DOM.a( {href: this.props.link },  this.props.title.content ),
        React.DOM.span( {className:"author"},  this.props.author ? this.props.author : '' )),
        React.DOM.span( {className:"tim"},  moment(this.props.published).fromNow() ),
        React.DOM.a( {href: "/feed/debug/?_id=" + this.props.key }, "debug"),
      React.DOM.a( {className:"origin fa fa-rss", href: window.encodeURIComponent(this.props.origin),  title:"Source: " + this.props.origin },  " " ),
      (this.props.tags) ? this.props.tags.map(function(t){return React.DOM.a( {className:"tag label label-default",
        href:"?tag=" + window.encodeURIComponent(t),  key: t },  t ) }) : React.DOM.span(null )
      ),
      React.DOM.div( {className:"panel-body"},
        ((this.props.content)) ?
        React.DOM.div( {className:"content", dir: this.props.content.dir,
        dangerouslySetInnerHTML:{__html: this.props.content.content }} ) : '',

        (!this.props.content && this.props.description) ?
        React.DOM.div( {className:"well", dir: this.props.description.dir,
          dangerouslySetInnerHTML:{__html: this.props.description.content }} )
        : ''
      )
    )
    );
  },
  componentDidMount: function() {

  }
});

var Feeds = React.createClass({displayName: 'Feeds',
  getInitialState: function() { return { items: [] }; },
  render: function() {
     var items = this.state.items.map(function(item, i){
        return (
          FeedItem( {content:item.content, key:item._id, link:item.link,
          title:item.title, description:item.description,
          published:item.published, origin:item.origin, tags:item.tags,
          author:item.author}
          )
        )
     }.bind(this));
   return React.DOM.div(null, items);
  },
  handleLoad: function() {
    var arg = query_str_to_obj(window.location.hash.substr(1));
    console.log("Arg is: " + JSON.stringify(arg));
    $.getJSON('/feed/river', arg, function(resp) {
        var items = resp.items;
        this.setState({ items: resp.items })
        last_on_page = items[items.length-1].published;
        first_on_page = items[0].published;
    }.bind(this));
  },
  componentDidMount: function() {
    this.handleLoad();
  }
});

var feeds = React.renderComponent( Feeds(), document.getElementById('feeds') );
var subs =  React.renderComponent( blogroll(), document.getElementById('sublist') );

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
*/
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

m.module(document.getElementById('sublist'), blogroll);
