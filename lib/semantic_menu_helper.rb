module SemanticMenuHelper
  def semantic_menu(opts = {}, &block)
    ::SemanticMenu::Menu.new(controller, self, opts, &block)
  end

  def previous_page(by = 1)
    begin
      (session[:crumbs][-by] || session[:crumbs[0]])[0]
    rescue
      return "/"
    end
  end
end