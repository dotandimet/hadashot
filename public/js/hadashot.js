var hadashot = (function(jq,me){
//  jq(function(){ alert("hello!")});
  me.subsLoad = function(container, template, url) {
    jq.getJSON(url, 
      function(resp) {
        var subs = resp.subs;
        var sub = me.tmpl(template);
        // console.log(sub.toSource());
        var l = resp.subs.length;
        var elements = [];
        for (var i = 0; i < l; i++ ) {
          elements.push(sub( subs[i] ));
        }
        jq(container).append(elements.join(''));
      });
  };

  var cache = {};
  me.tmpl = function tmpl(str, data) {
// Simple JavaScript Templating
// John Resig - http://ejohn.org/ - MIT Licensed
    // Figure out if we're getting a template, or if we need to
    // load the template - and be sure to cache the result.
    var fn = !/\W/.test(str) ?
      cache[str] = cache[str] ||
        tmpl(document.getElementById(str).innerHTML) :
     
      // Generate a reusable function that will serve as a template
      // generator (and which will be cached).
      new Function("obj",
        "var p=[],print=function(){p.push.apply(p,arguments);};" +
       
        // Introduce the data as local variables using with(){}
        "with(obj){p.push('" +
       
        // Convert the template into pure JavaScript
        str
          .replace(/[\r\t\n]/g, " ")
          .split("{{").join("\t")
          .replace(/((^|}})[^\t]*)'/g, "$1\r")
          .replace(/\t=(.*?)}}/g, "',$1,'")
          .split("\t").join("');")
          .split("}}").join("p.push('")
          .split("\r").join("\\'")
      + "');}return p.join('');");
   
    // Provide some basic currying to the user
    return data ? fn( data ) : fn;
  };

  
  return me;
})(jQuery, hadashot || {});
