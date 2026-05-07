import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox", "state"]

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(cb => { cb.checked = checked })
  }
}
