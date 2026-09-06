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
    this.scheduleSave()
  }

  removeField(event) {
    event.target.closest(".form-field-row").remove()
    this.scheduleSave()
  }

  // Adding or deleting a field is a change to `options` like any other, but
  // neither fires an input or change event, so neither reaches the autosave
  // action on the wrapper. Dispatching a bubbling change is how they join it —
  // rather than reaching for the autosave controller directly, which would tie
  // this controller to that one.
  scheduleSave() {
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
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
    // The ERB version carries this; the JS one did not, so choosing "select" on
    // a freshly added row never revealed its choices box.
    select.dataset.action = "change->form-field-builder#toggleChoices"
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
