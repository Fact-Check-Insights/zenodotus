import { Controller } from "@hotwired/stimulus"

// Copies the value of the `source` target to the clipboard, briefly relabelling the button
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copiedLabel: { type: String, default: "Copied!" } }

  copy(event) {
    event.preventDefault()
    const originalLabel = this.buttonTarget.innerText
    navigator.clipboard.writeText(this.sourceTarget.value).then(() => {
      this.buttonTarget.innerText = this.copiedLabelValue
      setTimeout(() => {
        this.buttonTarget.innerText = originalLabel
      }, 2000)
    })
  }
}
