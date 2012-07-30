#!/usr/bin/python
#-*-encoding:utf-8-*-

import pygtk
import gtk
import os
import subprocess
import os
import json
import sys
#import pprint
import logging
import re 


creatorName = 'sebogh'

# Links:
# http://www.metadataworkinggroup.org/
# http://metadatadeluxe.pbworks.com
# http://metadatadeluxe.pbworks.com/w/page/47662311/Top%2010%20List%20of%20Embedded%20Metadata%20Properties
# http://owl.phy.queensu.ca/~phil/exiftool/TagNames/index.html
# http://www.photometadata.org/META-Resources-Field-Guide-to-Metadata


# catalog describes all metadata that shall be dealt with.
#
# Each (list-) element is a dictonary describing one GUI-element:
#
#   'label'        : The label to use (in the GUI).
#   'max'          : The maximum length of the input value (should as
#                    in accordance to the respective standard EXIF-,
#                    IPTC- and/or XMP) (in the GUI).
#   'view_delim'   : How to visially join the different values from 
#                    the different files (in the GUI)(e.g. '"\n"', or 
#                    '", "').
#   'view_show'    : Whether to initially show the current values (in 
#                    the GUI)(TRUE or FALSE).
#   'enabled'      : Whether to initially enable the entry (in the 
#                    (in the GUI)(TRUE or FALSE).
#   'synlabels'    : A list of (syntactic-) labels the metadata in 
#                    questions is know by (in exiftool)(e.g. 
#                    '["EXIF:Copyright", "IPTC:CopyrightNotice"]').
#   'rule_below'   : Whether to put a horizontal rule below this entry
#                    (and the current values) (in the GUI)(TRUE or 
#                    FALSE).
#   'default'      : The default text to place in the entry (in the 
#                    GUI)(None or some string).
#   'query'        : Whether to query current values (using the given 
#                    synlabels)(in exiftool)(TRUE or FALSE).
#   'write_op'     : Which write-/assignment operator to use (in 
#                    exiftool)(e.g. '+=', '-=', or '=').
#   'write_splitre': Regular expression to use while splitting the
#                    GUI-input before handing it over to exiftool 
#                    (e.g. ', *' or FALSE).
catalog = [
           {'label'        : 'Keywords (+)', 
            'max'          : 64,             
            'view_delim'   : ', ', 
            'view_show'    : True, 
            'enabled'      : True,
            'synlabels'    : ['IPTC:Keywords', 'XMP-dc:subject'],
            'rule_below'   : False,
            'default'      : None,
            'query'        : False,
            'write_op'     : '+=',
            'write_splitre': ', *',
            },             
           {'label'        : 'Keywords (-)',
            'max'          : 64,   
            'view_delim'   : ', ', 
            'view_show'    : True, 
            'enabled'      : True,
            'synlabels'    : ['IPTC:Keywords', 'XMP-dc:subject'],
            'rule_below'   : True,
            'default'      : None,
            'query'        : True,
            'write_op'     : '-=',
            'write_splitre': ', *',
            },             
           {'label'        : 'ID',      
            'max'          : 64,  
            'view_show'    : True, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['EXIF:UserComment', 'IPTC:ObjectName', 'XMP-dc:Title'],
            'rule_below'   : False,
            'default'      : None,
            'query'        : True,
            'write_op'     : '=',
            'write_splitre': False,
            },             
           {'label'        : 'Headline',      
            'max'          : 256,  
            'view_show'    : True, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['IPTC:Headline', 'XMP-photoshop:Headline'],
            'rule_below'   : False,
            'default'      : None,
            'query'        : True,
            'write_op'     : '=',
            'write_splitre': False,
            },             
           {'label'        : 'Description',   
            'max'          : 2000, 
            'view_show'    : True, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['EXIF:ImageDescription', 'IPTC:Caption-Abstract', 'XMP-dc:Description'],
            'rule_below'   : False,
            'default'      : None,
            'query'        : True,
            'write_op'     : '=',
            'write_splitre': False,
            },             
           {'label'        : 'Creator',       
            'max'          : 32,   
            'view_show'    : True, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['EXIF:Artist', 'IPTC:By-line', 'XMP-dc:Creator'],
            'rule_below'   : False,
            'default'      : creatorName,
            'query'        : True,
            'write_op'     : '=',
            'write_splitre': False,
            },             
           {'label'        : 'Copyright',     
            'max'          : 128,  
            'view_show'    : True, 
            'enabled'      : False,
            'view_delim'   : '\n', 
            'synlabels'    : ['EXIF:Copyright', 'IPTC:CopyrightNotice', 'XMP-dc:Rights'],
            'rule_below'   : False,
            'default'      : 'Copyright (c) 2012 ' + 
                             creatorName + 
                             ', all rights reserved',
            'query'        : True,
            'write_op'     : '=',
            'write_splitre': False,
            },
           ]


def read_metadata(targets):
    """Read current metadata for all targets and all synlabels."""

    # Compose "base-command".
    command = ['/usr/bin/exiftool']
    command+= ['-j']

    # Add all synlabels as query parameter.
    for x in catalog:
        if x['query']:
            command+= ['-' + y for y in x['synlabels']]

    # Add all query targets.
    command+= targets

    # Execute command.
    #print ' '.join(command)
    process = subprocess.Popen(command, 
                               shell=False, 
                               stdout=subprocess.PIPE)
    (stdout, stderr) = process.communicate()

    # Get json encoded output.
    values = json.loads(stdout)

    return values


def write_metadata(targets, values):
    """Write/Update metadata for all targets and all synlabels
    (depending on values)."""

    # Compose "base-command".
    command = ['/usr/bin/exiftool']

    # For each catalog entry ... 
    for i in range(len(catalog)):

        # For each synlabel of this catalog entry ...
        for x in catalog[i]['synlabels']:

            # If there are new values for those synlabels ...
            if values[i] != None:

                # Create separate or joined exiftool write-parameter.
                if catalog[i]['write_splitre']:
                    for value in re.split(catalog[i]['write_splitre'], 
                                          values[i]):
                        command.append('-' + 
                                       x + 
                                       catalog[i]['write_op'] + 
                                       value)
                else:
                    command.append('-' + 
                                   x + 
                                   catalog[i]['write_op'] + 
                                   values[i])

    # Add all targets.
    command+= targets

    # Execute command.
    #print ' '.join(command)
    process = subprocess.Popen(command, 
                               shell=False, 
                               stdout=subprocess.PIPE)
    (stdout, stderr) = process.communicate()
    return 


def join_metadata(metadata):
    """Join same type metadata across targets."""

    # Dictonary mapping each catalog entry to the associated metadata.
    joined = {}

    # For all catalog entries ...
    for i in range(len(catalog)):
        foo = set()

        # If current values are of interests ...
        if catalog[i]['query']:

            # For all targets ...
            for target in metadata:

                # Collect metadata from all synlables and ...
                for synlabel in catalog[i]['synlabels']:
                    
                    # Remove any leading family group name.
                    synlabel = re.sub(r'^[^:]+:', '', synlabel)

                    # If there is an entry for the synlabel.
                    if synlabel in target:
                        bar = target[synlabel]
                        
                        # Merge into a single set (removing duplicates).
                        if isinstance(bar, list):
                            foo = foo.union(bar) 
                        else:
                            foo.add(bar)

        # Save the metadata collected for this catalog entry.
        joined[i] = foo

    return joined


def dialog(target_basename, joined):
    dialog = gtk.Dialog('Tag',
                        None,
                        gtk.DIALOG_MODAL | 
                        gtk.DIALOG_DESTROY_WITH_PARENT,
                        (gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL,
                         gtk.STOCK_OK, gtk.RESPONSE_OK))
    dialog.set_default_response(gtk.RESPONSE_OK)

    # Get style values of the dialog window (for viewhelp()).
    dialog.realize()
    bgStyle = dialog.get_style().bg[gtk.STATE_NORMAL]
    fgStyle = dialog.get_style().fg[gtk.STATE_INSENSITIVE]

    # Toggle callback.
    def toggleDisable(check, widgets):
        active = check.get_active()
        for widget in widgets:
            if widget:
                widget.set_sensitive(active)

    # Callback for info button.
    def toggleCurrentVisibility(button, label, height):
        if label.get_child_visible():
            label.set_child_visible(False)
            label.get_child().set_size_request(0, 0)
            dialog.resize(1,1)
        else:
            label.get_child().set_size_request(0, height)
            label.set_child_visible(True)
            label.set_visible(True)

    # Helper to create entries with size and max parameters.
    def entryWithSize(size, max):
        entry = gtk.Entry()
        entry.set_width_chars(size)
        entry.set_max_length(max)
        return entry

    # Helper for the textview (showing the current values).
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

    # Helper to create and populate an alignment.
    def aligned(widget, 
                xalign=0.5, yalign=0.5, 
                xscale=0.0, yscale=0.0):
        alignment = gtk.Alignment(xalign, yalign, xscale, yscale)
        alignment.add(widget)
        return alignment

    # Helper to create a place the widgets for one catalog entry.
    def make_line(joined, i, table, y, delimitor, view_height=60, 
                  size=48, max=48, 
                  view_show=False, enabled=False, 
                  default=None, label_text=None, rule_below=False):

        # The check button.
        check = gtk.CheckButton()
        table.attach(check, 0, 1, y, y+1)
        check.set_active(enabled)

        # The label (if desired).
        label = None
        if label_text:
            label = gtk.Label(label_text)
            table.attach(aligned(label, 1, 0.5), 1, 2, y, y+1)
            label.set_sensitive(enabled)

        # The entry possibly with default text.
        entry = entryWithSize(size, max)
        table.attach(aligned(entry, 0, 0.5, 1.0), 2, 3, y, y+1)
        entry.set_sensitive(enabled)
        if default:
            entry.set_text(default)

        # Connect the toogle to disable/enable label and entry.
        check.connect('toggled', toggleDisable, [label, entry])

        # If there are current values.
        if joined and joined[i]:

            # Create and placethe textview showing current values.
            y += 1
            str = delimitor.join(joined[i])
            textview = viewhelp(str, view_height)
            table.attach(aligned(textview, 0.5, 0.5, 1, 0), 2, 3, y, y+1)

            # Add the info button.
            button = gtk.ToolButton(gtk.STOCK_INFO)
            table.attach(aligned(button, 0.5, 0), 3, 4, y-1, y)

            # Connect the info button to hide/show the textview.
            button.connect('clicked', toggleCurrentVisibility, 
                           textview, view_height)

            # Set the default visiblility according to catalog.
            if not view_show:
                textview.set_child_visible(False)
                textview.get_child().set_size_request(0, 0)

        # If there are no current values.
        else:

            # Add some additional vertical space.
            if y>0:
                table.set_row_spacing(y-1, 
                                      table.get_row_spacing(y-1)+5)
            table.set_row_spacing(y, 
                                  table.get_row_spacing(y)+5)

        # Add a horizontal rule below, if desired.
        if rule_below:
            y += 1
            table.attach(gtk.HSeparator(), 1, 4, y, y+1)
            if y>0:
                table.set_row_spacing(y-1, 
                                      table.get_row_spacing(y-1)+5)
            table.set_row_spacing(y, 
                                  table.get_row_spacing(y)+5)

        # Return the toogle and the entry for later reference.
        return ({'check' : check, 'entry' : entry}, y+1)



    # The main layout table.
    table = gtk.Table(len(catalog)*3, 5, False)
    table.set_row_spacings(0)
    table.set_col_spacings(10)

    # Create and save widgets for each catalog entry.
    widgets = []
    y = 0
    for i in range(len(catalog)):
        x = catalog[i]
        (tmp, y) = make_line(joined, i, table, y, x['view_delim'], 60, 
                             48, x['max'], 
                             x['view_show'], x['enabled'], 
                             x['default'], x['label'], x['rule_below'])
        widgets.append(tmp)

    # Reduce table size to the necessary number of rows.
    table.resize(y-1, 5)

    # Set the focus.
    #widgets[0]['entry'].grab_focus() 

    # Alignment of the main layout table within the window.
    tableAlign = aligned(table)
    tableAlign.set_padding(10, 10, 10 ,10)
    dialog.vbox.pack_start(tableAlign)

    # Run the Dialog.
    dialog.show_all()
    response = dialog.run()

    res = {}

    # Capture Inputs.
    for i in range(len(widgets)):
        input = widgets[i]['entry'].get_text()

        # If entry enabled, get the input possibly ''.
        if widgets[i]['check'].get_active():
            res[i] = input
        
        # If entry !enabled, save as None.
        else:
            res[i] = None

    dialog.destroy()

    return (response, res)


def main():
    """The main function."""

    # Get the selection, i.e. a list of files (targets).
    selected = os.environ.get('NAUTILUS_SCRIPT_SELECTED_FILE_PATHS',
                              '')

    # Get targets (from selection or command line) or terminate.
    if selected:
        targets = selected.splitlines()
    else:
        targets = sys.argv[1::]
        if not targets:
            return 

    # Read current metadata values and join across targets.
    values = join_metadata(read_metadata(targets))

    # Query new values via dialog.
    (response, new_values) = dialog(targets, values)
    if response == gtk.RESPONSE_CANCEL:
        return 

    # Write (update) metadata.
    write_metadata(targets, new_values)

    return

if __name__ == "__main__":
     main()
