module SemanticMenu
  class MenuItem
    attr_accessor :children, :link, :title
    cattr_accessor :ctrl
    cattr_accessor :view
    extend ActiveSupport::Memoizable

    def initialize(title, link, level = 0, opts = {})
      @title = title
      @link = link
      @method = opts.delete(:method) || :get
      @ctrl = opts.delete(:ctrl) || false
      @level = level
      @opts = opts
      @children = []
    end

    def add(title, link = nil, opts = {}, &block)
      MenuItem.new(title, link, @level + 1, opts).tap do |item|
        @children << item
        yield item if block_given?
      end
    end

    def to_s
      ret = ""
      unless @link.nil?
        has_link = true
        ret = @@view.link_to(@title, @link, @opts)
      end
      if ret.empty?
        has_link = false
        ret = @@view.content_tag(:span, @title)
      end
      children = to_s_children
      unless children.empty?
        has_link = true
        ret << children
      end
      if has_link and !ret.empty?
        ret = view.content_tag :li, ret, active? ? {:class => "active"} : {}
      end
    end

    def active?
      @children.any?(&:active?) || on_current_page?
    end

    protected

      def get_breadcrumb
        unless active?
          return []
        end
        @children.map{ |child| child.get_breadcrumb }.
          flatten.compact.unshift(self)
      end

      def to_s_children
        ret = ''.html_safe
        if @children.empty?
          return ret
        end
        ret = @children.inject(ret) do |ret, child|
          ret.safe_concat child.to_s.html_safe
        end
        if ret.empty?
          ret
        else
          css = ["menu_level_#{@level}"]
          if active?
            css << "active"
          end
          if self.on_current_page? or @children.any?(&:on_current_page?)
            css << "current"
          end
          view.content_tag(:ul, ret, :class => css.join(" "))
        end
      end

      def on_current_page?
        if @link.nil?
          return false
        end
        if @link == @@ctrl.request.fullpath
          return true
        end
        link_points_to = Rails.application.routes.recognize_path(@link, :method => @method)
        req_points_to = @@ctrl.instance_variable_get(:@_params)
        if @ctrl != false && req_points_to[:@@ctrl] == link_points_to[:@@ctrl]
          return true
        end
        req_points_to == link_points_to
      end

      memoize :get_breadcrumb
      memoize :active?
      memoize :on_current_page?
  end

  class Menu < MenuItem
    def initialize(ctrl, view, opts = {}, &block)
      @@ctrl = ctrl
      @@view = view
      @level = 0
      @opts = {:class => 'menu'}.merge opts
      @children = []
      yield self if block_given?
    end

    def to_s
      opts = @opts
      if !active?
        opts[:class] += " current"
      end
      @@view.content_tag(:ul, @children.inject(''.html_safe) {|r, e| r << e.to_s.html_safe}, opts)
    end

    def to_breadcrumb
      thispage = @@ctrl.request.fullpath
      crumbs = @@ctrl.session[:crumbs]
      if @@ctrl.session.has_key?(:crumbs) and crumbs.size > 0
        if (key = crumbs.assoc(thispage))
          crumbs.slice!(crumbs.index(key)+1..-1)
        else
          crumbs.push([thispage, @@view.title])
        end
      else
        @@ctrl.session[:crumbs] = crumbs = path_to_breadcrumb
      end
      scrumbs = (crumbs[0..-2] << [nil, crumbs[-1][1]]).map do |link, title|
        title = @@view.send(:h, title)
        link.nil? ? title.html_safe : @@view.link_to(title, link)
      end
      scrumbs = scrumbs.join(" &raquo; ").html_safe
      if crumbs.length == 1
        scrumbs << " &raquo;".html_safe
      end
      crumbs
    end

    def get_breadcrumb
      [[@@view.url_for(:root) || "/", I18n.t(:menu_root)]] + super
    end

    def path_to_breadcrumb
      bc = get_breadcrumb
      if bc.nil?
        return [["/", "/"]]
      end
      bc.map { |item| item.is_a?(Array) ? item : [item.link, item.title] }
    end
  end
end
