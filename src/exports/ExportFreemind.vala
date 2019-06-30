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

using GLib;
using Gdk;
using Gee;

public class ExportFreemind : Object {

  /* Exports the given drawing area to the file of the given name */
  public static bool export( string fname, DrawArea da ) {
    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    doc->set_root_element( export_map( da ) );
    doc->save_format_file( fname, 1 );
    delete doc;
    return( false );
  }

  /* Generates the header for the document */
  private static Xml.Node* export_map( DrawArea da ) {
    Xml.Node* map = new Xml.Node( null, "map" );
    map->new_prop( "version", "1.0.1" );
    var nodes = da.get_nodes();
    for( int i=0; i<nodes.length; i++ ) {
      map->add_child( export_node( nodes.index( i ), da ) );
    }
    return( map );
  }

  /* Exports the given node information */
  private static Xml.Node* export_node( Node node, DrawArea da ) {

    Xml.Node* n = new Xml.Node( null, "node" );

    n->new_prop( "ID", "id_" + node.id().to_string() );
    n->new_prop( "TEXT", node.name.text );
    if( node.linked_node != null ) {
      n->new_prop( "LINK", "#id_" + node.linked_node.id().to_string() );
    }
    n->new_prop( "FOLDED", node.folded.to_string() );
    n->new_prop( "COLOR", Utils.color_from_rgba( node.link_color ) );
    n->new_prop( "POSITION", ((node.side == NodeSide.LEFT) ? "left" : "right") );

    n->add_child( export_edge( node, da ) );
    n->add_child( export_font( node, da ) );

    /* Add arrowlinks */
    int         index = 0;
    Connection? conn  = null;
    while( (conn = da.get_connections().get_attached_connection( node, index++ )) != null ) {
      if( conn.from_node == node ) {
        n->add_child( export_arrowlink( conn, da ) );
      }
    }

    /* Add nodes */
    for( int i=0; i<node.children().length; i++ ) {
      n->add_child( export_node( node.children().index( i ), da ) );
    }

    return( n );

  }

  /* Exports the given node link as an edge */
  private static Xml.Node* export_edge( Node node, DrawArea da ) {
    Xml.Node* n = new Xml.Node( null, "edge" );
    n->new_prop( "STYLE", (node.style.link_type.name() == "curved") ? "bezier" : "linear" );
    n->new_prop( "COLOR", Utils.color_from_rgba( node.link_color ) );
    n->new_prop( "WIDTH", node.style.link_width.to_string() );
    return( n );
  }

  /* Exports the given node font */
  private static Xml.Node* export_font( Node node, DrawArea da ) {
    Xml.Node* n = new Xml.Node( null, "font" );
    n->new_prop( "NAME",   node.style.node_font.get_family() );
    n->new_prop( "SIZE",   (node.style.node_font.get_size() / Pango.SCALE).to_string() );
    n->new_prop( "BOLD",   ((node.name.text.substring( 0, 3 ) == "<b>") || (node.name.text.substring( 0, 6 ) == "<i><b>")).to_string() );
    n->new_prop( "ITALIC", ((node.name.text.substring( 0, 3 ) == "<i>") || (node.name.text.substring( 0, 6 ) == "<b><i>")).to_string() );
    return( n );
  }

  /* Exports the given connection as an arrowlink */
  private static Xml.Node* export_arrowlink( Connection conn, DrawArea da ) {
    Xml.Node* n = new Xml.Node( null, "arrowlink" );
    n->new_prop( "COLOR", Utils.color_from_rgba( conn.color ) );
    n->new_prop( "DESTINATION", "id_" + conn.to_node.id().to_string() );
    n->new_prop( "STARTARROW",  ((conn.style.connection_arrow == "none") || (conn.style.connection_arrow == "fromto")) ? "None" : "Default" );
    n->new_prop( "ENDARROW",    ((conn.style.connection_arrow == "none") || (conn.style.connection_arrow == "tofrom")) ? "None" : "Default" );
    return( n );
  }

  /*
   Reads the contents of an OPML file and creates a new document based on
   the stored information.
  */
  public static bool import( string fname, DrawArea da ) {

    /* Read in the contents of the Freemind file */
    var doc = Xml.Parser.parse_file( fname );
    if( doc == null ) {
      return( false );
    }

    /* Load the contents of the file */
    import_map( da, doc->get_root_element() );

    /* Update the drawing area */
    da.queue_draw();

    /* Delete the OPML document */
    delete doc;

    return( true );

  }

  /* Parses the OPML head block for information that we will use */
  private static void import_map( DrawArea da, Xml.Node* n ) {

    var color_map = new HashMap<string,RGBA?>();
    var id_map    = new HashMap<string,int>();
    var link_ids  = new Array<NodeLinkInfo?>();
    var to_nodes  = new Array<string>();

    /* Not sure what to do with the version information */
    string? v = n->get_prop( "version" );
    if( v != null ) {
      /* Not sure what to do with this value */
    }

    for( Xml.Node* it = n->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        if( it->name == "node" ) {
          var root = import_node( it, da, null, color_map, id_map, link_ids, to_nodes );
          da.get_nodes().append_val( root );
        }
      }
    }

    /* Connect linked nodes */
    for( int i=0; i<link_ids.length; i++ ) {
      link_ids.index( i ).node.linked_node = da.get_node( da.get_nodes(), id_map.get( link_ids.index( i ).id_str ) );
    }

    /* Finish up the connections */
    for( int i=0; i<to_nodes.length; i++ ) {
      if( id_map.has_key( to_nodes.index( i ) ) ) {
        var to_node = da.get_node( da.get_nodes(), id_map.get( to_nodes.index( i ) ) );
        if( to_node != null ) {
          da.get_connections().complete_connection( i, to_node );
        }
      }
    }

  }

  /* Parses the given Freemind node */
  public static Node import_node( Xml.Node* n, DrawArea da, Node? parent, HashMap<string,RGBA?> color_map, HashMap<string,int> id_map, Array<NodeLinkInfo?> link_ids, Array<string> to_nodes ) {

    var node = new Node( da, da.layouts.get_default() );

    /* Make sure the style has a default value */
    node.style = StyleInspector.styles.get_style_for_level( (parent == null) ? 0 : 1 );

    string? i = n->get_prop( "ID" );
    if( i != null ) {
      id_map.set( i, node.id() );
    }

    string? t = n->get_prop( "TEXT" );
    if( t != null ) {
      node.name.text = t;
    }

    string? l = n->get_prop( "LINK" );
    if( l != null ) {
      link_ids.append_val( NodeLinkInfo( l.substring( 1 ), node ) );
    }

    string? f = n->get_prop( "FOLDED" );
    if( f != null ) {
      node.folded = bool.parse( f );
    }

    string? c = n->get_prop( "COLOR" );
    if( c != null ) {
      if( color_map.has_key( c ) ) {
        node.link_color = color_map.get( c );
      } else {
        node.link_color = da.get_theme().next_color();
        color_map.set( c, node.link_color );
      }
    }

    string? p = n->get_prop( "POSITION" );
    if( p != null ) {
      node.side = (p == "left") ? NodeSide.LEFT : NodeSide.RIGHT;
    }

    /* Parse the child nodes */
    for( Xml.Node* it = n->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        switch( it->name ) {
          case "node"      :  import_node( it, da, node, color_map, id_map, link_ids, to_nodes );  break;
          case "edge"      :  import_edge( it, node );  break;
          case "font"      :  import_font( it, node );  break;
          case "icon"      :  break;  // Not implemented
          case "cloud"     :  break;  // Not implemented
          case "arrowlink" :  import_arrowlink( it, da, node, to_nodes );  break;
        }
      }
    }

    /* Attach the new node to its parent */
    if( parent != null ) {
      node.attach( parent, -1, da.get_theme() );
    }

    return( node );

  }

  private static void import_edge( Xml.Node* n, Node node ) {

    string? s = n->get_prop( "STYLE" );
    if( s != null ) {
      switch( s ) {
        case "bezier" :  node.style.link_type = new LinkTypeCurved();    break;
        case "linear" :  node.style.link_type = new LinkTypeStraight();  break;
      }
    }

    string? c = n->get_prop( "COLOR" );
    if( c != null ) {
      /* Not implemented - link color and node color must be the same */
    }

    string? w = n->get_prop( "WIDTH" );
    if( w != null ) {
      node.style.link_width = int.parse( w );
    }

  }

  private static void import_font( Xml.Node* n, Node node ) {

    string? f = n->get_prop( "NAME" );
    if( f != null ) {
      node.style.node_font.set_family( f );
    }

    string? s = n->get_prop( "SIZE" );
    if( s != null ) {
      node.style.node_font.set_size( int.parse( s ) * Pango.SCALE );
    }

    string? b = n->get_prop( "BOLD" );
    if( b != null ) {
      if( bool.parse( b ) ) {
        node.name.text = "<b>" + node.name.text + "</b>";
      }
    }

    string? i = n->get_prop( "ITALIC" );
    if( i != null ) {
      if( bool.parse( i ) ) {
        node.name.text = "<i>" + node.name.text + "</i>";
      }
    }

  }

  private static void import_arrowlink( Xml.Node* n, DrawArea da, Node from_node, Array<string> to_nodes ) {

    var conn        = new Connection( da, from_node );
    var start_arrow = "None";
    var end_arrow   = "None";

    string? c = n->get_prop( "COLOR" );
    if( c != null ) {
      /* Not implemented */
    }

    string? d = n->get_prop( "DESTINATION" );
    if( d != null ) {
      to_nodes.append_val( d );
    }

    string? sa = n->get_prop( "STARTARROW" );
    if( sa != null ) {
      start_arrow = sa;
    }

    string? ea = n->get_prop( "ENDARROW" );
    if( ea != null ) {
      end_arrow = ea;
    }

    /* Stylize the arrow */
    switch( start_arrow + end_arrow ) {
      case "NoneNone"       :  conn.style.connection_arrow = "none";    break;
      case "NoneDefault"    :  conn.style.connection_arrow = "fromto";  break;
      case "DefaultNone"    :  conn.style.connection_arrow = "tofrom";  break;
      case "DefaultDefault" :  conn.style.connection_arrow = "both";    break;
    }

    /* Add the connection to the connections list */
    da.get_connections().add_connection( conn );

  }

}