import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "category", "description", "button", "status"]
  static values = { url: String }

  async generate() {
    const name = this.nameTarget.value.trim()
    if (!name) {
      this.statusTarget.textContent = "Сначала укажите название товара."
      this.nameTarget.focus()
      return
    }

    this.buttonTarget.disabled = true
    this.statusTarget.textContent = "Готовлю описание..."

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          name,
          category: this.categoryTarget.value.trim()
        })
      })
      const result = await response.json()

      if (!response.ok) {
        throw new Error(result.error || "Не удалось создать описание.")
      }

      this.descriptionTarget.value = result.description
      this.descriptionTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.statusTarget.textContent = "Черновик готов. Проверьте и при необходимости отредактируйте его."
    } catch (error) {
      this.statusTarget.textContent = error.message || "Не удалось создать описание."
    } finally {
      this.buttonTarget.disabled = false
    }
  }
}
