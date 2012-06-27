#!/usr/bin/python
#-*-encoding:utf-8-*-

import pygtk
import gtk
import os
import subprocess
import os
import json
import sys
import pprint
import textwrap
import logging
import re 

creatorName = 'sebogh'

mapping = [
           {'label'        : 'Keywords (+)',
            'max'          : 64,   
            'view_delim'   : ', ', 
            'view_show'    : False, 
            'enabled'      : True,
            'synlabels'    : ['Keywords', 'keywords'],
            'rule_below'   : False,
            'default'      : None,
            'query'        : False,
            'write_op'     : '+=',
            'write_split_re'  : ', *',
            },             
           {'label'        : 'Keywords (-)',
            'max'          : 64,   
            'view_delim'   : ', ', 
            'view_show'    : True, 
            'enabled'      : True,
            'synlabels'    : ['Keywords', 'keywords'],
            'rule_below'   : True,
            'default'      : None,
            'query'        : True,
            'write_op'     : '-=',
            'write_split_re'  : ', *',
            },             
           {'label'        : 'Headline',      
            'max'          : 256,  
            'view_show'    : False, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['Headline'],
            'rule_below'   : False,
            'default'      : None,
            'query'        : True,
            'write_op'     : '=',
            'write_split_re'  : False,
            },             
           {'label'        : 'Description',   
            'max'          : 2000, 
            'view_show'    : False, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['Description'],
            'rule_below'   : False,
            'default'      : None,
            'query'        : True,
            'write_op'     : '=',
            'write_split_re'  : False,
            },             
           {'label'        : 'Creator',       
            'max'          : 32,   
            'view_show'    : False, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['Creator', 'By-line'],
            'rule_below'   : False,
            'default'      : creatorName,
            'query'        : True,
            'write_op'     : '=',
            'write_split_re'  : False,
            },             
           {'label'        : 'Copyright',     
            'max'          : 128,  
            'view_show'    : False, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['CopyrightNotice', 'Copyright'],
            'rule_below'   : False,
            'default'      : 'Copyright (c) 2010 ' +  creatorName + ', all rights reserved',
            'query'        : True,
            'write_op'     : '=',
            'write_split_re'  : False,
            },
           ]



def alert(msg):
    """Show a dialog with a simple message."""

    dialog = gtk.MessageDialog(type=gtk.MESSAGE_ERROR)
    dialog.set_markup(msg)
    dialog.run()


def wrapAtSpaces(str, length):
    """Wrap a string such that is at most length chars wide.  Wrap, if possible, at whitespaces"""    

    return str


def getTags(targets):
    """Run exiftool, i.e. query all targets for all synlabels
       associated with the known semlabels."""

    # Compose "base-command".
    command = ['/usr/bin/exiftool']
    command+= ['-j']

    # Add all synlabels as query parameter.
    for x in mapping:
        if x['query']:
            command+= ['-' + y for y in x['synlabels']]

    # Add all query targets.
    command+= targets

    #print ' '.join(command)

    # Execute command.
    process = subprocess.Popen(command, shell=False, stdout=subprocess.PIPE)
    (stdout, stderr) = process.communicate()

    # Return the output
    return json.loads(stdout)

def setTags(targets, values):

    # Compose "base-command".
    command = ['/usr/bin/exiftool']

    # Add all synlabels as write parameter.
    for i in range(len(mapping)):
        for x in mapping[i]['synlabels']:
            if values[i] != None:
                if mapping[i]['write_split_re']:
                    for value in re.split(mapping[i]['write_split_re'], values[i]):
                        command.append('-' + x + mapping[i]['write_op'] + value)
                else:
                    command.append('-' + x + mapping[i]['write_op'] + values[i])


    command+= targets

    #print ' '.join(command)

    # Execute command.
    process = subprocess.Popen(command, shell=False, stdout=subprocess.PIPE)
    (stdout, stderr) = process.communicate()

    return 





def normalizeData(metadata):
    """Rearange/normalize the output of exiftool."""

    # A dictonary mapping semlabels to the associated metadata.
    joinedoo = {}

    # For all semlabels.
    for i in range(len(mapping)):
        bar = set()

        if mapping[i]['query']:

            # For all files.
            for target in metadata:

                # Collect metadata from all synlables into a set.
                for synlabel in mapping[i]['synlabels']:
                    if synlabel in target:
                        tmp = target[synlabel]
                        
                    # Merge sets or add a single item.
                        if isinstance(tmp, list):
                            bar = bar.union(tmp) 
                        else:
                            bar.add(tmp)

        joinedoo[i] = bar

    return ({}, joinedoo)





def tagDialog(target_basename, joined, joinedoo):
    dialog = gtk.Dialog('Tag',
                        None,
                        gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                        (gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL,
                         gtk.STOCK_OK, gtk.RESPONSE_OK))
    dialog.set_default_response(gtk.RESPONSE_OK)

    # Get style values of the dialog window (for viewhelp()).
    dialog.realize()
    bgStyle = dialog.get_style().bg[gtk.STATE_NORMAL]
    fgStyle = dialog.get_style().fg[gtk.STATE_INSENSITIVE]

    # Callbacks the toggles.
    def toggleDisable(check, widgets):
        active = check.get_active()
        for widget in widgets:
            if widget:
                widget.set_sensitive(active)

    # Callbacks the warnings.
    def toggleCurrentVisibility(button, label, height):
        if label.get_child_visible():
            label.set_child_visible(False)
            label.get_child().set_size_request(0, 0)
            dialog.resize(1,1)
        else:
            label.get_child().set_size_request(0, height)
            label.set_child_visible(True)
            label.set_visible(True)

    # Entries.
    def entryWithSize(size, max):
        entry = gtk.Entry()
        entry.set_width_chars(size)
        entry.set_max_length(max)
        return entry

    # Helper for the textview.
    def viewhelp(text, height=60):
        scroller = gtk.ScrolledWindow()
        scroller.set_policy(gtk.POLICY_NEVER, gtk.POLICY_AUTOMATIC)
        textarea = gtk.TextView()
        scroller.add(textarea)
        textarea.get_buffer().insert_at_cursor(text)
        textarea.set_editable(False)
        textarea.set_cursor_visible(False)
        textarea.set_wrap_mode(gtk.WRAP_WORD_CHAR)
        textarea.modify_base(gtk.STATE_NORMAL, bgStyle)
        textarea.modify_text(gtk.STATE_NORMAL, fgStyle)
        alignment = gtk.Alignment(xscale=1.0)
        alignment.add(scroller)
        scroller.set_size_request(100, height) 
        return alignment

    def aligned(widget, xalign=0.5, yalign=0.5, xscale=0.0, yscale=0.0):
        alignment = gtk.Alignment(xalign, yalign, xscale, yscale)
        alignment.add(widget)
        return alignment

   
    def make_line(joinedoo, semlabel, table, y, delimitor, view_height=60, size=48, max=48, view_show=False, enabled=False, default=None, label_text=None, rule_below=False):

        check = gtk.CheckButton()
        table.attach(check, 0, 1, y, y+1)
        check.set_active(enabled)

        label = None
        if label_text:
            label = gtk.Label(label_text)
            table.attach(aligned(label, 1, 0.5), 1, 2, y, y+1)
            label.set_sensitive(enabled)

        entry = entryWithSize(size, max)
        table.attach(aligned(entry, 0, 0.5, 1.0), 2, 3, y, y+1)
        entry.set_sensitive(enabled)
        if default:
            entry.set_text(default)

        check.connect('toggled', toggleDisable, [label, entry])

        if joinedoo and joinedoo[semlabel]:
            y += 1
            str = delimitor.join(joinedoo[semlabel])
            textview = viewhelp(str, view_height)
            table.attach(aligned(textview, 0.5, 0.5, 1, 0), 2, 3, y, y+1)

            button = gtk.ToolButton(gtk.STOCK_INFO)
            table.attach(aligned(button, 0.5, 0), 3, 4, y-1, y)

            button.connect('clicked', toggleCurrentVisibility, textview, view_height)

            if not view_show:
                textview.set_child_visible(False)
                textview.get_child().set_size_request(0, 0)
        else:
            if y>0:
                table.set_row_spacing(y-1, table.get_row_spacing(y-1)+5)
            table.set_row_spacing(y, table.get_row_spacing(y)+5)

        if rule_below:
            y += 1
            table.attach(gtk.HSeparator(), 1, 4, y, y+1)
            if y>0:
                table.set_row_spacing(y-1, table.get_row_spacing(y-1)+5)
            table.set_row_spacing(y, table.get_row_spacing(y)+5)

        return ({'check' : check, 'entry' : entry}, y+1)



    # The main layout table.
    table = gtk.Table(200, 5, False)
    table.set_row_spacings(0)
    table.set_col_spacings(10)

    widgets = []

    y = 0
    for i in range(len(mapping)):
        x = mapping[i]
        (tmp, y) = make_line(joinedoo, i, table, y, x['view_delim'], 60, 48, x['max'], x['view_show'], x['enabled'], x['default'], x['label'], x['rule_below'])
        widgets.append(tmp)

    table.resize(y-1, 5)


    # Set the focus.
    widgets[0]['entry'].grab_focus() 

    # Alignment of the main layout table within the window.
    tableAlign = gtk.Alignment(xalign=0.5, yalign=0.5, xscale=0.0, yscale=0.0)
    tableAlign.set_padding(10, 10, 10 ,10)
    tableAlign.add(table)
    dialog.vbox.pack_start(tableAlign)

    # Run the Dialog.
    dialog.show_all()
    response = dialog.run()

    res = {}

    # Capture Inputs.
    for i in range(len(widgets)):
        input = widgets[i]['entry'].get_text()
        if widgets[i]['check'].get_active():
            res[i] = input
        else:
            res[i] = None

    dialog.destroy()

    return (response, res)


def main():
    """The main function."""

    # Get the selection, i.e. a list of files (targets).
    selected = os.environ.get('NAUTILUS_SCRIPT_SELECTED_FILE_PATHS','')

    # Terminate, if there is no selection, otherwise split.
    if selected:
        targets = selected.splitlines()
    else:
        targets = sys.argv[1::]
        if not targets:
            return 

    if targets:

        # Get the current metadata in a normalized form.
        tags = getTags(targets)

        #pp = pprint.PrettyPrinter()        
        #pp.pprint(tags)

        (joined, joinedoo) = normalizeData(tags)

        #pp.pprint(joinedoo)


        # Dialog.
        (response, values) = tagDialog(targets, joined, joinedoo)

        #pp.pprint(values)

        if response == gtk.RESPONSE_CANCEL:
            return 

        # Write the tags.
        setTags(targets, values)

    return

if __name__ == "__main__":
     main()
