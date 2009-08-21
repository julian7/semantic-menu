module SemanticMenuHelper
  def semantic_menu(opts = {}, &block)
    ::SemanticMenu::Menu.new(controller, self, opts, &block)
  end
end