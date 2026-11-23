Product.find_or_create_by!(name: "Домашний органайзер") do |product|
  product.price = 2490
  product.category = "Дом"
  product.description = "Компактная система хранения для мелочей, документов и аксессуаров. Дизайн в нейтральной палитре подходит для любого интерьера."
  product.image_url = "https://images.unsplash.com/photo-1517705008128-361805f42e86?auto=format&fit=crop&w=900&q=80"
  product.featured = true
end

Product.find_or_create_by!(name: "Мини-лампа для рабочего стола") do |product|
  product.price = 1890
  product.category = "Рабочее пространство"
  product.description = "Тёплый свет и регулируемая яркость для комфортной работы и чтения в вечернее время."
  product.image_url = "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=80"
  product.featured = true
end

Product.find_or_create_by!(name: "Кофейный набор") do |product|
  product.price = 3290
  product.category = "Кухня"
  product.description = "Набор из кружки, шейкера и аксессуаров для уютного завтрака и спокойных утренних ритуалов."
  product.image_url = "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80"
  product.featured = false
end
