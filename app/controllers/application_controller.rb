class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :admin?, :cart, :cart_count, :cart_total

  def current_user
    Current.user
  end

  def admin?
    current_user&.admin?
  end

  def cart
    session[:cart] ||= {}
  end

  def cart_count
    cart.values.sum(&:to_i)
  end

  def cart_total
    cart_items.sum { |item| item[:product].price * item[:quantity] }
  end

  def cart_items
    cart.to_h.map do |product_id, quantity|
      product = Product.find_by(id: product_id)
      next if product.nil?

      {
        product: product,
        quantity: quantity.to_i,
        subtotal: product.price * quantity.to_i
      }
    end.compact
  end

  def require_admin
    return if admin?

    redirect_to root_path, alert: "У вас нет доступа к управлению товарами."
  end
end
