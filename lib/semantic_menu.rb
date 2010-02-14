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
        return []
      end
      @children.map{ |child| child.get_breadcrumb }.
        flatten.compact.unshift(self)
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
      link_points_to = if ActionController::Routing::Routes.respond_to? :recognize_path
        ActionController::Routing::Routes.recognize_path(@link, :method => @method)
      else
        ActionDispatch::Routing::Routes.recognize_path(@link, :method => @method)
      end
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
      view.content_tag(:ul, @children.join, opts)
    end

    def to_breadcrumb
      thispage = @@controller.session[:thispage]
      crumbs = @@controller.session[:crumbs]
      if @@controller.session.has_key?(:crumbs) and crumbs.size > 0
        #Rails.logger.info "Original crumbs: #{crumbs.inspect}"
        if ((key = crumbs.assoc(thispage)))
          crumbs.slice!(crumbs.index(key)+1..-1)
          #Rails.logger.info "Page found in #{crumbs.index(key)}th element, stripping: #{crumbs.inspect}"
        else
          crumbs.push([thispage, @@view.title])
          #Rails.logger.info "New page, push #{thispage}: #{crumbs.inspect}"
        end
      else
        @@controller.session[:crumbs] = crumbs = path_to_breadcrumb
        #Rails.logger.info "No crumbs found, generating: #{crumbs.inspect}"
      end
      scrumbs = (crumbs[0..-2] << [nil, crumbs[-1][1]]).reject do |link, title|
        title.nil? or title.empty?
      end.map do |link, title|
        unless title.nil?
          title = title.html_safe
          link.nil? ? title : @@view.link_to(title, link)
        end
      end
      scrumbs = scrumbs.join(" &raquo; ".html_safe)
      if (crumbs.length == 1)
        scrumbs += " &raquo;".html_safe
      end
      scrumbs.html_safe
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