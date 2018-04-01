/*
* Copyright (c) 2018 (https://github.com/phase1geo/Minder)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;

public class UndoNodeName : UndoItem {
  
  DrawArea  _da;
  Node      _node;
  string    _old_name;
  string    _new_name;

  /* Constructor for a node name change */
  public UndoNodeName( DrawArea da, Node n, string new_name ) {
    base( _( "Node Name Change" ) );
    _da       = da;
    _node     = n;
    _old_name = n.name;
    _new_name = new_name;
  }

  /* Undoes a node name change */
  public override void undo() {
    _node.name = _old_name;
    _da.queue_draw();
  }
  
  /* Redoes a node name change */
  public override void redo() {
    _node.name = _new_name;
    _da.queue_draw();
  }
  
}