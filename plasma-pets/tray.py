"""Register a Plasma tray item and exit cleanly when its Quit action is used."""

from gi.repository import Gio, GLib

V = GLib.Variant
loop = GLib.MainLoop()
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
item_path = "/StatusNotifierItem"
menu_path = "/MenuBar"

item_properties = {
    "Category": V("s", "ApplicationStatus"),
    "Id": V("s", "plasma-pets"),
    "Title": V("s", "plasma-pets"),
    "Status": V("s", "Active"),
    "IconName": V("s", "face-smile"),
    "ItemIsMenu": V("b", True),
    "Menu": V("o", menu_path),
}

item_xml = (
    '<interface name="org.kde.StatusNotifierItem">'
    + "".join(
        f'<property name="{name}" type="{value.get_type_string()}" access="read"/>'
        for name, value in item_properties.items()
    )
    + "</interface>"
)
menu_xml = """
<interface name="com.canonical.dbusmenu">
  <property name="Version" type="u" access="read"/>
  <method name="GetLayout">
    <arg type="i"/><arg type="i"/><arg type="as"/>
    <arg type="u" direction="out"/><arg type="(ia{sv}av)" direction="out"/>
  </method>
  <method name="GetGroupProperties">
    <arg type="ai"/><arg type="as"/><arg type="a(ia{sv})" direction="out"/>
  </method>
  <method name="AboutToShow">
    <arg type="i"/><arg type="b" direction="out"/>
  </method>
  <method name="Event">
    <arg type="i"/><arg type="s"/><arg type="v"/><arg type="u"/>
  </method>
</interface>
"""
entries = {
    0: {"children-display": V("s", "submenu")},
    1: {"label": V("s", "Закрыть plasma-pets"), "icon-name": V("s", "application-exit")},
}


def menu_call(connection, sender, path, interface, method, parameters, invocation):
    args = parameters.unpack()
    if method == "GetLayout":
        item, depth, _ = args
        children = [V("(ia{sv}av)", (1, entries[1], []))] if item == 0 and depth != 0 else []
        invocation.return_value(V("(u(ia{sv}av))", (1, (item, entries.get(item, {}), children))))
    elif method == "GetGroupProperties":
        ids, _ = args
        invocation.return_value(V("(a(ia{sv}))", ([(i, entries[i]) for i in ids if i in entries],)))
    elif method == "AboutToShow":
        invocation.return_value(V("(b)", (False,)))
    elif method == "Event":
        invocation.return_value(None)
        if args[0] == 1 and args[1] == "clicked":
            loop.quit()


def register(path, xml, callback, properties):
    info = Gio.DBusNodeInfo.new_for_xml(f"<node>{xml}</node>").interfaces[0]
    bus.register_object(path, info, callback, lambda *_args: properties.get(_args[4]), None)


def watcher_appeared(connection, name, _owner):
    connection.call(
        name, "/StatusNotifierWatcher", name, "RegisterStatusNotifierItem",
        V("(s)", (connection.get_unique_name(),)), None,
        Gio.DBusCallFlags.NONE, -1, None, None,
    )


register(item_path, item_xml, None, item_properties)
register(menu_path, menu_xml, menu_call, {"Version": V("u", 3)})
Gio.bus_watch_name_on_connection(
    bus, "org.kde.StatusNotifierWatcher", Gio.BusNameWatcherFlags.NONE, watcher_appeared, None
)
loop.run()
