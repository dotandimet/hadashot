App = Ember.Application.create();

App.Router.map(function() {
  // put your routes here
  this.resource('blogroll', { path: '/' });
});
App.BlogrollRoute = Ember.Route.extend({
  model: function() {
    return $.getJSON('/settings/blogroll', {js : 1})
  }
})

Ember.Handlebars.registerBoundHelper('date', function(date) {
 return moment(date).fromNow();
});
