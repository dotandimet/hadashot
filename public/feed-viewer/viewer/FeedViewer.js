/**
 * @class FeedViewer.FeedViewer
 * @extends Ext.container.Viewport
 *
 * The main FeedViewer application
 * 
 * @constructor
 * Create a new Feed Viewer app
 * @param {Object} config The config object
 */

Ext.define('FeedViewer.App', {
    extend: 'Ext.container.Viewport',
    
    initComponent: function(){
        
        Ext.define('Feed', {
            extend: 'Ext.data.Model',
            fields: ['title', 
                    { name: 'url', mapping: 'xmlUrl' } ]
        });

        Ext.define('FeedItem', {
            extend: 'Ext.data.Model',
            fields: [
            { name: 'title',
            convert: function(value, record) { return value.content; }  },
            { name: 'title_dir', mapping: 'title', convert :  function(value, record) { return value.dir;  } },
            // 'author',
            {
                name: 'pubDate',
                type: 'date',
                mapping: 'published'
            },
            'link',
            { name: 'description',
            convert: function(value, record) { return value.content; }  },
            { name: 'description_dir', convert: function(value, record) { return value.dir;  }, mapping: 'description' },
            { name: 'content',
            convert: function(value, record) { return value.content; }  },
            { name: 'content_dir', mapping : 'content', convert: function(value, record) { return value.dir;  } },
            ]
        });
        
        Ext.apply(this, {
            layout: {
                type: 'border',
                padding: 5
            },
            items: [this.createFeedPanel(), this.createFeedInfo()]
        });
        this.callParent(arguments);
    },
    
    /**
     * Create the list of fields to be shown on the left
     * @private
     * @return {FeedViewer.FeedPanel} feedPanel
     */
    createFeedPanel: function(){
        this.feedPanel = Ext.create('widget.feedpanel', {
            region: 'west',
            collapsible: true,
            width: 225,
            //floatable: false,
            split: true,
            minWidth: 175,
            listeners: {
                scope: this,
                feedselect: this.onFeedSelect
            }
        });
        this.feedPanel.view.store.load();
        return this.feedPanel;
    },
    
    /**
     * Create the feed info container
     * @private
     * @return {FeedViewer.FeedInfo} feedInfo
     */
    createFeedInfo: function(){
        this.feedInfo = Ext.create('widget.feedinfo', {
            region: 'center',
            minWidth: 300
        });
        return this.feedInfo;
    },
    
    /**
     * Reacts to a feed being selected
     * @private
     */
    onFeedSelect: function(feed, title, url){
        this.feedInfo.addFeed(title, url);
    }
});
