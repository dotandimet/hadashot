var hadashot = (function(jq,me){
  jq(function(){ alert("hello!")});
  me.subsCtrl = function($scope) {
    jq.getJSON('/settings/blogroll/?js=1', 
      function(resp) {
        console.log("First item: " + resp.subs[0].htmlUrl);
        $scope.subs = resp.subs;
      });
    $scope.subs = [ {
     direction: 'ltr',
     xmlUrl: '//foo.com/rss',
     title: 'My Blog',
     htmlUrl: '//foo.com',
     categories: ['blogs', 'farts']
     }, 
     {
     direction: 'ltr',
     xmlUrl: '//bar.com/rss',
     title: 'Someone Else\'s Blog',
     htmlUrl: '//bar.com',
     categories: ['blogs', 'belches']
     }];
  };
  
  return me;
})(jQuery, hadashot || {});
