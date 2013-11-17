Ext.define(

)
Ext.application({
    name: 'Hadashot',
    launch: function() {
        Ext.create('Ext.Panel', {
            layout: 'fit',
            renderTo: document.getElementById('app'),
            items: [
                {
                    title: 'Hello Ext',
                    html : 'Hello! Welcome to Ext JS.'
                }
            ]
        });
    }
});
