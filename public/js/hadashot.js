var hadashot = (function(doc,jq,me){
  me.subsLoad = function(container, template, url, root) {
    var coll = new me.collection({
      url: url, item_template: template, root: root,
     });
    jq(container).append(coll.el);
    coll.load();
  };

  var cache = {};
  me.tmpl = function tmpl(str, data) {
// Simple JavaScript Templating
// John Resig - http://ejohn.org/ - MIT Licensed
// Dotan Dimet - modifications: dropped "with" 
    // Figure out if we're getting a template, or if we need to
    // load the template - and be sure to cache the result.
    var fn = !/\W/.test(str) ?
      cache[str] = cache[str] ||
        tmpl(doc.getElementById(str).innerHTML) :
     
      // Generate a reusable function that will serve as a template
      // generator (and which will be cached).
      new Function("obj",
        "var p=[],print=function(){p.push.apply(p,arguments);};" +
       
        "p.push('" +
       
        // Convert the template into pure JavaScript
        str
          .replace(/[\r\t\n]/g, " ")
          .split("<%").join("\t")
          .replace(/((^|%>)[^\t]*)'/g, "$1\r")
          .replace(/\t=(.*?)%>/g, "',$1,'")
          .split("\t").join("');")
          .split("%>").join("p.push('")
          .split("\r").join("\\'")
      + "');return p.join('');");
   
    // Provide some basic currying to the user
    return data ? fn( data ) : fn;
  };

  me.collection = function(conf) {
    this.items = [];
    this.settings = jq.extend({},
            { 
              url: doc.location.pathname,
              args: undefined,
              tag: '<div>', // container tag
              item_template : 'item',
              root: 'items', // name of element in json response containing array of items
              onload: function() {
                this.el.fadeIn();
              }
    }, conf);
    this.url = this.settings.url;
    this.args = this.settings.args;
    this.el = jq(this.settings.tag);
    return this;
  };

  me.collection.prototype = {
    template: function(template_name) {
      if (template_name && !/\W/.test(template_name)) { // setter
        this.settings.item_template = template_name;
      }
      return me.tmpl(this.settings.item_template); // tmpl caches for us
    },
    render: function (container) {
        var tmpl_func = this.template();
        // console.log(sub.toSource());
        var items = this.items;
        var l = items.length;
        var elements = [];
        for (var i = 0; i < l; i++ ) {
          elements.push(tmpl_func( items[i] ));
        }
        return this.el.html(elements.join(''));
    },
    load: function(url, data) {
      this.url = url || this.settings.url;
      if (data) {
        this.args = jq.extend({}, this.settings.args, data);
      }
      var c = this;
      jq.getJSON(this.url, this.args,
        function(resp) {
          c.items = resp[c.settings.root];
          c.render();
          if (c.settings.onload && jq.isFunction(c.settings.onload)) {
              c.settings.onload.call(c);
          };
      });
    }
  }; // end hadashot.collection.prototype
  return me;
})(document, jQuery, hadashot || {});
