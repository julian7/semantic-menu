module SemanticMenu
  class MenuItem
    attr_accessor :children, :link, :title
    cattr_accessor :controller
    cattr_accessor :view
    extend ActiveSupport::Memoizable

    def initialize(title, link, level = 0, opts = {})
      @title = title
      @link = link
      @method = opts.delete(:method) || :get
      @ctrl = opts.delete(:controller) || false
      @level = level
      @opts = opts
      @children = []
    end
    
    def add(title, link = nil, opts = {}, &block)
      returning (MenuItem.new(title, link, @level + 1, opts)) do |item|
        @children << item
        yield item if block_given?
      end
    end
    
    def to_s
      ret = ""
      unless @link.nil?
        has_link = true
        ret = view.link_to(@title, @link, @opts)
      end
      if ret.empty?
        has_link = false
        ret = view.content_tag(:span, @title)
      end
      children = to_s_children
      unless children.empty?
        has_link = true
        ret += children
      end
      if has_link and !ret.empty?
        ret = view.content_tag :li, ret, active? ? {:class => "active"} : {}
      end
    end

    protected
    
    def get_breadcrumb
      unless active?
        return nil
      end
      @children.map{ |child| child.get_breadcrumb }.
        flatten.compact.unshift(self)
    end

    def to_s_breadcrumb
      ret = ""
      unless @link.nil?
        ret = view.link_to(@title, @link, @opts)
      end
      if ret.empty?
        ret = view.content_tag(:span, @title)
      end
      ret
    end
    
    def to_s_children
      if (@children.empty?)
        return ''
      end
      ret = @children.collect(&:to_s).join
      if ret.empty?
        ''
      else
        css = ["menu_level_#{@level}"]
        if active?
          css << "active"
        end
        if self.on_current_page? or @children.any?(&:on_current_page?)
          css << "current"
        end
        view.content_tag(:ul, ret,  :class => css.join(" "))
      end
    end
    
    def active?
      @children.any?(&:active?) || on_current_page?
    end
    
    def on_current_page?
      if (@link == nil)
        return false
      end
      if (@link == @@controller.request.request_uri)
        return true
      end
      link_points_to = ActionController::Routing::Routes.recognize_path(@link, :method => @method)
      req_points_to = @@controller.instance_variable_get(:@_params)
      if (@ctrl != false && req_points_to[:controller] == link_points_to[:controller])
        return true
      end
      req_points_to == link_points_to
    end

    memoize :get_breadcrumb
    memoize :active?
    memoize :on_current_page?
  end

  class Menu < MenuItem
    def initialize(controller, view, opts = {}, &block)
      @@controller = controller
      @@view = view
      @level = 0
      @opts = {:class => 'menu'}.merge opts
      @children = []
      yield self if block_given?
    end
    
    def to_s
      opts = @opts
      if (!active?)
        opts[:class] += " current"
      end
      view.content_tag(:ul, @children.collect(&:to_s).join, opts)
    end

    def to_breadcrumb
      bc = get_breadcrumb
      ret = [ MenuItem.new(I18n.t(:menu_root), "/", 0) ]
      if bc.nil?
        ret += [view.content_tag :li, view.title]
      else
        bc = bc.dup
        last = bc.pop.dup
        last.link = nil
        bc.push(last)
        ret += bc.collect{|item| item.to_s_breadcrumb}.
          reject{|item| item.nil? or item.empty?}.
          collect { |item| view.content_tag :li, item }
      end
      view.content_tag :ul, ret.join,
        :class => "breadcrumbs" + (active? ? "" : " current")
    end
    
    protected
    
    def to_s_breadcrumb
      nil
    end
  end
end