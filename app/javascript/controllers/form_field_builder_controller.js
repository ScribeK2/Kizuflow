import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fieldList", "choices"]
  static values = { fieldTypes: Array }

  connect() {
    this.fieldCount = this.fieldListTarget.children.length
  }

  addField() {
    this.fieldCount++
    const row = document.createElement("div")
    row.className = "form-field-row"
    row.dataset.position = this.fieldCount

    const inputs = document.createElement("div")
    inputs.className = "form-field-row__inputs"

    const nameInput = this.createInput("text", "step[options][][name]", "field_name")
    const labelInput = this.createInput("text", "step[options][][label]", "Label")
    const typeSelect = this.createTypeSelect()
    const requiredLabel = this.createRequiredCheckbox()
    const choicesInput = this.createChoicesInput()
    const positionInput = this.createHidden("step[options][][position]", this.fieldCount)
    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.className = "btn btn--negative btn--sm"
    removeBtn.textContent = "Remove"
    removeBtn.dataset.action = "form-field-builder#removeField"

    inputs.append(nameInput, labelInput, typeSelect, requiredLabel, choicesInput, positionInput, removeBtn)
    row.appendChild(inputs)
    this.fieldListTarget.appendChild(row)
  }

  removeField(event) {
    event.target.closest(".form-field-row").remove()
  }

  // A select field is the only one with choices to author. The input stays in
  // the DOM either way — `options` posts unindexed, so a key present on some
  // rows and absent on others is how Rails' grouping goes wrong.
  toggleChoices(event) {
    const row = event.target.closest(".form-field-row")
    const choices = row?.querySelector("[data-form-field-builder-target='choices']")
    if (choices) choices.hidden = event.target.value !== "select"
  }

  createInput(type, name, placeholder) {
    const input = document.createElement("input")
    input.type = type
    input.name = name
    input.placeholder = placeholder
    input.className = "form-input form-input--sm"
    input.required = true
    return input
  }

  createTypeSelect() {
    const select = document.createElement("select")
    select.name = "step[options][][field_type]"
    select.className = "form-select form-select--sm"
    this.fieldTypesValue.forEach(t => {
      const opt = document.createElement("option")
      opt.value = t
      opt.textContent = t.charAt(0).toUpperCase() + t.slice(1)
      select.appendChild(opt)
    })
    return select
  }

  createChoicesInput() {
    const input = document.createElement("input")
    input.type = "text"
    input.name = "step[options][][select_options_raw]"
    input.placeholder = "Choices, comma separated"
    input.className = "form-input form-input--sm"
    input.dataset.formFieldBuilderTarget = "choices"
    input.hidden = true
    return input
  }

  createRequiredCheckbox() {
    const label = document.createElement("label")
    label.className = "form-checkbox-label"
    const cb = document.createElement("input")
    cb.type = "checkbox"
    cb.name = "step[options][][required]"
    cb.value = "true"
    cb.className = "form-checkbox"
    label.appendChild(cb)
    label.append(" Required")
    return label
  }

  createHidden(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    return input
  }
}
