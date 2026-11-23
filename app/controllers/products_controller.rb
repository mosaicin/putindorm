class ProductsController < ApplicationController
  MAX_PRODUCT_NAME_LENGTH = 160
  MAX_CATEGORY_LENGTH = 80
  MAX_GENERATED_DESCRIPTION_LENGTH = 2_000

  allow_unauthenticated_access only: %i[ index show ]
  before_action :require_admin, except: %i[ index show ]
  before_action :set_product, only: %i[ show edit update destroy ]
  rate_limit to: 5, within: 3.minutes, only: :generate_description, with: -> {
    render json: { error: "Слишком много запросов. Попробуйте позже." }, status: :too_many_requests
  }

  def index
    @products = Product.all
  end

  def show
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to products_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to @product
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path
  end

  def generate_description
    name = params[:name].to_s.strip
    category = params[:category].to_s.strip

    if name.blank?
      return render json: { error: "Сначала укажите название товара." }, status: :unprocessable_entity
    end

    if name.length > MAX_PRODUCT_NAME_LENGTH || category.length > MAX_CATEGORY_LENGTH
      return render json: { error: "Название или категория слишком длинные." }, status: :unprocessable_entity
    end

    description = AiDescriptionService.new.generate_description(name, category: category)
    if description.blank?
      return render json: { error: "Не удалось получить описание. Попробуйте ещё раз позже." }, status: :service_unavailable
    end

    if description.length > MAX_GENERATED_DESCRIPTION_LENGTH
      return render json: { error: "ИИ вернул слишком длинное описание. Попробуйте ещё раз." }, status: :bad_gateway
    end

    render json: { description: description.strip }
  end

  private
    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.expect(product: [ :name, :price, :description, :image_url, :category, :featured ])
    end
end
