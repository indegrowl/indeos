"""
CATPPUCCIN MOCHA
----------------
Catppuccin Mocha with a Lavender accent. See https://catppuccin.com/palette
"""
from enum import Enum

from pygments.styles.material import MaterialStyle

from zulipterminal.config.color import color_properties


# fmt: off
class CatppuccinMochaColor(Enum):
    # color  =  16code        256code  24code
    DEFAULT  = 'default       default  default'
    BASE     = 'black         h235     #1e1e2e'
    MANTLE   = 'black         h234     #181825'
    SURFACE0 = 'black         h237     #313244'
    SURFACE1 = 'dark_gray     h239     #45475a'
    SURFACE2 = 'dark_gray     h241     #585b70'
    OVERLAY0 = 'dark_gray     h243     #6c7086'
    TEXT     = 'white         h189     #cdd6f4'
    SUBTEXT1 = 'light_gray    h146     #bac2de'
    SUBTEXT0 = 'light_gray    h146     #a6adc8'
    LAVENDER = 'light_blue    h147     #b4befe'
    BLUE     = 'dark_blue     h111     #89b4fa'
    GREEN    = 'light_green   h151     #a6e3a1'
    RED      = 'light_red     h211     #f38ba8'
    YELLOW   = 'yellow        h223     #f9e2af'
    PEACH    = 'brown         h216     #fab387'
    MAUVE    = 'light_magenta h183     #cba6f7'
    PINK     = 'dark_magenta  h218     #f5c2e7'
    TEAL     = 'dark_cyan     h116     #94e2d5'


Color = color_properties(CatppuccinMochaColor, "BOLD")


STYLES = {
    # style_name       :  foreground                   background
    None               : (Color.TEXT,              Color.BASE),
    'selected'         : (Color.BASE,              Color.LAVENDER),
    'msg_selected'     : (Color.BASE,              Color.LAVENDER),
    'header'           : (Color.LAVENDER,          Color.BLUE),
    'general_narrow'   : (Color.BASE,              Color.BLUE),
    'general_bar'      : (Color.TEXT,              Color.BASE),
    'name'             : (Color.PEACH__BOLD,       Color.BASE),
    'unread'           : (Color.MAUVE,             Color.BASE),
    'user_active'      : (Color.GREEN,             Color.BASE),
    'user_idle'        : (Color.PEACH,             Color.BASE),
    'user_offline'     : (Color.TEXT,              Color.BASE),
    'user_inactive'    : (Color.TEXT,              Color.BASE),
    'title'            : (Color.TEXT__BOLD,        Color.BASE),
    'column_title'     : (Color.TEXT__BOLD,        Color.BASE),
    'time'             : (Color.BLUE,              Color.BASE),
    'bar'              : (Color.TEXT,              Color.SURFACE2),
    'msg_emoji'        : (Color.MAUVE,             Color.BASE),
    'reaction'         : (Color.MAUVE__BOLD,       Color.BASE),
    'reaction_mine'    : (Color.BASE,              Color.MAUVE),
    'msg_heading'      : (Color.BASE__BOLD,        Color.GREEN),
    'msg_math'         : (Color.BASE,              Color.SURFACE2),
    'msg_mention'      : (Color.RED__BOLD,         Color.BASE),
    'msg_link'         : (Color.BLUE,              Color.BASE),
    'msg_link_index'   : (Color.BLUE__BOLD,        Color.BASE),
    'msg_quote'        : (Color.PEACH,             Color.BASE),
    'msg_code'         : (Color.BASE,              Color.TEXT),
    'msg_bold'         : (Color.TEXT__BOLD,        Color.BASE),
    'msg_time'         : (Color.BASE,              Color.TEXT),
    'footer'           : (Color.BASE,              Color.SUBTEXT0),
    'footer_contrast'  : (Color.TEXT,              Color.BASE),
    'starred'          : (Color.RED__BOLD,         Color.BASE),
    'unread_count'     : (Color.PEACH,             Color.BASE),
    'starred_count'    : (Color.SUBTEXT0,          Color.BASE),
    'table_head'       : (Color.TEXT__BOLD,        Color.BASE),
    'filter_results'   : (Color.BASE,              Color.GREEN),
    'edit_topic'       : (Color.BASE,              Color.SURFACE2),
    'edit_tag'         : (Color.BASE,              Color.SURFACE2),
    'edit_author'      : (Color.PEACH,             Color.BASE),
    'edit_time'        : (Color.BLUE,              Color.BASE),
    'current_user'     : (Color.TEXT,              Color.BASE),
    'muted'            : (Color.BLUE,              Color.BASE),
    'popup_border'     : (Color.TEXT,              Color.BASE),
    'popup_category'   : (Color.BLUE__BOLD,        Color.BASE),
    'popup_contrast'   : (Color.BASE,              Color.SURFACE2),
    'popup_important'  : (Color.RED__BOLD,         Color.BASE),
    'widget_disabled'  : (Color.SURFACE2,          Color.BASE),
    'area:help'        : (Color.BASE,              Color.GREEN),
    'area:msg'         : (Color.BASE,              Color.MAUVE),
    'area:stream'      : (Color.BASE,              Color.BLUE),
    'area:error'       : (Color.BASE,              Color.RED),
    'area:user'        : (Color.BASE,              Color.YELLOW),
    'search_error'     : (Color.RED,               Color.BASE),
    'task:success'     : (Color.BASE,              Color.GREEN),
    'task:error'       : (Color.BASE,              Color.RED),
    'task:warning'     : (Color.BASE,              Color.MAUVE),
}

META = {
    'pygments': {
        'styles'    : MaterialStyle().styles,
        'background': 'h234',
        'overrides' : {},
    }
}
# fmt: on
