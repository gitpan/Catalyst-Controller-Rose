/*
    Atomic Learning Edit In Place JS library
    requires Prototype 1.4 or later.
    Copyright 2007 by Atomic Learning.
    Available under the same terms as Perl.
    
*/

var Atomic = {
  Version: '2.0.0',
  prototypeVersion: parseFloat(Prototype.Version.split(".")[0] + "." + Prototype.Version.split(".")[1])
}

if((typeof Prototype=='undefined') || Atomic.prototypeVersion < 1.4)
      throw("Atomic JS requires the Prototype JavaScript framework >= 1.4");

Atomic.debug = Class.create();

Atomic.debug.prototype = {

    initialize: function( id )
    {
        this.cnt    = 0;
        this.bgr    = 0;
        this.id     = id;
    
    },
    
    insert: function(msg)
    {
        var alt     = this.bgr ? 'white' : '#e3eaf0;';
        this.bgr    = this.bgr ? 0 : 1; // toggle
        new Insertion.Bottom(
            $(this.id),
            '<div style="background:' + 
            alt + 
            '"><span style="color:blue">[' + 
            this.cnt++ +
            ']</span> ' +
            msg +
             "</div>" 
        );
    },
    
    debug_events: function()
    {
        if(Event.observers)
        {
        
            this.insert('event observers');
            
            // skip first one since it is for window object
            for(var i=1; Event.observers[i]; i++)
            {
                var e = Event.observers[i];
                this.insert("Event");
                for(var j=0; j < 4; j++)
                {
                    this.insert(" " + j + ": " + e[j]);
                    if(j==0 && $(e[j]))
                    {
                        this.insert("id of watched element: " + $(e[j]).getAttribute('id'));
                    }
                }
            }
        }
    
    
    }
    
};

Atomic.eip = Class.create();

Atomic.eip.prototype = {
    
    /* row is a json object that describes a table row.
       each item in the array is a form field.
       e.g.:
       {
         id: 'table_id',
         row: [
         {
            name: 'foo',
            type: 'text',
            size: 10,
            auto: 'http://some.url.com'
         },
         {
            name: 'bar',
            type: 'text',
            size: 20
         }
        ]
      };
    
    */
    
    initialize: function( args )
    {
    
        this.tid        = args.tid;
        this.tmpl       = args.tmpl;
        this.url        = args.url;
        this.spin_url   = args.spin_url;
        this.is_ie      = args.is_ie || 0;
        this.timeout    = args.timeout || 5000; // 5 seconds
        this.id_joiner  = args.id_joiner || '.';
        this.parent_tag = args.parent_tag || 'tbody';       // change if HTML struct changes
        this.child_tag  = args.child_tag  || 'tr';          // change if HTML struct changes
        this.cell_tag   = args.cell_tag   || 'td';          // ditto
        this.tmpl_id    = args.tmpl_id    || 'tmpl';
        this.error      = 0;        
        this.active_id  = 0;    // only one row active at a time
        this.alt        = 1;    // start with odd number
        this.new_id     = this.tid + this.id_joiner + this.tmpl.id;
        this.events     = new Hash;
        this.auto       = new Hash;
        this.ids        = new Hash;
        
        if (args.debug && $(args.debug))
        {
            this.mydebugger = new Atomic.debug( args.debug );
            this.debug = function(msg) { this.mydebugger.insert(msg) };
        }
        else
        {
            this.debug = function(msg) { }; // do nothing
        }
        
        this.set_ajax_timeout();
        
    },
    
    
    // timeout stuff based on http://codejanitor.com/wp/2006/03/23/ajax-timeouts-with-prototype/
    
    ajax_in_progress: function(xhr)
    {
        switch (xhr.readyState)
        {
            case 1: case 2: case 3:
                return true;
            break;
            default:
                return false;
            break;
        }
    },
            
    ajax_timed_out: function()
    {
        this.error = 1;
        this.debug("ajax_timed_out: " + this.active_id);
        this.write_error(this.active_id,
                         "The network appears to have failed. Please try again.");
                         
        this.cancel_ajax();
            
    },
    
    /* 
        NOTE this is global, which means if user tries to activate
        an ajax request while another is still pending, the timeouts
        can get screwy.
        that will happen so seldom in this application that we don't worry.
        we could also set the timeout value to something lower than 5 seconds
        by default, assuming that user will be patient for N seconds.
    */
    set_ajax_timeout: function()
    {
        var self = this;
        
        Ajax.Responders.register({
        onCreate: function(request) 
        {
            request['timeout_id'] = setTimeout(
             function() 
             {
                // If we have hit the timeout and the AJAX request is active, 
                // abort it and let the user know
                if (self.ajax_in_progress(request.transport)) 
                {
                    request.transport.abort();
                    request.is_aborted  = true;
                    self.ajax_timed_out();
                    // Run the onFailure method if we set one up 
                    // when creating the AJAX object
                    if (request.options['onFailure']) 
                    {
                        request.options['onFailure'](request.transport, request.json);
                    }
                }
             },
             self.timeout // Five seconds
            );
        },
        onComplete: function(request) 
        {
            // Clear the timeout, the request completed ok
            clearTimeout(request['timeout_id']);
            self.debug("ajax completed");
        }
        });
    },
    
    cancel_ajax: function()
    {
        if (! this.ajax_request.is_aborted)
        {
            this.debug("ajax not yet aborted");
            this.ajax_request.transport.abort();
        }
                
        // onFailure will reactivate form and turn off spinner
        
    },
    
    // turning this on will break other things but here for starting point
    // and reference
    debug_ajax: function()
    {

        Ajax.Responders.register({
        onCreate: function(){
            alert('a request has been initialized!');
        }, 
        onComplete: function(){
            alert('a request completed');
        },
        onLoaded: function(ajax, xhr){
            alert('a request loaded');
            var head = xhr.requestHeaders;
            alert('request headers: ' + head);
        },
        onLoading: function(){
            alert('a request loading');
        },
        onException: function(aj,err){
            alert('request threw exception');
            alert('error name: ' + err.name);
            alert('error msg: ' + err.message);
            alert('error num: ' + err.number );
        }
        });

    },
    
    bolder: function(t)
    {
        return "<b>" + t + "</b>";
    },
    
    /* fix Firefox js error.
       via http://erik.eae.net/archives/2005/06/10/22.21.42/ 
    */
    autocomplete_off: function( node )
    {
        if (node.getElementsByTagName)
        {
            var inputElements = node.getElementsByTagName('input');
            for (var i=0; inputElements[i]; i++)
                inputElements[i].setAttribute('autocomplete','off');
        }
    },
    
    show_json: function(obj)
    {
        var txt = JSON.stringify(obj);
        this.debug(txt);
    },
    
    /* return the _ro id for a parent id */
    ro_id: function(id)
    {
        return id + this.id_joiner + 'ro';
    },
    
    form_id: function(id)
    {
        return id + this.id_joiner + 'form';
    },

    /*  set_active_ids(id)
    
    the entire EIP magic relies on unique id attributes
    for each parent, .ro and .form child, and each form element.
    the basic pattern looks like:
    
        <tid> (top level table id)
         <tid>.<pk> (each tbody)
          <tid>.<pk>.ro (read only tr in tbody)
           <tid>.<pk>.<name>.ro (each td in tr (td = col = cell)
           ...
          <tid>.<pk>.form (form tr in tbody)
           <tid>.<pk>.<name> (each element in form)
           ...
           <tid>.<pk>.save      (save button)
           <tid>.<pk>.rm        (delete button)
           <tid>.<pk>.cancel    (cancel button)
    
    */

    set_active_ids: function(id)
    {
        if (id)
            this.active_id = id;
            
        var i = this.active_id;
        this.ids.row         = i;
        this.ids.row_ro      = this.ro_id(i);
        this.ids.row_form    = this.form_id(i);
        
        if (    !$(this.ids.row)
            ||  !$(this.ids.row_ro)
            ||  !$(this.ids.row_form)
            )
        {
            this.debug("DOM appears broken for id: " + i);
        }
        
        this.ids.error      = i + this.id_joiner + 'error';
        this.ids.error_cell = i + this.id_joiner + 'error_cell';
        this.ids.error_b    = i + this.id_joiner + 'error_b';
        
        // buttons
        this.ids.buttons    = i + this.id_joiner + 'buttons';
        this.ids.save       = i + this.id_joiner + 'save';
        this.ids.rm         = i + this.id_joiner + 'rm';
        this.ids.cancel     = i + this.id_joiner + 'cancel';
    
    },
    
    hide: function(id)
    {
        $(id).style.display = 'none';   // could use Prototype Element.hide() too
    },
    
    show: function(id)
    {
        $(id).style.cssText = 'display:table-row';  // use Prototype ??
    },
    
    make_button: function(id, val)
    {
        var b = document.createElement('input');
        b.setAttribute('type',  'button');
        b.setAttribute('id',    id);
        b.value = val;
        b.className = 'eip';    // IE syntax
        return b;
    },
    
    get_parent_id_from_event: function(e)
    {
        this.debug("getting id from event");
        var id = Event.findElement(e,this.parent_tag).getAttribute('id');
        this.debug("found id: " + id);
        return id;
    },
    
    save_on_enter: function(event)
    {
    
      //this.debug("caught keypress");
      if ( event.keyCode == Event.KEY_RETURN )    // same as 13 -- browser compat ?
      {
         this.debug("save_on_enter() start");
         var id = this.get_parent_id_from_event(event);
         this.debug("caught RETURN for " + id);
         this.save(id);
         this.debug("save_on_enter() finished");
      }
    },
    
    /* see http://particletree.com/notebook/prototype-and-the-this-keyword/ */
    make_buttons: function(id)
    {           
        var save    = this.make_button(this.ids.save, 'save');
        var rm      = this.make_button(this.ids.rm, 'delete');
        var cancel  = this.make_button(this.ids.cancel, 'cancel');
        
        save.setAttribute('onclick', this.tid + '.save("' + id + '")');
        rm.setAttribute('onclick', this.tid + '.rm("' + id + '")');
        cancel.setAttribute('onclick', this.tid + '.cancel("' + id + '")');
        
        $(this.ids.buttons).appendChild(cancel);
        $(this.ids.buttons).appendChild(save);
        $(this.ids.buttons).appendChild(rm);
    },
    
    hide_buttons: function(id)
    {
        Element.hide(this.ids.save);
        Element.hide(this.ids.rm);
        Element.hide(this.ids.cancel);
    },
    
    show_buttons: function(id)
    {
        Element.show(this.ids.save);
        Element.show(this.ids.rm);
        Element.show(this.ids.cancel);
    },
    
    rm_row: function(id)
    {
        var row = $(id);
        row.parentNode.removeChild(row);
        this.active_id = 0;
    },
        
    /* de-activate the _form belonging to parent id */
    cancel: function(id)
    {
    
        this.debug("cancel() id: " + id);
        
        var ro = $(this.ro_id(id));
        if (! ro)
        {
            this.debug("can't get ro for id: " + this.ro_id(id));
        }
        if (! $(id) )
        {
            this.debug("can't get element for id:" + id);
        }
        
        if (id == this.new_id)
        {
            this.rm_row(id);
            return;
        }

        
        this.deactivate_form(id);
        this.clear_errors(id);        
        this.copy_ro_to_form(id);
        this.hide(this.form_id(id));
        this.show(this.ro_id(id));
        this.active_id = 0;
        
        this.debug("cancel() finished");
    
    },
    
    /*  disable_button( button_id )
    
        turn button 'off' temporarily.
        this allows us to keep user from clicking a particular button,
        while keeping all buttons and their listening events active.
    
        example: user clicks 'save' but then changes mind.
        clicking 'cancel' might indicate that the save should be 'undone'.
        or more likely, the whole edit session could be reset.
        helps user experience of being able to abort a spinning url
        if the server is slow to respond.
    */
    disable_button: function(bid) 
    {
        var b = $(bid);
        b.oldValue     = b.value;
        b.value        = 'in progress...';
        b.myDisable    = true;

        if (typeof b.disabled != 'undefined')
            b.disabled = true;
        else if (!b.buttonDisabled) 
        {
            b.oldOnclick       = b.onclick;
            b.onclick          = function() { return false };
            b.buttonDisabled   = true;
        }
    },
    
    enable_button: function(bid) 
    {
        var b       = $(bid);
        if (b.oldValue)
            b.value     = b.oldValue;
            
        b.myDisable = false;
        
        if (typeof b.disabled != 'undefined')
            b.disabled = false;
        else if (b.buttonDisabled) 
        {
            b.onclick          = b.oldOnclick;
            b.buttonDisabled   = false;
        }
    },
    
    
    /* walk_active_row( func )
          walk through template and call func for each col.
          the func callback should be a function closure
          and expect 5 arguments:
          
           0:   this class
           1:   the column object
           2:   the column id
           3:   the form object
           4:   the ro object
    */
    walk_active_row: function(func)
    {    
        var pid = this.active_id;
        var i;
        for(i=0; i < this.tmpl.cols.length; i++)
        {
            var col     = this.tmpl.cols[i];
            var form_id = pid + this.id_joiner + col.name;
            var ro_id   = this.ro_id(form_id);
            var form_obj = $(form_id);
            var ro_obj   = $(ro_id);
            if (!form_obj)
            {
                this.debug("failed to find form_id: " + form_id);
                return;
            }
            
            if (!ro_obj)
            {
                this.debug("failed to find ro_id: " + ro_id);
                return;
            }
            
            func(this, col, form_id, form_obj, ro_obj);
        }
    
    },
        
    /* copy_ro_to_form( id )
    
        copy ro values to form.
        user may be 'cancel'ing an edit
        and we don't want any changes to persist in the hidden .form
    */

    copy_ro_to_form: function(id)
    {
    
        this.walk_active_row(
            function(self, col, el_id, form_obj, ro_obj)
            {
                var v = ro_obj.innerHTML;
                
                self.debug("copying <b>'" + v + "'</b>");
                self.debug("form_obj type = " + form_obj.type);
                
                if (form_obj.type == 'text')
                {
                    form_obj.value = v;
                }
                
                /* TODO other input types?
                   maybe use col.type as well ?
                */
                
                else
                {
                    form_obj.innerHTML = v;
                }
            }
        );
    
    },
    
    add_row: function(id)
    {
        // use the template to create a new row
        // and insert it before the first row
        var nid = this.new_id;
        if ($(nid))
        {
            alert("Sorry. Only one new row allowed at a time.");
            return;
        }
        
        // copy the template
        var tmplid = this.tid + this.id_joiner + this.tmpl_id;
        if(! $(tmplid))
        {
            alert("Error: no template defined for new row");
            return;
        }
        
        var clone = $(tmplid).cloneNode(true);
        clone.setAttribute('id', nid);
        
        // set ids on all children
        var kids = $(clone).descendants();
        this.debug("got descendants array with " + kids.length + ' items');
        var re = new RegExp('^' + tmplid);
        var self = this;
        kids.each(function(item)
        {
            var id = item.getAttribute('id');
            if (!id)
                return;
                
            //self.debug("got id: " + id);
            //self.debug("replace(" + re + " - " + nid);
            var uid = id.replace(re, nid);
            //self.debug("new id: " + uid);
            item.setAttribute('id', uid);
            //self.debug("id is now: " + item.getAttribute('id'));
        });
        
        
        var first = $(this.tid).getElementsByTagName(this.parent_tag)[1]; // 1 since tmpl is 0
        $(this.tid).insertBefore( clone, first );
        
        if(!$(nid))
        {
            this.debug("error inserting new row with id: " + nid);
            return;
        }
        
        $(nid).style.cssText = 'display:table-row-group';
        
        if(!$(this.ro_id($(first).getAttribute('id'))).hasClassName('alternate'))
            Element.addClassName(this.ro_id(nid), 'alternate');
        else
            Element.removeClassName(this.ro_id(nid), 'alternate');
        
        
        this.edit(nid, nid + this.id_joiner + this.tmpl.cols[0].name);
    
    },
    
    rm: function(id)
    {
        this.debug("rm() called for id: " + id);
        
        if (id == this.new_id)
        {
            this.cancel(id);
            return;
        }
        
        this.spinner_on(id);
        this.deactivate_form(id);
        var self = this;
        var pk = this.pk_from_id(id);
        
        url = this.url + '/' + encodeURIComponent(pk) + '/' + 'rm';
        
        this.debug("pk: " + pk);
        this.debug("url: " + url);
        this.debug("id: " + id);
        
        this.ajax_request = new Ajax.Updater(
            { success: $(id), failure: $(this.ids.error) },
            url,
            {
                method:     'post',
                onFailure:  function(req, json) 
                            { 
                                self.debug(" ajax onFailure ");
                                self.write_error( id, req.responseText );
                                self.activate_form(id); // turn everything back on
                            },
                onSuccess:  function(req, json)
                            {
                                if (self.error)
                                {
                                    self.debug("onSuccess reached but error is ON");
                                    return;
                                }
                                self.rm_row(id);
                                self.active_id = 0;
                                self.debug("rm() done");
                            },
                onComplete: function(req, head, json)
                            {
                                self.spinner_off(id)
                            }
            }
        );
        
    
    },
    
    rm_row: function(id)
    {
        this.debug("rm_row() for id: " + id);
        
        if(!$(id))
        {
            this.debug("DOM broken: no row to remove for id: " + id);
            return false;
        }
        
        // a little tricky. we get the node, then have its parent remove it.
        var row = $(id);
        row.parentNode.removeChild(row);
        return true;    
    },
    
    save: function(id)
    {
        this.debug("save() called for id: " + id);
        
        this.deactivate_form(id);
        
        // compare: has anything actually changed? could just be correcting an error
        // or manually undo-ing change
        
        var changed = 0;
        var self = this;
        this.walk_active_row(
            function(self, col, col_id, form_obj, ro_obj)
            {
                var av = form_obj.value;
                var bv = ro_obj.innerHTML;
                if (av != bv)
                    changed++;
            }
        );
        if (!changed)
        {
            this.debug("no data changed - aborting save");
            this.cancel(id);
            return;
        }
        
        this.spinner_on(id);
        this.save_data( id,
                        this.build_query_from_form(id),
                        this.url
                        );
       
    },
        
    pk_from_id: function(id)
    {
        var arr = id.split( this.id_joiner );
        return arr[1];
    },
    
    build_query_from_form: function(id)
    {
        var cols   = new Array();
        var before = new Hash();
        var after  = new Hash();
                
        this.walk_active_row(
            function(self, col, col_id, form_obj, ro_obj)
            {
                var n  = form_obj.name;
                var av = form_obj.value;
                var bv = ro_obj.innerHTML;
                before[n] = bv;
                after[n]  = av;
                
                var str = n + '=' + encodeURIComponent(av);
                //self.debug("q str: " + str);
                cols.push(str);
                
                
            }
        );
        
        cols.push('_id='     + encodeURIComponent(this.pk_from_id(id)));
        cols.push('_tname='  + encodeURIComponent(this.tid));
        cols.push('_tmpl='   + encodeURIComponent(JSON.stringify(this.tmpl)));
        cols.push('_before=' + encodeURIComponent(JSON.stringify(before)));
        cols.push('_after='  + encodeURIComponent(JSON.stringify(after)));
        
        if ($(this.ids.row_ro).hasClassName('alternate'))
        {
            cols.push('_rc=1'); // preserve alternate class
        }
        
        this.show_json( cols );
        
        return cols.join('&');
    },
    
    /*
        save data to server
        
        onComplete:
            * turn spinning ball off no matter what.
            
        onSuccess:
            * parent content will be updated with html in-place via Ajax.Updater
              but parent id will need to be set explicitly in case the PK has changed
              as it often will. the new id is returned in the X-JSON header.
            * clear errors
            
        onFailure:
            * error message written to parent as new 3rd row: .error
                
    */
    save_data: function(id, q, url)
    {
        var self = this;
        var pk = this.pk_from_id(id);
        
        url = url + '/' + encodeURIComponent(pk) + '/' + 'save';
        
        this.debug("pk: " + pk);
        this.debug("url: " + url);
        this.debug("q: " + q);
        this.debug("id: " + id);
        
        this.ajax_request = new Ajax.Updater(
            { success: $(id), failure: $('no_such_id') },
            url,
            {
                method:     'post',
                parameters: q,
                onFailure:  function(req, json) 
                            { 
                                self.spinner_off(this.active_id);
                                self.debug(" ajax onFailure ");
                                self.write_error( id, req.responseText );
                                self.activate_form(id); // turn everything back on
                            },
                onSuccess:  function(req, json)
                            {
                                if (self.error)
                                {
                                    self.debug("onSuccess reached but error is ON");
                                    return;
                                }
                                var pk = json.id;
                                self.debug("new pk: " + pk);
                                var newid = self.tid + self.id_joiner + pk;
                                self.debug("new id: " + newid);
                                $(id).setAttribute('id', newid);
                                self.deactivate_form(id);
                                self.active_id = 0;
                                self.debug("save_ok() done");
                            },
                onComplete: function(req, head, json)
                            {
                                self.spinner_off(id)
                            }
            }
        );
                
    
    },
    
    
    /* edit( parent_id, cell_id )
        main method called from HTML onclick
        swaps the _ro and _form elements,
        creates buttons, and sets Event listeners
        for the _form element.
    */
    edit: function(parent_id, cell_id)
    {

        this.debug("edit() called for " + cell_id);
        
        /* if another row is active, deactivate it */
        if ( this.active_id && this.active_id != parent_id )
        {
            this.cancel(this.active_id);
        }
       
        this.set_active_ids(parent_id);
       
        /* "fix" firefox */
        this.autocomplete_off( $(this.ids.row_form) );
        
        this.hide(this.ids.row_ro);
        this.show(this.ids.row_form);              
       
        if (!$(this.ids.save))
        {
            this.make_buttons(parent_id);
        }
               
        this.activate_form(parent_id);
        
        /* if 'edit' button was clicked, we don't have cell_id */
        if (! cell_id || ! $(cell_id))
        {
            this.debug("no element " + cell_id + " -- returning true");
            return true;
        }
           
        this.debug("trying to focus/select on " + cell_id);
        $(cell_id).focus();
        $(cell_id).select();
        this.debug("edit() finished");
        
        //this.mydebugger.debug_events;
    },
    
    /* let users hit Return to auto-save from any cell - this mimics Excel, etc. 
       either/or with autocomplete, since 'return' on list select would submit as well
       which might be pre-mature
    */

    activate_form: function(pid)
    {
    
        this.show_buttons(pid);
    
        this.walk_active_row(
            function(self, col, col_id, form_obj, ro_obj)
            {
                if (col.readonly)
                {
                    // do nothing
                }
                else if (col.auto)
                {
                    self.set_autocomplete(col, col_id);
                }
                else
                {
                    self.set_save_key_listener(col_id);
                }
            }
        );
        
    },

    /* deactivate_form( parent_id )
    
        turn off the Event listeners for all buttons
        and the autocomplete and key listeners
        for all form elements.
        i.e., undo activate_form()
        
        should call this whenever form is submitted as well,
        in order to keep user from extra clicks, etc.,
        and then re-activate_form() if server returns error.
        
    */
    
    deactivate_form: function(pid)
    {
    
        this.hide_buttons(pid);
    
        // walk form and turn off stuff
        this.walk_active_row(
            function(self, col, col_id, form_obj, ro_obj)
            {
                if (col.readonly)
                {
                    // do nothing
                }
                else
                {
                    // both just in case
                    if (self.auto[col_id])
                        self.unset_autocomplete(col, col_id);
                        
                    if (self.events[col_id])
                        Event.stopObserving(
                                        col_id,
                                        'keypress',
                                        self.events[col_id],
                                        false
                                        );
                    
                }
            }
        );
            
    },
    
    set_save_key_listener: function(col_id)
    {
        this.events[col_id] = this.save_on_enter.bindAsEventListener(this);
        Event.observe(  col_id, 
                        'keypress',
                        this.events[col_id],
                        false
                        );
                                    
    },
    
    set_autocomplete: function(col, col_id)
    {            
        var cont = col_id + '_auto_complete';
        
        this.debug("setting autocomplete for: " + col_id);
        
        if ($(col_id))
        {
            this.debug("col id exists");
        }
        if ($(cont))
        {
            this.debug("container exists");
        }
        
        // TODO this doesn't work. no js errors either.
            
        var self = this;        
        
        this.auto[col_id] = 
            new Ajax.Autocompleter(
                    col_id, 
                    cont, 
                    col.auto, 
                    {
                        method: 'post',
                        minChars: 1,
                        afterUpdateElement: function()
                                    {
                                        self.set_save_key_listener(col_id);
                                    },
                        paramName: col.name
                    }
            );
            
        this.debug('autocomplete set');
    
    },
    
    unset_autocomplete: function(col, col_id)
    {
        this.auto[col_id] = 0;
    },
    
    write_error: function(id, msg)
    {
        this.create_error_container(id);
        // append error as div inside first cell
        if (msg)
        {
            new Insertion.Bottom( 
                $(this.ids.error_cell),
                '<div style="padding:4px" class="error">Error: ' + msg + '</div>'
                );
        }
        else
        {
            this.debug('no error msg given');
        }
        
    },
    
    // TODO use Prototype methods instead of doing it the long way
    create_error_container: function(id)
    {
    
        //this.debug("checking for error container for id: " + id);
        //this.debug("error id: " + this.ids.error);
        
        // only create it if it doesn't yet exist
        if ($(this.ids.error))
        {
            //this.debug("error container exists");
            return;
        }
        
        this.debug("error container does not yet exist");
    
        // new row
        var tr = document.createElement(this.child_tag);
        tr.setAttribute('id',this.ids.error);
        tr.className        = 'error';
        
        // left cell for message
        var td = document.createElement(this.cell_tag);
        td.setAttribute('colspan', this.tmpl.cols.length); // one cell as wide as all data columns
        td.setAttribute('id', this.ids.error_cell);
        td.className        = 'error';
        td.style.cssText    = 'display:table-cell';
        
        // right cell for button
        var err_b_cell = document.createElement(this.cell_tag);
        err_b_cell.setAttribute('colspan', 1);    // one cell at end for the button
        
        // button
        var err_b = this.make_button(this.ids.error_b, 'clear errors');
        err_b.setAttribute('onclick', this.tid + '.clear_errors("' + id + '")');
        
        // assemble
        err_b_cell.appendChild(err_b);
        tr.appendChild(td);
        tr.appendChild(err_b_cell);
        
        this.debug("error container created: " + this.ids.error);
        
        $(id).appendChild(tr);  // add 3rd row to tbody

    },
    
    clear_errors: function(id)
    {
        this.debug("clearing errors for id: " + this.ids.error);
        if ($(this.ids.error))
        {
            $(this.ids.row).removeChild( $(this.ids.error) );
            this.debug("error row removed");
        }
        this.error = 0;   // always clear this flag
    },
    
    /*
        spinner_on()
        spinner_off()
        
        toggle the status spinner.
        uses the table cell where the action buttons sit,
        so those are hidden/shown as needed.
        
    */
    
    make_spinner: function(id)
    {
        var s = document.createElement('img');
        s.setAttribute('src', this.spin_url);
        s.setAttribute('alt','... action in progress ...');
        s.setAttribute('id','spinner');
        return s;
    },
    
    spinner_on: function(id)
    {
        var spin = this.make_spinner(id);
        this.hide_buttons(id);
        $(this.ids.buttons).appendChild(spin);
    },
    
    spinner_off: function(id)
    {
        $(this.ids.buttons).removeChild($('spinner'));
        this.show_buttons;
    }
    
   



};
