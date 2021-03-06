require "../ncurses"

module NCurses
  class Window
    ATTRIBUTES = [
      :normal, :attributes, :chartext, :color, :standout, :underline, :reverse,
      :blink, :dim, :bold, :altcharset, :invis, :protect, :horizontal, :left,
      :low, :right, :top, :vertical, :italic,
    ]

    def initialize(height = nil, width = nil, y = 0, x = 0)
      max_height, max_width = NCurses.stdscr.max_x, NCurses.stdscr.max_y
      initialize(LibNCurses.newwin(height || max_height, width || max_width, y, x))
    end

    def max_x
      LibNCurses.getmaxx(self)
    end

    def max_y
      LibNCurses.getmaxy(self)
    end

    def max_dimensions
      {x: max_x, y: max_y}
    end

    private macro attr_mask(attributes)
      mask = LibNCurses::Attribute::NORMAL

      attributes.each do |attribute|
        mask |= case(attribute)
        {% for attribute in ATTRIBUTES %}
          when {{attribute}}
            LibNCurses::Attribute::{{attribute.upcase.id}}
        {% end %}
        else
          raise "unknown attribute #{attribute}"
        end
      end

      mask
    end

    def attr_on(*attributes)
      attr_on(attributes.to_a)
    end

    def attr_on(attributes : Array(Symbol?))
      LibNCurses.wattr_on(self, attr_mask(attributes), Pointer(Void).null)
    end

    def attr_off(*attributes)
      attr_off(attributes.to_a)
    end

    def attr_off(attributes : Array(Symbol?))
      LibNCurses.wattr_off(self, attr_mask(attributes), Pointer(Void).null)
    end

    def with_attr(*attributes, &block)
      with_attr(attributes.to_a, &block)
    end

    def with_attr(attributes : Array(Symbol?))
      attr_on(attributes)
      begin
        yield
      ensure
        attr_off(attributes)
      end
    end

    def current_color
      @current_color ||= 0
    end

    def set_color(slot)
      LibNCurses.wcolor_set(self, slot.to_i16, nil)
      @current_color = slot
    end

    def with_color(slot)
      old_color = current_color
      set_color(slot)
      yield
    ensure
      set_color(old_color || 0)
    end

    def current_background
      @current_background ||= 0
    end

    def set_background(color_pair : Int32)
      background = NCurses.color_pair(color_pair)
      LibNCurses.wbkgd(self, background)
      @current_background = background
    end

    def get_char
      LibNCurses.wgetch(self)
    end

    def no_timeout
      LibNCurses.nodelay(self, false)
      LibNCurses.notimeout(self, true)
    end

    def no_delay
      LibNCurses.notimeout(self, false)
      LibNCurses.nodelay(self, true)
    end

    def timeout=(value)
      LibNCurses.notimeout(self, false)
      LibNCurses.wtimeout(self, value)
    end

    def add_char(chr, position = nil)
      if position
        LibNCurses.mvwaddch(self, position[0], position[1], chr)
      else
        LibNCurses.waddch(self, chr)
      end
    end

    def print(message, position = nil)
      if position
        LibNCurses.mvwprintw(self, position[0], position[1], message)
      else
        LibNCurses.wprintw(self, message)
      end
    end

    def move(x, y)
      if ERR == LibNCurses.wmove(self, x, y)
        raise "Unable to set cursor position"
      end
    end

    def clear
      LibNCurses.wclear(self)
    end

    def refresh
      LibNCurses.wrefresh(self)
    end

    def on_input
      no_timeout
      char = get_char
      case (char)
      when 27
        on_special_input { |key, mod| yield(key, mod) }
      when 10
        yield(:return, nil)
      when 32..127
        yield(char.chr, nil)
      end
    end

    private def on_special_input
      no_delay
      char = get_char
      if char == -1
        yield(:escape, nil)
      elsif char == 91
        case (get_char)
        when 65 then yield(:up, nil)
        when 66 then yield(:down, nil)
        end
      else
        yield(char.chr, :alt)
      end
    end
  end
end
